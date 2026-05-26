import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cats/providers/pipelines_provider.dart';

class ImportPipeDialog extends ConsumerStatefulWidget {
  const ImportPipeDialog({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _ImportPipeDialogState();
}

class _ImportPipeDialogState extends ConsumerState<ImportPipeDialog> {
  String? _importError;
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 750),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Import pipelines", style: Theme.of(context).textTheme.titleLarge),
            const Text(
                "Paste the JSON representation of the pipelines you want to import. Note that this will overwrite your current pipelines. Pasting hand-modified JSON may or may not lead to crashes."),
            const SizedBox(height: 20),
            Flexible(
              child: SingleChildScrollView(
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: "Paste here",
                    errorText: _importError,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("Cancel"),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: () {
                    try {
                      ref.read(pipelinesProvider.notifier).importState(_controller.text);
                      Navigator.pop(context);
                    } catch (e) {
                      setState(() {
                        _importError = e.toString();
                      });
                    }
                  },
                  child: const Text("Import"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
