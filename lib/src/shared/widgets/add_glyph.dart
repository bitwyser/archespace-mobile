import 'package:flutter/material.dart';

/// A "+" glyph drawn as two rounded strokes, so its thickness is controllable
/// (the bundled Material Icons font has a fixed weight). Used for the add FABs.
/// Colour defaults to the surrounding [IconTheme] (e.g. the FAB's foreground).
class AddGlyph extends StatelessWidget {
  const AddGlyph({super.key, this.size = 22, this.stroke = 3.2, this.color});

  final double size;
  final double stroke;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c =
        color ??
        IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onPrimary;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _PlusPainter(c, stroke)),
    );
  }
}

class _PlusPainter extends CustomPainter {
  _PlusPainter(this.color, this.stroke);

  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    final cx = size.width / 2;
    final cy = size.height / 2;
    // Inset by half the stroke so the rounded caps stay inside the bounds.
    final half = size.width / 2 - stroke / 2;
    canvas.drawLine(Offset(cx - half, cy), Offset(cx + half, cy), paint);
    canvas.drawLine(Offset(cx, cy - half), Offset(cx, cy + half), paint);
  }

  @override
  bool shouldRepaint(_PlusPainter old) =>
      old.color != color || old.stroke != stroke;
}
