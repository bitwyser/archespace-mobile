import 'package:flutter/material.dart';

/// The tone of a [StatusBanner].
enum StatusTone { info, pending }

/// A thin, full-width status banner pinned at the top of a list (e.g. an
/// offline notice or a pending-sync notice). Shared so every status banner
/// looks and behaves the same (Law of Similarity) and reads as a persistent
/// state, distinct from the transient snackbars.
class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.icon,
    required this.message,
    this.tone = StatusTone.info,
  });

  final IconData icon;
  final String message;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color bg, Color fg) = switch (tone) {
      StatusTone.info => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      StatusTone.pending => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
    };
    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: fg, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
