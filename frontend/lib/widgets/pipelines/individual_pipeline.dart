import 'dart:math';

import 'package:cats/constants.dart';
import 'package:cats/widgets/pipelines/pipe_settings_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cats/models/module.dart';
import 'package:cats/models/pipeline.dart';
import 'package:cats/providers/pipelines_provider.dart';
import 'package:cats/widgets/modules/individual_module.dart';

class IndividualPipeline extends StatelessWidget {
  const IndividualPipeline({super.key, required this.pipeline, required this.index});

  final Pipeline pipeline;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PipelineHeader(pipeline: pipeline, index: index),
        const SizedBox(height: 10),
        _PipelineContent(modules: pipeline.modules, pipeIndex: index),
      ],
    );
  }
}

class _PipelineHeader extends ConsumerStatefulWidget {
  const _PipelineHeader({required this.pipeline, required this.index});

  final Pipeline pipeline;
  final int index;

  @override
  ConsumerState<_PipelineHeader> createState() => __PipelineHeaderState();
}

class __PipelineHeaderState extends ConsumerState<_PipelineHeader> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _controller;
  bool isEditable = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.pipeline.name);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void handleNewInput() {}

  @override
  Widget build(BuildContext context) {
    bool firstEdit = true;
    final bool allowNewPipe = ref.read(pipelinesProvider).length < maximumPipelines;
    int avgMethodIndex = ref.read(pipelinesProvider)[widget.index].settings.averagingMethod.indexOf(true);

    return Row(
      children: [
        Container(
          width: 200,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: isEditable
              ? BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                  border: Border.all(width: 1, color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 1)),
                )
              : const BoxDecoration(),
          child: isEditable
              ? Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _controller,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Name can't be empty.";
                      }
                      return null;
                    },
                    maxLength: 30,
                    style: TextStyle(fontSize: Theme.of(context).textTheme.bodyMedium!.fontSize),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                    ),
                    onTap: () {
                      if (firstEdit) {
                        _controller.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: _controller.value.text.length,
                        );
                        firstEdit = false;
                      }
                    },
                    onFieldSubmitted: (value) {
                      setState(() {
                        if (_controller.text != widget.pipeline.name) {
                          if (_formKey.currentState!.validate()) {
                            ref.read(pipelinesProvider.notifier).changePipeName(_controller.text, widget.index);
                            isEditable = !isEditable;
                          }
                        } else {
                          isEditable = !isEditable;
                        }
                      });
                    },
                  ),
                )
              : Text(_controller.text, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 9),
        Tooltip(
          message: isEditable ? "Apply change" : "Edit pipeline name",
          child: IconButton(
            onPressed: () {
              setState(() {
                if (isEditable && _controller.text != widget.pipeline.name) {
                  if (_formKey.currentState!.validate()) {
                    ref.read(pipelinesProvider.notifier).changePipeName(_controller.text, widget.index);
                    isEditable = !isEditable;
                  }
                } else {
                  isEditable = !isEditable;
                }
              });
            },
            icon: isEditable ? const Icon(Icons.check) : const Icon(Icons.edit),
            iconSize: 18,
          ),
        ),
        _VisibilityButton(index: widget.index),
        Tooltip(
          message: allowNewPipe ? "Duplicate pipeline" : "Maximum of $maximumPipelines pipelines reached.",
          child: IconButton(
            onPressed: allowNewPipe
                ? () => ref.read(pipelinesProvider.notifier).duplicatePipeline(widget.index)
                : null,
            icon: const Icon(Icons.copy),
            iconSize: 18,
          ),
        ),
        Tooltip(
          message: "Pipeline settings",
          child: IconButton(
            onPressed: () {
              showGeneralDialog(
                context: context,
                barrierDismissible: true,
                barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
                transitionDuration: const Duration(milliseconds: 300),
                pageBuilder: (context, animation, secondaryAnimation) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Material(
                      elevation: 16,
                      child: SizedBox(
                        width: (MediaQuery.of(context).size.width < mediumScreenMinSize)
                            ? MediaQuery.of(context).size.width * 0.4
                            : MediaQuery.of(context).size.width * 0.25,
                        height: double.infinity,
                        child: PipeSettingsDrawer(pipeIndex: widget.index),
                      ),
                    ),
                  );
                },
                transitionBuilder: (context, animation, secondaryAnimation, child) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(-1.0, 0.0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutExpo)),
                    child: child,
                  );
                },
              );
            },
            icon: const Icon(Icons.settings),
            iconSize: 18,
          ),
        ),
        Tooltip(
          message: "Averaging method",
          child: InkWell(
            onTap: () => ref.read(pipelinesProvider.notifier).toggleAveragingMethod(widget.index),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                // color: Theme.of(context).colorScheme.SOME_COLOR,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.primary, width: 1),
              ),
              child: Text(
                ["Geometric mean", "Arithmetic mean"][avgMethodIndex],
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: Theme.of(context).textTheme.bodyMedium!.fontSize,
                ),
              ),
            ),
          ),
        ),
        Expanded(child: Container()),
        Padding(
          padding: const EdgeInsets.only(right: 36),
          child: Tooltip(
            message: "Delete pipeline",
            child: IconButton(
              onPressed: () => ref.read(pipelinesProvider.notifier).deletePipeline(widget.index),
              icon: const Icon(Icons.delete_outline),
              color: Theme.of(context).colorScheme.error,
              iconSize: 18,
            ),
          ),
        ),
      ],
    );
  }
}

class _PipelineContent extends ConsumerWidget {
  const _PipelineContent({required this.modules, required this.pipeIndex});

  final List<Module> modules;
  final int pipeIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrollController = ScrollController();
    final double sumOfWeights = modules.fold(0, (sum, mod) => sum + mod.weight);

    final List<IndividualModule> content = [
      for (int i = 0; i < modules.length; i++)
        IndividualModule(
          module: modules[i],
          pipeIndex: pipeIndex,
          moduleIndex: i,
          sumOfWeights: sumOfWeights,
          key: ValueKey(modules[i].uuid),
        ),
    ];

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: getMaxModuleHeight(modules)),
      child: content.isEmpty
          ? Text(
              "No modules here... try adding one!",
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            )
          : Scrollbar(
              controller: scrollController,
              child: ReorderableListView(
                scrollDirection: Axis.horizontal,
                cacheExtent: 100000, // keep everything in cache
                scrollController: scrollController,
                onReorder: (oldIndex, newIndex) {
                  if (oldIndex != newIndex) {
                    ref.read(pipelinesProvider.notifier).swapModules(pipeIndex, oldIndex, newIndex);
                  }
                },
                children: content,
              ),
            ),
    );
  }
}

double getMaxModuleHeight(List<Module> modules) {
  double currentMax = 0;
  const double headerHeight = 60 + 16;
  const double handleHeight = 45;

  for (var mod in modules) {
    if (mod.inputs.isEmpty) {
      continue;
    }

    double thisModHeight = 0;

    for (var input in mod.inputs) {
      if (input.description != "") {
        thisModHeight += 24;
      }

      // find heights via flutter inspector
      if (input.type == ModuleInputType.digitSlider) {
        thisModHeight += 48;
      } else if (input.type == ModuleInputType.rangeSlider) {
        thisModHeight += 48;
      } else if (input.type == ModuleInputType.checkbox) {
        thisModHeight += 40 * min(4, (input as CheckboxInput).labels.length);
      } else if (input.type == ModuleInputType.dropdown) {
        thisModHeight += 34;
      } else if (input.type == ModuleInputType.smallText) {
        thisModHeight += 48;
      }
    }

    if (thisModHeight > currentMax) {
      currentMax = thisModHeight;
    }
  }

  if (currentMax == 0) {
    return headerHeight + 20 + handleHeight;
  } else {
    return min(450, headerHeight + currentMax + handleHeight);
  }
}

class _VisibilityButton extends ConsumerWidget {
  const _VisibilityButton({required this.index});

  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isVisible = ref.watch(pipelineVisibilityProvider)[index];

    return Tooltip(
      message: isVisible ? "Hide pipeline" : "Show pipeline",
      child: IconButton(
        onPressed: () {
          ref.read(pipelineVisibilityProvider.notifier).toggleVisibility(index);
        },
        icon: isVisible ? const Icon(Icons.visibility_outlined) : const Icon(Icons.visibility_off_outlined),
        iconSize: 18,
        color: isVisible ? null : IconTheme.of(context).color?.withValues(alpha: 0.4),
      ),
    );
  }
}
