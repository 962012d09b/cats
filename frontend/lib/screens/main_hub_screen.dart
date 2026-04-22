import 'package:flutter/material.dart';
import 'package:cats/screens/subscreens/dataset_screen.dart';
import 'package:cats/screens/subscreens/pipeline_screen.dart';
import 'package:cats/screens/subscreens/results_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ScreenOne extends StatelessWidget {
  const ScreenOne({super.key, required this.useHorizontalLayout});

  final bool useHorizontalLayout;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Align(
        alignment: Alignment.topLeft,
        child:
            useHorizontalLayout
                ? SingleChildScrollView(
                  padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20, top: 10),
                  child: Column(
                    children: [
                      const _HubSegment(segmentWidget: DatasetScreen(), segmentTitle: "Datasets"),
                      const _HubDivider(),
                      const _HubSegment(segmentWidget: PipelineScreen(), segmentTitle: "Pipelines & Modules"),
                      const _HubDivider(),
                      _HubSegment(
                        segmentWidget: ProcessingScreen(useHorizontalLayout: useHorizontalLayout),
                        segmentTitle: "Results",
                      ),
                    ],
                  ),
                )
                : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.only(left: 20, bottom: 20, top: 10),
                        child: Column(
                          children: [
                            _HubSegment(segmentWidget: DatasetScreen(), segmentTitle: "Datasets"),
                            _HubDivider(),
                            _HubSegment(segmentWidget: PipelineScreen(), segmentTitle: "Pipelines & Modules"),
                          ],
                        ),
                      ),
                    ),
                    const _HubDivider(isVertical: true),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(right: 20, bottom: 20, top: 10),
                        child: _HubSegment(
                          segmentWidget: ProcessingScreen(useHorizontalLayout: useHorizontalLayout),
                          segmentTitle: "Results",
                          showLoading: true,
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}

class _HubSegment extends ConsumerWidget {
  const _HubSegment({required this.segmentWidget, required this.segmentTitle, this.showLoading = false});

  final Widget segmentWidget;
  final String segmentTitle;
  final bool showLoading; // TEMPORARY SOLUTION

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 15),
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.all(Radius.circular(10)),
              ),
              child: RotatedBox(
                quarterTurns: 3,
                child: Text(segmentTitle, style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer)),
              ),
            ),
          ],
        ),
        const SizedBox(width: 20),
        segmentWidget,
      ],
    );
  }
}

class _HubDivider extends StatelessWidget {
  const _HubDivider({this.isVertical = false});

  final bool isVertical;

  @override
  Widget build(BuildContext context) {
    return isVertical
        ? VerticalDivider(
          color: Theme.of(context).colorScheme.primary,
          endIndent: 15,
          indent: 15,
          width: 50,
          thickness: 2,
        )
        : Divider(color: Theme.of(context).colorScheme.primary, endIndent: 15, indent: 15, height: 50, thickness: 2);
  }
}
