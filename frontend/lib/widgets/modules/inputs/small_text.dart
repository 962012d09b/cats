import 'package:cats/models/module.dart';
import 'package:flutter/material.dart';

class SmallText extends StatefulWidget {
  const SmallText({
    super.key,
    required this.input,
    required this.onParamChange,
  });

  final SmallTextInput input;
  final Function(String) onParamChange;

  @override
  State<StatefulWidget> createState() => _SmallTextState();
}

class _SmallTextState extends State<SmallText> {
  late TextEditingController _controller;
  String? _error;
  late String _errorMessage;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(text: widget.input.currentValue ?? widget.input.initialValue);
    _errorMessage = widget.input.errorMessage ??
        (widget.input.hasToMatchRegex
            ? "Input must match regex \"${widget.input.regex}\""
            : "Input must not match regex \"${widget.input.regex}\"");
  }

  @override
  void didUpdateWidget(covariant SmallText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.input.currentValue != oldWidget.input.currentValue) {
      _controller.text = widget.input.currentValue ?? widget.input.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final input = widget.input;

    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        errorText: _error,
      ),
      onSubmitted: (String userInput) {
        setState(() {
          if (input.regex != null) {
            final regex = RegExp(input.regex!);
            if (input.hasToMatchRegex && !regex.hasMatch(userInput) ||
                !input.hasToMatchRegex && regex.hasMatch(userInput)) {
              _error = _errorMessage;
              return;
            }
          }
          _error = null;
          widget.onParamChange(userInput);
        });
      },
    );
  }
}
