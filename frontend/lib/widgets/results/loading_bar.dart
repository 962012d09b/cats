import 'package:cats/providers/datasets_provider.dart';
import 'package:cats/providers/module_provider.dart';
import 'package:cats/providers/pipelines_provider.dart';
import 'package:cats/providers/processing_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoadingBar extends ConsumerWidget {
  const LoadingBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(processingProvider);

    final Color containerColor =
        (state.ready && !state.successful)
            ? Theme.of(context).colorScheme.errorContainer
            : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3);

    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Container(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 5),
        constraints: const BoxConstraints(minHeight: 90),
        decoration: BoxDecoration(borderRadius: const BorderRadius.all(Radius.circular(10)), color: containerColor),
        child: Column(
          children: [
            Row(
              children: [
                state.ready
                    ? Stack(
                      alignment: Alignment.center,
                      children: [
                        const CircularProgressIndicator(value: 1.0, strokeWidth: 3),
                        Icon(
                          state.successful
                              ? Icons.sentiment_satisfied_alt_outlined
                              : Icons.sentiment_dissatisfied_outlined,
                          color:
                              state.successful
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.error,
                          size: 20,
                        ),
                      ],
                    )
                    : const CircularProgressIndicator(strokeWidth: 3),
                const SizedBox(width: 20),
                Expanded(
                  child: LinearProgressIndicator(
                    value: state.progress.clamp(0.0, 1.0),
                    color: Theme.of(context).colorScheme.primary,
                    backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
                  ),
                ),
              ],
            ),
            if ((state.ready && !state.successful))
              SelectableText(
                state.message,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onErrorContainer),
                textAlign: TextAlign.center,
              )
            else
              Text(state.message, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),

            if (state.jobId.isNotEmpty) ...[
              SelectableText(
                'Job ID: ${state.jobId}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
              ),
            ],

            if (state.ready && !state.successful)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: ElevatedButton.icon(
                  onPressed: () {
                    ref.invalidate(moduleListProvider);
                    ref.invalidate(availableDatasetsProvider);
                    ref.invalidate(processingProvider);
                    ref.invalidate(savedPipelinesProvider);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                  icon: Icon(Icons.replay_outlined, color: Theme.of(context).colorScheme.onError),
                  label: Text("Reload the application"),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
