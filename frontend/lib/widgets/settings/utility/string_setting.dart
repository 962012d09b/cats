import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cats/widgets/settings/utility/helper.dart';

class SettingStringFormField extends StatefulWidget {
  const SettingStringFormField({
    super.key,
    required this.description,
    required this.initialValue,
    this.obscureText = false,
    required this.updateFunction,
  });

  final String? description;
  final String initialValue;
  final bool obscureText;
  final String? Function(String input) updateFunction;

  @override
  State<SettingStringFormField> createState() => _SettingStringFormFieldState();
}

class _SettingStringFormFieldState extends State<SettingStringFormField> with SingleTickerProviderStateMixin {
  late TextEditingController _controller;
  String? _error;
  Timer? _timer;
  bool _didChange = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final _random = Random();
  String _message = "";

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);

    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(_animationController);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void submit(String input) {
    setState(() {
      _error = widget.updateFunction(input);
      if (_error == null) {
        _message = _random.nextInt(100) < 5 ? "Hope you're having a nice day!" : "Setting applied";
        _didChange = true;
        _animationController.reset();
        _timer?.cancel();
        _timer = Timer(const Duration(seconds: 1), () {
          setState(() {
            _animationController.forward();
          });
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: paddingAfterTitle),
        widget.description != null
            ? Text(
              widget.description!,
              softWrap: true,
              overflow: TextOverflow.visible,
              style: settingsTextStyle(context),
            )
            : const SizedBox.shrink(),
        const SizedBox(height: 5),
        Row(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: TextField(
                controller: _controller,
                obscureText: widget.obscureText,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  errorText: _error,
                  hintText: widget.description,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.check, size: 15),
                    onPressed: () => submit(_controller.text),
                  ),
                ),
                onSubmitted: (String input) => submit(input),
              ),
            ),
            const SizedBox(width: 10),
            _didChange
                ? FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    _message,
                    style: TextStyle(color: Theme.of(context).colorScheme.primary, fontStyle: FontStyle.italic),
                  ),
                )
                : const SizedBox.shrink(),
          ],
        ),
      ],
    );
  }
}
