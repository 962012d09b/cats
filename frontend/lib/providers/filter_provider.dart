import 'package:cats/providers/datasets_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'generated/filter_provider.g.dart';

@riverpod
class DatasetFilterTags extends _$DatasetFilterTags {
  @override
  List<String> build() {
    ref.keepAlive();
    return [];
  }

  void toggleFilterTag(String tag) {
    state = _toggleFilterTag(state, tag);
  }

  void removeFilterTag(String tag) {
    state = _removeFilterTag(state, tag);
  }

  void clearFilterTags() {
    state = _clearFilterTags(state);
  }

  List<int> getExcludedButSelectedIds(List<int> selectedIds) {
    var allDatasetsAsync = ref.read(availableDatasetsProvider);

    List<int> excludedButSelectedIds = [];
    allDatasetsAsync.when(
      data: (allDatasets) {
        var selectedDatasets = allDatasets.where((dataset) => selectedIds.contains(dataset.id));
        for (var dataset in selectedDatasets) {
          if (!state.every((tag) => dataset.tags.contains(tag))) {
            excludedButSelectedIds.add(dataset.id);
          }
        }
      },
      loading: () {},
      error: (err, stack) {},
    );

    return excludedButSelectedIds;
  }
}

@riverpod
class ModuleFilterTags extends _$ModuleFilterTags {
  @override
  List<String> build() {
    return [];
  }

  void toggleFilterTag(String tag) {
    state = _toggleFilterTag(state, tag);
  }

  void removeFilterTag(String tag) {
    state = _removeFilterTag(state, tag);
  }

  void clearFilterTags() {
    state = _clearFilterTags(state);
  }
}

List<String> _toggleFilterTag(List<String> state, String tag) {
  if (state.contains(tag)) {
    return state.where((element) => element != tag).toList();
  } else {
    return [...state, tag];
  }
}

List<String> _removeFilterTag(List<String> state, String tag) {
  return state.where((element) => element != tag).toList();
}

List<String> _clearFilterTags(List<String> state) {
  return [];
}
