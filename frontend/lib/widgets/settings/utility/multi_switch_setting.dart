import 'package:cats/widgets/settings/utility/helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MultiSwitchSetting extends ConsumerStatefulWidget {
  const MultiSwitchSetting({
    super.key,
    required this.descriptions,
    required this.toggleFunction,
    required this.initialValues,
    this.isExclusive = false,
  });

  final List<String> descriptions;
  final void Function(List<bool>) toggleFunction;
  final List<bool> initialValues;
  final bool isExclusive;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _MultiSwitchSettingState();
}

class _MultiSwitchSettingState extends ConsumerState<MultiSwitchSetting> {
  late List<bool> isToggled;

  @override
  void initState() {
    super.initState();
    assert(
      widget.descriptions.length == widget.initialValues.length,
      'Descriptions and initial values must have the same length',
    );
    isToggled = widget.initialValues;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: paddingAfterTitle),
      child: Column(
        children:
            widget.descriptions.asMap().entries.map((entry) {
              int index = entry.key;
              String description = entry.value;

              if (widget.isExclusive) {
                return RadioListTile<int>(
                  title: Text(description, style: settingsTextStyle(context)),
                  value: index,
                  groupValue: isToggled.indexOf(true),
                  dense: true,
                  onChanged: (value) {
                    setState(() {
                      isToggled = List<bool>.filled(widget.descriptions.length, false);
                      if (value != null) {
                        isToggled[value] = true;
                      }
                      widget.toggleFunction(isToggled);
                    });
                  },
                );
              } else {
                return CheckboxListTile(
                  title: Text(description, style: settingsTextStyle(context)),
                  value: isToggled[index],
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (value) {
                    setState(() {
                      isToggled[index] = value ?? false;
                    });
                    widget.toggleFunction(isToggled);
                  },
                );
              }
            }).toList(),
      ),
    );
  }
}
