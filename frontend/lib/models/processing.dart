import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';

part 'generated/processing.freezed.dart';
part 'generated/processing.g.dart';

@freezed
abstract class ProcessingState with _$ProcessingState {
  factory ProcessingState({
    required final String jobId,
    required final String message,
    required final double progress,
    required final List<Map<String, dynamic>> results,
    required final bool ready,
    required final bool successful,
  }) = _ProcessingState;

  factory ProcessingState.fromJson(Map<String, dynamic> json) => _$ProcessingStateFromJson(json);
}
