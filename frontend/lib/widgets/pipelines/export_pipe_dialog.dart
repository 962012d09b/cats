import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cats/providers/pipelines_provider.dart';

class ExportPipeDialog extends ConsumerStatefulWidget {
  const ExportPipeDialog({super.key});

  @override
  ConsumerState<ExportPipeDialog> createState() => _ExportPipeDialogState();
}

class _ExportPipeDialogState extends ConsumerState<ExportPipeDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final text = ref.read(pipelinesProvider.notifier).exportState();
    _controller = TextEditingController(text: text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 750),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Export pipelines", style: Theme.of(context).textTheme.titleLarge),
            const Text("Your pipeline configuration, including any parameters, is represented in JSON below. "
                "Send it to someone or save it for later usage. "
                "Note that, for the import to be successful, the same modules must be available in the target application."),
            const SizedBox(height: 20),
            _controller.text == "[]"
                ? Center(
                    child: Text(
                      "There's nothing to export",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  )
                : Flexible(
                    child: SingleChildScrollView(
                      child: TextField(
                        controller: _controller,
                        readOnly: true,
                        maxLines: null,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: "Paste here",
                        ),
                        onTap: () => _controller.selection =
                            TextSelection(baseOffset: 0, extentOffset: _controller.value.text.length),
                      ),
                    ),
                  ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text((_controller.text == "[]") ? "Got it :(" : "Got it"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
