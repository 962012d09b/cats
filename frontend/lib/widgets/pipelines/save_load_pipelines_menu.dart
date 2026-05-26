import 'package:cats/constants.dart';
import 'package:cats/models/pipeline.dart';
import 'package:cats/providers/pipelines_provider.dart';
import 'package:cats/widgets/settings/utility/helper.dart';
import 'package:cats/widgets/utility/error_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

class SaveLoadPipelinesMenu extends ConsumerWidget {
  const SaveLoadPipelinesMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saveSlots = ref.watch(savedPipelinesProvider);

    return MenuAnchor(
      alignmentOffset: const Offset(
        // I'm not sure that this is the best approach for positioning the menu. Probably not?
        -moduleInstanceWidth * 1.3,
        0,
      ),
      builder: (BuildContext context, MenuController controller, Widget? child) {
        return IconButton(
          iconSize: 26,
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          icon: const Icon(Icons.save),
        );
      },
      style: MenuStyle(
        side: WidgetStatePropertyAll(BorderSide(color: Theme.of(context).colorScheme.onSurface, width: 2)),
      ),
      menuChildren: saveSlots.when(
        data: (slots) {
          return [
            _SaveMenuUI(ctx: context, ref: ref),
            if (slots.isNotEmpty)
              Divider(height: 0, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
            for (var slot in slots)
              _SaveMenuItem(
                title: slot.name,
                description: slot.description,
                onPressed: () {
                  try {
                    ref.read(pipelinesProvider.notifier).importState(slot.pipelineData);
                    showConfirmationSnackbar(context, "Pipeline configuration loaded from \"${slot.name}\"");
                  } catch (e) {
                    showDialog(
                      context: context,
                      builder:
                          (BuildContext context) => ForcedErrorDialog(
                            errorTitle: "Unable to load configuration \"${slot.name}\"",
                            errorMessage: e.toString(),
                          ),
                    );
                  }
                },
                onEdit: () async {
                  final result = await showDialog(
                    context: context,
                    builder: (ctx) => _SavePipelineDialog(existingSave: slot),
                  );
                  if (result != null && result.length == 2) {
                    String saveName = result[0];
                    String saveDescription = result[1];
                    ref
                        .read(savedPipelinesProvider.notifier)
                        .editExistingSave(slot.copyWith(name: saveName, description: saveDescription));

                    if (!context.mounted) {
                      return;
                    }
                    showConfirmationSnackbar(context, "Edited saved configuration \"$saveName\"");
                  }
                },
                onOverwrite: () {
                  ref
                      .read(savedPipelinesProvider.notifier)
                      .editExistingSave(
                        slot.copyWith(pipelineData: ref.read(pipelinesProvider.notifier).exportState()),
                      );
                  showConfirmationSnackbar(context, "Overwrote saved configuration \"${slot.name}\"");
                },
                onDelete: () {
                  ref.read(savedPipelinesProvider.notifier).deleteSavedPipeline(slot.id);
                  showConfirmationSnackbar(context, "Deleted saved configuration \"${slot.name}\"");
                },
              ),
          ];
        },
        error: (error, stackTrace) {
          return [Flexible(child: ErrorContainer(errorInfo: error, stackTrace: stackTrace))];
        },
        loading: () => [CircularProgressIndicator()],
      ),
    );
  }
}

class _SaveMenuUI extends StatelessWidget {
  const _SaveMenuUI({required this.ctx, required this.ref});

  final BuildContext ctx;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final bool pipelineIsEmpty = ref.read(pipelinesProvider).isEmpty;

    return SizedBox(
      width: moduleInstanceWidth * 2,
      child: MenuItemButton(
        onPressed:
            pipelineIsEmpty
                ? null
                : () async {
                  final List<String>? result = await showDialog<List<String>>(
                    context: ctx,
                    builder: (ctx) => const _SavePipelineDialog(),
                  );

                  if (result != null && result.length == 2) {
                    String saveName = result[0];
                    String saveDescription = result[1];
                    ref.read(savedPipelinesProvider.notifier).savePipelineState(saveName, saveDescription);

                    if (!ctx.mounted) {
                      return;
                    }
                    showConfirmationSnackbar(ctx, "Pipeline configuration saved as \"$saveName\"");
                  }
                },
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child:
              pipelineIsEmpty
                  ? Row(
                    children: [
                      Icon(Icons.info),
                      SizedBox(width: 8),
                      Text("Nothing to save, create some pipelines first"),
                    ],
                  )
                  : Row(
                    children: [
                      Icon(Icons.save_as, size: 30),
                      SizedBox(width: 8),
                      const Text("Save current pipeline configuration"),
                    ],
                  ),
        ),
      ),
    );
  }
}

class _SaveMenuItem extends StatefulWidget {
  const _SaveMenuItem({
    required this.title,
    required this.description,
    required this.onEdit,
    required this.onOverwrite,
    required this.onPressed,
    required this.onDelete,
  });

  final String title;
  final String description;
  final void Function() onEdit;
  final void Function() onOverwrite;
  final void Function() onPressed;
  final void Function() onDelete;

  @override
  State<_SaveMenuItem> createState() => _SaveMenuItemState();
}

class _SaveMenuItemState extends State<_SaveMenuItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: moduleInstanceWidth * 2,
      child: MenuItemButton(
        onHover: (isHovered) => setState(() => _isHovered = isHovered),
        onPressed: widget.onPressed,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(
                        widget.description == "" ? "No description provided." : widget.description,
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontStyle: FontStyle.italic),
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 3,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                flex: 2,
                child:
                    _isHovered
                        ? Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Tooltip(
                              message: "Overwrite save",
                              child: IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: Icon(Icons.flip_to_front_rounded),
                                onPressed: widget.onOverwrite,
                              ),
                            ),
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
                        )
                        : Container(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavePipelineDialog extends StatefulWidget {
  const _SavePipelineDialog({this.existingSave});

  final SavedPipelineConfig? existingSave;

  @override
  _SavePipelineDialogState createState() => _SavePipelineDialogState();
}

class _SavePipelineDialogState extends State<_SavePipelineDialog> {
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
    if (widget.existingSave != null) {
      _nameController.text = widget.existingSave!.name;
      _descriptionController.text = widget.existingSave!.description;
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
      title: Text(
        widget.existingSave != null ? "Edit saved pipeline metadata" : "Save current pipeline configuration",
      ),
      content: SizedBox(
        width: 700,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              focusNode: _nameFocusNode,
              decoration: InputDecoration(labelText: "Name", errorText: _isError ? "Name cannot be empty." : null),
              maxLength: 50,
            ),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: "Description (optional)", alignLabelWithHint: true),
              maxLength: 1000,
              maxLines: null,
              keyboardType: TextInputType.multiline,
            ),
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
