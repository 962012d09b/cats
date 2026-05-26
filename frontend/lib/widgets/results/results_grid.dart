import 'package:cats/constants.dart';
import 'package:cats/models/result.dart';
import 'package:cats/providers/results_provider.dart';
import 'package:cats/widgets/plots/dataset_pipeline_statistics.dart';
import 'package:cats/widgets/plots/legend.dart';
import 'package:cats/widgets/plots/multi_use_curve.dart';
import 'package:cats/widgets/plots/radar_chart.dart';
import 'package:cats/widgets/plots/result_helper.dart';
import 'package:cats/widgets/plots/risk_scores.dart';
import 'package:cats/widgets/results/pipe_error_report.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ResultsGrid extends ConsumerWidget {
  const ResultsGrid({super.key, required this.useHorizontalLayout});

  final bool useHorizontalLayout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    List<PipeResult> data = ref.watch(maskedResultsProvider);

    List<PipeResult> pipesWithErrors = data
        .where((element) => element.logs.isNotEmpty && element.logs.any((log) => log.isNotEmpty))
        .toList();
    String errorMsg = "";
    if (pipesWithErrors.length == 1) {
      errorMsg = "Pipeline ${pipesWithErrors[0].name} completed with errors";
    } else if (pipesWithErrors.length > 1) {
      List<String> pipeNames = data.where((element) => element.logs.isNotEmpty).map((e) => e.name).toList();
      String pipeNamesExceptLast = pipeNames.sublist(0, pipesWithErrors.length - 1).join(", ");
      errorMsg = "Pipelines $pipeNamesExceptLast and ${pipeNames.last} completed with errors";
    }

    final List<PipeResult> maskedData = [];
    final List<int> hiddenPipeIndexes = [];
    for (var i = 0; i < data.length; i++) {
      data[i].plotColor = plotColors[i];
      if (data[i].isVisible) {
        maskedData.add(data[i]);
      } else {
        // used to render "invisible lines" at that position so that graph animations are consistent when hiding/showing pipes
        hiddenPipeIndexes.add(i);
      }
    }

    final double currentScreenWidth = MediaQuery.sizeOf(context).width;
    final ScreenSize screenSize;
    if (currentScreenWidth >= largeScreenMinSize) {
      screenSize = ScreenSize.large;
    } else if (currentScreenWidth >= mediumScreenMinSize) {
      screenSize = ScreenSize.medium;
    } else {
      screenSize = ScreenSize.small;
    }

    HorizontalLegend colorLegend = HorizontalLegend(
      segments: [
        for (var i = 0; i < maskedData.length; i++)
          Indicator(
            color: maskedData[i].plotColor!,
            text: maskedData[i].name,
            size: screenSize == ScreenSize.large ? 14 : 12,
          ),
      ],
    );

    final visualizedResults = [
      ResultBuilder(
        title: "Dataset and Pipeline Statistics",
        resultToShow: GeneralOverview(data: maskedData, screenSize: screenSize),
      ),
      ResultBuilder(
        title: "Risk Score Histogram",
        resultToShow: RiskScoresBarChart(data: maskedData, screenSize: screenSize),
        legend: colorLegend,
        innerPadding: EdgeInsets.only(top: 4, bottom: 16, left: 16, right: 16),
      ),
      ResultBuilder(
        title: "Alert Prioritization Performance: Graphs",
        resultToShow: MultiUseCurve(data: maskedData, hiddenPipeIndexes: hiddenPipeIndexes, screenSize: screenSize),
        legend: colorLegend,
        innerPadding: EdgeInsets.only(top: 4, bottom: 16, left: 16, right: 16),
      ),
      ResultBuilder(
        title: "Alert Prioritization Performance: Aggregate Metrics",
        resultToShow: MetricsRadarChart(
          data: maskedData,
          hiddenPipeIndexes: hiddenPipeIndexes,
          screenSize: screenSize,
        ),
        legend: colorLegend,
        innerPadding: EdgeInsets.only(top: 4, bottom: 16, left: 16, right: 16),
      ),
    ];

    return maskedData.isEmpty
        ? SizedBox.shrink()
        : SelectionArea(
            child: Column(
              children: [
                pipesWithErrors.isNotEmpty
                    ? PipeErrorReport(errorMsg: errorMsg, pipesWithErrors: pipesWithErrors)
                    : const SizedBox.shrink(),
                GridView.count(
                  crossAxisCount: useHorizontalLayout
                      ? screenSize == ScreenSize.small
                            ? 2
                            : 4
                      : screenSize == ScreenSize.small
                      ? 1
                      : 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: visualizedResults,
                ),
              ],
            ),
          );
  }
}
