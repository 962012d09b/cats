import 'package:cats/constants.dart';
import 'package:cats/models/module.dart';
import 'package:cats/widgets/modules/input_dialogs/input_preview.dart';
import 'package:cats/widgets/modules/inputs/range_slider.dart';
import 'package:flutter/material.dart';

class RangeSliderForm extends StatefulWidget {
  const RangeSliderForm({
    super.key,
    required this.formKey,
    required this.input,
  });

  final GlobalKey<FormState> formKey;
  final RangeSliderInput input;

  @override
  State<RangeSliderForm> createState() => _RangeSliderFormState();
}

class _RangeSliderFormState extends State<RangeSliderForm> {
  late TextEditingController _descriptionController;
  late TextEditingController _minValueController;
  late TextEditingController _maxValueController;
  late TextEditingController _minRangeController;
  late TextEditingController _maxRangeController;
  late TextEditingController _divisionsController;
  late TextEditingController _initialStartController;
  late TextEditingController _initialEndController;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController();
    _minValueController = TextEditingController();
    _maxValueController = TextEditingController();
    _minRangeController = TextEditingController();
    _maxRangeController = TextEditingController();
    _divisionsController = TextEditingController();
    _initialStartController = TextEditingController();
    _initialEndController = TextEditingController();

    _descriptionController.text = widget.input.description;
    _minValueController.text = widget.input.minValue.toString();
    _maxValueController.text = widget.input.maxValue.toString();
    _minRangeController.text = widget.input.minRange == null ? "" : widget.input.minRange.toString();
    _maxRangeController.text = widget.input.maxRange == null ? "" : widget.input.maxRange.toString();
    _divisionsController.text = widget.input.divisions.toString();
    _initialStartController.text = widget.input.initialValues[0].toString();
    _initialEndController.text = widget.input.initialValues[1].toString();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _minValueController.dispose();
    _maxValueController.dispose();
    _minRangeController.dispose();
    _maxRangeController.dispose();
    _divisionsController.dispose();
    _initialStartController.dispose();
    _initialEndController.dispose();
    super.dispose();
  }

  double _getDivisionSize(double min, double max, int div) {
    return (max - min) / div;
  }

  void _onParamChange(List<double> newValues) {
    setState(() {
      widget.input.initialValues = newValues;
    });
  }

  void _updateRangeSlider() {
    if (widget.formKey.currentState!.validate()) {
      final double minValue = double.tryParse(_minValueController.text)!;
      final double maxValue = double.tryParse(_maxValueController.text)!;
      final int divisions = int.tryParse(_divisionsController.text)!;
      final double? minRange = double.tryParse(_minRangeController.text);
      final double? maxRange = double.tryParse(_maxRangeController.text);

      setState(() {
        final double divisionSize = (maxValue - minValue) / divisions;
        final int necessarySteps = minRange == null ? 1 : (minRange / divisionSize).ceil();
        final double initialEndValue = minValue + divisionSize * necessarySteps;
        widget.input.initialValues = [roundToPrecision(minValue), roundToPrecision(initialEndValue)];

        widget.input.minValue = minValue;
        widget.input.maxValue = maxValue;
        widget.input.divisions = divisions;
        widget.input.minRange = minRange;
        widget.input.maxRange = maxRange;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: "Description (optional)"),
            validator: (value) {
              widget.input.description = value ?? "";
              return null;
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _minValueController,
                        decoration: const InputDecoration(labelText: "Min Value"),
                        onChanged: (_) => _updateRangeSlider(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Required";
                          }
                          double? min = double.tryParse(value);
                          double? max = double.tryParse(_maxValueController.text);
                          if (min == null) {
                            return "Not a number";
                          }
                          if (max != null && min >= max) {
                            return "Min value must be less than max value";
                          }
                          widget.input.minValue = min;
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: horizontalSpacing / 2),
                    Expanded(
                      child: TextFormField(
                        controller: _maxValueController,
                        decoration: const InputDecoration(labelText: "Max Value"),
                        onChanged: (_) => _updateRangeSlider(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Required";
                          }
                          double? max = double.tryParse(value);
                          double? min = double.tryParse(_minValueController.text);
                          if (max == null) {
                            return "Not a number";
                          }
                          if (min != null && min >= max) {
                            return "Max value must be greater than min value";
                          }
                          widget.input.maxValue = max;
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: horizontalSpacing),
              Expanded(
                child: TextFormField(
                  controller: _divisionsController,
                  decoration: const InputDecoration(labelText: "Divisions"),
                  onChanged: (_) => _updateRangeSlider(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Required";
                    }
                    int? divisions = int.tryParse(value);
                    if (divisions == null) {
                      return "Not a whole number";
                    }
                    if (divisions < 1) {
                      return "Must be greater than 0";
                    }
                    widget.input.divisions = divisions;
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _minRangeController,
                  decoration: const InputDecoration(labelText: "Min Range (optional)"),
                  onChanged: (_) => _updateRangeSlider(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return null;
                    }
                    double? min = double.tryParse(value);
                    double? max = double.tryParse(_maxRangeController.text);
                    if (min == null) {
                      return "Not a number";
                    }
                    if (max != null && min > max) {
                      return "Min range must be <= max range";
                    }

                    final double? start = double.tryParse(_minValueController.text);
                    final double? end = double.tryParse(_maxValueController.text);
                    if (start != null && end != null) {
                      final totalRange = end - start;
                      if (totalRange < min) {
                        return "Min range bigger than total range";
                      }
                    }

                    widget.input.minRange = min;
                    return null;
                  },
                ),
              ),
              const SizedBox(width: horizontalSpacing),
              Expanded(
                child: TextFormField(
                  controller: _maxRangeController,
                  decoration: const InputDecoration(labelText: "Max Range (optional)"),
                  onChanged: (_) => _updateRangeSlider(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return null;
                    }
                    double? max = double.tryParse(value);
                    double? min = double.tryParse(_minRangeController.text);
                    if (max == null) {
                      return "Not a number";
                    }
                    if (min != null && min > max) {
                      return "Max range must be >= min range";
                    }

                    final double? start = double.tryParse(_minValueController.text);
                    final double? end = double.tryParse(_maxValueController.text);
                    final int? divisions = int.tryParse(_divisionsController.text);
                    if (start != null && end != null && divisions != null) {
                      final double divisionSize = _getDivisionSize(start, end, divisions);
                      if (divisionSize > max) {
                        return "Max range smaller than single division";
                      }
                    }

                    widget.input.maxRange = max;
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text("Initial Values: ${widget.input.initialValues[0]} - ${widget.input.initialValues[1]}"),
              SizedBox(width: horizontalSpacing / 2),
              Expanded(
                child: CustomRangeSlider(
                  input: widget.input,
                  onParamChange: _onParamChange,
                  inEditingMode: true,
                ),
              )
            ],
          )
        ],
      ),
    );
  }
}
