import 'dart:convert';
import 'package:cats/utility/http_utility.dart';
import 'package:http/http.dart' as http;
import 'package:cats/models/dataset.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cats/providers/connection_provider.dart';

part 'generated/datasets_provider.g.dart';

@riverpod
class AvailableDatasets extends _$AvailableDatasets {
  Uri _apiEndpoint = Uri();
  Map<String, String> _credentialsHeader = {};

  @override
  Future<List<Dataset>> build() async {
    _apiEndpoint = ref.watch(backendUriProvider).replace(path: "/api/datasets");
    _credentialsHeader = ref.watch(credentialsHeaderProvider);

    final response = await http.get(_apiEndpoint, headers: _credentialsHeader);
    verifyResponse(response);

    ref.keepAlive();
    return _convertResponseToList(response);
  }

  Future<void> addNewDataset(Dataset dataset) async {
    final response = await http.post(
      _apiEndpoint,
      headers: {'Content-Type': 'application/json', ..._credentialsHeader},
      body: jsonEncode(dataset.toJson()),
    );

    ref.invalidateSelf();
    await future;

    verifyResponse(response);
  }

  Future<void> editExistingDataset(Dataset modifiedDataset) async {
    final response = await http.put(
      _apiEndpoint,
      headers: {'Content-Type': 'application/json', ..._credentialsHeader},
      body: jsonEncode(modifiedDataset.toJson()),
    );

    ref.invalidateSelf();
    await future;

    verifyResponse(response);
  }

  Future<void> deleteDataset(int id) async {
    final response = await http.delete(
      _apiEndpoint,
      headers: {'Content-Type': 'application/json', ..._credentialsHeader},
      body: jsonEncode({"id": id}),
    );

    ref.read(selectedDatasetIdsProvider.notifier).removeMultipleDatasets([id]);
    ref.invalidateSelf();
    await future;

    verifyResponse(response);
  }

  Future<List<Map>> fetchPreviewForDataset(int id) async {
    final Uri apiEndpoint = _apiEndpoint.replace(path: "/api/datasets/$id/preview");
    final response = await http.get(apiEndpoint, headers: _credentialsHeader);

    try {
      final List<dynamic> rawList = jsonDecode(response.body);

      final List<Map> validatedList = rawList.map((item) {
        if (item is Map) {
          return item;
        } else {
          throw FormatException('Cannot parse to JSON. This was the offending item:\n$item');
        }
      }).toList();

      return validatedList;
    } catch (e) {
      throw Exception('Failed to parse preview data: $e');
    }
  }

  Future<Map<String, Map<String, Map<String, int>>>> fetchJitterData(int id) async {
    final Uri apiEndpoint = _apiEndpoint.replace(path: "/api/datasets/$id/jitter");
    final response = await http.get(apiEndpoint, headers: _credentialsHeader);

    verifyResponse(response);

    try {
      final dynamic rawData = jsonDecode(response.body);

      final Map<String, Map<String, Map<String, int>>> jitterData = {};
      (rawData as Map<String, dynamic>).forEach((timestamp, alertTypes) {
        final Map<String, Map<String, int>> alertTypeMap = {};
        (alertTypes as Map<String, dynamic>).forEach((alertType, misuseCounts) {
          alertTypeMap[alertType] = Map<String, int>.from(misuseCounts as Map);
        });
        jitterData[timestamp] = alertTypeMap;
      });

      return jitterData;
    } catch (e) {
      throw Exception('Failed to parse jitter data: $e');
    }
  }

  List<Dataset> _convertResponseToList(http.Response response) {
    try {
      final List<dynamic> jsonList = jsonDecode(response.body);
      final List<Dataset> datasets = jsonList.map((item) => Dataset.fromJson(item as Map<String, dynamic>)).toList();
      return datasets;
    } catch (e) {
      throw Exception('Failed to parse datasets: $e');
    }
  }
}

@riverpod
class SelectedDatasetIds extends _$SelectedDatasetIds {
  @override
  List<int> build() {
    ref.keepAlive();
    return [];
  }

  void toggleDataset(int datasetId) {
    if (state.contains(datasetId)) {
      state = [];
    } else {
      state = [datasetId];
    }
  }

  void removeMultipleDatasets(List<int> datasetIds) {
    final newState = [...state];
    newState.removeWhere((id) => datasetIds.contains(id));
    state = newState;
  }
}
