import 'package:flutter/material.dart';

/// A compact icon action button with a guaranteed circular tap splash.
///
/// Material 3 IconButtons can render a stadium-shaped (oval) state layer when
/// they are not square; forcing a [CircleBorder] shape at a fixed square size
/// keeps the touch highlight a consistent circle across every action button in
/// the app.
class ActionIconButton extends StatelessWidget {
  const ActionIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.iconSize = 21,
    this.size = 40,
    this.selected = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final double iconSize;
  final double size;

  /// An "on" toggle: tinted with the accent colour.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      isSelected: selected,
      icon: Icon(
        icon,
        size: iconSize,
        color: selected ? Theme.of(context).colorScheme.primary : null,
      ),
      style: IconButton.styleFrom(
        shape: const CircleBorder(),
        fixedSize: Size(size, size),
        minimumSize: Size(size, size),
        maximumSize: Size(size, size),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
