import 'package:flutter/material.dart';

/// A full-page "Locked" state with an Unlock button, shown in place of locked
/// content until the vault PIN opens it.
class LockedView extends StatelessWidget {
  const LockedView({super.key, required this.message, required this.onUnlock});

  final String message;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.lock_outline, size: 30, color: scheme.primary),
            ),
            const SizedBox(height: 16),
            Text('Locked', style: textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onUnlock,
              icon: const Icon(Icons.lock_open_outlined),
              label: const Text('Unlock'),
            ),
          ],
        ),
      ),
    );
  }
}
