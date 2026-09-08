import 'package:flutter/material.dart';

/// A compact, left-aligned tag filter row: small toggle chips plus a Clear
/// action. Shared by the dashboard and the space detail screen so tag menus
/// look the same everywhere. Toggles [activeTags] in place, then calls
/// [onChanged] (the caller runs setState).
Widget compactTagFilterBar({
  required BuildContext context,
  required List<String> allTags,
  required Set<String> activeTags,
  required VoidCallback onChanged,
}) {
  final scheme = Theme.of(context).colorScheme;

  Widget chip(String tag) {
    final active = activeTags.contains(tag);
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () {
        if (!activeTags.remove(tag)) activeTags.add(tag);
        onChanged();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: active
              ? scheme.primary.withValues(alpha: 0.15)
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
          border: active
              ? Border.all(color: scheme.primary.withValues(alpha: 0.4))
              : null,
        ),
        child: Text(
          tag,
          style: TextStyle(
            fontSize: 11,
            color: active ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  return Padding(
    padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        alignment: WrapAlignment.start,
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final tag in allTags) chip(tag),
          if (activeTags.isNotEmpty)
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () {
                activeTags.clear();
                onChanged();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Text(
                  'Clear',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
