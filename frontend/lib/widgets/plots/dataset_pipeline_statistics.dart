import 'package:cats/constants.dart';
import 'package:cats/widgets/plots/result_helper.dart';
import 'package:cats/widgets/plots/subplots/alert_count_pie_chart.dart';
import 'package:cats/widgets/plots/subplots/alert_type_pie_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cats/models/result.dart';

final _formatter = NumberFormat('#,##0.#####'); // at most 5 decimal places
final percentageFormatter = NumberFormat('##0.00%'); // at most 2 decimal places

class GeneralOverview extends StatelessWidget {
  const GeneralOverview({super.key, required this.data, required this.screenSize});

  final List<PipeResult> data;
  final ScreenSize screenSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AlertCountPieChart(data: data[0], screenSize: screenSize),
              AlertTypePieChart(
                data: data[0],
                colorsPalette: _generateColorPalette(data[0].results.alertCountPerAlertType.all.length),
                screenSize: screenSize,
              ),
            ],
          ),
        ),
        const Divider(height: 20),
        Expanded(
          child: _TextualOverview(pipelineResults: data, screenSize: screenSize),
        ),
      ],
    );
  }

  List<Color> _generateColorPalette(int count) {
    return List.generate(count, (index) {
      return plotColors[index % plotColors.length];
    });
  }
}

class _TextualOverview extends StatelessWidget {
  const _TextualOverview({required this.pipelineResults, required this.screenSize});

  final List<PipeResult> pipelineResults;
  final ScreenSize screenSize;

  @override
  Widget build(BuildContext context) {
    final ScrollController scrollController = ScrollController();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8.0),
      child: Scrollbar(
        controller: scrollController,
        child: ListView(
          controller: scrollController,
          children: [
            _OverviewExpansionTile(
              title: "Processing Times",
              labels: [
                "Pre-processing",
                ...[for (var pipe in pipelineResults) pipe.name],
              ],
              values: [
                "${_formatter.format(pipelineResults[0].timeToPreprocess)} s",
                ...[for (var pipe in pipelineResults) _formatComputingTime(pipe.timeToCompute)],
              ],
              screenSize: screenSize,
              initiallyExpanded: true,
            ),
            _OverviewExpansionTile(
              title: "Feature Prevalence",
              labels: pipelineResults[0].results.generalMetrics.featureCount.keys.toList(),
              values: pipelineResults[0].results.generalMetrics.featureCount.values
                  .map((e) => percentageFormatter.format(e / pipelineResults[0].results.totalAlertCount.all))
                  .toList(),
              screenSize: screenSize,
              initiallyExpanded: true,
            ),
          ],
        ),
      ),
    );
  }

  String _formatComputingTime(double time) {
    if (time == 0) {
      return "(cached)";
    } else {
      return "${_formatter.format(time)} s";
    }
  }
}

class _OverviewExpansionTile extends StatelessWidget {
  const _OverviewExpansionTile({
    required this.title,
    required this.labels,
    required this.values,
    required this.screenSize,
    this.initiallyExpanded = false,
  });

  final String title;
  final List<String> labels;
  final List<String> values;
  final ScreenSize screenSize;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final TextStyle? titleTheme = screenSize == ScreenSize.large
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.titleSmall;
    final TextStyle? contentTheme = screenSize == ScreenSize.large
        ? Theme.of(context).textTheme.bodyMedium
        : Theme.of(context).textTheme.bodySmall;

    return ExpansionTile(
      title: Text(title, style: titleTheme),
      dense: true,
      childrenPadding: const EdgeInsets.only(left: 10),
      tilePadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      initiallyExpanded: initiallyExpanded,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      children: [
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var label in labels) Text("$label:", style: contentTheme!.copyWith(fontStyle: FontStyle.italic)),
              ],
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (var value in values) Text(value, style: contentTheme)],
            ),
          ],
        ),
      ],
    );
  }
}
