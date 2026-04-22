import 'package:cats/providers/settings_provider.dart';
import 'package:cats/widgets/settings/utility/multi_switch_setting.dart';
import 'package:cats/widgets/settings/utility/string_setting.dart';
import 'package:cats/widgets/settings/utility/helper.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PipelineDefaultSettingsScreen extends ConsumerWidget {
  const PipelineDefaultSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsTitle("Default risk score"),
        SettingStringFormField(
          description:
              "Default risk score value that will be applied to every alert at the \n"
              "beginning of every individual pipeline. Must be in the range of [0, 1].",
          initialValue: ref.read(globalPipelineDefaultsProvider).defaultRiskScore.toString(),
          updateFunction: (String input) {
            double? riskScore = double.tryParse(input);
            if (riskScore == null || riskScore < 0 || riskScore > 1) {
              return "Invalid risk score value";
            } else {
              ref.read(globalPipelineDefaultsProvider.notifier).setDefaultRiskScore(riskScore);
              return null;
            }
          },
        ),
        SettingsDivider(),
        const SettingsTitle("Default averaging method"),
        MultiSwitchSetting(
          descriptions: ["Geometric mean", "Arithmetic mean"],
          toggleFunction: ref.read(globalPipelineDefaultsProvider.notifier).setDefaultAveragingMethod,
          initialValues: ref.read(globalPipelineDefaultsProvider).averagingMethod,
          isExclusive: true,
        ),
      ],
    );
  }
}
