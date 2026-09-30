import 'package:archespace_mobile/src/features/items/domain/rich_text_html.dart';

/// Rich text content is Tiptap (ProseMirror) JSON: `{ doc: { type: 'doc',
/// content: [...] } }`, written by the Tiptap editor on web and in the app's
/// WebView. Items saved before it hold `{ html }` (the old Rich text) or are
/// the old `markdown` type with `{ text }`; they still display, and convert
/// the first time they're edited. Mirrors the web `lib/richText/doc.js`.

const Map<String, dynamic> kEmptyRichDoc = {
  'type': 'doc',
  'content': [
    {'type': 'paragraph'},
  ],
};

/// True when [content] holds a Tiptap document (not an older format).
bool isRichDoc(Map<String, dynamic> content) {
  final doc = content['doc'];
  return doc is Map && doc['type'] == 'doc';
}

/// Child nodes of a Tiptap node.
List<Map<String, dynamic>> richChildren(Object? node) {
  if (node is! Map) return const [];
  final content = node['content'];
  if (content is! List) return const [];
  return content
      .whereType<Map>()
      .map((e) => e.cast<String, dynamic>())
      .toList();
}

const Set<String> _blocks = {
  'paragraph',
  'heading',
  'blockquote',
  'codeBlock',
  'listItem',
  'taskItem',
  'tableRow',
  'horizontalRule',
};

void _lineBreak(StringBuffer out) {
  final s = out.toString();
  if (s.isNotEmpty && !s.endsWith('\n')) out.write('\n');
}

void _nodeText(Map<String, dynamic> node, StringBuffer out) {
  final type = node['type'];
  if (type == 'text') {
    out.write((node['text'] ?? '').toString());
    return;
  }
  if (type == 'hardBreak') {
    out.write('\n');
    return;
  }
  if (type == 'tableCell' || type == 'tableHeader') {
    final cell = StringBuffer();
    for (final child in richChildren(node)) {
      _nodeText(child, cell);
    }
    out
      ..write(cell.toString().trim().replaceAll(RegExp(r'\s*\n\s*'), ' '))
      ..write('\t');
    return;
  }
  for (final child in richChildren(node)) {
    _nodeText(child, out);
  }
  if (type == 'tableRow') {
    final s = out.toString();
    if (s.endsWith('\t')) {
      out
        ..clear()
        ..write(s.substring(0, s.length - 1));
    }
  }
  if (_blocks.contains(type)) _lineBreak(out);
}

/// Plain text of Rich text content in any of its formats: a line per block,
/// tabs between table cells (for copy, search and empty checks).
String richContentPlainText(String type, Map<String, dynamic> content) {
  if (isRichDoc(content)) {
    final out = StringBuffer();
    _nodeText((content['doc'] as Map).cast<String, dynamic>(), out);
    return out.toString().replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }
  if (type == 'markdown') return (content['text'] ?? '').toString();
  return richHtmlToPlainText((content['html'] ?? '').toString());
}
