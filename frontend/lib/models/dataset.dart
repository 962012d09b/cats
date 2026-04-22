import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';

part 'generated/dataset.freezed.dart';
part 'generated/dataset.g.dart';

@freezed
abstract class Dataset with _$Dataset {
  factory Dataset({
    required final int id,
    required final String name,
    final String? description,
    required final String fileName,
    required final bool doesExist,
    required final int trueAlertCount,
    required final int falseAlertCount,
    required final int alertTypeCount,
    required final int alertSourceCount,
    required final String durationIso8601,
    required final List<String> tags,
  }) = _Dataset;

  factory Dataset.fromJson(Map<String, dynamic> json) => _$DatasetFromJson(json);
}
