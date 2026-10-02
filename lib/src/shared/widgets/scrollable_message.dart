import 'package:flutter/material.dart';

/// The empty / error state used across screens: an icon, a plain-language
/// title, an optional detail line, and an optional action (e.g. Retry). It
/// scrolls, so it works inside a `RefreshIndicator`.
class StateMessage extends StatelessWidget {
  const StateMessage({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
    this.destructiveIcon = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;

  /// Tint the icon with the error color (for failure states).
  final bool destructiveIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasAction = actionLabel != null && onAction != null;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 44,
                    color: destructiveIcon
                        ? scheme.error
                        : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (hasAction) ...[
                    const SizedBox(height: 24),
                    actionIcon != null
                        ? FilledButton.icon(
                            onPressed: onAction,
                            icon: Icon(actionIcon, size: 18),
                            label: Text(actionLabel!),
                          )
                        : FilledButton(
                            onPressed: onAction,
                            child: Text(actionLabel!),
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
