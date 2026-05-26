import 'package:cats/models/module.dart';
import 'package:cats/providers/module_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cats/constants.dart';
import 'package:flutter/material.dart';
import 'package:cats/providers/pipelines_provider.dart';

class PresetUI extends ConsumerWidget {
  PresetUI({
    super.key,
    required this.pipeIndex,
    required this.moduleIndex,
    required this.module,
  });

  final int pipeIndex;
  final int moduleIndex;
  final Module module;

  final FocusNode _buttonFocusNode = FocusNode();

  String get currentModulePresetName {
    final defaultValues = module.inputs.map((input) => input.defaultValue).toList();
    final currentValues = module.inputs.map((input) => input.currentValue).toList();

    if (listEquals(defaultValues, currentValues)) {
      return "Default";
    }

    if (module.inputPresets != null) {
      for (InputPreset preset in module.inputPresets!) {
        if (listEquals(preset.inputs, currentValues)) {
          return preset.name;
        }
      }
    }

    return "-";
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        SizedBox(width: 8),
        Text("Preset:"),
        SizedBox(width: 4),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: moduleInstanceWidth / 2),
          child: MenuAnchor(
            builder: (BuildContext context, MenuController controller, Widget? child) {
              return TextButton(
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  backgroundColor: Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.5),
                  foregroundColor: Theme.of(context).colorScheme.onTertiaryContainer.withValues(alpha: 0.8),
                ),
                focusNode: _buttonFocusNode,
                onPressed: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
                child: Text(
                  currentModulePresetName,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
            menuChildren: [
              _PresetMenuItem(
                onPressed: () => ref.read(pipelinesProvider.notifier).resetParametersToDefault(pipeIndex, moduleIndex),
                title: "Default",
                description: "Load the default values for this module.",
              ),
              if (module.inputPresets != null)
                for (InputPreset curPreset in module.inputPresets!) ...[
                  Divider(height: 0),
                  _PresetMenuItem(
                    onPressed: () => ref
                        .read(pipelinesProvider.notifier)
                        .updateAllParameters(pipeIndex, moduleIndex, curPreset.inputs),
                    title: curPreset.name,
                    description: curPreset.description,
                    onEdit: () async {
                      final List<String>? result = await showDialog<List<String>>(
                        context: context,
                        builder: (context) => _AddPresetDialog(existingPreset: curPreset),
                      );

                      if (result != null && result.length == 2) {
                        String presetName = result[0];
                        String presetDescription = result[1];

                        List<InputPreset> oldPresets = List.from(module.inputPresets!);
                        InputPreset newPreset = InputPreset(
                          name: presetName,
                          description: presetDescription,
                          inputs: curPreset.inputs,
                        );
                        oldPresets[module.inputPresets!.indexOf(curPreset)] = newPreset;

                        ref.read(moduleListProvider.notifier).editExistingModule(
                              module.copyWith(inputPresets: oldPresets),
                              onlyPresetsEdited: true,
                            );
                      }
                    },
                    onDelete: () {
                      List<InputPreset> oldPresets = List.from(module.inputPresets!);
                      oldPresets.remove(curPreset);

                      ref.read(moduleListProvider.notifier).editExistingModule(
                            module.copyWith(inputPresets: oldPresets),
                            onlyPresetsEdited: true,
                          );
                    },
                  ),
                ],
              if (currentModulePresetName == "-") ...[
                Divider(height: 0),
                MenuItemButton(
                  style: ButtonStyle(
                    backgroundColor:
                        WidgetStateProperty.all<Color>(Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8)),
                    foregroundColor: WidgetStateProperty.all<Color>(Theme.of(context).colorScheme.onSecondary),
                    overlayColor: WidgetStateProperty.all<Color>(Theme.of(context).colorScheme.secondary),
                  ),
                  child: Center(
                    child: Text(
                      "Save current parameters as a preset",
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                  onPressed: () async {
                    final List<String>? result = await showDialog<List<String>>(
                      context: context,
                      builder: (context) => const _AddPresetDialog(),
                    );

                    if (result != null && result.length == 2) {
                      String presetName = result[0];
                      String presetDescription = result[1];

                      ref.read(moduleListProvider.notifier).editExistingModule(
                            module.copyWith(inputPresets: [
                              ...?module.inputPresets,
                              InputPreset(
                                name: presetName,
                                description: presetDescription,
                                inputs: module.inputs.map((input) => input.currentValue).toList(),
                              ),
                            ]),
                            onlyPresetsEdited: true,
                          );
                    }
                  },
                ),
              ]
            ],
          ),
        ),
      ],
    );
  }
}

class _PresetMenuItem extends StatefulWidget {
  const _PresetMenuItem({
    required this.onPressed,
    required this.title,
    required this.description,
    this.onEdit,
    this.onDelete,
  });

  final void Function() onPressed;
  final String title;
  final String description;
  final void Function()? onEdit;
  final void Function()? onDelete;

  @override
  State<_PresetMenuItem> createState() => _PresetMenuItemState();
}

class _PresetMenuItemState extends State<_PresetMenuItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MenuItemButton(
      onHover: (isHovered) => setState(() => _isHovered = isHovered),
      onPressed: widget.onPressed,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SizedBox(
          width: moduleInstanceWidth * 1.2,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                width: moduleInstanceWidth * 0.9,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title),
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(
                        widget.description == "" ? "No description provided." : widget.description,
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontStyle: FontStyle.italic),
                        softWrap: true,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isHovered && widget.onEdit != null && widget.onDelete != null)
                Row(
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.edit),
                      onPressed: widget.onEdit,
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.delete),
                      onPressed: widget.onDelete,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddPresetDialog extends StatefulWidget {
  const _AddPresetDialog({
    this.existingPreset,
  });

  final InputPreset? existingPreset;

  @override
  _AddPresetDialogState createState() => _AddPresetDialogState();
}

class _AddPresetDialogState extends State<_AddPresetDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocusNode.requestFocus();
    });
    if (widget.existingPreset != null) {
      _nameController.text = widget.existingPreset!.name;
      _descriptionController.text = widget.existingPreset!.description;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existingPreset != null ? "Edit preset" : "Add a new preset"),
      content: SizedBox(
        width: 700,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              focusNode: _nameFocusNode,
              decoration: InputDecoration(
                labelText: "Name",
                errorText: _isError ? "Name cannot be empty." : null,
              ),
              maxLength: 50,
            ),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: "Description (optional)",
                alignLabelWithHint: true,
              ),
              maxLength: 1000,
              maxLines: null,
              keyboardType: TextInputType.multiline,
            )
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () {
            if (_nameController.text.isEmpty) {
              setState(() {
                _isError = true;
              });
              return;
            }

            Navigator.of(context).pop([_nameController.text, _descriptionController.text]);
          },
          child: const Text("Save"),
        ),
      ],
    );
  }
}
