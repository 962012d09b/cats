import 'package:cats/widgets/filters/tags_edit.dart';
import 'package:cats/widgets/settings/utility/helper.dart';
import 'package:cats/widgets/utility/error_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cats/models/dataset.dart';
import 'package:cats/providers/datasets_provider.dart';

class NewDatasetDialog extends ConsumerStatefulWidget {
  const NewDatasetDialog({super.key, this.isEditing = false, this.dataset});

  final bool isEditing;
  final Dataset? dataset;

  @override
  ConsumerState<NewDatasetDialog> createState() => _NewDatasetDialogState();
}

class _NewDatasetDialogState extends ConsumerState<NewDatasetDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _filenameController;

  List<String> _tags = [];
  bool _hasSubmitted = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _filenameController = TextEditingController();

    if (widget.isEditing) {
      _nameController.text = widget.dataset!.name;
      _descriptionController.text = widget.dataset!.description ?? "";
      _filenameController.text = widget.dataset!.fileName;
      _tags = [...widget.dataset!.tags];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _filenameController.dispose();
    super.dispose();
  }

  void _updateTags(List<String> tags) {
    setState(() {
      _tags = tags;
    });
  }

  void _handleAddOrEdit() async {
    if (_formKey.currentState!.validate()) {
      String? errorMsg;
      setState(() {
        _hasSubmitted = true;
      });

      try {
        if (widget.isEditing) {
          await ref
              .read(availableDatasetsProvider.notifier)
              .editExistingDataset(
                Dataset(
                  id: widget.dataset!.id,
                  name: _nameController.text,
                  description: _descriptionController.text,
                  fileName: _filenameController.text,
                  doesExist: true, // will be overwritten by backend
                  trueAlertCount: 0, // will be overwritten by backend
                  falseAlertCount: 0, // will be overwritten by backend
                  alertTypeCount: 0, // will be overwritten by backend
                  alertSourceCount: 0, // will be overwritten by backend
                  durationIso8601: "", // will be overwritten by backend
                  tags: _tags,
                ),
              );
        } else {
          await ref
              .read(availableDatasetsProvider.notifier)
              .addNewDataset(
                Dataset(
                  id: 0, // will be overwritten by backend
                  name: _nameController.text,
                  description: _descriptionController.text,
                  fileName: _filenameController.text,
                  doesExist: true, // will be overwritten by backend
                  trueAlertCount: 0, // will be overwritten by backend
                  falseAlertCount: 0, // will be overwritten by backend
                  alertTypeCount: 0, // will be overwritten by backend
                  alertSourceCount: 0, // will be overwritten by backend
                  durationIso8601: "", // will be overwritten by backend
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
          builder:
              (BuildContext context) => ForcedErrorDialog(
                errorTitle:
                    widget.isEditing
                        ? "Something went wrong, unable to edit dataset"
                        : "Something went wrong, unable to register dataset",
                errorMessage: errorMsg!,
              ),
        );
      } else {
        showConfirmationSnackbar(
          context,
          widget.isEditing ? "Successfully edited dataset!" : "Successfully registered dataset!",
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
      await ref.read(availableDatasetsProvider.notifier).deleteDataset(widget.dataset!.id);
    } catch (e) {
      errorMsg = e.toString();
    }

    if (!mounted) return;
    Navigator.pop(context);

    if (errorMsg != null) {
      showDialog(
        context: context,
        builder:
            (BuildContext context) => ForcedErrorDialog(
              errorTitle: "Something went wrong, unable to delete dataset",
              errorMessage: errorMsg!,
            ),
      );
    } else {
      showConfirmationSnackbar(context, "Successfully deleted dataset!");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isEditing ? "Edit an existing dataset" : "Add a new dataset",
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
                      labelText: "Dataset Name",
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
                        "The name of the file you have placed in the /datasets directory.",
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Please enter a file name.";
                      } else if (["/", "\\", "..", "~"].any((substring) => value.contains(substring))) {
                        return "No path traversal, only enter the name of the file itself (e.g., 'dataset.jsonl')";
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 45, thickness: 2),
            Text("Configure Tags", style: Theme.of(context).textTheme.titleMedium),
            const _Spacer(),
            TagsEdit(tags: _tags, onUpdateTags: _updateTags),
            const SizedBox(height: 50),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                widget.isEditing
                    ? TextButton.icon(
                      label: Text("Delete entry", style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
                        widget.isEditing ? "Save Changes" : "Add Dataset",
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
    );
  }
}

class _Spacer extends StatelessWidget {
  const _Spacer();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 20);
  }
}
