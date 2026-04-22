import 'dart:convert';
import 'dart:typed_data';
import 'package:cats/providers/pipelines_provider.dart';
import 'package:cats/providers/results_provider.dart';
import 'package:cats/widgets/settings/utility/helper.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class DownloadResultsButton extends ConsumerWidget {
  const DownloadResultsButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(maskedResultsProvider);
    final maskedResults = results.where((element) => element.isVisible).toList();
    final visibility = ref.read(pipelineVisibilityProvider);
    final pipelines = ref.read(pipelinesProvider);

    final maskedPipelines = [
      for (var i = 0; i < pipelines.length; i++)
        if (visibility[i]) pipelines[i],
    ];

    return IconButton(
      iconSize: 22,
      color: Theme.of(context).colorScheme.primary,
      onPressed: (maskedResults.isEmpty)
          ? null
          : () {
              var currentTimestamp = DateTime.now().toIso8601String().replaceAll(":", "-");
              var name = "cats_results_$currentTimestamp.json";

              final jsonData = maskedResults.map((e) => e.toJson()).toList();
              for (var i = 0; i < maskedPipelines.length; i++) {
                jsonData[i]['pipeline'] = maskedPipelines[i].toJson();
              }
              const encoder = JsonEncoder.withIndent('  '); // 2-space indentation
              final jsonString = encoder.convert(jsonData);
              final bytes = Uint8List.fromList(utf8.encode(jsonString));

              FileSaver.instance.saveFile(name: name, bytes: bytes, mimeType: MimeType.json);
              showConfirmationSnackbar(
                context,
                "Results saved as \"$name\" to your downloads folder.",
                durationSeconds: 4,
              );
            },
      icon: const Icon(FontAwesomeIcons.download),
    );
  }
}
