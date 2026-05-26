import 'package:cats/widgets/datasets/alert_preview.dart';
import 'package:cats/widgets/datasets/jitter_plot.dart';
import 'package:flutter/material.dart';

enum PreviewType { alerts, graph }

class PreviewDialog extends StatefulWidget {
  final String title;
  final int id;

  const PreviewDialog({super.key, required this.title, required this.id});

  @override
  State<PreviewDialog> createState() => _PreviewDialogState();
}

class _PreviewDialogState extends State<PreviewDialog> {
  PreviewType _selectedType = PreviewType.alerts;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${widget.title} Preview", style: Theme.of(context).textTheme.headlineSmall),
              SizedBox(width: 16),
              SegmentedButton(
                segments: const [
                  ButtonSegment<PreviewType>(value: PreviewType.alerts, label: Text('Alert JSON')),
                  ButtonSegment<PreviewType>(value: PreviewType.graph, label: Text('Jitter Plot')),
                ],
                showSelectedIcon: false,
                selected: {_selectedType},
                onSelectionChanged: (newSelection) {
                  setState(() {
                    _selectedType = newSelection.first;
                  });
                },
              ),

              Expanded(child: Container()),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),

          Expanded(
            child: _selectedType == PreviewType.alerts ? AlertPreview(id: widget.id) : JitterPreview(id: widget.id),
          ),
        ],
      ),
    );
  }
}
