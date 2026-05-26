import 'package:cats/models/module.dart';
import 'package:flutter/material.dart';

class DropdownForm extends StatefulWidget {
  const DropdownForm({
    super.key,
    required this.formKey,
    required this.input,
  });

  final GlobalKey<FormState> formKey;
  final DropdownInput input;

  @override
  State<DropdownForm> createState() => _DropdownFormState();
}

class _DropdownFormState extends State<DropdownForm> {
  late TextEditingController _descriptionController;
  late List<TextEditingController> _itemControllers;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController();
    _itemControllers = List.generate(widget.input.items.length, (_) => TextEditingController(), growable: true);

    _descriptionController.text = widget.input.description;
    for (var i = 0; i < widget.input.items.length; i++) {
      _itemControllers[i].text = widget.input.items[i];
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    for (final controller in _itemControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int numItems = widget.input.items.length;

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
          for (var i = 0; i < numItems; i++)
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _itemControllers[i],
                    decoration: InputDecoration(
                      labelText: i == 0 ? "Item ${i + 1} (default)" : "Item ${i + 1}",
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Required";
                      }
                      if (_itemControllers.where((ctrl) => ctrl.text == value).length > 1) {
                        return "Values must be unique";
                      }
                      widget.input.items[i] = value;
                      return null;
                    },
                  ),
                ),
                numItems < 3
                    ? Tooltip(
                        message: "At least 2 items are required",
                        child: IconButton(
                          onPressed: null,
                          icon: Icon(Icons.delete_outline),
                        ),
                      )
                    : IconButton(
                        onPressed: () {
                          setState(() {
                            _itemControllers[i].dispose();
                            _itemControllers.removeAt(i);
                            widget.input.items.removeAt(i);
                          });
                        },
                        icon: Icon(Icons.delete_outline),
                      ),
              ],
            ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: IconButton(
              onPressed: () {
                setState(() {
                  _itemControllers.add(TextEditingController());
                  widget.input.items.add("");
                });
              },
              icon: const Icon(Icons.add),
            ),
          )
        ],
      ),
    );
  }
}
