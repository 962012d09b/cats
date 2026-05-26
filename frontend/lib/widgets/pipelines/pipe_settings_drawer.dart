import 'package:cats/models/module.dart';
import 'package:cats/models/settings.dart';
import 'package:cats/providers/pipelines_provider.dart';
import 'package:cats/widgets/settings/utility/helper.dart';
import 'package:cats/widgets/settings/utility/multi_switch_setting.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PipeSettingsDrawer extends ConsumerStatefulWidget {
  const PipeSettingsDrawer({super.key, required this.pipeIndex});

  final int pipeIndex;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _PipeSettingsDrawerState();
}

class _PipeSettingsDrawerState extends ConsumerState<PipeSettingsDrawer> {
  late PipelineSettings modifiedSettings;
  late List<double> originalWeights;
  late List<double> modifiedWeights;
  late List<Module> modules;
  bool enableSubmit = true;

  @override
  void initState() {
    super.initState();
    var currentPipe = ref.read(pipelinesProvider)[widget.pipeIndex];
    modifiedSettings = currentPipe.settings;
    modules = currentPipe.modules;
    originalWeights = List.generate(modules.length, (index) => modules[index].weight);
    modifiedWeights = List.from(originalWeights);
  }

  void _handleWeightChange(List<double> newWeights, List<bool> errorStates) {
    modifiedWeights = newWeights;
    setState(() {
      enableSubmit = !errorStates.any((error) => error);
    });
  }

  @override
  Widget build(BuildContext context) {
    var currentPipe = ref.read(pipelinesProvider)[widget.pipeIndex];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
              const Text('Pipeline Settings'),
              Expanded(child: Container()),
              ElevatedButton(
                onPressed: enableSubmit
                    ? () {
                        ref
                            .read(pipelinesProvider.notifier)
                            .updateSettings(widget.pipeIndex, modifiedSettings, modifiedWeights);

                        Navigator.of(context).pop();
                      }
                    : null,
                child: Text('Apply Changes'),
              ),
            ],
          ),
          const Divider(height: 20, thickness: 3),
          const SettingsTitle("Averaging method"),
          MultiSwitchSetting(
            descriptions: ["Geometric mean", "Arithmetic mean"],
            toggleFunction: (newMethod) {
              modifiedSettings = modifiedSettings.copyWith(averagingMethod: newMethod);
            },
            initialValues: currentPipe.settings.averagingMethod,
            isExclusive: true,
          ),
          const Divider(height: 20, thickness: 2),
          _WeightSetter(weights: originalWeights, onWeightsChange: _handleWeightChange),
        ],
      ),
    );
  }
}

class _WeightSetter extends StatefulWidget {
  const _WeightSetter({required this.weights, required this.onWeightsChange});

  final List<double> weights;
  final Function(List<double>, List<bool>) onWeightsChange;

  @override
  State<_WeightSetter> createState() => __WeightSetterState();
}

class __WeightSetterState extends State<_WeightSetter> {
  bool hasValidationError = false;
  late List<double> inputWeights;
  late List<double> normalizedWeights;
  late List<bool> errorStates;
  late List<TextEditingController> controllers;

  @override
  void initState() {
    super.initState();
    inputWeights = List.from(widget.weights);
    controllers = List.generate(
      inputWeights.length,
      (index) => TextEditingController(text: inputWeights[index].toString()),
    );
    if (inputWeights.isEmpty) {
      normalizedWeights = [];
    } else {
      normalizedWeights = _normalizeWeights(inputWeights);
    }
    errorStates = List.generate(widget.weights.length, (index) => false);
  }

  bool _isNonNegativeDouble(String? value) {
    if (value == null || value.isEmpty) return false;
    final parsedValue = double.tryParse(value);
    return parsedValue != null && parsedValue >= 0;
  }

  List<double> _normalizeWeights(List<double> input) {
    double sum = input.fold(0, (prev, cur) => prev + cur);
    if (sum <= 0) {
      throw Exception("Impossible exception: Sum of weights is non-positive");
    }
    return input.map((weight) => weight / sum).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsTitle("Module weights"),
        SizedBox(height: 8),
        Text(
          "Module weights will be normalized during processing such that they sum up to 1.",
          style: settingsTextStyle(context),
        ),
        SizedBox(height: 8),
        if (inputWeights.isEmpty)
          Center(child: Text("No modules in this pipeline", style: settingsTextStyle(context))),
        for (var i = 0; i < inputWeights.length; i++)
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                width: 70,
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: TextFormField(
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: errorStates[i]
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: errorStates[i]
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary,
                        width: 2.0,
                      ),
                    ),
                  ),
                  controller: controllers[i],
                  onChanged: (value) {
                    setState(() {
                      if (!_isNonNegativeDouble(value)) {
                        errorStates[i] = true;
                      } else {
                        inputWeights[i] = double.parse(value);

                        double sum = inputWeights.fold(0, (prev, cur) => prev + cur);
                        if (sum == 0) {
                          errorStates = List.generate(inputWeights.length, (index) => true);
                        } else {
                          normalizedWeights = _normalizeWeights(inputWeights);
                          errorStates[i] = false;
                          for (var j = 0; j < inputWeights.length; j++) {
                            if (inputWeights[j] == 0 && _isNonNegativeDouble(controllers[j].text)) {
                              // reset previously illegal zeroes
                              errorStates[j] = false;
                            }
                          }
                        }
                      }
                      widget.onWeightsChange(inputWeights, errorStates);
                    });
                  },
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(
                        5,
                        (index) => Container(
                          width: 1,
                          height: 40,
                          color: Theme.of(context).colorScheme.onSurface.withValues(
                            alpha: ([0, 2, 4].contains(index) ? 0.8 : 0.5).toDouble(),
                          ),
                        ),
                      ),
                    ),
                    AnimatedFractionallySizedBox(
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      alignment: Alignment.centerLeft,
                      widthFactor: normalizedWeights[i],
                      child: Container(
                        height: 20,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Text(
                "→ ${normalizedWeights[i].toStringAsFixed(5)}",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        if (errorStates.any((error) => error))
          Text(
            "Please enter valid non-negative numbers for all weights. At least one must be greater than zero.",
            style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
          ),
      ],
    );
  }
}
