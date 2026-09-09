import 'package:flutter/material.dart';

import 'package:archespace_mobile/src/features/settings/application/appearance_controller.dart';
import 'package:archespace_mobile/src/shared/widgets/brand_wordmark.dart';

/// The app-open landing screen: the ArcheSpace wordmark and a circular accent
/// button that continues to the login / create-account screen. A fuller
/// introduction can replace the middle of this screen later.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final accent = AppearanceController.instance.accent;
    // Pick a foreground that stays legible on whatever accent is selected.
    final onAccent =
        ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
        ? Colors.white
        : const Color(0xFF0B1512);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandWordmark(height: 46),
              const SizedBox(height: 64),
              Semantics(
                button: true,
                label: 'Continue',
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: FilledButton(
                    onPressed: onContinue,
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: EdgeInsets.zero,
                      backgroundColor: accent,
                      foregroundColor: onAccent,
                    ),
                    child: CustomPaint(
                      size: const Size(36, 36),
                      painter: _ArrowPainter(color: onAccent),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A thick, rounded right-pointing arrow drawn to fit its box.
class _ArrowPainter extends CustomPainter {
  const _ArrowPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.13
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width;
    final h = size.height;
    final midY = h * 0.5;
    // Shaft.
    canvas.drawLine(Offset(w * 0.16, midY), Offset(w * 0.82, midY), paint);
    // Arrow head.
    final head = Path()
      ..moveTo(w * 0.55, h * 0.27)
      ..lineTo(w * 0.83, midY)
      ..lineTo(w * 0.55, h * 0.73);
    canvas.drawPath(head, paint);
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) => oldDelegate.color != color;
}
