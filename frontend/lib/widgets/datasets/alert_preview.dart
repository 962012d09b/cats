import 'dart:convert';

import 'package:cats/providers/datasets_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AlertPreview extends ConsumerWidget {
  const AlertPreview({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).brightness == Brightness.dark ? monokaiSublimeTheme : githubTheme;
    final preview = ref.read(availableDatasetsProvider.notifier).fetchPreviewForDataset(id);

    return FutureBuilder<List<Map>>(
      future: preview,
      builder: (context, webRequest) {
        if (webRequest.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (webRequest.hasError) {
          return SelectableText(
            'Failed to load preview:\n${webRequest.error}',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          );
        } else if (webRequest.hasData) {
          final data = webRequest.data!;
          final prettyContent = const JsonEncoder.withIndent('    ').convert(data);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Showing first ${data.length} alerts:"),
              const SizedBox(height: 10),
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                    child: HighlightView(
                      prettyContent,
                      language: 'json',
                      theme: theme,
                      padding: const EdgeInsets.all(12),
                      textStyle: const TextStyle(fontFamily: 'Courier', fontSize: 14),
                    ),
                  ),
                ),
              ),
            ],
          );
        } else {
          return const Text('No data available.');
        }
      },
    );
  }
}
