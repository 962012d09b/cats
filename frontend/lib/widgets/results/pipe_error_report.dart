import 'package:cats/models/result.dart';
import 'package:flutter/material.dart';

class PipeErrorReport extends StatelessWidget {
  const PipeErrorReport({super.key, required this.errorMsg, required this.pipesWithErrors});

  final String errorMsg;
  final List<PipeResult> pipesWithErrors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ExpansionTile(
          title: Text(
            errorMsg,
            style: Theme.of(context).textTheme.titleMedium!.copyWith(color: Theme.of(context).colorScheme.onError),
          ),
          expandedAlignment: Alignment.centerLeft,
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          backgroundColor: Theme.of(context).colorScheme.error,
          collapsedBackgroundColor: Theme.of(context).colorScheme.error,
          collapsedTextColor: Theme.of(context).colorScheme.onError,
          textColor: Theme.of(context).colorScheme.onError,
          iconColor: Theme.of(context).colorScheme.onError,
          collapsedIconColor: Theme.of(context).colorScheme.onError,
          children: [
            Divider(color: Theme.of(context).colorScheme.onError, thickness: 2),
            for (var i = 0; i < pipesWithErrors.length; i++)
              _ErrorReport(pipe: pipesWithErrors[i], isLast: i == pipesWithErrors.length - 1),
          ],
        ),
      ),
    );
  }
}

class _ErrorReport extends StatelessWidget {
  const _ErrorReport({required this.pipe, required this.isLast});

  final PipeResult pipe;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pipe.name,
                style: Theme.of(context).textTheme.titleMedium!.copyWith(color: Theme.of(context).colorScheme.onError),
              ),
              for (var i = 0; i < pipe.logs.length; i++) ...[
                Text("Module ${i + 1}:", style: TextStyle(color: Theme.of(context).colorScheme.onError)),
                Row(
                  children: [
                    const SizedBox(width: 20),
                    pipe.logs[i].isEmpty
                        ? Text(
                          "No errors",
                          style: TextStyle(color: Theme.of(context).colorScheme.onError, fontStyle: FontStyle.italic),
                        )
                        : Text(
                          pipe.logs[i].toString(),
                          style: TextStyle(color: Theme.of(context).colorScheme.onError),
                        ),
                  ],
                ),
                if (i != pipe.logs.length - 1) const SizedBox(height: 5),
              ],
            ],
          ),
        ),
        if (!isLast) Divider(color: Theme.of(context).colorScheme.onError),
      ],
    );
  }
}
