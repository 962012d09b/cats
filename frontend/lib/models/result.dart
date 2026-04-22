import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

part 'generated/result.freezed.dart';
part 'generated/result.g.dart';

@unfreezed
abstract class PipeResult with _$PipeResult {
  factory PipeResult({
    required final String name,
    required final List<List<String>> logs,
    required final Results results,
    required final double timeToCompute,
    required final double timeToPreprocess,
    @Default(true) bool isVisible,
    @ColorConverter() Color? plotColor,
  }) = _Result;

  factory PipeResult.fromJson(Map<String, dynamic> json) => _$PipeResultFromJson(json);
}

@freezed
abstract class Results with _$Results {
  factory Results({
    required final AlertCounts totalAlertCount,
    required final AlertCountsPerNum alertCountPerScore,
    required final AlertCountsPerNum alertCountPerScoreAccumulated,
    required final AlertCountsPerString alertCountPerAlertType,
    required final GeneralMetrics generalMetrics,
    @DoubleKeyMapConverter() required final Map<double, PerScoreMetrics> metricsPerScore,
  }) = _Results;

  factory Results.fromJson(Map<String, dynamic> json) => _$ResultsFromJson(json);
}

@freezed
abstract class AlertCounts with _$AlertCounts {
  factory AlertCounts({
    required final int all,
    required final int allExceptUnknown,
    required final int fp,
    required final int tp,
    required final int unknown,
  }) = _AlertCounts;

  factory AlertCounts.fromJson(Map<String, dynamic> json) => _$AlertCountsFromJson(json);
}

@freezed
abstract class AlertCountsPerNum with _$AlertCountsPerNum {
  factory AlertCountsPerNum({
    @DoubleKeyIntMapConverter() required final Map<double, int> all,
    @DoubleKeyIntMapConverter() required final Map<double, int> allExceptUnknown,
    @DoubleKeyIntMapConverter() required final Map<double, int> fp,
    @DoubleKeyIntMapConverter() required final Map<double, int> tp,
    @DoubleKeyIntMapConverter() required final Map<double, int> unknown,
  }) = _AlertCountsPerNum;

  factory AlertCountsPerNum.fromJson(Map<String, dynamic> json) => _$AlertCountsPerNumFromJson(json);
}

@freezed
abstract class AlertCountsPerString with _$AlertCountsPerString {
  factory AlertCountsPerString({
    required final Map<String, int> all,
    required final Map<String, int> allExceptUnknown,
    required final Map<String, int> fp,
    required final Map<String, int> tp,
    required final Map<String, int> unknown,
  }) = _AlertCountsPerString;

  factory AlertCountsPerString.fromJson(Map<String, dynamic> json) => _$AlertCountsPerStringFromJson(json);
}

@freezed
abstract class GeneralMetrics with _$GeneralMetrics {
  factory GeneralMetrics({
    required final double tpPrevalence,
    required final double maximumScore,
    required final double minimumScore,
    required final double uniqueAlertTypes,
    required final double alertsAveragePrecisionAbsolute,
    required final double alertsAveragePrecisionRelative,
    required final double? alertsAucRelative,
    required final double? alertsAucAbsolute,
    required final double alertsBrierScoreAbsolute,
    required final double? alertsBrierScoreRelative,
    required final double? alertTypesAucRelative,
    required final double? alertTypesAucAbsolute,
    required final double? alertTypesAveragePrecisionAbsolute,
    required final double? alertTypesAveragePrecisionRelative,
    required final double? alertTypesAveragePrecisionNoSkill,
    required final double? alertTypesBrierScoreAbsolute,
    required final double? alertTypesBrierScoreRelative,
    required final double compositeScoreAbsolute,
    required final double compositeScoreRelative,
    required final Map<String, int> featureCount,
  }) = _GeneralMetrics;

  factory GeneralMetrics.fromJson(Map<String, dynamic> json) => _$GeneralMetricsFromJson(json);
}

@freezed
abstract class PerScoreMetrics with _$PerScoreMetrics {
  factory PerScoreMetrics({
    required final double tpr,
    required final double fpr,
    required final double precision,
    required final double recall,
    required final double f1,
    required final double mcc,
  }) = _PerScoreMetrics;

  factory PerScoreMetrics.fromJson(Map<String, dynamic> json) => _$PerScoreMetricsFromJson(json);
}

class DoubleKeyMapConverter implements JsonConverter<Map<double, PerScoreMetrics>, Map<String, dynamic>> {
  // freezed does not support double keys in maps, we have to convert them to strings for serialization
  const DoubleKeyMapConverter();

  @override
  Map<double, PerScoreMetrics> fromJson(Map<String, dynamic> json) {
    return json.map((key, value) => MapEntry(double.parse(key), PerScoreMetrics.fromJson(value)));
  }

  @override
  Map<String, dynamic> toJson(Map<double, PerScoreMetrics> object) {
    return object.map((key, value) => MapEntry(key.toString(), value.toJson()));
  }
}

class DoubleKeyIntMapConverter implements JsonConverter<Map<double, int>, Map<String, dynamic>> {
  const DoubleKeyIntMapConverter();

  @override
  Map<double, int> fromJson(Map<String, dynamic> json) {
    return json.map((key, value) => MapEntry(double.parse(key), value as int));
  }

  @override
  Map<String, dynamic> toJson(Map<double, int> object) {
    return object.map((key, value) => MapEntry(key.toString(), value));
  }
}

class ColorConverter implements JsonConverter<Color, int> {
  const ColorConverter();

  @override
  Color fromJson(int json) {
    return Color(json);
  }

  @override
  int toJson(Color object) {
    return object.toARGB32();
  }
}
