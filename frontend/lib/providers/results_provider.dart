import 'package:cats/widgets/plots/multi_use_curve.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cats/models/result.dart';
import 'package:cats/providers/pipelines_provider.dart';
import 'package:cats/widgets/plots/radar_chart.dart';
part 'generated/results_provider.g.dart';

@riverpod
class MaskedResults extends _$MaskedResults {
  @override
  List<PipeResult> build() {
    ref.keepAlive();

    final visibility = ref.watch(pipelineVisibilityProvider);
    final results = ref.watch(resultsProvider);

    final List<PipeResult> maskedResults = [];

    for (var i = 0; i < results.length; i++) {
      results[i].isVisible = visibility[i];
      maskedResults.add(results[i].copyWith(isVisible: visibility[i]));
    }

    return maskedResults;
  }
}

@riverpod
class Results extends _$Results {
  @override
  List<PipeResult> build() {
    ref.keepAlive();
    return [];
  }

  void setResults(List<Map<String, dynamic>> newResults) {
    if (newResults.isEmpty) {
      state = [];
      return;
    }

    final List<PipeResult> results = [];
    for (var i = 0; i < newResults.length; i++) {
      results.add(PipeResult.fromJson(newResults[i]));
    }
    state = results;
  }

  void removeAt(int index) {
    var newState = [...state];
    if (newState.isEmpty) return;
    newState.removeAt(index);
    state = newState;
  }
}

@riverpod
class PreviousMultiUseGraphType extends _$PreviousMultiUseGraphType {
  @override
  MultiUseGraphType build() {
    ref.keepAlive();
    return MultiUseGraphType.precisionRecall;
  }

  void updatePreviousType(MultiUseGraphType newState) {
    state = newState;
  }
}

@riverpod
class PreviousAucGraphType extends _$PreviousAucGraphType {
  @override
  AucGraphType build() {
    ref.keepAlive();
    return AucGraphType.skillAdjusted;
  }

  void updatePreviousType(AucGraphType newState) {
    state = newState;
  }
}
