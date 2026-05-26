import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:recase/recase.dart';

part 'generated/module.freezed.dart';
part 'generated/module.g.dart';

enum ModuleInputType { digitSlider, rangeSlider, smallText, checkbox, dropdown }

@freezed
abstract class Module with _$Module {
  const Module._();

  factory Module({
    required final int id,
    required final String name,
    final String? description,
    required final String fileName,
    required final bool doesExist,
    required final List<ModuleInput> inputs,
    final List<InputPreset>? inputPresets,
    required final List<String> tags,
    @Default(1.0) final double weight,
    // Required for the purpose of having unique keys when using widgets like ReorderableListView
    // Freezed does not allow for function calls in the constructor, so the UUID is assigned in the module provider
    @Default("") final String uuid,
  }) = _Module;

  @override
  factory Module.fromJson(Map<String, dynamic> json) => _$ModuleFromJson(json);

  bool roughlyEquals(Module other) {
    return name == other.name &&
        fileName == other.fileName &&
        inputs.length == other.inputs.length &&
        inputs.asMap().entries.every((entry) => entry.value.roughlyEquals(other.inputs[entry.key]));
  }

  bool get hasPresets => inputPresets != null && inputPresets!.isNotEmpty;
}

@freezed
abstract class InputPreset with _$InputPreset {
  const InputPreset._();

  factory InputPreset({
    required final String name,
    required final String description,
    required final List<dynamic> inputs,
  }) = _InputPreset;

  @override
  factory InputPreset.fromJson(Map<String, dynamic> json) => _$InputPresetFromJson(json);
}

@unfreezed
abstract class ModuleInput with _$ModuleInput {
  const ModuleInput._();

  factory ModuleInput.digitSlider({
    @InputConverter() required final ModuleInputType type,
    required double minValue,
    required double maxValue,
    required double initialValue,
    required int divisions,
    @Default("") String description,
    dynamic currentValue,
  }) = DigitSliderInput;

  factory ModuleInput.rangeSlider({
    @InputConverter() required final ModuleInputType type,
    required double minValue,
    required double maxValue,
    required List<double> initialValues,
    required int divisions,
    double? minRange,
    double? maxRange,
    @Default("") String description,
    dynamic currentValue,
  }) = RangeSliderInput;

  factory ModuleInput.smallText({
    @InputConverter() required final ModuleInputType type,
    required String initialValue,
    String? regex,
    String? errorMessage,
    @Default(true) bool hasToMatchRegex,
    @Default("") String description,
    dynamic currentValue,
  }) = SmallTextInput;

  factory ModuleInput.checkbox({
    @InputConverter() required final ModuleInputType type,
    required List<bool> initialValues,
    required List<String> labels,
    required bool isMutuallyExclusive,
    @Default("") String description,
    dynamic currentValue,
  }) = CheckboxInput;

  factory ModuleInput.dropdown({
    @InputConverter() required final ModuleInputType type,
    required List<String> items,
    @Default("") String description,
    dynamic currentValue,
  }) = DropdownInput;

  bool roughlyEquals(ModuleInput other) {
    // Only compare the type for now
    return (type == other.type);
  }

  bool exactlyEquals(ModuleInput other) {
    return when(
      digitSlider: (type, minValue, maxValue, initialValue, divisions, description, currentValue) =>
          other is DigitSliderInput &&
          type == other.type &&
          minValue == other.minValue &&
          maxValue == other.maxValue &&
          initialValue == other.initialValue &&
          divisions == other.divisions,
      rangeSlider:
          (type, minValue, maxValue, initialValues, divisions, minRange, maxRange, description, currentValue) =>
              other is RangeSliderInput &&
              type == other.type &&
              minValue == other.minValue &&
              maxValue == other.maxValue &&
              initialValues == other.initialValues &&
              divisions == other.divisions,
      smallText: (type, initialValue, regex, hasToMatchRegex, errorMessage, description, currentValue) =>
          other is SmallTextInput && type == other.type && initialValue == other.initialValue,
      checkbox: (type, initialValues, labels, isMutuallyExclusive, description, currentValue) =>
          other is CheckboxInput &&
          type == other.type &&
          initialValues == other.initialValues &&
          labels == other.labels,
      dropdown: (type, items, description, currentValue) =>
          other is DropdownInput && type == other.type && items == other.items,
    );
  }

  factory ModuleInput.fromJson(Map<String, dynamic> json) =>
      _$ModuleInputFromJson({...json, "runtimeType": ReCase(json["type"]).camelCase});

  // Sadly, freezed does not generate actual deep copy methods, so we need to define our own to deal with nested objects
  ModuleInput deepCopy() {
    return when(
      digitSlider: (type, minValue, maxValue, initialValue, divisions, description, currentValue) =>
          (this as DigitSliderInput).copyWith(),
      rangeSlider:
          (type, minValue, maxValue, initialValues, divisions, minRange, maxRange, description, currentValue) =>
              (this as RangeSliderInput).copyWith(initialValues: List.from(initialValues)),
      smallText: (type, initialValue, regex, hasToMatchRegex, errorMessage, description, currentValue) =>
          (this as SmallTextInput).copyWith(),
      checkbox: (type, initialValues, labels, isMutuallyExclusive, description, currentValue) =>
          (this as CheckboxInput).copyWith(initialValues: List.from(initialValues), labels: List.from(labels)),
      dropdown: (type, items, description, currentValue) => (this as DropdownInput).copyWith(items: List.from(items)),
    );
  }

  dynamic get defaultValue {
    return when(
      digitSlider: (type, minValue, maxValue, initialValue, divisions, description, currentValue) => initialValue,
      rangeSlider:
          (type, minValue, maxValue, initialValues, divisions, minRange, maxRange, description, currentValue) =>
              initialValues,
      smallText: (type, initialValue, regex, hasToMatchRegex, errorMessage, description, currentValue) => initialValue,
      checkbox: (type, initialValues, labels, isMutuallyExclusive, description, currentValue) => initialValues,
      dropdown: (type, items, description, currentValue) => items.first,
    );
  }
}

class InputConverter implements JsonConverter<ModuleInputType, String> {
  const InputConverter();

  @override
  ModuleInputType fromJson(String json) {
    return switch (json) {
      "digit_slider" => ModuleInputType.digitSlider,
      "range_slider" => ModuleInputType.rangeSlider,
      "small_text" => ModuleInputType.smallText,
      "checkbox" => ModuleInputType.checkbox,
      "dropdown" => ModuleInputType.dropdown,
      _ => throw ArgumentError("Unknown ModuleInput: $json"),
    };
  }

  @override
  String toJson(ModuleInputType inputType) {
    return switch (inputType) {
      ModuleInputType.digitSlider => "digit_slider",
      ModuleInputType.rangeSlider => "range_slider",
      ModuleInputType.smallText => "small_text",
      ModuleInputType.checkbox => "checkbox",
      ModuleInputType.dropdown => "dropdown",
    };
  }
}
