import 'dart:math';

import 'package:cats/constants.dart';
import 'package:cats/providers/datasets_provider.dart';
import 'package:cats/widgets/plots/legend.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String _tpLabel = "tp";
const String _fpLabel = "fp";
const String _unknownLabel = "unknown";
const String _placeholderLabel = "PLACEHOLDER";

const double _xJitterRange = 0.1;
const double _yJitterRange = 0.1;

class JitterPreview extends ConsumerWidget {
  const JitterPreview({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jitterData = ref.read(availableDatasetsProvider.notifier).fetchJitterData(id);
    return FutureBuilder<Map<String, Map<String, Map<String, int>>>>(
      future: jitterData,
      builder: (context, webRequest) {
        if (webRequest.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (webRequest.hasError) {
          return Center(child: Text('Error: ${webRequest.error}'));
        } else {
          final data = webRequest.data;
          final uniqueTypes = data!.values.expand((typeCounts) => typeCounts.keys).toSet().toList();
          final timestampsSorted = data.keys.toList();

          return _JitterPlot(data: data, uniqueTypes: uniqueTypes, timestampsSorted: timestampsSorted);
        }
      },
    );
  }
}

class _JitterPlot extends StatelessWidget {
  const _JitterPlot({required this.data, required this.uniqueTypes, required this.timestampsSorted});

  final Map<String, Map<String, Map<String, int>>> data;
  final List<String> uniqueTypes;
  final List<String> timestampsSorted;

  List<ScatterSpot> _generateScatterSpots() {
    List<ScatterSpot> spots = [];

    for (var timestampIndex = 0; timestampIndex < data.keys.length; timestampIndex++) {
      if (data[timestampsSorted[timestampIndex]]!.isEmpty) {
        spots.add(_createScatterSpot(timestampIndex.toDouble(), 0, _placeholderLabel, 0));
        continue;
      }

      for (var type in uniqueTypes) {
        if (data[timestampsSorted[timestampIndex]]!.containsKey(type)) {
          var curData = data[timestampsSorted[timestampIndex]]![type]!;

          for (var entry in curData.entries) {
            final label = entry.key;
            final count = entry.value;

            for (var i = 0; i < count; i++) {
              double jitterFactor = min(count / 10, 1.0);
              spots.add(
                _createScatterSpot(
                  timestampIndex.toDouble(),
                  uniqueTypes.indexOf(type).toDouble(),
                  label,
                  jitterFactor,
                ),
              );
            }
          }
        }
      }
    }
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 2,
          child: ScatterChart(
            ScatterChartData(
              scatterSpots: _generateScatterSpots(),
              minX: -1,
              maxX: data.keys.length.toDouble(),
              minY: -1,
              maxY: uniqueTypes.length.toDouble(),
              gridData: FlGridData(show: true, horizontalInterval: 1),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() < 0 || value.toInt() >= timestampsSorted.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: RotationTransition(
                          turns: const AlwaysStoppedAnimation(0.15),
                          child: Text(timestampsSorted[value.toInt()].substring(8, 16)),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 400,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() < 0 || value.toInt() >= uniqueTypes.length) {
                        return const SizedBox.shrink();
                      }
                      return Tooltip(
                        message: uniqueTypes[value.toInt()],
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              uniqueTypes[value.toInt()],
                              style: Theme.of(context).textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              scatterTouchData: ScatterTouchData(enabled: false),
            ),
          ),
        ),
        Align(
          alignment: AlignmentGeometry.centerRight,
          child: Container(
            margin: EdgeInsets.only(right: 24),
            padding: EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Indicator(color: plotTpColor, text: "True Alert", size: 15),
                Indicator(color: plotFpColor, text: "False Alert", size: 15),
                Indicator(color: plotUnknownColor, text: "Unknown", size: 15),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

ScatterSpot _createScatterSpot(double x, double y, String label, double jitterFactor) {
  Color color;
  if (label == _tpLabel) {
    color = plotTpColor;
  } else if (label == _fpLabel) {
    color = plotFpColor;
  } else if (label == _unknownLabel) {
    color = plotUnknownColor;
  } else if (label == _placeholderLabel) {
    color = Colors.transparent;
  } else {
    throw Exception("Unknown label $label for jitter plot");
  }

  double xJitter = (Random().nextDouble() * _xJitterRange * 2 - _xJitterRange) * jitterFactor;
  double yJitter = (Random().nextDouble() * _yJitterRange * 2 - _yJitterRange) * jitterFactor;

  return ScatterSpot(x + xJitter, y + yJitter, dotPainter: FlDotCrossPainter(color: color, width: 1));
}
