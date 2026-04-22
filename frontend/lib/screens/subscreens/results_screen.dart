import 'package:cats/widgets/results/loading_bar.dart';
import 'package:cats/widgets/results/results_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProcessingScreen extends ConsumerWidget {
  const ProcessingScreen({super.key, required this.useHorizontalLayout});

  final bool useHorizontalLayout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Expanded(child: Column(children: [LoadingBar(), ResultsGrid(useHorizontalLayout: useHorizontalLayout)]));
  }
}
