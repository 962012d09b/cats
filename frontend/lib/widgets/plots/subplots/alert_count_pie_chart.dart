import 'package:cats/constants.dart';
import 'package:cats/models/result.dart';
import 'package:cats/widgets/plots/dataset_pipeline_statistics.dart';
import 'package:cats/widgets/plots/legend.dart';
import 'package:cats/widgets/plots/result_helper.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class AlertCountPieChart extends StatefulWidget {
  const AlertCountPieChart({super.key, required this.data, required this.screenSize});

  final PipeResult data;
  final ScreenSize screenSize;

  @override
  State<AlertCountPieChart> createState() => _AlertCountPieChartState();
}

class _AlertCountPieChartState extends State<AlertCountPieChart> {
  OverlayEntry? _overlayEntry;

  late RichText _tpTooltip;
  late RichText _fpTooltip;
  late RichText _unknownTooltip;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    var allTps =
        widget.data.results.alertCountPerAlertType.tp.entries.toList().where((entry) => entry.value > 0).toList();
    var allFps =
        widget.data.results.alertCountPerAlertType.fp.entries.toList().where((entry) => entry.value > 0).toList();
    var allUnknowns =
        widget.data.results.alertCountPerAlertType.unknown.entries.toList().where((entry) => entry.value > 0).toList();

    allTps.sort((a, b) => b.value.compareTo(a.value));
    allFps.sort((a, b) => b.value.compareTo(a.value));
    allUnknowns.sort((a, b) => b.value.compareTo(a.value));

    _tpTooltip = _generateTooltipText("true alert", Map.fromEntries(allTps.take(10)));
    _fpTooltip = _generateTooltipText("false alert", Map.fromEntries(allFps.take(10)));
    _unknownTooltip = _generateTooltipText("Unknown", Map.fromEntries(allUnknowns.take(10)));
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _createOverlayEntry(int touchedSectionIndex) {
    _removeOverlay();

    RichText tooltipToDisplay;
    switch (touchedSectionIndex) {
      case 0:
        tooltipToDisplay = _tpTooltip;
        break;
      case 1:
        tooltipToDisplay = _fpTooltip;
        break;
      case 2:
        tooltipToDisplay = _unknownTooltip;
        break;
      default:
        return;
    }

    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;
    var offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder:
          (context) => Positioned(
            left: offset.dx - size.width * 0.25,
            top: offset.dy + size.height + 5.0,
            width: size.width * 1.5,
            child: IntrinsicWidth(
              child: Container(
                padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: tooltipToDisplay,
              ),
            ),
          ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  RichText _generateTooltipText(String alertName, Map<String, int> relevantData) {
    List<TextSpan> contentSpans = [];

    contentSpans =
        relevantData.entries.map((e) {
          return TextSpan(
            children: [
              TextSpan(text: "(${e.value}) "),
              TextSpan(text: "${e.key}\n", style: TextStyle(fontWeight: FontWeight.w500)),
              TextSpan(text: "\n", style: TextStyle(height: 0.2)),
            ],
          );
        }).toList();

    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.bodySmall,
        children: [
          TextSpan(
            text: "Most prevalent $alertName types (max. 10):\n",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          TextSpan(text: "\n", style: TextStyle(height: 0.5)),
          ...contentSpans,
        ],
      ),
      textAlign: TextAlign.start,
    );
  }

  @override
  Widget build(BuildContext context) {
    final int tpCount = widget.data.results.totalAlertCount.tp;
    final int fpCount = widget.data.results.totalAlertCount.fp;
    final int unknownCount = widget.data.results.totalAlertCount.unknown;
    final double tpPercentage = widget.data.results.generalMetrics.tpPrevalence;

    final double iSize = widget.screenSize == ScreenSize.large ? 14 : 12;

    final indicators = [
      Indicator(color: plotFpColor, text: "False Alerts", isBold: false, size: iSize),
      Indicator(color: plotTpColor, text: "True Alerts", isBold: false, size: iSize),
      Indicator(color: plotUnknownColor, text: "Unknown", isBold: false, size: iSize),
    ];

    var radius = widget.screenSize == ScreenSize.large ? 25.0 : 18.0;
    final TextStyle? titleStyle =
        widget.screenSize == ScreenSize.large
            ? Theme.of(context).textTheme.bodyMedium
            : Theme.of(context).textTheme.bodySmall;

    var sections = [
      PieChartSectionData(
        value: tpCount.toDouble(),
        title: tpCount.toString(),
        radius: radius,
        color: plotTpColor,
        titleStyle: titleStyle,
      ),
      PieChartSectionData(
        value: fpCount.toDouble(),
        title: fpCount.toString(),
        radius: radius,
        color: plotFpColor,
        titleStyle: titleStyle,
      ),
      PieChartSectionData(
        value: unknownCount.toDouble(),
        title: unknownCount.toString(),
        radius: radius,
        color: plotUnknownColor,
        titleStyle: titleStyle,
      ),
    ];

    return MouseRegion(
      onExit: (event) => _removeOverlay(),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: widget.data.results.totalAlertCount.unknown > 0 ? indicators : indicators.sublist(0, 2),
                  ),
                  Text(
                    "${widget.data.results.totalAlertCount.all} total",
                    style:
                        widget.screenSize == ScreenSize.large
                            ? Theme.of(context).textTheme.bodyMedium
                            : Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    "${percentageFormatter.format(tpPercentage)} true",
                    style:
                        widget.screenSize == ScreenSize.large
                            ? Theme.of(context).textTheme.bodyMedium
                            : Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    "[hover for info]",
                    style:
                        widget.screenSize == ScreenSize.large
                            ? Theme.of(context).textTheme.bodyMedium!.copyWith(fontStyle: FontStyle.italic)
                            : Theme.of(context).textTheme.bodySmall!.copyWith(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            PieChart(
              PieChartData(
                sections: sections,
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    if (!event.isInterestedForInteractions) {
                      _removeOverlay();
                      return;
                    }
                    setState(() {
                      _createOverlayEntry(pieTouchResponse?.touchedSection?.touchedSectionIndex ?? -1);
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
