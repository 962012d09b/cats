import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';

part 'generated/settings.freezed.dart';
part 'generated/settings.g.dart';

@freezed
abstract class WarningSettings with _$WarningSettings {
  factory WarningSettings({required final bool warnExcludedSelected}) = _BehaviorSettings;

  factory WarningSettings.fromJson(Map<String, dynamic> json) => _$WarningSettingsFromJson(json);
}

@freezed
abstract class PipelineSettings with _$PipelineSettings {
  factory PipelineSettings({required final double defaultRiskScore, required final List<bool> averagingMethod}) =
      _PipelineSettings;

  factory PipelineSettings.fromJson(Map<String, dynamic> json) => _$PipelineSettingsFromJson(json);
}
