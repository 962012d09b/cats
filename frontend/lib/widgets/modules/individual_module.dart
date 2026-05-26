import 'package:cats/constants.dart';
import 'package:cats/widgets/modules/inputs/checkbox.dart';
import 'package:cats/widgets/modules/inputs/dropdown.dart';
import 'package:cats/widgets/modules/preset_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cats/models/module.dart';
import 'package:cats/providers/pipelines_provider.dart';
import 'package:cats/widgets/modules/inputs/slider.dart';
import 'package:cats/widgets/modules/inputs/range_slider.dart';
import 'package:cats/widgets/modules/inputs/small_text.dart';

class IndividualModule extends ConsumerWidget {
  const IndividualModule({
    super.key,
    required this.module,
    required this.pipeIndex,
    required this.moduleIndex,
    required this.sumOfWeights,
  });

  final Module module;
  final int pipeIndex;
  final int moduleIndex;
  final double sumOfWeights;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ScrollController scrollController = ScrollController();
    final double normalizedWeight = module.weight / sumOfWeights;
    final String weightDisplay = (sumOfWeights == 0) ? "0.00%" : "${(normalizedWeight * 100).toStringAsFixed(2)}%";

    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.4),
      child: SizedBox(
        width: moduleInstanceWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              minTileHeight: 48,
              title: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(module.name, style: Theme.of(context).textTheme.titleMedium),
                  SizedBox(width: 8),
                  Tooltip(
                    message: "Weight: ${module.weight.toStringAsFixed(2)} (Normalized: $normalizedWeight)",
                    child: Text(
                      "($weightDisplay)",
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        fontStyle: FontStyle.italic,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: (normalizedWeight == 0) ? 0.2 : 0.8),
                      ),
                    ),
                  ),
                ],
              ),
              contentPadding: EdgeInsetsDirectional.only(start: 16, end: 8),
              trailing: IconButton(
                onPressed: () => ref.read(pipelinesProvider.notifier).removeModuleFromPipe(pipeIndex, moduleIndex),
                icon: const Icon(Icons.delete_outline, size: 18),
              ),
              subtitle: module.inputs.isEmpty
                  ? SizedBox(height: 20)
                  : PresetUI(pipeIndex: pipeIndex, moduleIndex: moduleIndex, module: module),
            ),
            Divider(color: Theme.of(context).colorScheme.onTertiaryContainer),
            Expanded(
              child: Scrollbar(
                controller: scrollController,
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, right: 8, top: 4, bottom: 30),
                    child: module.inputs.isEmpty
                        ? const Text(
                            "This module does not provide parameters.",
                            style: TextStyle(fontStyle: FontStyle.italic),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(module.inputs.length, (index) {
                              return _ModuleUi(
                                input: module.inputs[index],
                                inputIndex: index,
                                pipeIndex: pipeIndex,
                                moduleIndex: moduleIndex,
                              );
                            }),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleUi extends ConsumerWidget {
  const _ModuleUi({required this.input, required this.pipeIndex, required this.moduleIndex, required this.inputIndex});

  final ModuleInput input;
  final int pipeIndex;
  final int moduleIndex;
  final int inputIndex;

  void handleParamChange(WidgetRef ref, dynamic newValue) {
    ref.read(pipelinesProvider.notifier).updateSingleParameter(pipeIndex, moduleIndex, inputIndex, newValue);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget content;

    Widget uiWidget;

    switch (input.type) {
      case ModuleInputType.digitSlider:
        uiWidget = CustomSlider(
          input: input as DigitSliderInput,
          onParamChange: (newValue) => handleParamChange(ref, newValue),
        );
        break;
      case ModuleInputType.rangeSlider:
        uiWidget = CustomRangeSlider(
          input: input as RangeSliderInput,
          onParamChange: (newValue) => handleParamChange(ref, newValue),
        );
        break;
      case ModuleInputType.smallText:
        uiWidget = SmallText(
          input: input as SmallTextInput,
          onParamChange: (newValue) => handleParamChange(ref, newValue),
        );
        break;
      case ModuleInputType.checkbox:
        uiWidget = CheckboxList(
          input: input as CheckboxInput,
          onParamChange: (newValue) => handleParamChange(ref, newValue),
        );
        break;
      case ModuleInputType.dropdown:
        uiWidget = CustomDropdown(
          input: input as DropdownInput,
          onParamChange: (newValue) => handleParamChange(ref, newValue),
        );
        break;
    }

    content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        input.description.isNotEmpty
            ? Text(input.description, style: Theme.of(context).textTheme.titleMedium)
            : SizedBox.shrink(),
        uiWidget,
      ],
    );

    return content;
  }
}
