import 'package:cats/constants.dart';
import 'package:cats/models/dataset.dart';
import 'package:cats/providers/filter_provider.dart';
import 'package:cats/widgets/filters/filter_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cats/providers/datasets_provider.dart';
import 'package:cats/widgets/datasets/new_dataset_dialog.dart';
import 'package:cats/widgets/datasets/dataset_card.dart';
import 'package:cats/widgets/utility/error_widgets.dart';

class DatasetScreen extends ConsumerWidget {
  const DatasetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datasetsList = ref.watch(availableDatasetsProvider);
    final filterTags = ref.watch(datasetFilterTagsProvider);

    final scrollController = ScrollController();

    return datasetsList.when(
      data: (allDatasets) {
        final List<Dataset> filteredDatasets = allDatasets.where((dataset) {
          return filterTags.every((tag) => dataset.tags.contains(tag));
        }).toList();

        final List<Widget> datasetCards = filteredDatasets.isEmpty
            ? [
                _NoDatasetsCard(
                  content: allDatasets.isEmpty ? "No datasets available." : "Filter doesn't match any datasets.",
                )
              ]
            : filteredDatasets.map((dataset) => DatasetCard(dataset: dataset, key: ValueKey(dataset.id))).toList();

        return Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilterUi(
                filterType: FilterType.datasetFilter,
              ),
              Scrollbar(
                controller: scrollController,
                child: SingleChildScrollView(
                  controller: scrollController,
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        ...datasetCards,
                        const SizedBox(width: 4),
                        Material(
                          // Wrapping the InkWell inside a "dummy" Material fixes a weird rendering bug (see https://github.com/flutter/flutter/issues/73315)
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => showDialog(
                              context: context,
                              builder: (BuildContext ctx) => const Dialog(child: NewDatasetDialog()),
                            ),
                            child: Ink(
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: LinearGradient(colors: [
                                    Theme.of(context).colorScheme.surfaceContainer,
                                    Theme.of(context).colorScheme.surface
                                  ])),
                              width: datasetCardWidth / 2,
                              height: datasetCardHeight,
                              child: const Center(child: Icon(Icons.add)),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      error: (error, stackTrace) {
        return Flexible(
          child: ErrorContainer(
            errorInfo: error,
            stackTrace: stackTrace,
          ),
        );
      },
      loading: () => const CircularProgressIndicator(),
    );
  }
}

class _NoDatasetsCard extends StatelessWidget {
  const _NoDatasetsCard({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        height: datasetCardHeight,
        width: datasetCardWidth,
        child: Center(
          child: Text(
            content,
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}
