import 'package:cats/models/module.dart';
import 'package:cats/widgets/modules/input_dialogs/input_preview.dart';
import 'package:cats/widgets/modules/inputs/slider.dart';
import 'package:flutter/material.dart';

class DigitSliderForm extends StatefulWidget {
  const DigitSliderForm({
    super.key,
    required this.formKey,
    required this.input,
  });

  final GlobalKey<FormState> formKey;
  final DigitSliderInput input;

  @override
  State<DigitSliderForm> createState() => _DigitSliderFormState();
}

class _DigitSliderFormState extends State<DigitSliderForm> {
  late TextEditingController _descriptionController;
  late TextEditingController _minValueController;
  late TextEditingController _maxValueController;
  late TextEditingController _divisionsController;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController();
    _minValueController = TextEditingController();
    _maxValueController = TextEditingController();
    _divisionsController = TextEditingController();

    _descriptionController.text = widget.input.description;
    _minValueController.text = widget.input.minValue.toString();
    _maxValueController.text = widget.input.maxValue.toString();
    _divisionsController.text = widget.input.divisions.toString();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _minValueController.dispose();
    _maxValueController.dispose();
    _divisionsController.dispose();
    super.dispose();
  }

  void onParamChange(double newValue) {
    setState(() {
      widget.input.initialValue = newValue;
    });
  }

  void updateSlider() {
    if (widget.formKey.currentState!.validate()) {
      final double minValue = double.tryParse(_minValueController.text)!;
      final double maxValue = double.tryParse(_maxValueController.text)!;
      final int divisions = int.tryParse(_divisionsController.text)!;

      setState(() {
        widget.input.initialValue = minValue;

        widget.input.minValue = minValue;
        widget.input.maxValue = maxValue;
        widget.input.divisions = divisions;
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
                child: TextFormField(
                  controller: _minValueController,
                  decoration: const InputDecoration(labelText: "Min Value"),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => updateSlider(),
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
                  keyboardType: TextInputType.number,
                  onChanged: (value) => updateSlider(),
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
              const SizedBox(width: horizontalSpacing),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _divisionsController,
                  decoration: const InputDecoration(labelText: "Divisions"),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => updateSlider(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Required";
                    }
                    int? divisions = int.tryParse(value);
                    if (divisions == null) {
                      return "Not a number";
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
              Text("Initial Value:"),
              SizedBox(width: horizontalSpacing / 4),
              Expanded(
                child: CustomSlider(
                  input: widget.input,
                  onParamChange: onParamChange,
                  inEditingMode: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
