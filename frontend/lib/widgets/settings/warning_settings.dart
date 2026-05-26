import 'package:cats/models/settings.dart';
import 'package:cats/providers/settings_provider.dart';
import 'package:cats/widgets/settings/utility/switch_setting.dart';
import 'package:cats/widgets/settings/utility/helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WarningsSettingScreen extends ConsumerWidget {
  const WarningsSettingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WarningSettings currentSetting = ref.read(warningProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsTitle("Datasets Excluded by Filter"),
        SwitchSetting(
          description:
              ("Show a small warning whenever one or more datasets excluded by the current filter are selected.\n"
                  "This warning will also offer the option to deselect these datasets with one click."),
          toggleFunction: ref.read(warningProvider.notifier).toggleWarnExcludedSelected,
          initialValue: currentSetting.warnExcludedSelected,
        ),
      ],
    );
  }
}
