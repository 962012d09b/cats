import 'package:cats/providers/results_provider.dart';
import 'package:cats/widgets/plots/result_helper.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cats/models/result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum MultiUseGraphType {
  precisionRecall("Precision/Recall"),
  precision("Precision"),
  recall("Recall"),
  f1("F1"),
  mcc("MCC"),
  roc("ROC");

  final String value;
  const MultiUseGraphType(this.value);
}

class MultiUseCurve extends ConsumerStatefulWidget {
  const MultiUseCurve({super.key, required this.data, required this.hiddenPipeIndexes, required this.screenSize});

  final List<PipeResult> data;
  final List<int> hiddenPipeIndexes;
  final ScreenSize screenSize;

  @override
  ConsumerState<MultiUseCurve> createState() => _MultiUseCurveState();
}

class _MultiUseCurveState extends ConsumerState<MultiUseCurve> {
  late MultiUseGraphType _graphType;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _graphType = ref.read(previousMultiUseGraphTypeProvider);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<LineChartBarData> lines = [];

    for (final completedPipe in widget.data) {
      final scoreCutoffPoints = completedPipe.results.metricsPerScore.keys.toList()
        ..sort((a, b) => b.compareTo(a)); // High to low

      if (_graphType == MultiUseGraphType.precision) {
        lines.add(_getPrecisionLine(completedPipe, scoreCutoffPoints));
      } else if (_graphType == MultiUseGraphType.recall) {
        lines.add(_getRecallLine(completedPipe, scoreCutoffPoints));
      } else if (_graphType == MultiUseGraphType.precisionRecall) {
        lines.add(_getPrecisionRecallLine(completedPipe, scoreCutoffPoints));
      } else if (_graphType == MultiUseGraphType.f1) {
        lines.add(_getF1Line(completedPipe, scoreCutoffPoints));
      } else if (_graphType == MultiUseGraphType.mcc) {
        lines.add(_getMccLine(completedPipe, scoreCutoffPoints));
      } else if (_graphType == MultiUseGraphType.roc) {
        lines.add(_getRocLine(completedPipe, scoreCutoffPoints));
      } else {
        throw Exception("Unknown graph type");
      }
    }

    _addAnimationHelperLines(lines, widget.hiddenPipeIndexes);
    _addNoSkillLine(lines, widget.data, _graphType, Theme.of(context).colorScheme.primary);

    final TextStyle? titleStyle = widget.screenSize == ScreenSize.large
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.titleSmall!.copyWith(fontSize: 13);

    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            DropdownButton(
              items: [
                DropdownMenuItem(
                  value: MultiUseGraphType.precisionRecall,
                  child: Text("Precision/Recall", style: titleStyle),
                ),
                DropdownMenuItem(
                  value: MultiUseGraphType.precision,
                  child: Text("Precision", style: titleStyle),
                ),
                DropdownMenuItem(
                  value: MultiUseGraphType.recall,
                  child: Text("Recall", style: titleStyle),
                ),
                DropdownMenuItem(
                  value: MultiUseGraphType.f1,
                  child: Text("F1", style: titleStyle),
                ),
                DropdownMenuItem(
                  value: MultiUseGraphType.mcc,
                  child: Text("MCC", style: titleStyle),
                ),
                DropdownMenuItem(
                  value: MultiUseGraphType.roc,
                  child: Text("ROC", style: titleStyle),
                ),
              ],
              value: _graphType,
              isDense: true,
              focusNode: _focusNode,
              onChanged: (newType) {
                setState(() {
                  _graphType = newType as MultiUseGraphType;
                  ref.read(previousMultiUseGraphTypeProvider.notifier).updatePreviousType(_graphType);
                });
              },
              onTap: () {
                _focusNode.unfocus();
                FocusScope.of(context).unfocus();
              },
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: _buildLegend(context, widget.data[0].plotColor!, _graphType, widget.screenSize),
              ),
            ),
          ],
        ),
        SizedBox(height: 20),
        AspectRatio(
          aspectRatio: widget.screenSize == ScreenSize.large ? 1.2 : 1.26,
          child: LineChart(
            LineChartData(
              minY: _minYforGraphType(_graphType),
              minX: 0,
              maxY: 1,
              maxX: _maxXforGraphType(_graphType, widget.data),
              borderData: FlBorderData(
                border: Border(
                  bottom: BorderSide(color: Theme.of(context).colorScheme.secondary),
                  left: BorderSide(color: Theme.of(context).colorScheme.secondary),
                ),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  axisNameWidget: Text(_xAxisLabelForGraphType(_graphType)),
                  sideTitles: _graphType == MultiUseGraphType.roc
                      ? SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: _convertRocLabels)
                      : SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          maxIncluded: _graphType == MultiUseGraphType.precisionRecall,
                        ),
                ),
                leftTitles: AxisTitles(
                  axisNameWidget: Text(_yAxisLabelForGraphType(_graphType)),
                  axisNameSize: 20,
                  sideTitles: _graphType == MultiUseGraphType.roc
                      ? SideTitles(showTitles: true, reservedSize: 35, getTitlesWidget: _convertRocLabels)
                      : SideTitles(showTitles: true, reservedSize: 35),
                ),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: lines,
              lineTouchData: LineTouchData(enabled: false),
            ),
          ),
        ),
      ],
    );
  }
}

LineChartBarData _getPrecisionRecallLine(PipeResult pipeResult, List<double> scoreCutoffPoints) {
  var data = pipeResult.results;

  final precisionRecallX = scoreCutoffPoints.map((score) => data.metricsPerScore[score]!.recall).toList();
  final precisionRecallY = scoreCutoffPoints.map((score) => data.metricsPerScore[score]!.precision).toList();

  precisionRecallX.insert(0, 0);
  precisionRecallY.insert(0, precisionRecallY[0]);

  List<double> prWithStepsX = [];
  List<double> prWithStepsY = [];

  for (var i = 0; i < precisionRecallX.length - 1; i++) {
    prWithStepsX.add(precisionRecallX[i]);
    prWithStepsY.add(precisionRecallY[i]);

    prWithStepsX.add(precisionRecallX[i]);
    prWithStepsY.add(precisionRecallY[i + 1]);
  }
  prWithStepsX.add(precisionRecallX.last);
  prWithStepsY.add(precisionRecallY.last);

  List<FlSpot> precisionRecallPoints = [];
  for (var i = 0; i < prWithStepsX.length; i++) {
    precisionRecallPoints.add(FlSpot(prWithStepsX[i], prWithStepsY[i]));
  }

  return LineChartBarData(dotData: FlDotData(show: false), spots: precisionRecallPoints, color: pipeResult.plotColor!);
}

LineChartBarData _getPrecisionLine(PipeResult pipeResult, List<double> scoreCutoffPoints) {
  var data = pipeResult.results;

  final precisionX = scoreCutoffPoints
      .map((score) => data.alertCountPerScoreAccumulated.allExceptUnknown[score]!.toDouble())
      .toList();
  final precisionY = scoreCutoffPoints.map((score) => data.metricsPerScore[score]!.precision).toList();

  precisionX.insert(0, 0);
  precisionY.insert(0, precisionY[0]);

  List<FlSpot> precision = [];
  for (var i = 0; i < precisionX.length; i++) {
    precision.add(FlSpot(precisionX[i], precisionY[i]));
  }

  return LineChartBarData(dotData: FlDotData(show: false), spots: precision, color: pipeResult.plotColor!);
}

LineChartBarData _getRecallLine(PipeResult pipeResult, List<double> scoreCutoffPoints) {
  var data = pipeResult.results;

  final recallX = scoreCutoffPoints
      .map((score) => data.alertCountPerScoreAccumulated.allExceptUnknown[score]!.toDouble())
      .toList();
  final recallY = scoreCutoffPoints.map((score) => data.metricsPerScore[score]!.recall).toList();

  recallX.insert(0, 0);
  recallY.insert(0, 0);

  List<FlSpot> recall = [];
  for (var i = 0; i < recallX.length; i++) {
    recall.add(FlSpot(recallX[i], recallY[i]));
  }

  return LineChartBarData(dotData: FlDotData(show: false), barWidth: 3, spots: recall, color: pipeResult.plotColor!);
}

LineChartBarData _getF1Line(PipeResult pipeResult, List<double> scoreCutoffPoints) {
  var data = pipeResult.results;

  final f1X = scoreCutoffPoints
      .map((score) => data.alertCountPerScoreAccumulated.allExceptUnknown[score]!.toDouble())
      .toList();
  final f1Y = scoreCutoffPoints.map((score) => data.metricsPerScore[score]!.f1).toList();

  f1X.insert(0, 0);
  f1Y.insert(0, 0);

  List<FlSpot> f1 = [];
  for (var i = 0; i < f1X.length; i++) {
    f1.add(FlSpot(f1X[i], f1Y[i]));
  }

  return LineChartBarData(dotData: FlDotData(show: false), barWidth: 3, spots: f1, color: pipeResult.plotColor!);
}

LineChartBarData _getMccLine(PipeResult pipeResult, List<double> scoreCutoffPoints) {
  var data = pipeResult.results;

  final mccX = scoreCutoffPoints
      .map((score) => data.alertCountPerScoreAccumulated.allExceptUnknown[score]!.toDouble())
      .toList();
  final mccY = scoreCutoffPoints.map((score) => data.metricsPerScore[score]!.mcc).toList();

  mccX.insert(0, 0);
  mccY.insert(0, 0);

  List<FlSpot> mcc = [];
  for (var i = 0; i < mccX.length; i++) {
    mcc.add(FlSpot(mccX[i], mccY[i]));
  }

  return LineChartBarData(dotData: FlDotData(show: false), barWidth: 3, spots: mcc, color: pipeResult.plotColor!);
}

LineChartBarData _getRocLine(PipeResult pipeResult, List<double> scoreCutoffPoints) {
  var data = pipeResult.results;

  final rocX = scoreCutoffPoints.map((score) => data.metricsPerScore[score]!.fpr).toList();
  final rocY = scoreCutoffPoints.map((score) => data.metricsPerScore[score]!.tpr).toList();

  rocX.insert(0, 0);
  rocY.insert(0, 0);

  List<FlSpot> roc = [];
  for (var i = 0; i < rocX.length; i++) {
    roc.add(FlSpot(rocX[i], rocY[i]));
  }

  return LineChartBarData(dotData: FlDotData(show: false), barWidth: 3, spots: roc, color: pipeResult.plotColor!);
}

List<Widget> _buildLegend(BuildContext context, Color color, MultiUseGraphType selectedType, ScreenSize screenSize) {
  final List<Widget> legendItems = [];

  final bool isDense = screenSize != ScreenSize.large;
  final double lineLength = screenSize == ScreenSize.large ? 30 : 20;
  final TextStyle? labelStyle = screenSize == ScreenSize.large
      ? Theme.of(context).textTheme.bodySmall
      : Theme.of(context).textTheme.labelSmall;

  legendItems.add(
    buildLineLegendItem(
      color: Theme.of(context).colorScheme.primary,
      label: selectedType.value,
      labelStyle: labelStyle,
      lineLength: lineLength,
      isDense: isDense,
    ),
  );

  legendItems.add(
    buildLineLegendItem(
      color: Theme.of(context).colorScheme.primary,
      isDashed: true,
      label: "No skill",
      dashWidth: 10,
      dashSpace: 10,
      labelStyle: labelStyle,
      lineLength: 30,
      isDense: isDense,
    ),
  );

  return legendItems;
}

void _addNoSkillLine(List<LineChartBarData> lines, List<PipeResult> data, MultiUseGraphType graphType, Color color) {
  final totalAlertCount = data[0].results.totalAlertCount.allExceptUnknown.toDouble();
  final totalTpCount = data[0].results.totalAlertCount.tp;
  final ratio = totalTpCount / totalAlertCount;

  List<FlSpot> spots = [];

  switch (graphType) {
    case MultiUseGraphType.precision:
      spots = [FlSpot(0, ratio), FlSpot(totalAlertCount, ratio)];
      break;
    case MultiUseGraphType.recall:
      spots = [FlSpot(0, 0), FlSpot(totalAlertCount, 1)];
      break;
    case MultiUseGraphType.precisionRecall:
      spots = [FlSpot(0, ratio), FlSpot(1, ratio)];
      break;
    case MultiUseGraphType.f1:
      // https://stats.stackexchange.com/questions/390200/what-is-the-baseline-of-the-f1-score-for-a-binary-classifier
      var alwaysTrueF1 = (2 * ratio) / (1 + ratio);
      spots = [FlSpot(0, 0), FlSpot(totalAlertCount, alwaysTrueF1)];
      break;
    case MultiUseGraphType.mcc:
      spots = [FlSpot(0, 0), FlSpot(totalAlertCount, 0)];
      break;
    case MultiUseGraphType.roc:
      spots = [FlSpot(0, 0), FlSpot(1, 1)];
      break;
  }

  lines.add(LineChartBarData(dotData: FlDotData(show: false), spots: spots, dashArray: [10, 10], color: color));
}

double _maxXforGraphType(MultiUseGraphType graphType, List<PipeResult> data) {
  switch (graphType) {
    case MultiUseGraphType.precision:
    case MultiUseGraphType.recall:
    case MultiUseGraphType.f1:
    case MultiUseGraphType.mcc:
      return data[0].results.totalAlertCount.allExceptUnknown.toDouble();
    case MultiUseGraphType.precisionRecall:
    case MultiUseGraphType.roc:
      return 1;
  }
}

double _minYforGraphType(MultiUseGraphType graphType) {
  switch (graphType) {
    case MultiUseGraphType.precision:
    case MultiUseGraphType.recall:
    case MultiUseGraphType.precisionRecall:
    case MultiUseGraphType.roc:
    case MultiUseGraphType.f1:
      return 0;
    case MultiUseGraphType.mcc:
      return -1;
  }
}

String _xAxisLabelForGraphType(MultiUseGraphType graphType) {
  switch (graphType) {
    case MultiUseGraphType.precision:
    case MultiUseGraphType.recall:
    case MultiUseGraphType.f1:
    case MultiUseGraphType.mcc:
      return "Number of viewed alerts";
    case MultiUseGraphType.precisionRecall:
      return "Recall";
    case MultiUseGraphType.roc:
      return "FPR";
  }
}

String _yAxisLabelForGraphType(MultiUseGraphType graphType) {
  switch (graphType) {
    case MultiUseGraphType.precision:
    case MultiUseGraphType.recall:
    case MultiUseGraphType.f1:
    case MultiUseGraphType.mcc:
      return "Score";
    case MultiUseGraphType.precisionRecall:
      return "Precision";
    case MultiUseGraphType.roc:
      return "TPR";
  }
}

void _addAnimationHelperLines(List<LineChartBarData> lines, List<int> hiddenPipeIndexes) {
  for (final index in hiddenPipeIndexes) {
    lines.insert(index, LineChartBarData(color: Colors.transparent));
  }
}

Text _convertRocLabels(double value, TitleMeta meta) {
  // annoying: Due to floating point imprecision, the values given to this function
  // can be something like 0.30000000000000004 or 0.7999999999999999 (because 0.1 and floats don't mix well)
  // The following is a somewhat lazy way of ensuring we only show the values we want (for the ROC curve)
  if (((value + 0.001) % 0.1).abs() < 0.01) {
    return Text(value.toStringAsFixed(1));
  }

  return const Text("");
}
