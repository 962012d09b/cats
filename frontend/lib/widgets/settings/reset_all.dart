import 'package:cats/providers/connection_provider.dart';
import 'package:cats/providers/settings_provider.dart';
import 'package:cats/widgets/settings/utility/helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RestoreDefaultsButton extends ConsumerWidget {
  const RestoreDefaultsButton({super.key, this.onReset});

  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilledButton(
      onPressed: () {
        ref.read(warningProvider.notifier).resetToDefault();
        ref.read(globalPipelineDefaultsProvider.notifier).resetToDefault();
        ref.read(backendUriProvider.notifier).resetToDefault();
        ref.read(credentialsProvider.notifier).resetToDefault();
        showConfirmationSnackbar(context, "Restored default settings");

        onReset?.call();
      },
      style: FilledButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
        // side: BorderSide(color: Theme.of(context).colorScheme.error),
      ),
      child: Text("Reset to defaults", style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
    );
  }
}
