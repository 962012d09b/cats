import 'package:cats/providers/pipelines_provider.dart';
import 'package:cats/providers/processing_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cats/providers/datasets_provider.dart';
import 'package:cats/providers/module_provider.dart';

class ErrorContainer extends ConsumerWidget {
  const ErrorContainer({super.key, required this.errorInfo, required this.stackTrace});

  final Object errorInfo;
  final StackTrace? stackTrace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error,
        borderRadius: const BorderRadius.all(Radius.circular(7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              "Something went wrong. Check the backend server logs and restart the application.",
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
            TextButton.icon(
              onPressed:
                  () => showDialog(
                    context: context,
                    builder:
                        (BuildContext context) =>
                            OnDemandErrorDialog(error: errorInfo, stackTrace: stackTrace ?? StackTrace.empty),
                  ),
              icon: Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onError),
              label: Text(
                "Show frontend error and stack trace",
                style: TextStyle(color: Theme.of(context).colorScheme.onError),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                ref.invalidate(moduleListProvider);
                ref.invalidate(availableDatasetsProvider);
                ref.invalidate(processingProvider);
                ref.invalidate(savedPipelinesProvider);
              },
              icon: Icon(Icons.replay_outlined, color: Theme.of(context).colorScheme.onError),
              label: Text("Reload the application", style: TextStyle(color: Theme.of(context).colorScheme.onError)),
            ),
          ],
        ),
      ),
    );
  }
}

class OnDemandErrorDialog extends StatelessWidget {
  const OnDemandErrorDialog({super.key, required this.error, required this.stackTrace});

  final Object error;
  final StackTrace stackTrace;

  @override
  Widget build(BuildContext context) {
    final String message = "$error\n\nThis was the stack trace:\n\n${Trace.from(stackTrace)}.";

    return AlertDialog(
      title: const Text('Something went wrong.'),
      content: SingleChildScrollView(child: SelectableText(message)),
      actions: <Widget>[
        FilledButton(
          style: ButtonStyle(backgroundColor: WidgetStateProperty.all(Theme.of(context).colorScheme.error)),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: message));
          },
          child: Text(
            "Copy error message to clipboard",
            style: TextStyle(color: Theme.of(context).colorScheme.onError),
          ),
        ),
        TextButton(onPressed: () => Navigator.pop(context, 'OK'), child: const Text('OK')),
      ],
    );
  }
}

class ForcedErrorDialog extends StatelessWidget {
  const ForcedErrorDialog({super.key, required this.errorTitle, required this.errorMessage});

  final String errorTitle;
  final String errorMessage;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(errorTitle, style: TextStyle(color: Theme.of(context).colorScheme.onError)),
      backgroundColor: Theme.of(context).colorScheme.error,
      content: SingleChildScrollView(
        child: SelectableText(errorMessage, style: TextStyle(color: Theme.of(context).colorScheme.onError)),
      ),
      actions: <Widget>[
        FilledButton(
          style: ButtonStyle(backgroundColor: WidgetStateProperty.all(Theme.of(context).colorScheme.errorContainer)),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: errorMessage));
          },
          child: Text(
            "Copy error message to clipboard",
            style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('OK', style: TextStyle(color: Theme.of(context).colorScheme.onError)),
        ),
      ],
    );
  }
}
