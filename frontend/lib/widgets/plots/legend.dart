import 'package:flutter/material.dart';

class HorizontalLegend extends StatelessWidget {
  const HorizontalLegend({super.key, required this.segments});

  final List<Indicator> segments;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var maxWidth = constraints.maxWidth / segments.length;
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: segments
                  .map((segment) => ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: segment,
                      ))
                  .toList(),
            ),
          ],
        );
      },
    );
  }
}

class Indicator extends StatelessWidget {
  const Indicator({
    super.key,
    required this.color,
    required this.text,
    this.isSquare = true,
    this.isBold = true,
    this.size = 16,
    this.textColor,
  });
  final Color color;
  final String text;
  final bool isSquare;
  final bool isBold;
  final double size;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: isSquare ? BoxShape.rectangle : BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(
          width: 4,
        ),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: size,
              overflow: TextOverflow.ellipsis,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: textColor,
            ),
          ),
        )
      ],
    );
  }
}
