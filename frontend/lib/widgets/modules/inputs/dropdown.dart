import 'package:cats/models/module.dart';
import 'package:flutter/material.dart';

class CustomDropdown extends StatefulWidget {
  const CustomDropdown({
    super.key,
    required this.input,
    required this.onParamChange,
  });

  final DropdownInput input;
  final Function(String) onParamChange;

  @override
  State<CustomDropdown> createState() => _CustomDropdownState();
}

class _CustomDropdownState extends State<CustomDropdown> {
  late String _selectedValue;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.input.currentValue ?? widget.input.items.first;
  }

  @override
  void didUpdateWidget(covariant CustomDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.input.currentValue != oldWidget.input.currentValue) {
      _selectedValue = widget.input.currentValue ?? widget.input.items.first;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: _selectedValue,
      focusNode: _focusNode,
      underline: Container(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      isDense: true,
      items: widget.input.items.map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        );
      }).toList(),
      isExpanded: true,
      onChanged: (String? newValue) {
        setState(() {
          _selectedValue = newValue!;
        });
        widget.onParamChange(newValue!);
      },
      onTap: () {
        _focusNode.unfocus();
        FocusScope.of(context).unfocus();
      },
    );
  }
}
