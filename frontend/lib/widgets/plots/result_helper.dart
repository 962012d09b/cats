import 'package:flutter/material.dart';
import 'package:cats/widgets/plots/legend.dart';

enum ScreenSize { small, medium, large }

class ResultBuilder extends StatelessWidget {
  const ResultBuilder({
    super.key,
    required this.title,
    required this.resultToShow,
    this.innerPadding = const EdgeInsets.all(16),
    this.legend,
  });

  final String title;
  final Widget resultToShow;
  final EdgeInsets innerPadding;
  final HorizontalLegend? legend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
      ),
      child: Column(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          Expanded(child: Padding(padding: innerPadding, child: resultToShow)),
          (legend != null) ? legend! : const SizedBox.shrink(),
        ],
      ),
    );
  }
}

Widget buildLineLegendItem({
  required Color color,
  required String label,
  bool isDashed = false,
  double dashWidth = 4,
  double dashSpace = 4,
  double lineLength = 30,
  double lineThickness = 3,
  TextStyle? labelStyle,
  bool isDense = false,
}) {
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: isDense ? 4.0 : 8.0),
    child: Row(
      children: [
        isDashed
            ? Container(
              width: lineLength,
              height: lineThickness,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.transparent, width: 1),
                borderRadius: BorderRadius.circular(2),
              ),
              child:
                  isDashed
                      ? CustomPaint(
                        painter: DashedLinePainter(color: color, dashWidth: dashWidth, dashSpace: dashSpace),
                      )
                      : null,
            )
            : Container(width: lineLength, height: lineThickness, color: color),
        SizedBox(width: isDense ? 2 : 4),
        labelStyle != null ? Text(label, style: labelStyle) : Text(label),
      ],
    ),
  );
}

// Custom painter for dashed lines, absolutely stupid that this isn't built in
class DashedLinePainter extends CustomPainter {
  final Color color;
  final double dashWidth;
  final double dashSpace;

  DashedLinePainter({required this.color, required this.dashWidth, required this.dashSpace});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke;

    double currentX = 0;

    while (currentX < size.width) {
      canvas.drawLine(Offset(currentX, 0), Offset(currentX + dashWidth, 0), paint);
      currentX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
