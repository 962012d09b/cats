import 'package:cats/models/result.dart';
import 'package:cats/widgets/plots/result_helper.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class AlertTypePieChart extends StatefulWidget {
  const AlertTypePieChart({super.key, required this.data, required this.colorsPalette, required this.screenSize});

  final PipeResult data;
  final List<Color> colorsPalette;
  final ScreenSize screenSize;

  @override
  State<AlertTypePieChart> createState() => _AlertTypePieChartState();
}

class _AlertTypePieChartState extends State<AlertTypePieChart> {
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _createOverlayEntry(String currentRule) {
    _removeOverlay();

    var tooltipToDisplay = _generateTooltipText(currentRule);

    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;
    var offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder:
          (context) => Positioned(
            left: offset.dx - size.width * 0.1,
            top: offset.dy + size.height + 5.0,
            width: size.width * 1.2,
            child: IntrinsicWidth(
              child: Container(
                padding: const EdgeInsets.all(4),
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

  RichText _generateTooltipText(String currentRule) {
    int allCount = widget.data.results.alertCountPerAlertType.all[currentRule] ?? 0;
    int tpCount = widget.data.results.alertCountPerAlertType.tp[currentRule] ?? 0;
    int fpCount = widget.data.results.alertCountPerAlertType.fp[currentRule] ?? 0;
    int unknownCount = widget.data.results.alertCountPerAlertType.unknown[currentRule] ?? 0;

    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.bodySmall,
        children: [
          TextSpan(text: "$currentRule\n", style: Theme.of(context).textTheme.titleMedium),
          TextSpan(text: "\n", style: TextStyle(height: 0.5)),
          TextSpan(text: "Total: $allCount\n", style: Theme.of(context).textTheme.bodyMedium),
          TextSpan(text: "\n", style: TextStyle(height: 0.5)),
          TextSpan(text: "True Alerts: $tpCount\n", style: Theme.of(context).textTheme.bodySmall),
          TextSpan(text: "False Alerts: $fpCount", style: Theme.of(context).textTheme.bodySmall),
          if (unknownCount > 0) ...[
            TextSpan(text: "\nUnknown: $unknownCount\n", style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
      textAlign: TextAlign.start,
    );
  }

  @override
  Widget build(BuildContext context) {
    Map<String, int> alertsPerTypeAll = widget.data.results.alertCountPerAlertType.all;
    final sortedData = alertsPerTypeAll.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    var sections = <PieChartSectionData>[];

    for (var i = 0; i < sortedData.length; i++) {
      final entry = sortedData.elementAt(i);
      sections.add(
        PieChartSectionData(
          value: entry.value.toDouble(),
          title: entry.key,
          radius: widget.screenSize == ScreenSize.large ? 25.0 : 18.0,
          showTitle: false,
          color: entry.key == "n/a" ? Colors.grey : widget.colorsPalette[i],
        ),
      );
    }

    final TextStyle? textStyle =
        widget.screenSize == ScreenSize.large
            ? Theme.of(context).textTheme.bodyMedium
            : Theme.of(context).textTheme.bodySmall;

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
                  Text("Alert Types\n${sections.length} total", style: textStyle!, textAlign: TextAlign.center),
                  Text("[hover for info]", style: textStyle.copyWith(fontStyle: FontStyle.italic)),
                ],
              ),
            ),
            PieChart(
              PieChartData(
                sections: sections,
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    var sectionIndex = pieTouchResponse?.touchedSection?.touchedSectionIndex;
                    if (!event.isInterestedForInteractions || sectionIndex == null || sectionIndex == -1) {
                      _removeOverlay();
                      return;
                    }
                    setState(() {
                      var currentRule = sortedData[sectionIndex].key;
                      _createOverlayEntry(currentRule);
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
