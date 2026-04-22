import 'package:flutter/material.dart';

const double paddingAfterTitle = 10.0;

class SettingsTitle extends StatelessWidget {
  const SettingsTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
  }
}

class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 40);
  }
}

TextStyle settingsTextStyle(BuildContext context) {
  return TextStyle(fontStyle: FontStyle.italic, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8));
}

void showConfirmationSnackbar(BuildContext context, String message, {int durationSeconds = 2}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: Duration(seconds: durationSeconds),
      width: MediaQuery.of(context).size.width * 0.4,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
