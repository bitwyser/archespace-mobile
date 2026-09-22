import 'package:flutter/material.dart';

/// Space accent presets, matching the web `SPACE_COLORS`.
const Map<String, Color> kSpaceColors = {
  'violet': Color(0xFF7C6AF7),
  'blue': Color(0xFF60A5FA),
  'green': Color(0xFF34D399),
  'amber': Color(0xFFFBBF24),
  'rose': Color(0xFFFB7185),
  'slate': Color(0xFF94A3B8),
};

Color? spaceColor(String? id) => id == null ? null : kSpaceColors[id];

/// A stable colour for a tag: the same tag name always maps to the same colour
/// from the palette (case-insensitively), so a tag reads consistently across
/// every space rather than taking on each space's own colour.
Color tagColor(String tag) {
  final palette = kSpaceColors.values.toList();
  final key = tag.trim().toLowerCase();
  if (key.isEmpty) return palette.first;
  final sum = key.codeUnits.fold<int>(0, (a, c) => a + c);
  return palette[sum % palette.length];
}
