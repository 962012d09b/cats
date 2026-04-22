import 'package:cats/widgets/plots/result_helper.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cats/models/result.dart';

final int _groupCount = 10;
final int _maximumPossibleScore = 1;
typedef _Metrics = ({double tps, double fps});

class RiskScoresBarChart extends StatefulWidget {
  const RiskScoresBarChart({super.key, required this.data, required this.screenSize});

  final List<PipeResult> data;
  final ScreenSize screenSize;

  @override
  State<RiskScoresBarChart> createState() => _RiskScoresBarChartState();
}

class _RiskScoresBarChartState extends State<RiskScoresBarChart> {
  @override
  Widget build(BuildContext context) {
    assert(_groupCount % 10 == 0, '_groupCount must be divisible by 10');

    List<Map<double, int>> alertsPerScorePerPipe = [
      for (var pipe in widget.data) pipe.results.alertCountPerScore.allExceptUnknown,
    ];

    var groupInterval = _maximumPossibleScore / _groupCount;
    var labelsToDisplay = [
      // floating-point imprecision strikes again
      for (int i = 0; i <= 10; i++) double.parse((_maximumPossibleScore * i / 10).toStringAsFixed(10)),
    ];

    List<Map<double, _Metrics>> groupedValues = _groupValues(alertsPerScorePerPipe, widget.data, groupInterval);
    List<BarChartGroupData> barData = [];

    for (var curGroupIndex = 0; curGroupIndex < _groupCount + 1; curGroupIndex++) {
      var curValue = curGroupIndex * groupInterval;
      final List<BarChartRodData> rodData = [];
      List<_Metrics> collectedValues = [
        for (var i = 0; i < alertsPerScorePerPipe.length; i++) groupedValues[i][curValue]!,
      ];

      for (var i = 0; i < collectedValues.length; i++) {
        _Metrics metrics = collectedValues[i];
        if (metrics.tps + metrics.fps == 0) {
          continue;
        }
        rodData.add(_createRodData(metrics, widget.data[i].plotColor!));
      }

      // FLChart doesn't support doubles as x values (for some reason)
      // convert to int here and back to double when generating the labels
      if (rodData.isNotEmpty) {
        barData.add(BarChartGroupData(x: (curValue * 100).toInt(), barRods: rodData, barsSpace: 2));
      } else {
        barData.add(
          // Add empty bar for non-existent values to ensure appropriate spacing between bars
          BarChartGroupData(
            x: (curValue * 100).toInt(),
            barRods: [BarChartRodData(toY: 0, width: 4, color: Colors.transparent)],
            barsSpace: 0,
          ),
        );
      }
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _buildLegend(context, widget.screenSize),
        ),
        SizedBox(height: 20),
        AspectRatio(
          aspectRatio: widget.screenSize == ScreenSize.large ? 1.2 : 1.26,
          child: BarChart(
            BarChartData(
              barGroups: barData,
              alignment: BarChartAlignment.spaceBetween,
              borderData: FlBorderData(
                border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.secondary)),
              ),
              gridData: FlGridData(drawVerticalLine: false),
              titlesData: FlTitlesData(
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  axisNameWidget: Text("Number of alerts"),
                  sideTitles: SideTitles(reservedSize: 50, showTitles: true, maxIncluded: false),
                ),
                bottomTitles: AxisTitles(
                  axisNameWidget: Text("Risk score"),
                  sideTitles: SideTitles(
                    reservedSize: 20,
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      // convert back to [0, 1] range
                      value = value / 100.0;
                      if (labelsToDisplay.contains(value)) {
                        var label = value.toString();
                        return Text(label);
                      }
                      return Text("");
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(enabled: false),
            ),
          ),
        ),
      ],
    );
  }
}

List<Map<double, _Metrics>> _groupValues(
  List<Map<double, int>> mappingPerPipe,
  List<PipeResult> results,
  double groupInterval,
) {
  // sorts all values into _groupCount+1 groups ranging from groupInterval*0 to groupInterval*_groupCount
  var groupedValues = List<Map<double, _Metrics>>.generate(mappingPerPipe.length, (_) {
    var map = <double, _Metrics>{};
    for (int i = 0; i <= _groupCount; i++) {
      map[groupInterval * i] = (tps: 0, fps: 0);
    }
    return map;
  });

  for (var i = 0; i < mappingPerPipe.length; i++) {
    var pipe = mappingPerPipe[i];
    for (var score in pipe.keys) {
      int tps = results[i].results.alertCountPerScore.tp[score] ?? 0;
      int fps = results[i].results.alertCountPerScore.fp[score] ?? 0;
      int group = score ~/ groupInterval;

      groupedValues[i][group * groupInterval] = (
        tps: groupedValues[i][group * groupInterval]!.tps + tps,
        fps: groupedValues[i][group * groupInterval]!.fps + fps,
      );
    }
  }

  return groupedValues;
}

BarChartRodData _createRodData(_Metrics metrics, Color color) {
  return BarChartRodData(
    color: Colors.transparent,
    width: 3,
    toY: metrics.fps + metrics.tps,
    borderDashArray: [2, 2],
    borderSide: BorderSide(color: color, width: 2, strokeAlign: BorderSide.strokeAlignOutside),
    rodStackItems: [
      BarChartRodStackItem(
        0,
        metrics.tps,
        color,
        borderSide: BorderSide(color: color, width: 2, strokeAlign: BorderSide.strokeAlignOutside),
      ),
      BarChartRodStackItem(metrics.tps, metrics.tps + metrics.fps, Colors.transparent),
    ],
  );
}

List<Widget> _buildLegend(BuildContext context, ScreenSize screenSize) {
  final double lineLength = screenSize == ScreenSize.large ? 30 : 20;
  final TextStyle? labelStyle = screenSize == ScreenSize.large
      ? Theme.of(context).textTheme.bodySmall
      : Theme.of(context).textTheme.labelSmall;

  return [
    buildLineLegendItem(
      color: Theme.of(context).colorScheme.primary,
      label: "True Positives",
      labelStyle: labelStyle,
      lineLength: lineLength,
    ),
    buildLineLegendItem(
      color: Theme.of(context).colorScheme.primary,
      label: "False Positives",
      labelStyle: labelStyle,
      lineLength: lineLength,
      isDashed: true,
      dashWidth: 1,
      dashSpace: 3,
    ),
  ];
}
