import 'package:cats/models/module.dart';
import 'package:flutter/material.dart';
import 'package:cats/constants.dart';

class CustomRangeSlider extends StatefulWidget {
  const CustomRangeSlider({
    super.key,
    required this.input,
    required this.onParamChange,
    this.inEditingMode = false,
  });

  final RangeSliderInput input;
  final Function(List<double>) onParamChange;
  final bool inEditingMode;

  @override
  State<StatefulWidget> createState() => _CustomRangeSliderState();
}

class _CustomRangeSliderState extends State<CustomRangeSlider> {
  late RangeValues _currentRange;
  late double _legalMinDelta;
  late double _legalMaxDelta;

  @override
  void initState() {
    super.initState();
    var input = widget.input;

    _currentRange = widget.input.currentValue == null
        ? RangeValues(input.initialValues[0], input.initialValues[1])
        : RangeValues(input.currentValue![0], input.currentValue![1]);

    final double divisionSize = (input.maxValue - input.minValue) / input.divisions;
    final int minSteps = input.minRange == null ? 1 : (input.minRange! / divisionSize).ceil();
    final int maxSteps = input.maxRange == null ? input.divisions : (input.maxRange! / divisionSize).floor();
    _legalMinDelta = divisionSize * minSteps;
    _legalMaxDelta = divisionSize * maxSteps;
  }

  @override
  void didUpdateWidget(covariant CustomRangeSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.inEditingMode) {
      var input = widget.input;

      _currentRange = RangeValues(input.initialValues[0], input.initialValues[1]);

      final double divisionSize = (input.maxValue - input.minValue) / input.divisions;
      final int minSteps = input.minRange == null ? 1 : (input.minRange! / divisionSize).ceil();
      final int maxSteps = input.maxRange == null ? input.divisions : (input.maxRange! / divisionSize).floor();
      _legalMinDelta = divisionSize * minSteps;
      _legalMaxDelta = divisionSize * maxSteps;
    } else if (widget.input.currentValue != oldWidget.input.currentValue) {
      _currentRange = RangeValues(widget.input.currentValue![0], widget.input.currentValue![1]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final input = widget.input;
    final double? minRange = input.minRange;
    final double? maxRange = input.maxRange;

    return RangeSlider(
      values: _currentRange,
      min: input.minValue,
      max: input.maxValue,
      divisions: input.divisions,
      labels: RangeLabels(
        _currentRange.start.toString(),
        _currentRange.end.toString(),
      ),
      onChanged: (RangeValues newRange) {
        newRange = RangeValues(
          roundToPrecision(newRange.start),
          roundToPrecision(newRange.end),
        );

        if (minRange != null &&
            ((newRange.start == input.minValue && newRange.end < input.minValue + minRange) ||
                newRange.end == input.maxValue && newRange.start > input.maxValue - minRange)) {
          // Outside of legal slider bounds, no need for further checks
          return;
        }

        setState(() {
          final double delta = newRange.end - newRange.start;

          if (minRange != null && delta < minRange) {
            final RangeValues backup = _currentRange;
            if (newRange.start > _currentRange.start) {
              _currentRange = RangeValues(newRange.start, newRange.start + _legalMinDelta);
            } else if (newRange.end < _currentRange.end) {
              _currentRange = RangeValues(newRange.end - _legalMinDelta, newRange.end);
            }
            if (_currentRange.start < input.minValue || _currentRange.end > input.maxValue) {
              _currentRange = backup;
            }
          } else if (maxRange != null && delta > maxRange) {
            if (newRange.start < _currentRange.start) {
              _currentRange = RangeValues(newRange.start, newRange.start + _legalMaxDelta);
            } else if (newRange.end > _currentRange.end) {
              _currentRange = RangeValues(newRange.end - _legalMaxDelta, newRange.end);
            }
          } else {
            _currentRange = newRange;
          }
        });
      },
      onChangeEnd: (value) {
        final start = roundToPrecision(value.start);
        final end = roundToPrecision(value.end);
        final delta = end - start;

        final double divisionSize = (widget.input.maxValue - widget.input.minValue) / widget.input.divisions;
        final int necessarySteps = minRange == null ? 1 : (minRange / divisionSize).ceil();

        if (minRange != null && start == input.minValue && delta < minRange) {
          widget.onParamChange([start, roundToPrecision(start + divisionSize * necessarySteps)]);
        } else if (minRange != null && end == input.maxValue && delta < minRange) {
          widget.onParamChange([roundToPrecision(end - divisionSize * necessarySteps), end]);
        } else {
          widget.onParamChange([start, end]);
        }
      },
    );
  }
}
