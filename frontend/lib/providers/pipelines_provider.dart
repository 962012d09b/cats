import 'dart:convert';
import 'package:cats/models/settings.dart';
import 'package:cats/providers/results_provider.dart';
import 'package:cats/providers/settings_provider.dart';
import 'package:cats/utility/http_utility.dart';
import 'package:http/http.dart' as http;

import 'package:cats/providers/connection_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cats/models/module.dart';
import 'package:cats/models/pipeline.dart';
import 'package:cats/providers/module_provider.dart';
import 'package:uuid/uuid.dart';

part 'generated/pipelines_provider.g.dart';

@riverpod
class Pipelines extends _$Pipelines {
  @override
  List<Pipeline> build() {
    ref.keepAlive();
    return [];
  }

  void addPipeline(String name, {List<Module> modules = const []}) {
    var defaultSettings = ref.read(globalPipelineDefaultsProvider);
    ref.read(pipelineVisibilityProvider.notifier).addNew();

    state = [...state, Pipeline(name: name, modules: modules, settings: defaultSettings, uuid: const Uuid().v4())];
  }

  void deletePipeline(int pipeIndex) {
    var newState = [...state];
    newState.removeAt(pipeIndex);
    ref.read(pipelineVisibilityProvider.notifier).removeAt(pipeIndex);
    ref.read(resultsProvider.notifier).removeAt(pipeIndex);

    state = newState;
  }

  void duplicatePipeline(int pipeIndex) {
    var newState = [...state];
    var newPipe = newState[pipeIndex].copyWith(
      uuid: const Uuid().v4(),
      name: "${newState[pipeIndex].name} (copy)",
      modules: [for (var module in newState[pipeIndex].modules) module.copyWith(uuid: const Uuid().v4())],
    );

    newState.insert(pipeIndex + 1, newPipe);
    ref.read(pipelineVisibilityProvider.notifier).addNew(atIndex: pipeIndex + 1);

    state = newState;
  }

  void changePipeName(String newName, int pipeIndex) {
    var newState = [...state];
    newState[pipeIndex].name = newName;
    state = newState;
  }

  void addModuleToPipe(int pipeIndex, Module module) {
    var newState = [...state];
    Module newModule = module.copyWith(uuid: const Uuid().v4());
    for (var input in newModule.inputs) {
      input.currentValue = input.defaultValue;
    }

    var updatedModules = [...newState[pipeIndex].modules, newModule];
    newState[pipeIndex].modules = updatedModules;
    state = newState;
  }

  void addModuleToAllPipes(Module module) {
    var newState = [...state];
    Module newModule = module.copyWith();
    for (var input in newModule.inputs) {
      input.currentValue = input.defaultValue;
    }

    for (var pipe in newState) {
      var updatedModules = [...pipe.modules, newModule.copyWith(uuid: const Uuid().v4())];
      pipe.modules = updatedModules;
    }
    state = newState;
  }

  void removeModuleFromPipe(int pipeIndex, int moduleIndex) {
    var newState = [...state];
    newState[pipeIndex].modules.removeAt(moduleIndex);
    state = newState;
  }

  void swapModules(int pipeIndex, int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final newState = [...state];
    final movedModule = newState[pipeIndex].modules.removeAt(oldIndex);
    newState[pipeIndex].modules.insert(newIndex, movedModule);
    state = newState;
  }

  void updateSingleParameter(int pipeIndex, int moduleIndex, int inputIndex, dynamic newValue) {
    var newState = [...state];

    var updatedInputs = [for (var input in newState[pipeIndex].modules[moduleIndex].inputs) input.copyWith()];

    updatedInputs[inputIndex] = updatedInputs[inputIndex].copyWith(currentValue: newValue);

    var updatedModule = newState[pipeIndex].modules[moduleIndex].copyWith(inputs: updatedInputs);
    var updatedModules = [...newState[pipeIndex].modules];
    updatedModules[moduleIndex] = updatedModule;

    newState[pipeIndex] = newState[pipeIndex].copyWith(modules: updatedModules);

    state = newState;
  }

  void updateAllParameters(int pipeIndex, int moduleIndex, List<dynamic> newValues) {
    var newState = [...state];

    var updatedInputs = [for (var input in newState[pipeIndex].modules[moduleIndex].inputs) input.copyWith()];

    for (var i = 0; i < updatedInputs.length; i++) {
      updatedInputs[i] = updatedInputs[i].copyWith(currentValue: newValues[i]);
    }

    var updatedModule = newState[pipeIndex].modules[moduleIndex].copyWith(inputs: updatedInputs);
    var updatedModules = [...newState[pipeIndex].modules];
    updatedModules[moduleIndex] = updatedModule;

    newState[pipeIndex] = newState[pipeIndex].copyWith(modules: updatedModules);

    state = newState;
  }

  void updateSettings(int pipeIndex, PipelineSettings newSettings, List<double> newWeights) {
    var newState = [...state];
    var updatedModules = [...newState[pipeIndex].modules];
    for (var i = 0; i < updatedModules.length; i++) {
      updatedModules[i] = updatedModules[i].copyWith(weight: newWeights[i]);
    }
    newState[pipeIndex] = newState[pipeIndex].copyWith(settings: newSettings, modules: updatedModules);
    state = newState;
  }

  void toggleAveragingMethod(int pipeIndex) {
    var newState = [...state];
    var currentMethod = newState[pipeIndex].settings.averagingMethod;

    // shift list one position to the right
    var modifiedMethod = [...currentMethod];
    modifiedMethod.insert(0, modifiedMethod.removeAt(modifiedMethod.length - 1));
    newState[pipeIndex].settings = newState[pipeIndex].settings.copyWith(averagingMethod: modifiedMethod);

    state = newState;
  }

  void resetParametersToDefault(int pipeIndex, int moduleIndex) {
    var newParams = [for (var input in state[pipeIndex].modules[moduleIndex].inputs) input.defaultValue];
    updateAllParameters(pipeIndex, moduleIndex, newParams);
  }

  void resetModulesAfterModuleEdit(int editedModuleId, bool keepOldValues) {
    var newPipes = [...state];
    List<Module> availableModules = ref.read(moduleListProvider).value!;
    Module newModule = availableModules.firstWhere((module) => module.id == editedModuleId).copyWith();

    for (var input in newModule.inputs) {
      input.currentValue = input.defaultValue;
    }

    for (var index = 0; index < newPipes.length; index++) {
      for (var i = 0; i < newPipes[index].modules.length; i++) {
        if (newPipes[index].modules[i].id == editedModuleId) {
          var newModuleInstance = newModule.copyWith(uuid: const Uuid().v4());

          if (keepOldValues) {
            for (var j = 0; j < newPipes[index].modules[i].inputs.length; j++) {
              newModuleInstance.inputs[j].currentValue = state[index].modules[i].inputs[j].currentValue;
            }
          }

          newPipes[index].modules[i] = newModuleInstance;
        }
      }
    }
    state = newPipes;
  }

  void propagateNewPreset(int editedModulePresetId) {
    var newState = [...state];
    final relevantModule = ref
        .read(moduleListProvider)
        .value!
        .firstWhere((module) => module.id == editedModulePresetId);
    final newPreset = relevantModule.inputPresets;

    for (var pipe in newState) {
      for (var i = 0; i < pipe.modules.length; i++) {
        if (pipe.modules[i].id == editedModulePresetId) {
          pipe.modules[i] = pipe.modules[i].copyWith(inputPresets: newPreset);
        }
      }
    }

    state = newState;
  }

  void updateAfterModuleDelete(int editedModuleId) {
    var newState = [...state];
    for (var pipe in newState) {
      pipe.modules = pipe.modules.where((module) => module.id != editedModuleId).toList();
    }
    state = newState;
  }

  String exportState() {
    // for pretty printing:
    // return const JsonEncoder.withIndent('  ').convert([for (var pipe in state) pipe.toJson()]);
    return const JsonEncoder().convert([for (var pipe in state) pipe.toJson()]);
  }

  String? importState(String json) {
    List<Pipeline> newState = [];

    List<Module> availableModules = ref.read(moduleListProvider).value!;
    final List<dynamic> decoded = jsonDecode(json);

    newState = [for (var pipe in decoded) Pipeline.fromJson(pipe)];
    for (var pipe in newState) {
      pipe.verifyModules(availableModules);
    }

    // don't import input presets, keep those that currently exist
    for (var pipe in newState) {
      for (var index = 0; index < pipe.modules.length; index++) {
        var availableModule = availableModules.firstWhere((mod) => mod.id == pipe.modules[index].id);
        pipe.modules[index] = pipe.modules[index].copyWith(inputPresets: availableModule.inputPresets);
      }
    }

    ref.read(pipelineVisibilityProvider.notifier).loadNewState(newState.length);

    state = newState;
    return null;
  }
}

@riverpod
class OngoingPipeCounter extends _$OngoingPipeCounter {
  @override
  int build() {
    ref.keepAlive();
    return 0;
  }

  String generatePipeName() {
    state = state + 1;
    return "Pipe ${state.toString()}";
  }
}

@riverpod
class PipelineVisibility extends _$PipelineVisibility {
  @override
  List<bool> build() {
    ref.keepAlive();
    return [];
  }

  void toggleVisibility(int index) {
    var newState = [...state];
    newState[index] = !newState[index];
    state = newState;
  }

  void addNew({int? atIndex}) {
    if (atIndex != null) {
      var newState = [...state];
      newState.insert(atIndex, true);
      state = newState;
    } else {
      state = [...state, true];
    }
  }

  void removeAt(int index) {
    var newState = [...state];
    newState.removeAt(index);
    state = newState;
  }

  void loadNewState(int numOfPipes) {
    state = [for (var i = 0; i < numOfPipes; i++) true];
  }
}

@riverpod
class SavedPipelines extends _$SavedPipelines {
  Uri _apiEndpoint = Uri();
  Map<String, String> _credentialsHeader = {};

  @override
  Future<List<SavedPipelineConfig>> build() async {
    ref.keepAlive();
    _apiEndpoint = ref.watch(backendUriProvider).replace(path: "/api/saves");
    _credentialsHeader = ref.watch(credentialsHeaderProvider);

    final response = await http.get(_apiEndpoint, headers: _credentialsHeader);
    verifyResponse(response);
    return _convert(response);
  }

  void savePipelineState(String name, String description) async {
    final pipelineData = ref.read(pipelinesProvider.notifier).exportState();
    if (pipelineData.isEmpty) {
      return;
    }

    final response = await http.post(
      _apiEndpoint,
      headers: {'Content-Type': 'application/json', ..._credentialsHeader},
      body: jsonEncode({"name": name, "description": description, "pipeline_data": pipelineData}),
    );

    ref.invalidateSelf();
    await future;

    verifyResponse(response);
  }

  void editExistingSave(SavedPipelineConfig editedSave) async {
    final response = await http.put(
      _apiEndpoint,
      headers: {'Content-Type': 'application/json', ..._credentialsHeader},
      body: jsonEncode(editedSave),
    );

    ref.invalidateSelf();
    await future;

    verifyResponse(response);
  }

  void deleteSavedPipeline(int saveId) async {
    final response = await http.delete(
      _apiEndpoint,
      headers: {'Content-Type': 'application/json', ..._credentialsHeader},
      body: jsonEncode({'id': saveId}),
    );

    ref.invalidateSelf();
    await future;

    verifyResponse(response);
  }

  List<SavedPipelineConfig> _convert(http.Response response) {
    final List<dynamic> jsonResponse = jsonDecode(response.body);
    List<SavedPipelineConfig> saves = [
      for (Map<String, dynamic> save in jsonResponse) SavedPipelineConfig.fromJson(save),
    ];
    return saves;
  }
}
