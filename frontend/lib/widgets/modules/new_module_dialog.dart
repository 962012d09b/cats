import 'package:cats/widgets/filters/tags_edit.dart';
import 'package:cats/widgets/settings/utility/helper.dart';
import 'package:cats/widgets/utility/error_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cats/models/module.dart';
import 'package:cats/providers/module_provider.dart';
import 'package:cats/widgets/modules/input_dialogs/input_preview.dart';

class NewModuleDialog extends ConsumerStatefulWidget {
  const NewModuleDialog({super.key, this.isEditing = false, this.module});

  final bool isEditing;
  final Module? module;

  @override
  ConsumerState<NewModuleDialog> createState() => _NewModuleDialogState();
}

class _NewModuleDialogState extends ConsumerState<NewModuleDialog> {
  final _formKey = GlobalKey<FormState>();
  late List<ModuleInput> _inputs;

  final List<GlobalKey<FormState>> _inputFormKeys = [];
  final List<ExpansibleController> _inputControllers = [];

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _filenameController;

  List<String> _tags = [];
  bool _hasSubmitted = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.module == null) {
      throw ArgumentError("Module must be provided when editing.");
    }

    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _filenameController = TextEditingController();

    _inputs = widget.module?.inputs.map((input) => input.deepCopy()).toList() ?? [];

    if (widget.isEditing) {
      _nameController.text = widget.module!.name;
      _descriptionController.text = widget.module!.description ?? "";
      _filenameController.text = widget.module!.fileName;
      _tags = [...widget.module!.tags];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _filenameController.dispose();
    super.dispose();
  }

  void onAddInput(ModuleInputType inputType) {
    setState(() {
      var newInput = switch (inputType) {
        ModuleInputType.digitSlider => ModuleInput.digitSlider(
          type: ModuleInputType.digitSlider,
          minValue: 1,
          maxValue: 10,
          initialValue: 5,
          divisions: 9,
        ),
        ModuleInputType.rangeSlider => ModuleInput.rangeSlider(
          type: ModuleInputType.rangeSlider,
          minValue: 1,
          maxValue: 10,
          initialValues: [3, 7],
          divisions: 9,
          minRange: 1,
          maxRange: 9,
        ),
        ModuleInputType.smallText => ModuleInput.smallText(type: ModuleInputType.smallText, initialValue: ""),
        ModuleInputType.checkbox => ModuleInput.checkbox(
          type: ModuleInputType.checkbox,
          initialValues: [false, false],
          labels: ["", ""],
          isMutuallyExclusive: false,
        ),
        ModuleInputType.dropdown => ModuleInput.dropdown(type: ModuleInputType.dropdown, items: ["", ""]),
      };
      _inputs.add(newInput);
    });
  }

  void onRemoveInput(ModuleInput input) {
    setState(() {
      _inputs.remove(input);
    });
  }

  void onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final temp = _inputs.removeAt(oldIndex);
      _inputs.insert(newIndex, temp);
    });
  }

  void _updateTags(List<String> tags) {
    setState(() {
      _tags = tags;
    });
  }

  void register(GlobalKey<FormState> key, ExpansibleController controller) {
    _inputFormKeys.add(key);
    _inputControllers.add(controller);
  }

  void unregister(GlobalKey<FormState> key, ExpansibleController controller) {
    _inputFormKeys.remove(key);
    _inputControllers.remove(controller);
  }

  void _handleAddOrEdit() async {
    bool error = false;
    for (var key in _inputFormKeys) {
      if (!key.currentState!.validate()) {
        _inputControllers[_inputFormKeys.indexOf(key)].expand();
        error = true;
      }
    }
    if (_formKey.currentState!.validate() && !error) {
      String? errorMsg;
      setState(() {
        _hasSubmitted = true;
      });

      List<InputPreset>? presets = [];
      bool inputsEdited = false;

      if (widget.isEditing) {
        if (_inputs.length == widget.module!.inputs.length) {
          for (var i = 0; i < _inputs.length; i++) {
            if (!_inputs[i].exactlyEquals(widget.module!.inputs[i])) {
              inputsEdited = true;
              break;
            }
          }
        } else {
          inputsEdited = true;
        }
      }

      if (!inputsEdited && widget.module != null) {
        presets = widget.module!.inputPresets;
      }

      try {
        if (widget.isEditing) {
          await ref
              .read(moduleListProvider.notifier)
              .editExistingModule(
                Module(
                  id: widget.module!.id,
                  name: _nameController.text,
                  description: _descriptionController.text,
                  fileName: _filenameController.text,
                  inputs: _inputs,
                  inputPresets: presets,
                  doesExist: true, // will be overwritten by backend
                  tags: _tags,
                ),
                keepOldValues: !inputsEdited,
              );
        } else {
          await ref
              .read(moduleListProvider.notifier)
              .addNewModule(
                Module(
                  id: 0, // will be overwritten by backend
                  name: _nameController.text,
                  description: _descriptionController.text,
                  fileName: _filenameController.text,
                  inputs: _inputs,
                  doesExist: true, // will be overwritten by backend
                  tags: _tags,
                ),
              );
        }
      } catch (e) {
        errorMsg = e.toString();
      }

      if (!mounted) return;
      Navigator.pop(context);

      if (errorMsg != null) {
        showDialog(
          context: context,
          builder: (BuildContext context) => ForcedErrorDialog(
            errorTitle: widget.isEditing
                ? "Something went wrong, unable to edit module"
                : "Something went wrong, unable to register module",
            errorMessage: errorMsg!,
          ),
        );
      } else {
        showConfirmationSnackbar(
          context,
          widget.isEditing ? "Successfully edited module!" : "Successfully registered module!",
        );
      }
    }
  }

  void _handleDeletion() async {
    String? errorMsg;
    setState(() {
      _hasSubmitted = true;
    });

    try {
      await ref.read(moduleListProvider.notifier).deleteModule(widget.module!);
    } catch (e) {
      errorMsg = e.toString();
    }

    if (!mounted) return;
    Navigator.pop(context);

    if (errorMsg != null) {
      showDialog(
        context: context,
        builder: (BuildContext context) =>
            ForcedErrorDialog(errorTitle: "Something went wrong, unable to delete module", errorMessage: errorMsg!),
      );
    } else {
      showConfirmationSnackbar(context, "Successfully deleted module!");
    }
  }

  @override
  Widget build(BuildContext context) {
    String currentOutput =
        '[${_inputs.map((input) {
          switch (input.type) {
            case ModuleInputType.digitSlider:
              return "double";
            case ModuleInputType.rangeSlider:
              return "[double, double]";
            case ModuleInputType.smallText:
              return "String";
            case ModuleInputType.checkbox:
              return "[bool * n]";
            case ModuleInputType.dropdown:
              return "String";
          }
        }).join(", ")}]';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isEditing ? "Edit this module" : "Add a new module",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const _Spacer(),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      autofocus: true,
                      controller: _nameController,
                      maxLength: 50,
                      decoration: const InputDecoration(
                        icon: Icon(FontAwesomeIcons.signature),
                        labelText: "Module Name",
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please enter a name.";
                        }
                        return null;
                      },
                    ),
                    const _Spacer(),
                    TextFormField(
                      controller: _descriptionController,
                      maxLength: 300,
                      decoration: const InputDecoration(
                        icon: Icon(FontAwesomeIcons.fileLines),
                        labelText: "Description",
                      ),
                      validator: (value) {
                        return null;
                      },
                    ),
                    const _Spacer(),
                    TextFormField(
                      controller: _filenameController,
                      maxLength: 50,
                      decoration: InputDecoration(
                        icon: const Icon(FontAwesomeIcons.file),
                        labelText: "File name",
                        helper: Text(
                          "The name of the .py file you have placed in backend/modules.",
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please enter a file name.";
                        } else if (["/", "\\", "..", "~"].any((substring) => value.contains(substring))) {
                          return "No path traversal, only enter the name of the file itself (e.g., 'module1.py')";
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 45, thickness: 2),
              Text("Configure Tags", style: Theme.of(context).textTheme.titleMedium),
              _Spacer(),
              TagsEdit(tags: _tags, onUpdateTags: _updateTags),
              const Divider(height: 45, thickness: 2),
              Text("Configure Inputs", style: Theme.of(context).textTheme.titleMedium),
              const Text("The outputs of these will be passed to your module as a single list."),
              _inputs.isEmpty
                  ? Container()
                  : Text("Currently returns: $currentOutput", style: const TextStyle(fontStyle: FontStyle.italic)),
              _inputs.isEmpty ? Container() : const _Spacer(),
              _inputs.isEmpty
                  ? Container()
                  : Flexible(
                      child: ReorderableListView(
                        shrinkWrap: true,
                        scrollDirection: Axis.vertical,
                        onReorder: (oldIndex, newIndex) => onReorder(oldIndex, newIndex),
                        children: _inputs
                            .map(
                              (input) => InputPreview(
                                input: input,
                                onRemoveInput: onRemoveInput,
                                register: register,
                                unregister: unregister,
                                key: ValueKey(input),
                              ),
                            )
                            .toList(),
                      ),
                    ),
              const _Spacer(),
              _AddInputMenu(onAddInput: onAddInput),
              const SizedBox(height: 40),
              if (widget.isEditing && widget.module!.inputs.isNotEmpty) ...[
                Row(
                  children: [
                    Flexible(flex: 2, child: Container()),
                    Flexible(
                      flex: 5,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Text(
                              "Editing any inputs (excl. descriptions) will remove existing presets and reset all instances of this module",
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.secondary,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.end,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(Icons.warning_amber, color: Theme.of(context).colorScheme.secondary),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  widget.isEditing
                      ? TextButton.icon(
                          label: Text("Delete module", style: TextStyle(color: Theme.of(context).colorScheme.error)),
                          icon: const Icon(Icons.delete_outline),
                          style: ButtonStyle(
                            iconColor: WidgetStateProperty.all<Color>(Theme.of(context).colorScheme.error),
                          ),
                          onPressed: _hasSubmitted ? null : _handleDeletion,
                        )
                      : Container(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: _hasSubmitted ? null : _handleAddOrEdit,
                        child: Text(
                          widget.isEditing ? "Save & Update" : "Add Module",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
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

class _Spacer extends StatelessWidget {
  const _Spacer();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 15);
  }
}

class _AddInputMenu extends StatefulWidget {
  const _AddInputMenu({required this.onAddInput});

  final List<ModuleInputType> possibleInputs = ModuleInputType.values;
  final void Function(ModuleInputType) onAddInput;

  @override
  State<_AddInputMenu> createState() => _AddInputMenuState();
}

class _AddInputMenuState extends State<_AddInputMenu> {
  final FocusNode _buttonFocusNode = FocusNode();

  @override
  void dispose() {
    _buttonFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<MenuItemButton> menuItems = widget.possibleInputs.map((inputType) {
      String inputName = switch (inputType) {
        ModuleInputType.digitSlider => "Digit Slider",
        ModuleInputType.rangeSlider => "Range Slider",
        ModuleInputType.smallText => "Small Text Input",
        ModuleInputType.checkbox => "Checkbox",
        ModuleInputType.dropdown => "Dropdown",
      };
      return MenuItemButton(
        onPressed: () {
          widget.onAddInput(inputType);
        },
        child: Text(inputName),
      );
    }).toList();

    return MenuAnchor(
      childFocusNode: _buttonFocusNode,
      menuChildren: menuItems,
      builder: (_, MenuController controller, Widget? child) {
        return TextButton.icon(
          focusNode: _buttonFocusNode,
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          icon: const Icon(Icons.add),
          label: const Text("Add input"),
        );
      },
    );
  }
}
