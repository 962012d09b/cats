import 'package:cats/constants.dart';
import 'package:cats/providers/filter_provider.dart';
import 'package:cats/widgets/datasets/preview_dialog.dart';
import 'package:cats/widgets/filters/tags.dart';
import 'package:cats/widgets/settings/utility/helper.dart';
import 'package:cats/widgets/utility/error_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cats/models/dataset.dart';
import 'package:cats/providers/datasets_provider.dart';
import 'package:cats/widgets/datasets/new_dataset_dialog.dart';
import 'package:intl/intl.dart';
import 'package:iso_duration_parser/iso_duration_parser.dart';

class DatasetCard extends ConsumerStatefulWidget {
  const DatasetCard({super.key, required this.dataset});

  final Dataset dataset;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _DatasetCardState();
}

class _DatasetCardState extends ConsumerState<DatasetCard> {
  @override
  Widget build(BuildContext context) {
    final bool isSelected = ref.watch(selectedDatasetIdsProvider).contains(widget.dataset.id);

    return Card(
      elevation: isSelected ? 5 : 1,
      color: isSelected
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : Theme.of(context).colorScheme.surfaceContainer,
      child: SizedBox(
        width: datasetCardWidth,
        child: Column(
          children: [
            _MainContent(dataset: widget.dataset),
            _DatasetUI(
              isSelected: isSelected,
              onSelect: () => ref.read(selectedDatasetIdsProvider.notifier).toggleDataset(widget.dataset.id),
              dataset: widget.dataset,
            ),
          ],
        ),
      ),
    );
  }
}

class _MainContent extends ConsumerWidget {
  const _MainContent({required this.dataset});

  final Dataset dataset;

  String formatDuration(String isoDuration) {
    try {
      final duration = IsoDuration.parse(isoDuration);
      return "${duration.days.toStringAsFixed(0).padLeft(2, '0')}d ${duration.hours.toStringAsFixed(0).padLeft(2, '0')}h ${duration.minutes.toStringAsFixed(0).padLeft(2, '0')}m ${duration.seconds.toStringAsFixed(0).padLeft(2, '0')}s";
    } catch (e) {
      return "n/a";
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int total = dataset.trueAlertCount + dataset.falseAlertCount;
    String countLabel = total > 1 ? "alerts" : "alert";
    String typeLabel = dataset.alertTypeCount > 1 ? "types" : "type";
    String sourceLabel = dataset.alertSourceCount > 1 ? "sources" : "source";

    final formatter = NumberFormat("#,##0");

    List<Widget> content = [
      Text(
        "${formatter.format(total)} $countLabel (${formatter.format(dataset.trueAlertCount)} true, ${formatter.format(dataset.falseAlertCount)} false)\n"
        "${formatter.format(dataset.alertTypeCount)} alert $typeLabel | ${formatter.format(dataset.alertSourceCount)} alert $sourceLabel\n"
        "Duration: ${formatDuration(dataset.durationIso8601)}",
        style: Theme.of(context).textTheme.bodySmall!.copyWith(fontStyle: FontStyle.italic),
      ),
      Divider(height: 10),
      (dataset.description == null || dataset.description!.isEmpty)
          ? Text(
              "No description provided.",
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            )
          : Text(dataset.description!),
    ];

    if (dataset.tags.isNotEmpty) {
      final List<Widget> tagsContent = [SizedBox(height: 5)];
      final List<String> highlightedTags = ref.watch(datasetFilterTagsProvider);

      tagsContent.add(
        TagList(
          tags: dataset.tags,
          tagColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2),
          highlightedTags: highlightedTags,
          onTagTap: (tag) {
            ref.read(datasetFilterTagsProvider.notifier).toggleFilterTag(tag);
          },
        ),
      );

      tagsContent.add(SizedBox(height: 5));
      content = [...tagsContent, ...content];
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        height: datasetCardHeight * 0.78,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.dataset),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      dataset.name,
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: content),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DatasetUI extends ConsumerStatefulWidget {
  const _DatasetUI({required this.isSelected, required this.onSelect, required this.dataset});

  final bool isSelected;
  final void Function() onSelect;
  final Dataset dataset;

  @override
  ConsumerState<_DatasetUI> createState() => _DatasetUIState();
}

class _DatasetUIState extends ConsumerState<_DatasetUI> {
  bool _hasSubmitted = false;

  void _showPreviewDialog() {
    showDialog(
      context: context,
      builder: (BuildContext ctx) => Dialog(
        child: PreviewDialog(title: widget.dataset.name, id: widget.dataset.id),
      ),
    );
  }

  void _reloadDataset() async {
    String? errorMsg;
    setState(() {
      _hasSubmitted = true;
    });

    try {
      // Editing without any changes effectively reloads the dataset
      await ref.read(availableDatasetsProvider.notifier).editExistingDataset(widget.dataset);
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
        builder: (BuildContext context) =>
            ForcedErrorDialog(errorTitle: "Something went wrong, unable to reload dataset", errorMessage: errorMsg!),
      );
    } else {
      showConfirmationSnackbar(context, "Reloaded dataset!");
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: datasetCardHeight * 0.22,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Tooltip(
              message: "Edit dataset",
              child: IconButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (BuildContext ctx) =>
                      Dialog(child: NewDatasetDialog(isEditing: true, dataset: widget.dataset)),
                ),
                icon: const Icon(Icons.edit),
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(width: 5),
            Tooltip(
              message: "Preview dataset",
              child: IconButton(
                onPressed: widget.dataset.doesExist ? _showPreviewDialog : null,
                icon: Icon(Icons.preview),
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(width: 10),
            widget.dataset.doesExist
                ? Tooltip(
                    message: widget.isSelected ? "Unselect dataset" : "Select dataset",
                    child: IconButton(
                      onPressed: widget.onSelect,
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        widget.isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  )
                : Tooltip(
                    textAlign: TextAlign.center,
                    message:
                        "File '${widget.dataset.fileName}' doesn't exist in /backend/datasets\n(Click to reload this dataset)",
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.error_outline),
                      color: Theme.of(context).colorScheme.error,
                      iconSize: 30,
                      onPressed: _hasSubmitted ? null : _reloadDataset,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
