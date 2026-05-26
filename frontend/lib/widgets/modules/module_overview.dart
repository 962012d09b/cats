import 'package:cats/providers/filter_provider.dart';
import 'package:cats/widgets/filters/tags.dart';
import 'package:cats/widgets/settings/utility/helper.dart';
import 'package:cats/widgets/utility/error_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cats/constants.dart';
import 'package:cats/models/module.dart';
import 'package:cats/models/pipeline.dart';
import 'package:cats/providers/module_provider.dart';
import 'package:cats/providers/pipelines_provider.dart';
import 'package:cats/widgets/modules/new_module_dialog.dart';

class ModuleOverview extends StatelessWidget {
  const ModuleOverview({super.key, required this.mod, required this.pipelines});

  final Module mod;
  final List<Pipeline> pipelines;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: SizedBox(
        width: moduleOverviewWidth,
        height: moduleOverviewHeight,
        child: Align(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [_MainContent(mod: mod), _ModuleUI(pipelines: pipelines, module: mod)],
          ),
        ),
      ),
    );
  }
}

class _MainContent extends ConsumerWidget {
  const _MainContent({required this.mod});

  final Module mod;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    List<Widget> content = [
      (mod.description == null || mod.description!.isEmpty)
          ? Text(
            "No description provided.",
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          )
          : Expanded(child: SingleChildScrollView(child: Text(mod.description!))),
    ];

    if (mod.tags.isNotEmpty) {
      final List<Widget> tagsContent = [SizedBox(height: 5)];
      final List<String> highlightedTags = ref.watch(moduleFilterTagsProvider);

      tagsContent.add(
        TagList(
          tags: mod.tags,
          tagColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
          highlightedTags: highlightedTags,
          onTagTap: (tag) {
            ref.read(moduleFilterTagsProvider.notifier).toggleFilterTag(tag);
          },
        ),
      );

      tagsContent.add(SizedBox(height: 5));
      content = [...tagsContent, ...content];
    }

    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        height: moduleOverviewHeight * 0.78,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(mod.name, style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis),
              ...content,
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleUI extends ConsumerStatefulWidget {
  const _ModuleUI({required this.pipelines, required this.module});

  final List<Pipeline> pipelines;
  final Module module;

  @override
  ConsumerState<_ModuleUI> createState() => _ModuleUIState();
}

class _ModuleUIState extends ConsumerState<_ModuleUI> {
  bool _hasSubmitted = false;

  void _reloadModule() async {
    String? errorMsg;
    setState(() {
      _hasSubmitted = true;
    });

    try {
      // Editing without any changes effectively reloads the dataset
      await ref.read(moduleListProvider.notifier).editExistingModule(widget.module);
    } catch (e) {
      errorMsg = e.toString();
    }

    if (!mounted) return;
    setState(() {
      _hasSubmitted = false;
    });

    if (errorMsg != null) {
      showDialog(
        context: context,
        builder:
            (BuildContext context) => ForcedErrorDialog(
              errorTitle: "Something went wrong, unable to reload module",
              errorMessage: errorMsg!,
            ),
      );
    } else {
      showConfirmationSnackbar(context, "Reloaded module!");
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: moduleOverviewHeight * 0.22,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Tooltip(
            message: "Edit module",
            child: IconButton(
              onPressed:
                  () => showDialog(
                    context: context,
                    builder:
                        (BuildContext ctx) => Dialog(child: NewModuleDialog(isEditing: true, module: widget.module)),
                  ),
              icon: const Icon(Icons.edit),
              padding: EdgeInsets.zero,
            ),
          ),
          widget.module.doesExist
              ? _AddToPipeButton(pipelines: widget.pipelines, module: widget.module)
              : Tooltip(
                textAlign: TextAlign.center,
                message:
                    "File '${widget.module.fileName}' doesn't exist in /backend/modules\n(Click to reload this module)",
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.error_outline),
                  color: Theme.of(context).colorScheme.error,
                  iconSize: 30,
                  onPressed: _hasSubmitted ? null : _reloadModule,
                ),
              ),
        ],
      ),
    );
  }
}

class _AddToPipeButton extends ConsumerStatefulWidget {
  const _AddToPipeButton({required this.pipelines, required this.module});

  final List<Pipeline> pipelines;
  final Module module;

  @override
  ConsumerState<_AddToPipeButton> createState() => _AddToPipeButtonState();
}

class _AddToPipeButtonState extends ConsumerState<_AddToPipeButton> {
  final FocusNode _buttonFocusNode = FocusNode(debugLabel: 'Add module to pipeline');

  @override
  void dispose() {
    _buttonFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<MenuItemButton> menuItems = [];

    if (widget.pipelines.isEmpty) {
      menuItems.add(const MenuItemButton(child: Text("No pipelines, add one first.")));
    } else {
      menuItems.addAll(
        widget.pipelines.asMap().entries.map((mapEntry) {
          return MenuItemButton(
            child: Text(mapEntry.value.name),
            onPressed: () {
              int index = mapEntry.key;
              ref.read(pipelinesProvider.notifier).addModuleToPipe(index, widget.module);
            },
          );
        }),
      );
      if (menuItems.length > 1) {
        menuItems.add(
          MenuItemButton(
            onPressed:
                widget.pipelines.isEmpty || !widget.module.doesExist
                    ? null
                    : () => ref.read(pipelinesProvider.notifier).addModuleToAllPipes(widget.module),
            child: const Text("Add to ALL pipelines"),
          ),
        );
      }
    }

    return Tooltip(
      message: "Add module to pipeline",
      child: MenuAnchor(
        childFocusNode: _buttonFocusNode,
        menuChildren: menuItems,
        builder: (_, MenuController controller, Widget? child) {
          return IconButton(
            focusNode: _buttonFocusNode,
            onPressed: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
            icon: const Icon(Icons.playlist_add),
          );
        },
      ),
    );
  }
}
