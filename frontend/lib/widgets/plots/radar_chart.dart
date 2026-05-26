// ignore_for_file: prefer_adjacent_string_concatenation

import 'dart:math';

import 'package:cats/models/result.dart';
import 'package:cats/providers/results_provider.dart';
import 'package:cats/widgets/plots/result_helper.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AucGraphType { skillAdjusted, notAdjusted }

class MetricsRadarChart extends ConsumerStatefulWidget {
  const MetricsRadarChart({super.key, required this.data, required this.hiddenPipeIndexes, required this.screenSize});

  final List<PipeResult> data;
  final List<int> hiddenPipeIndexes;
  final ScreenSize screenSize;

  @override
  ConsumerState<MetricsRadarChart> createState() => _MetricsRadarChartState();
}

class _MetricsRadarChartState extends ConsumerState<MetricsRadarChart> {
  late AucGraphType _graphType;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _graphType = ref.read(previousAucGraphTypeProvider);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pipeResults = widget.data;
    List<RadarDataSet> radarDataSets = [];

    _ensureConsistentScaling(radarDataSets);
    List<({RadarChartTitle label, RadarEntry relative, RadarEntry absolute})> allEntries = [];

    for (int index = 0; index < pipeResults.length; index++) {
      final data = pipeResults[index].results.generalMetrics;

      // entries start at the top and go clockwise
      allEntries = [
        (
          label: RadarChartTitle(text: "AUROC", angle: 0, positionPercentageOffset: 0.05),
          relative: RadarEntry(value: max(data.alertsAucRelative ?? 0.0, 0.0)),
          absolute: RadarEntry(value: data.alertsAucAbsolute ?? 0.0),
        ),
        (
          label: RadarChartTitle(text: "IBBS", angle: 32),
          relative: RadarEntry(value: max(data.alertsBrierScoreRelative ?? 0.0, 0.0)),
          absolute: RadarEntry(value: data.alertsBrierScoreAbsolute),
        ),
        (
          label: RadarChartTitle(text: "Freq.-adj. IBBS", angle: -32),
          relative: RadarEntry(value: max(data.alertTypesBrierScoreRelative ?? 0.0, 0.0)),
          absolute: RadarEntry(value: data.alertTypesBrierScoreAbsolute ?? 0.0),
        ),
        (
          label: RadarChartTitle(text: "Freq.-adj. AUROC", angle: 0),
          relative: RadarEntry(value: max(data.alertTypesAucRelative ?? 0.0, 0.0)),
          absolute: RadarEntry(value: data.alertTypesAucAbsolute ?? 0.0),
        ),
        (
          label: RadarChartTitle(text: "Freq.-adj. AP", angle: 32),
          relative: RadarEntry(value: max(data.alertTypesAveragePrecisionRelative ?? 0.0, 0.0)),
          absolute: RadarEntry(value: data.alertTypesAveragePrecisionAbsolute ?? 0.0),
        ),
        (
          label: RadarChartTitle(text: "AP", angle: -32, positionPercentageOffset: 0.05),
          relative: RadarEntry(value: max(data.alertsAveragePrecisionRelative, 0.0)),
          absolute: RadarEntry(value: data.alertsAveragePrecisionAbsolute),
        ),
      ];

      List<RadarEntry> usedEntries = [];
      if (_graphType == AucGraphType.skillAdjusted) {
        usedEntries = allEntries.map((entry) => entry.relative).toList();
      } else if (_graphType == AucGraphType.notAdjusted) {
        usedEntries = allEntries.map((entry) => entry.absolute).toList();
      } else {
        throw Exception("Unknown AUC graph type: $_graphType");
      }

      radarDataSets.add(
        RadarDataSet(
          fillColor: pipeResults[index].plotColor!.withValues(alpha: 0.2),
          borderColor: pipeResults[index].plotColor,
          dataEntries: usedEntries,
          entryRadius: 0,
        ),
      );
    }

    _addAnimationHelperLines(radarDataSets, widget.hiddenPipeIndexes);
    if (_graphType == AucGraphType.notAdjusted) {
      _addNoSkillLine(radarDataSets, pipeResults[0], context);
    }

    final TextStyle? titleStyle = widget.screenSize == ScreenSize.large
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.titleSmall!.copyWith(fontSize: 13);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                DropdownButton(
                  items: [
                    DropdownMenuItem(
                      value: AucGraphType.skillAdjusted,
                      child: Text("Skill score", style: titleStyle),
                    ),
                    DropdownMenuItem(
                      value: AucGraphType.notAdjusted,
                      child: Text("Unadjusted score", style: titleStyle),
                    ),
                  ],
                  value: _graphType,
                  isDense: true,
                  focusNode: _focusNode,
                  onChanged: (newType) {
                    setState(() {
                      _graphType = newType as AucGraphType;
                      ref.read(previousAucGraphTypeProvider.notifier).updatePreviousType(newType);
                    });
                  },
                  onTap: () {
                    _focusNode.unfocus();
                    FocusScope.of(context).unfocus();
                  },
                ),
                SizedBox(width: 24),
                if (_graphType == AucGraphType.notAdjusted) _noSkillLegendItem(context),
                if (_graphType == AucGraphType.skillAdjusted)
                  Text("0 = no skill", style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            Tooltip(
              richMessage: WidgetSpan(
                child: SizedBox(
                  width: 400,
                  child: Text(
                    "AUROC - Area Under the Receiver Operating Characteristic Curve\n" +
                        "AP - Average Precision\n" +
                        "IBBS - Inverse Balanced Brier Score\n\n" +
                        "The skill score for each metric is the absolute score scaled from [\"no skill\", 1] to  [0, 1]. " +
                        "Note that the no skill score for IBBS equals 0.75, while for AUROC and AP it is equal to the TP prevalence. " +
                        "Values below zero are not visualized to focus on the improvement over no skill.\n\n" +
                        "The frequency-adjusted metrics weigh each alert with the inverse frequency of its alert type, thus giving the same weight to each alert type in the resulting score. " +
                        "The no skill score for frequency-adjusted metrics is calculated accordingly using the same weights (for AUROC and AP).\n\n" +
                        "The numeric scores on the right represent the arithmetic mean of all displayed metrics, scaled to [0, 100].",
                    softWrap: true,
                    style: TextStyle(color: Theme.of(context).colorScheme.onInverseSurface),
                  ),
                ),
              ),
              waitDuration: Duration(milliseconds: 100),
              child: CircleAvatar(radius: 12, child: Icon(Icons.question_mark, size: 16)),
            ),
          ],
        ),
        AspectRatio(
          aspectRatio: 1.13,
          child: Stack(
            children: [
              RadarChart(
                RadarChartData(
                  isMinValueAtCenter: true,
                  dataSets: radarDataSets,
                  getTitle: (index, angle) => allEntries[index].label,
                  radarBackgroundColor: Colors.transparent,
                  radarShape: RadarShape.polygon,
                  radarBorderData: BorderSide(
                    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.4),
                    width: 2,
                  ),
                  gridBorderData: BorderSide(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7)),
                  titlePositionPercentageOffset: 0.1,
                  borderData: FlBorderData(show: false),
                  tickBorderData: BorderSide(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.4)),
                  tickCount: 5,
                ),
              ),
              _AccumulatedScoreOverview(pipeResults: pipeResults, graphType: _graphType),
            ],
          ),
        ),
      ],
    );
  }
}

void _ensureConsistentScaling(List<RadarDataSet> radarDataSets) {
  // workaround because RadarChart() does not support setting min/max values
  List<List<double>> visData = [
    [0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    [1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
  ];
  for (var data in visData) {
    radarDataSets.add(
      RadarDataSet(
        fillColor: Colors.transparent,
        borderColor: Colors.transparent,
        dataEntries: data.map((e) => RadarEntry(value: e)).toList(),
        entryRadius: 0,
      ),
    );
  }
}

void _addAnimationHelperLines(List<RadarDataSet> radarDataSets, List<int> hiddenPipeIndexes) {
  for (var index in hiddenPipeIndexes) {
    radarDataSets.insert(
      // +2 due to the two empty datasets added for scaling
      index + 2,
      RadarDataSet(
        fillColor: Colors.transparent,
        borderColor: Colors.transparent,
        dataEntries: [
          RadarEntry(value: 0),
          RadarEntry(value: 0),
          RadarEntry(value: 0),
          RadarEntry(value: 0),
          RadarEntry(value: 0),
          RadarEntry(value: 0),
        ],
        entryRadius: 0,
      ),
    );
  }
}

void _addNoSkillLine(List<RadarDataSet> radarDataSets, PipeResult pipeResult, BuildContext context) {
  bool noMixedSubgroups = pipeResult.results.generalMetrics.alertTypesAveragePrecisionNoSkill == null;

  radarDataSets.add(
    RadarDataSet(
      fillColor: Colors.transparent,
      borderColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
      borderWidth: 2,
      dataEntries: [
        RadarEntry(value: 0.5), // AUROC no skill
        RadarEntry(value: 0.75), // IBBS no skill
        RadarEntry(value: noMixedSubgroups ? 0.0 : 0.75), // IBBS (alert types) no skill
        RadarEntry(value: noMixedSubgroups ? 0.0 : 0.5), // AUROC (alert types) no skill
        RadarEntry(
          value: pipeResult.results.generalMetrics.alertTypesAveragePrecisionNoSkill ?? 0,
        ), // AP (alert types) no skill
        RadarEntry(value: pipeResult.results.generalMetrics.tpPrevalence), // AP no skill
      ],
      entryRadius: 0,
    ),
  );
}

Widget _noSkillLegendItem(BuildContext context) {
  return buildLineLegendItem(
    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8),
    label: 'No skill',
    labelStyle: Theme.of(context).textTheme.bodySmall,
    lineLength: 30,
    isDense: true,
  );
}

class _AccumulatedScoreOverview extends StatelessWidget {
  const _AccumulatedScoreOverview({required this.pipeResults, required this.graphType});

  final List<PipeResult> pipeResults;
  final AucGraphType graphType;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment(0.8, 0.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (PipeResult pipeResult in pipeResults)
            Text(
              ((graphType == AucGraphType.skillAdjusted
                          ? pipeResult.results.generalMetrics.compositeScoreRelative
                          : pipeResult.results.generalMetrics.compositeScoreAbsolute) *
                      100)
                  .toStringAsFixed(0),
              style: Theme.of(
                context,
              ).textTheme.bodyLarge!.copyWith(color: pipeResult.plotColor!, fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }
}
