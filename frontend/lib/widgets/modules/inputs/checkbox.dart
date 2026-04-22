import 'package:cats/models/module.dart';
import 'package:flutter/material.dart';

class CheckboxList extends StatefulWidget {
  const CheckboxList({
    super.key,
    required this.input,
    required this.onParamChange,
  });

  final CheckboxInput input;
  final Function(List<bool>) onParamChange;

  @override
  State<CheckboxList> createState() => _CheckboxListState();
}

class _CheckboxListState extends State<CheckboxList> {
  late List<bool> _valuesToReturn;
  late int _groupValue;

  @override
  void initState() {
    super.initState();

    _valuesToReturn = widget.input.currentValue ?? List.from(widget.input.initialValues);
    _groupValue = _valuesToReturn.indexOf(true);
  }

  @override
  void didUpdateWidget(covariant CheckboxList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.input.currentValue != oldWidget.input.currentValue) {
      _valuesToReturn = widget.input.currentValue ?? List.from(widget.input.initialValues);
      _groupValue = _valuesToReturn.indexOf(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final input = widget.input;

    return Column(
      children: input.isMutuallyExclusive
          ? [
              for (var index = 0; index < input.labels.length; index++)
                RadioListTile(
                  title: Text(input.labels[index]),
                  value: index,
                  groupValue: _groupValue,
                  dense: true,
                  onChanged: (value) {
                    setState(() {
                      _groupValue = value!;
                      _valuesToReturn = List.filled(input.labels.length, false);
                      _valuesToReturn[_groupValue] = true;
                      widget.onParamChange(_valuesToReturn);
                    });
                  },
                ),
            ]
          : [
              for (var i = 0; i < input.labels.length; i++)
                CheckboxListTile(
                  title: Text(input.labels[i]),
                  value: _valuesToReturn[i],
                  dense: true,
                  onChanged: (bool? value) {
                    setState(() {
                      _valuesToReturn[i] = value!;
                      widget.onParamChange(_valuesToReturn);
                    });
                  },
                ),
            ],
    );
  }
}
