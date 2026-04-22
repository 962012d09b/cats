import 'package:cats/providers/datasets_provider.dart';
import 'package:cats/providers/filter_provider.dart';
import 'package:cats/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum FilterType {
  datasetFilter,
  moduleFilter,
}

class FilterUi extends ConsumerWidget {
  const FilterUi({
    super.key,
    required this.filterType,
  });

  final FilterType filterType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    List<String> filterTags = [];
    List<Widget> warning = [];
    if (filterType == FilterType.datasetFilter) {
      filterTags = ref.watch(datasetFilterTagsProvider);
      final bool showWarning = ref.watch(warningProvider).warnExcludedSelected;
      final List<int> selectedIds = ref.watch(selectedDatasetIdsProvider);
      List<int> excludedButSelectedIds =
          ref.read(datasetFilterTagsProvider.notifier).getExcludedButSelectedIds(selectedIds);

      if (showWarning && excludedButSelectedIds.isNotEmpty) {
        warning = [
          SizedBox(width: 32),
          Icon(
            Icons.warning_amber_rounded,
            color: Theme.of(context).colorScheme.error,
          ),
          SizedBox(width: 8),
          Text(
            "Datasets not included by the current filter are selected.",
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          TextButton(
              onPressed: () =>
                  ref.read(selectedDatasetIdsProvider.notifier).removeMultipleDatasets(excludedButSelectedIds),
              child: Text("Deselect?")),
        ];
      }
    } else if (filterType == FilterType.moduleFilter) {
      filterTags = ref.watch(moduleFilterTagsProvider);
    } else {
      throw Exception("Unknown filter type");
    }

    final List<Widget> content = filterTags.isEmpty
        ? [
            Icon(
              Icons.filter_alt_off_outlined,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            SizedBox(width: 8),
            Text(
              "Currently no filters, click on a tag to add one",
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            )
          ]
        : [
            Icon(Icons.filter_alt_outlined),
            SizedBox(width: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var tag in filterTags)
                  Chip(
                    label: Text(tag),
                    onDeleted: () {
                      if (filterType == FilterType.datasetFilter) {
                        ref.read(datasetFilterTagsProvider.notifier).removeFilterTag(tag);
                      } else if (filterType == FilterType.moduleFilter) {
                        ref.read(moduleFilterTagsProvider.notifier).removeFilterTag(tag);
                      }
                    },
                  ),
              ],
            ),
            ...warning,
          ];

    return SizedBox(
      height: 40,
      child: Row(
        children: content,
      ),
    );
  }
}
