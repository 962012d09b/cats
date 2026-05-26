import 'package:cats/models/module.dart';
import 'package:cats/widgets/modules/input_dialogs/input_preview.dart';
import 'package:flutter/material.dart';
import 'package:input_quantity/input_quantity.dart';

class CheckboxForm extends StatefulWidget {
  const CheckboxForm({
    super.key,
    required this.formKey,
    required this.input,
  });

  final GlobalKey<FormState> formKey;
  final CheckboxInput input;

  @override
  State<CheckboxForm> createState() => _CheckboxFormState();
}

class _CheckboxFormState extends State<CheckboxForm> {
  late TextEditingController _descriptionController;
  late List<TextEditingController> _labelControllers;
  late int _numCheckboxes;
  late int _groupValue;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController();
    _numCheckboxes = widget.input.labels.length;
    _labelControllers = List.generate(_numCheckboxes, (_) => TextEditingController(), growable: true);

    _descriptionController.text = widget.input.description;
    for (var i = 0; i < widget.input.labels.length; i++) {
      _labelControllers[i].text = widget.input.labels[i];
    }

    _groupValue = !widget.input.initialValues.contains(true) ? 0 : widget.input.initialValues.indexOf(true);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    for (final controller in _labelControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _updateNumCheckboxes(int newCount) {
    if (newCount == _numCheckboxes) {
      return;
    }
    setState(() {
      if (newCount < _numCheckboxes) {
        widget.input.initialValues.removeRange(newCount, _numCheckboxes);
        widget.input.labels.removeRange(newCount, _numCheckboxes);
        _labelControllers.removeRange(newCount, _numCheckboxes);

        if (_groupValue >= newCount) {
          _groupValue = newCount - 1;
          if (widget.input.isMutuallyExclusive) {
            List<bool> newValues = List.filled(newCount, false, growable: true);
            newValues[_groupValue] = true;
            widget.input.initialValues = newValues;
          }
        }
      } else {
        widget.input.initialValues.addAll(List.filled(newCount - _numCheckboxes, false));
        widget.input.labels.addAll(List.filled(newCount - _numCheckboxes, ""));
        _labelControllers.addAll(List.generate(newCount - _numCheckboxes, (_) => TextEditingController()));
      }
      _numCheckboxes = newCount;
    });
  }

  void _toggleMutuallyExclusive(bool isMutuallyExclusive) {
    setState(() {
      widget.input.isMutuallyExclusive = isMutuallyExclusive;

      if (isMutuallyExclusive) {
        List<bool> newValues = List.filled(_numCheckboxes, false, growable: true);

        final int indexOfFirstTrue = widget.input.initialValues.indexOf(true);
        if (indexOfFirstTrue == -1) {
          _groupValue = 0;
        } else {
          _groupValue = indexOfFirstTrue;
        }
        newValues[_groupValue] = true;
        widget.input.initialValues = newValues;
      }
    });
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
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Number of Checkboxes:",
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(width: horizontalSpacing / 2),
                  InputQty.int(
                    initVal: _numCheckboxes,
                    minVal: 1,
                    maxVal: 99,
                    steps: 1,
                    onQtyChanged: (value) => _updateNumCheckboxes(value),
                    decoration: QtyDecorationProps(
                      btnColor: Theme.of(context).colorScheme.secondary,
                      border: InputBorder.none,
                    ),
                  )
                ],
              ),
              const SizedBox(width: horizontalSpacing),
              Flexible(
                child: Tooltip(
                  message: "If checked, the GUI will enforce that exactly one option is selected at all times.",
                  child: SwitchListTile(
                    value: widget.input.isMutuallyExclusive,
                    onChanged: (value) => _toggleMutuallyExclusive(value),
                    title: const Text("Mutually Exclusive?"),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < _numCheckboxes; i++) ...[
            Row(
              key: UniqueKey(),
              children: [
                Flexible(
                  flex: 3,
                  child: TextFormField(
                    controller: _labelControllers[i],
                    decoration: InputDecoration(labelText: "Label ${i + 1}"),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Required";
                      }
                      widget.input.labels[i] = value;
                      return null;
                    },
                  ),
                ),
                Flexible(
                  child: widget.input.isMutuallyExclusive
                      ? RadioListTile(
                          title: Text(
                            "Default:",
                            style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontStyle: FontStyle.italic),
                          ),
                          value: i,
                          groupValue: _groupValue,
                          controlAffinity: ListTileControlAffinity.trailing,
                          onChanged: (newIndex) {
                            setState(() {
                              _groupValue = newIndex!;
                              List<bool> newValues = List.filled(_numCheckboxes, false, growable: true);
                              newValues[_groupValue] = true;
                              widget.input.initialValues = newValues;
                            });
                          },
                        )
                      : CheckboxListTile(
                          title: Text(
                            "Default:",
                            style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontStyle: FontStyle.italic),
                          ),
                          value: widget.input.initialValues[i],
                          dense: true,
                          onChanged: (value) {
                            setState(() {
                              widget.input.initialValues[i] = value ?? false;
                            });
                          },
                        ),
                ),
              ],
            ),
            const SizedBox(height: 5),
          ]
        ],
      ),
    );
  }
}
