import 'dart:convert';
import 'dart:async';
import 'package:cats/utility/http_utility.dart';
import 'package:http/http.dart' as http;

import 'package:cats/models/processing.dart';
import 'package:cats/providers/connection_provider.dart';
import 'package:cats/providers/datasets_provider.dart';
import 'package:cats/providers/pipelines_provider.dart';
import 'package:cats/providers/results_provider.dart';
import 'package:cats/providers/settings_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'generated/processing_provider.g.dart';

@riverpod
class Processing extends _$Processing {
  Timer? _pollingTimer;
  final String instructions = "Select datasets and pipelines to start processing";

  @override
  ProcessingState build() {
    ref.keepAlive();

    final selectedDatasets = ref.watch(selectedDatasetIdsProvider);
    final pipelineState = ref.watch(pipelinesProvider);
    final pipelineDefaults = ref.watch(globalPipelineDefaultsProvider);

    if (selectedDatasets.isEmpty || pipelineState.isEmpty) {
      _pollingTimer?.cancel();
      Future.microtask(() {
        // must be delayed to avoid modifying the results provider during initialization (which riverpod forbids)
        ref.read(resultsProvider.notifier).setResults([]);
      });
      return ProcessingState(
        jobId: "",
        message: instructions,
        progress: 0,
        results: [],
        ready: true,
        successful: true,
      );
    }

    _startProcessing(selectedDatasets, pipelineState, pipelineDefaults);

    return ProcessingState(
      jobId: "",
      message: "Starting processing...",
      progress: 0,
      results: [],
      ready: false,
      successful: false,
    );
  }

  void _startProcessing(List<int> selectedDatasets, List<dynamic> pipelines, dynamic defaults) async {
    _pollingTimer?.cancel();

    final apiEndpoint = ref.read(backendUriProvider).replace(path: "/api/process");
    final credentials = ref.read(credentialsHeaderProvider);

    try {
      final response = await http.post(
        apiEndpoint,
        headers: {'Content-Type': 'application/json', ...credentials},
        body: jsonEncode({
          "pipelines": [for (var pipe in pipelines) pipe.toJson()],
          "datasets": selectedDatasets,
          "pipeline_defaults": defaults.toJson(),
        }),
      );
      verifyResponse(response);

      final initialState = ProcessingState.fromJson(jsonDecode(response.body));
      state = initialState;

      _pollStatus(initialState.jobId);
    } catch (e) {
      state = ProcessingState(
        jobId: "",
        message: "Error: $e",
        progress: 0,
        results: [],
        ready: true,
        successful: false,
      );
      rethrow;
    }
  }

  void _pollStatus(String jobId) {
    final statusUri = ref.read(backendUriProvider).replace(path: "/api/process/status/$jobId");
    final credentials = ref.read(credentialsHeaderProvider);

    _pollingTimer = Timer.periodic(Duration(milliseconds: 500), (timer) async {
      try {
        final response = await http.get(statusUri, headers: credentials);
        verifyResponse(response);
        final newState = ProcessingState.fromJson(jsonDecode(response.body));
        state = newState;

        if (newState.ready) {
          timer.cancel();
          if (newState.successful && newState.results.isNotEmpty) {
            ref.read(resultsProvider.notifier).setResults(newState.results);
          }
        }
      } catch (e) {
        timer.cancel();
        state = ProcessingState(
          jobId: jobId,
          message: "Error polling: $e",
          progress: 0,
          results: [],
          ready: true,
          successful: false,
        );
        rethrow;
      }
    });
  }
}
