import 'package:flutter/material.dart';

class BulkAction {
  const BulkAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  /// Deletes or otherwise can't be undone easily: shown in red.
  final bool destructive;
}

/// The bar shown in selection mode, like the web's: a floating rounded card
/// (no outline) with the selected count, the batch actions as quiet round
/// icon buttons (destructive ones in red), and - after a divider - a button
/// that ends the selection.
class BulkActionBar extends StatelessWidget {
  const BulkActionBar({
    super.key,
    required this.count,
    required this.actions,
    this.onClear,
  });

  final int count;
  final List<BulkAction> actions;

  /// Clear the selection and leave selection mode. Null hides the button.
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        // Sized to its content and centred, not stretched across the screen.
        child: Align(
          heightFactor: 1,
          child: Material(
            // Set off by its raised colour and shadow, no outline.
            color: scheme.surfaceContainerHighest,
            elevation: 8,
            shadowColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$count selected',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Many actions on a narrow phone scroll sideways.
                  Flexible(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final action in actions)
                            IconButton(
                              onPressed: count == 0 ? null : action.onPressed,
                              icon: Icon(action.icon, size: 21),
                              tooltip: action.label,
                              color: action.destructive
                                  ? scheme.error
                                  : scheme.onSurfaceVariant,
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (onClear != null) ...[
                    Container(
                      width: 1,
                      height: 22,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      color: scheme.outlineVariant,
                    ),
                    IconButton(
                      onPressed: onClear,
                      icon: const Icon(Icons.close, size: 21),
                      tooltip: 'Clear selection',
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
