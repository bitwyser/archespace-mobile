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

  Widget pill(String label, {required bool active, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? scheme.primary.withValues(alpha: 0.14)
              : scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? scheme.primary.withValues(alpha: 0.45)
                : scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
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
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          pill(
            'All',
            active: activeTags.isEmpty,
            onTap: () {
              activeTags.clear();
              onChanged();
            },
          ),
          for (final tag in allTags)
            pill(
              tag,
              active: activeTags.contains(tag),
              onTap: () {
                if (!activeTags.remove(tag)) activeTags.add(tag);
                onChanged();
              },
            ),
        ],
      ),
    ),
  );
}
