import 'package:cats/providers/filter_provider.dart';
import 'package:cats/widgets/utility/error_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cats/providers/connection_provider.dart';
import 'package:cats/providers/datasets_provider.dart';
import 'package:cats/providers/module_provider.dart';
import 'package:cats/providers/pipelines_provider.dart';
import 'package:cats/widgets/settings/utility/string_setting.dart';
import 'package:cats/widgets/settings/utility/helper.dart';

class BackendSettingsScreen extends ConsumerWidget {
  const BackendSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsTitle("Backend Server Configuration"),
        SettingStringFormField(
          description: "Host (e.g., 127.0.0.1, my.domain.com, or https://my.domain.com)",
          initialValue: ref.read(backendUriProvider).origin.replaceFirst(RegExp(r':\d+$'), ''),
          updateFunction: (String input) {
            ref.read(backendUriProvider.notifier).setHost(input);
            return null;
          },
        ),
        SettingStringFormField(
          description: "Port (e.g., 47126)",
          initialValue: ref.read(backendUriProvider).port.toString(),
          updateFunction: (String input) {
            int? port = int.tryParse(input);
            if (port == null || port < 1 || port > 65535) {
              return "Invalid Port";
            } else {
              ref.read(backendUriProvider.notifier).setPort(port);
              return null;
            }
          },
        ),
        SettingStringFormField(
          description: "Password",
          initialValue: ref.read(credentialsProvider),
          obscureText: true,
          updateFunction: (String input) {
            if (input.isEmpty) {
              return "Password cannot be empty";
            } else {
              ref.read(credentialsProvider.notifier).set(input);
              return null;
            }
          },
        ),
        const SettingsDivider(),
        const SettingsTitle("Force reload of cached data"),
        Text(
          "Specifically, this will cause the app to re-fetch available datasets and modules from the server.\n"
          "This may be useful if you have changed things outside of the app.\n"
          "Note that this will also reset your current pipeline configuration.",
          style: settingsTextStyle(context),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: () {
            ref.invalidate(availableDatasetsProvider);
            ref.invalidate(moduleListProvider);
            ref.invalidate(ongoingPipeCounterProvider);
            ref.invalidate(pipelinesProvider);
            ref.invalidate(datasetFilterTagsProvider);
            ref.invalidate(moduleFilterTagsProvider);
            showConfirmationSnackbar(context, "Cache invalidated!");
          },
          child: const Text("Reload"),
        ),
        const SettingsDivider(),
        const SettingsTitle("Reset database"),
        Text(
          "Delete and re-initialize the SQLite database used by the backend server.\n"
          "WARNING: This will delete all custom additions and configurations you have made.\n"
          "Underlying files, i.e., the actual dataset and module files, will not be affected.",
          style: settingsTextStyle(context),
        ),
        const SizedBox(height: 10),
        _DbResetButton(ref: ref),
      ],
    );
  }
}

class _DbResetButton extends StatefulWidget {
  const _DbResetButton({required this.ref});

  final WidgetRef ref;

  @override
  _DbResetButtonState createState() => _DbResetButtonState();
}

class _DbResetButtonState extends State<_DbResetButton> {
  bool _isLoading = false;

  void _handleDatabaseReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Confirm Reset"),
          content: Text("Are you sure you want to reset the backend database?"),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text("Cancel"),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              style: ButtonStyle(backgroundColor: WidgetStateProperty.all(Theme.of(context).colorScheme.error)),
              child: Text("Reset", style: TextStyle(color: Theme.of(context).colorScheme.onError)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      String? errorMsg;
      setState(() {
        _isLoading = true;
      });

      try {
        await widget.ref.read(backendUriProvider.notifier).resetDatabase();
        widget.ref.invalidate(availableDatasetsProvider);
        widget.ref.invalidate(moduleListProvider);
        widget.ref.invalidate(ongoingPipeCounterProvider);
        widget.ref.invalidate(pipelinesProvider);
        widget.ref.invalidate(datasetFilterTagsProvider);
        widget.ref.invalidate(moduleFilterTagsProvider);
      } catch (e) {
        errorMsg = e.toString();
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      if (errorMsg != null) {
        showDialog(
          context: context,
          builder: (BuildContext context) =>
              ForcedErrorDialog(errorTitle: "Something went wrong, unable to reset database", errorMessage: errorMsg!),
        );
      } else {
        showConfirmationSnackbar(context, "Successfully reset database!");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        FilledButton(
          onPressed: _isLoading ? null : _handleDatabaseReset,
          style: ButtonStyle(backgroundColor: WidgetStateProperty.all(Theme.of(context).colorScheme.error)),
          child: Text(
            "Reset database",
            style: TextStyle(
              color: _isLoading
                  ? Theme.of(context).colorScheme.onError.withValues(alpha: 0.5)
                  : Theme.of(context).colorScheme.onError,
            ),
          ),
        ),
        _isLoading
            ? const Padding(
                padding: EdgeInsets.only(left: 10),
                child: Center(child: SizedBox(width: 15, height: 15, child: CircularProgressIndicator())),
              )
            : const SizedBox.shrink(),
      ],
    );
  }
}
