import 'package:flutter/material.dart';
import 'package:highlight/highlight.dart' show highlight, Node;

/// Token colours for syntax highlighting, shared by the code preview and the
/// code editor. Mid-tone hues so they read on both light and dark surfaces;
/// untokenised text uses the surrounding [base] colour.
Map<String, TextStyle> codeHighlightTheme(Color base) => {
  'root': TextStyle(color: base, backgroundColor: Colors.transparent),
  'comment': const TextStyle(
    color: Color(0xFF8B949E),
    fontStyle: FontStyle.italic,
  ),
  'quote': const TextStyle(
    color: Color(0xFF8B949E),
    fontStyle: FontStyle.italic,
  ),
  'keyword': const TextStyle(color: Color(0xFFA855F7)),
  'selector-tag': const TextStyle(color: Color(0xFFA855F7)),
  'literal': const TextStyle(color: Color(0xFFA855F7)),
  'type': const TextStyle(color: Color(0xFFA855F7)),
  'name': const TextStyle(color: Color(0xFFA855F7)),
  'string': const TextStyle(color: Color(0xFF3FB950)),
  'regexp': const TextStyle(color: Color(0xFF3FB950)),
  'addition': const TextStyle(color: Color(0xFF3FB950)),
  'number': const TextStyle(color: Color(0xFFE3A008)),
  'symbol': const TextStyle(color: Color(0xFFE3A008)),
  'bullet': const TextStyle(color: Color(0xFFE3A008)),
  'link': const TextStyle(color: Color(0xFFE3A008)),
  'title': const TextStyle(color: Color(0xFF58A6FF)),
  'built_in': const TextStyle(color: Color(0xFF58A6FF)),
  'attr': const TextStyle(color: Color(0xFF39C5CF)),
  'attribute': const TextStyle(color: Color(0xFF39C5CF)),
  'variable': const TextStyle(color: Color(0xFF39C5CF)),
  'template-variable': const TextStyle(color: Color(0xFF39C5CF)),
  'tag': const TextStyle(color: Color(0xFFFF7B72)),
  'selector-id': const TextStyle(color: Color(0xFFFF7B72)),
  'selector-class': const TextStyle(color: Color(0xFFFF7B72)),
  'deletion': const TextStyle(color: Color(0xFFFF7B72)),
  'meta': const TextStyle(color: Color(0xFF8B5CF6)),
  'emphasis': const TextStyle(fontStyle: FontStyle.italic),
  'strong': const TextStyle(fontWeight: FontWeight.w600),
};

void _render(List<Node> nodes, Map<String, TextStyle> theme, List<TextSpan> out) {
  for (final node in nodes) {
    final style = node.className == null ? null : theme[node.className!];
    if (node.value != null) {
      out.add(TextSpan(text: node.value, style: style));
    } else if (node.children != null) {
      final children = <TextSpan>[];
      _render(node.children!, theme, children);
      out.add(TextSpan(style: style, children: children));
    }
  }
}

/// A [TextEditingController] that live-highlights its text in the code editor,
/// auto-detecting the language. Untokenised text keeps the field's own style.
///
/// Highlighting is skipped above [_kMaxHighlightChars] and the parsed result is
/// cached per text, so pasting a large chunk doesn't run an expensive
/// auto-detect parse on every keystroke or cursor move (which stalled frames).
class CodeHighlightController extends TextEditingController {
  CodeHighlightController({super.text, required this.theme});

  final Map<String, TextStyle> theme;

  // Auto-detection over very large text is costly; beyond this show plain text.
  static const int _kMaxHighlightChars = 5000;

  String? _cachedText;
  List<TextSpan>? _cachedSpans;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final code = text;
    if (code.length > _kMaxHighlightChars) {
      return TextSpan(style: style, text: code);
    }
    if (_cachedText != code) {
      final spans = <TextSpan>[];
      final result = highlight.parse(code, autoDetection: true);
      _render(result.nodes ?? const [], theme, spans);
      _cachedText = code;
      _cachedSpans = spans;
    }
    return TextSpan(style: style, children: _cachedSpans);
  }
}
