import 'package:cats/models/module.dart';
import 'package:flutter/material.dart';
import 'package:cats/constants.dart';

class CustomSlider extends StatefulWidget {
  const CustomSlider({
    super.key,
    required this.input,
    required this.onParamChange,
    this.inEditingMode = false,
  });

  final DigitSliderInput input;
  final Function(double) onParamChange;
  final bool inEditingMode;

  @override
  State<StatefulWidget> createState() => _DigitSliderState();
}

class _DigitSliderState extends State<CustomSlider> {
  late double _currentValue;
  late double _finalValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.input.currentValue ?? widget.input.initialValue;
    _finalValue = widget.input.currentValue ?? widget.input.initialValue;
  }

  @override
  void didUpdateWidget(CustomSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.inEditingMode) {
      _currentValue = widget.input.initialValue;
      _finalValue = widget.input.initialValue;
    } else if (widget.input.currentValue != oldWidget.input.currentValue) {
      _currentValue = widget.input.currentValue ?? widget.input.initialValue;
      _finalValue = widget.input.currentValue ?? widget.input.initialValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 30,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(_finalValue == _finalValue.toInt() ? _finalValue.toStringAsFixed(0) : _finalValue.toString()),
          ),
        ),
        Expanded(
          child: Slider(
            value: _currentValue,
            min: widget.input.minValue,
            max: widget.input.maxValue,
            divisions: widget.input.divisions,
            label: _currentValue.toString(),
            onChanged: (double newValue) {
              setState(() {
                _currentValue = (newValue * precision).roundToDouble() / precision;
              });
            },
            onChangeEnd: (value) {
              setState(() {
                _finalValue = (value * precision).roundToDouble() / precision;
              });
              widget.onParamChange(_finalValue);
            },
          ),
        ),
      ],
    );
  }
}
