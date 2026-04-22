import 'dart:convert';

import 'package:cats/providers/pipelines_provider.dart';
import 'package:cats/utility/http_utility.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cats/models/module.dart';
import 'package:cats/providers/connection_provider.dart';

part 'generated/module_provider.g.dart';

@riverpod
class ModuleList extends _$ModuleList {
  Uri _apiEndpoint = Uri();
  Map<String, String> _credentialsHeader = {};

  @override
  Future<List<Module>> build() async {
    _apiEndpoint = ref.watch(backendUriProvider).replace(path: "/api/modules");
    _credentialsHeader = ref.watch(credentialsHeaderProvider);

    final response = await http.get(_apiEndpoint, headers: _credentialsHeader);
    verifyResponse(response);

    ref.keepAlive();
    return _convert(response);
  }

  Future<void> addNewModule(Module module) async {
    final response = await http.post(
      _apiEndpoint,
      headers: {'Content-Type': 'application/json', ..._credentialsHeader},
      body: _prepareForBackend(module),
    );

    ref.invalidateSelf();
    await future;

    verifyResponse(response);
  }

  Future<void> editExistingModule(Module module, {bool onlyPresetsEdited = false, bool keepOldValues = false}) async {
    final response = await http.put(
      _apiEndpoint,
      headers: {'Content-Type': 'application/json', ..._credentialsHeader},
      body: _prepareForBackend(module),
    );

    ref.invalidateSelf();
    await future;

    if (onlyPresetsEdited) {
      ref.read(pipelinesProvider.notifier).propagateNewPreset(module.id);
    } else {
      ref.read(pipelinesProvider.notifier).resetModulesAfterModuleEdit(module.id, keepOldValues);
    }

    verifyResponse(response);
  }

  Future<void> deleteModule(Module module) async {
    final response = await http.delete(
      _apiEndpoint,
      headers: {'Content-Type': 'application/json', ..._credentialsHeader},
      body: _prepareForBackend(module),
    );

    ref.invalidateSelf();
    await future;

    ref.read(pipelinesProvider.notifier).updateAfterModuleDelete(module.id);

    verifyResponse(response);
  }

  List<Module> _convert(http.Response response) {
    final List<dynamic> jsonResponse = jsonDecode(response.body);
    List<Module> modules = [for (Map<String, dynamic> module in jsonResponse) Module.fromJson(module)];
    return modules;
  }

  String _prepareForBackend(Module module) {
    final Map<String, dynamic> json = module.toJson();
    for (int i = 0; i < json["inputs"].length; i++) {
      // Remove fields that are not needed by the backend
      json["inputs"][i].remove("runtimeType");
      json["inputs"][i].remove("current_value");
    }
    return jsonEncode(json);
  }
}
