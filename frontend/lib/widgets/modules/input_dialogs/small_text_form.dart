import 'package:cats/models/module.dart';
import 'package:cats/widgets/modules/input_dialogs/input_preview.dart';
import 'package:flutter/material.dart';

class SmallTextForm extends StatefulWidget {
  const SmallTextForm({
    super.key,
    required this.formKey,
    required this.input,
  });

  final GlobalKey<FormState> formKey;
  final SmallTextInput input;

  @override
  State<SmallTextForm> createState() => _SmallTextFormState();
}

class _SmallTextFormState extends State<SmallTextForm> {
  late TextEditingController _descriptionController;
  late TextEditingController _initialStringController;
  late TextEditingController _regexController;
  late TextEditingController _errorMessageController;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController();
    _initialStringController = TextEditingController();
    _regexController = TextEditingController();
    _errorMessageController = TextEditingController();

    _descriptionController.text = widget.input.description;
    _initialStringController.text = widget.input.initialValue;
    _regexController.text = widget.input.regex ?? "";
    _errorMessageController.text = widget.input.errorMessage ?? "";
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _initialStringController.dispose();
    super.dispose();
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
          TextFormField(
            controller: _initialStringController,
            decoration: const InputDecoration(labelText: "Default Value"),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return "Required";
              }
              widget.input.initialValue = value;
              return null;
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text("Allow only strings"),
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: DropdownButton(
                  onChanged: (value) => setState(() {
                    widget.input.hasToMatchRegex = value!;
                  }),
                  value: widget.input.hasToMatchRegex,
                  items: [
                    DropdownMenuItem(
                      value: true,
                      child: Text("matching"),
                    ),
                    DropdownMenuItem(
                      value: false,
                      child: Text("NOT matching"),
                    )
                  ],
                ),
              ),
              SizedBox(width: horizontalSpacing / 2),
              Expanded(
                child: TextFormField(
                  controller: _regexController,
                  decoration: const InputDecoration(labelText: "Regex (optional)"),
                  validator: (pattern) {
                    if (pattern == null || pattern.isEmpty) {
                      widget.input.regex = null;
                      return null;
                    }
                    try {
                      final regex = RegExp(pattern);
                      if (widget.input.hasToMatchRegex == false && regex.hasMatch(_initialStringController.text)) {
                        return "Default value is excluded by your regex";
                      } else if (widget.input.hasToMatchRegex == true &&
                          !regex.hasMatch(_initialStringController.text)) {
                        return "Default value not included by your regex";
                      }
                    } catch (e) {
                      return "Invalid regex";
                    }

                    widget.input.regex = pattern;
                    return null;
                  },
                ),
              ),
            ],
          ),
          TextFormField(
            controller: _errorMessageController,
            decoration: const InputDecoration(labelText: "Custom Error Message (optional)"),
            validator: (value) {
              if (value == null || value.isEmpty) {
                widget.input.errorMessage = null;
              } else {
                widget.input.errorMessage = value;
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}
