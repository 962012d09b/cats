import 'package:cats/widgets/modules/input_dialogs/digit_slider_form.dart';
import 'package:cats/widgets/modules/input_dialogs/range_slider_form.dart';
import 'package:cats/widgets/modules/input_dialogs/small_text_form.dart';
import 'package:cats/widgets/modules/input_dialogs/checkbox_form.dart';
import 'package:cats/widgets/modules/input_dialogs/dropdown_form.dart';
import 'package:flutter/material.dart';
import 'package:cats/models/module.dart';

const double horizontalSpacing = 30;

class InputPreview extends StatefulWidget {
  const InputPreview({
    super.key,
    required this.input,
    required this.onRemoveInput,
    required this.register,
    required this.unregister,
  });

  final ModuleInput input;
  final void Function(ModuleInput) onRemoveInput;
  final void Function(GlobalKey<FormState>, ExpansibleController) register;
  final void Function(GlobalKey<FormState>, ExpansibleController) unregister;

  @override
  State<InputPreview> createState() => _InputPreviewState();
}

class _InputPreviewState extends State<InputPreview> {
  final _formKey = GlobalKey<FormState>();
  final ExpansibleController _controller = ExpansibleController();

  @override
  void initState() {
    super.initState();
    widget.register(_formKey, _controller);
  }

  @override
  void dispose() {
    widget.unregister(_formKey, _controller);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String title = switch (widget.input.type) {
      ModuleInputType.digitSlider => "Digit Slider",
      ModuleInputType.rangeSlider => "Range Slider",
      ModuleInputType.smallText => "Small Text Input",
      ModuleInputType.checkbox => "Checkbox",
      ModuleInputType.dropdown => "Dropdown",
    };

    Widget content = switch (widget.input.type) {
      ModuleInputType.digitSlider => DigitSliderForm(
          formKey: _formKey,
          input: widget.input as DigitSliderInput,
        ),
      ModuleInputType.rangeSlider => RangeSliderForm(
          formKey: _formKey,
          input: widget.input as RangeSliderInput,
        ),
      ModuleInputType.smallText => SmallTextForm(
          formKey: _formKey,
          input: widget.input as SmallTextInput,
        ),
      ModuleInputType.checkbox => CheckboxForm(
          formKey: _formKey,
          input: widget.input as CheckboxInput,
        ),
      ModuleInputType.dropdown => DropdownForm(
          formKey: _formKey,
          input: widget.input as DropdownInput,
        ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ExpansionTile(
        controller: _controller,
        initiallyExpanded: true,
        shape: Border.all(color: Theme.of(context).colorScheme.secondary),
        title: Text(title),
        controlAffinity: ListTileControlAffinity.leading,
        maintainState: true, // otherwise forms can'be validated when collapsed
        trailing: Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: IconButton(
            onPressed: () => widget.onRemoveInput(widget.input),
            icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8, right: 40),
            child: content,
          )
        ],
      ),
    );
  }
}
