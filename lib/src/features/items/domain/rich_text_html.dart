import 'package:flutter/material.dart';

/// Rich Text item support: parse and serialise the same sanitised HTML subset
/// the web app stores in `{ html }`, so the two clients interoperate.
///
/// Supported inline formatting (matching the web toolbar and sanitiser):
///   - bold: `b` / `strong`
///   - italic: `i` / `em`
///   - underline: `u`
///   - font size: `font size="1-7"` (and `span` with a `font-size` style)
///   - line breaks: `br`, and block boundaries from `div` / `p`
/// Anything else is unwrapped to its text. Nothing here executes markup; the
/// output is plain styled text, never rendered as live HTML.

/// A run of text sharing one set of formatting attributes.
class RichSpan {
  const RichSpan(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.size = kDefaultFontLevel,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool underline;

  /// Legacy execCommand font scale 1-7; 3 is the default (inherits base size).
  final int size;

  bool sameStyleAs(RichSpan o) =>
      bold == o.bold &&
      italic == o.italic &&
      underline == o.underline &&
      size == o.size;
}

const int kDefaultFontLevel = 3;
const int kMinFontLevel = 1;
const int kMaxFontLevel = 7;

/// Font size level (1-7) to a logical pixel size. Level 3 returns null so the
/// text inherits the surrounding base size.
double? fontSizeForLevel(int level) {
  switch (level) {
    case 1:
      return 11;
    case 2:
      return 13;
    case 4:
      return 18;
    case 5:
      return 22;
    case 6:
      return 28;
    case 7:
      return 36;
    default:
      return null; // level 3 (or out of range) inherits the base size
  }
}

// ── HTML -> spans ─────────────────────────────────────────────

class _Frame {
  _Frame({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.size,
  });
  final bool bold;
  final bool italic;
  final bool underline;
  final int? size;
}

/// Parse the sanitised HTML subset into a flat list of styled runs.
List<RichSpan> parseRichHtml(String? html) {
  if (html == null || html.isEmpty) return const [];
  final spans = <RichSpan>[];
  final frames = <_Frame>[];
  final buffer = StringBuffer();

  bool curBold() => frames.any((f) => f.bold);
  bool curItalic() => frames.any((f) => f.italic);
  bool curUnderline() => frames.any((f) => f.underline);
  int curSize() {
    for (var i = frames.length - 1; i >= 0; i--) {
      final s = frames[i].size;
      if (s != null) return s;
    }
    return kDefaultFontLevel;
  }

  void flush() {
    if (buffer.isEmpty) return;
    final text = buffer.toString();
    buffer.clear();
    final span = RichSpan(
      text,
      bold: curBold(),
      italic: curItalic(),
      underline: curUnderline(),
      size: curSize(),
    );
    if (spans.isNotEmpty && spans.last.sameStyleAs(span)) {
      final merged = spans.removeLast();
      spans.add(
        RichSpan(
          merged.text + text,
          bold: span.bold,
          italic: span.italic,
          underline: span.underline,
          size: span.size,
        ),
      );
    } else {
      spans.add(span);
    }
  }

  bool endsWithNewline() => buffer.isNotEmpty
      ? buffer.toString().endsWith('\n')
      : (spans.isNotEmpty && spans.last.text.endsWith('\n'));

  var i = 0;
  while (i < html.length) {
    if (html[i] == '<') {
      final end = html.indexOf('>', i);
      if (end == -1) break;
      final raw = html.substring(i + 1, end).trim();
      i = end + 1;
      if (raw.isEmpty) continue;
      final closing = raw.startsWith('/');
      final body = closing ? raw.substring(1).trim() : raw;
      final name = body.split(RegExp(r'[\s/]')).first.toLowerCase();

      if (name == 'br') {
        flush();
        buffer.write('\n');
        continue;
      }
      if (name == 'div' || name == 'p') {
        if (!closing &&
            (spans.isNotEmpty || buffer.isNotEmpty) &&
            !endsWithNewline()) {
          flush();
          buffer.write('\n');
        }
        continue; // block tags affect line breaks only, no style frame
      }
      // Inline style tags push/pop a frame.
      if (closing) {
        flush();
        if (frames.isNotEmpty) frames.removeLast();
        continue;
      }
      flush();
      switch (name) {
        case 'b':
        case 'strong':
          frames.add(_Frame(bold: true));
        case 'i':
        case 'em':
          frames.add(_Frame(italic: true));
        case 'u':
          frames.add(_Frame(underline: true));
        case 'font':
          frames.add(_Frame(size: _sizeFromFont(body)));
        case 'span':
          frames.add(_Frame(size: _sizeFromSpanStyle(body)));
        default:
          frames.add(_Frame()); // unknown but balanced tag
      }
    } else {
      final next = html.indexOf('<', i);
      final chunk = html.substring(i, next == -1 ? html.length : next);
      buffer.write(_decodeEntities(chunk));
      i = next == -1 ? html.length : next;
    }
  }
  flush();
  return spans;
}

int? _sizeFromFont(String body) {
  final m = RegExp(r'''size\s*=\s*["']?\s*(\d)''').firstMatch(body);
  if (m == null) return null;
  final n = int.tryParse(m.group(1)!);
  if (n == null || n < kMinFontLevel || n > kMaxFontLevel) return null;
  return n;
}

int? _sizeFromSpanStyle(String body) {
  final m = RegExp(
    r'font-size\s*:\s*([0-9.]+)\s*px',
    caseSensitive: false,
  ).firstMatch(body);
  if (m == null) return null;
  final px = double.tryParse(m.group(1)!);
  if (px == null) return null;
  // Map a pixel size back to the nearest 1-7 level.
  int best = kDefaultFontLevel;
  double bestDiff = double.infinity;
  for (var level = kMinFontLevel; level <= kMaxFontLevel; level++) {
    final ref = fontSizeForLevel(level) ?? 15.0;
    final diff = (ref - px).abs();
    if (diff < bestDiff) {
      bestDiff = diff;
      best = level;
    }
  }
  return best;
}

String _decodeEntities(String s) {
  if (!s.contains('&')) return s;
  return s
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&');
}

// ── spans -> HTML ─────────────────────────────────────────────

String _escape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

/// Serialise runs to the sanitised HTML subset the web app reads.
String richSpansToHtml(List<RichSpan> spans) {
  final out = StringBuffer();
  for (final span in spans) {
    if (span.text.isEmpty) continue;
    // Escape, then turn newlines into <br>.
    final parts = span.text.split('\n');
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) out.write('<br>');
      final text = parts[i];
      if (text.isEmpty) continue;
      var open = '';
      var close = '';
      if (span.size != kDefaultFontLevel) {
        open += '<font size="${span.size}">';
        close = '</font>$close';
      }
      if (span.bold) {
        open += '<b>';
        close = '</b>$close';
      }
      if (span.italic) {
        open += '<i>';
        close = '</i>$close';
      }
      if (span.underline) {
        open += '<u>';
        close = '</u>$close';
      }
      out.write('$open${_escape(text)}$close');
    }
  }
  return out.toString();
}

/// Flatten Rich Text HTML to plain text (for search, clipboard, PDF).
String richHtmlToPlainText(String? html) =>
    parseRichHtml(html).map((s) => s.text).join().trim();

// ── spans <-> (text, attrs) for the editing controller ────────

/// Per-character formatting used by the editing controller.
class CharAttr {
  const CharAttr({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.size = kDefaultFontLevel,
  });

  final bool bold;
  final bool italic;
  final bool underline;
  final int size;

  CharAttr copyWith({bool? bold, bool? italic, bool? underline, int? size}) =>
      CharAttr(
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
        underline: underline ?? this.underline,
        size: size ?? this.size,
      );

  bool same(CharAttr o) =>
      bold == o.bold &&
      italic == o.italic &&
      underline == o.underline &&
      size == o.size;
}

/// Build a Flutter [TextSpan] tree from runs, over an optional [base] style.
TextSpan richSpansToTextSpan(List<RichSpan> spans, {TextStyle? base}) {
  return TextSpan(
    style: base,
    children: [
      for (final s in spans)
        TextSpan(
          text: s.text,
          style: TextStyle(
            fontWeight: s.bold ? FontWeight.bold : null,
            fontStyle: s.italic ? FontStyle.italic : null,
            decoration: s.underline ? TextDecoration.underline : null,
            fontSize: fontSizeForLevel(s.size),
          ),
        ),
    ],
  );
}
