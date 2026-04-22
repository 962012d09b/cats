import 'package:cats/constants.dart';
import 'package:cats/providers/filter_provider.dart';
import 'package:cats/widgets/filters/filter_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cats/models/module.dart';
import 'package:cats/models/pipeline.dart';
import 'package:cats/providers/module_provider.dart';
import 'package:cats/providers/pipelines_provider.dart';
import 'package:cats/widgets/utility/error_widgets.dart';
import 'package:cats/widgets/pipelines/individual_pipeline.dart';
import 'package:cats/widgets/modules/module_overview.dart';
import 'package:cats/widgets/modules/new_module_dialog.dart';

class PipelineScreen extends ConsumerWidget {
  const PipelineScreen({super.key});

  void addPipeline(WidgetRef ref) {
    String name = ref.read(ongoingPipeCounterProvider.notifier).generatePipeName();
    ref.read(pipelinesProvider.notifier).addPipeline(name);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Pipeline> pipelines = ref.watch(pipelinesProvider);
    final AsyncValue<List<Module>> modules = ref.watch(moduleListProvider);
    final List<String> filterTags = ref.watch(moduleFilterTagsProvider);

    List<Widget> pipes =
        pipelines
            .asMap()
            .entries
            .expand(
              (entry) => [
                IndividualPipeline(key: ValueKey(entry.value.uuid), pipeline: entry.value, index: entry.key),
                const Divider(indent: 5, endIndent: 30),
              ],
            )
            .toList();

    return modules.when(
      data: (allModules) {
        List<Module> filteredModules =
            allModules.where((module) {
              return filterTags.every((tag) => module.tags.contains(tag));
            }).toList();

        return Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilterUi(filterType: FilterType.moduleFilter),
              _ModuleOverview(
                filteredModules: filteredModules,
                pipelines: pipelines,
                modulesExist: allModules.isNotEmpty,
              ),
              const Divider(indent: 5, endIndent: 30),
              ...pipes,
              _AddPipelineButton(addPipeline: () => addPipeline(ref), pipelineTotal: pipelines.length),
            ],
          ),
        );
      },
      error: (error, stackTrace) {
        return Flexible(child: ErrorContainer(errorInfo: error, stackTrace: stackTrace));
      },
      loading: () => const CircularProgressIndicator(),
    );
  }
}

class _ModuleOverview extends StatelessWidget {
  const _ModuleOverview({required this.filteredModules, required this.pipelines, required this.modulesExist});

  final List<Module> filteredModules;
  final List<Pipeline> pipelines;
  final bool modulesExist;

  @override
  Widget build(BuildContext context) {
    final scrollController = ScrollController();

    return Scrollbar(
      controller: scrollController,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        controller: scrollController,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            if (filteredModules.isEmpty)
              _NoModuleCard(content: modulesExist ? "Filter doesn't match any modules." : "No modules available.")
            else
              ...filteredModules.map((module) => ModuleOverview(mod: module, pipelines: pipelines)),
            const SizedBox(width: 4),
            Material(
              // Wrapping the Ink inside a "dummy" Material fixes a weird rendering error (see https://github.com/flutter/flutter/issues/73315)
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap:
                    () => showDialog(
                      context: context,
                      builder: (BuildContext ctx) => const Dialog(child: NewModuleDialog()),
                    ),
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [Theme.of(context).colorScheme.tertiaryContainer, Theme.of(context).colorScheme.surface],
                    ),
                  ),
                  width: moduleOverviewWidth / 2,
                  height: moduleOverviewHeight,
                  child: const Center(child: Icon(Icons.add)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddPipelineButton extends StatelessWidget {
  const _AddPipelineButton({required this.addPipeline, required this.pipelineTotal});

  final int pipelineTotal;
  final void Function() addPipeline;

  @override
  Widget build(BuildContext context) {
    final bool allowNewPipe = pipelineTotal < maximumPipelines;

    return Tooltip(
      message: allowNewPipe ? "" : "Maximum of $maximumPipelines pipelines reached.",
      textAlign: TextAlign.center,
      child: TextButton.icon(
        label: const Text("Add a pipeline"),
        icon: const Icon(Icons.add),
        onPressed: allowNewPipe ? () => addPipeline() : null,
      ),
    );
  }
}

class _NoModuleCard extends StatelessWidget {
  const _NoModuleCard({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: SizedBox(
        height: moduleOverviewHeight,
        width: moduleOverviewWidth,
        child: Center(
          child: Text(
            content,
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: Theme.of(context).colorScheme.onTertiaryContainer.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}
