import 'package:cats/widgets/settings/utility/helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SwitchSetting extends ConsumerStatefulWidget {
  const SwitchSetting({super.key, this.description, required this.toggleFunction, required this.initialValue});

  final String? description;
  final void Function() toggleFunction;
  final bool initialValue;

  @override
  ConsumerState<SwitchSetting> createState() => _SwitchSettingState();
}

class _SwitchSettingState extends ConsumerState<SwitchSetting> {
  late bool isToggled;

  @override
  void initState() {
    super.initState();
    isToggled = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: paddingAfterTitle),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Switch(
            value: isToggled,
            onChanged: (_) {
              widget.toggleFunction();
              setState(() {
                isToggled = !isToggled;
              });
            },
          ),
          const SizedBox(width: 10),
          widget.description != null
              ? Flexible(
                child: Text(
                  widget.description!,
                  softWrap: true,
                  overflow: TextOverflow.visible,
                  style: settingsTextStyle(context),
                ),
              )
              : const SizedBox.shrink(),
        ],
      ),
    );
  }
}
