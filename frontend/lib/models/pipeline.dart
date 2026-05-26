import 'package:cats/models/settings.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';
import 'package:cats/models/module.dart';

part 'generated/pipeline.freezed.dart';
part 'generated/pipeline.g.dart';

@unfreezed
abstract class Pipeline with _$Pipeline {
  // An empty constructor is needed if we want to add custom methods to the class
  const Pipeline._();

  factory Pipeline({
    required String name,
    required List<Module> modules,
    required PipelineSettings settings,
    required String uuid,
  }) = _Pipeline;

  factory Pipeline.fromJson(Map<String, dynamic> json) => _$PipelineFromJson(json);

  void verifyModules(List<Module> availableModules) {
    for (var module in modules) {
      if (!availableModules.any((availableModule) => availableModule.roughlyEquals(module))) {
        throw Exception('Module ${module.name} is not available');
      }
    }
    return;
  }
}

@freezed
abstract class SavedPipelineConfig with _$SavedPipelineConfig {
  const SavedPipelineConfig._();

  factory SavedPipelineConfig({
    required final int id,
    required final String name,
    required final String description,
    required final String pipelineData,
  }) = _SavedPipelineConfig;

  @override
  factory SavedPipelineConfig.fromJson(Map<String, dynamic> json) => _$SavedPipelineConfigFromJson(json);
}
