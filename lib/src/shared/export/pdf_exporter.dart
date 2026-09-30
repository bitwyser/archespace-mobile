import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:archespace_mobile/src/features/items/domain/draw.dart';
import 'package:archespace_mobile/src/features/items/domain/rich_text_html.dart';
import 'package:archespace_mobile/src/features/items/domain/space_item.dart';
import 'package:archespace_mobile/src/shared/brand/brand_paths.dart';

/// Builds a PDF for a whole space or a single item, per item type. Mirrors the
/// web PDF export's content structure.
class PdfExporter {
  const PdfExporter._();

  static Future<Uint8List> buildSpace(
    String name,
    List<SpaceItem> items,
  ) async {
    final logo = _logoSvg();
    final stamp = _timestamp();
    final theme = await _theme();
    final doc = pw.Document(theme: theme);
    doc.addPage(
      pw.MultiPage(
        header: (context) => _pageHeader(logo, stamp),
        footer: (context) => _pageFooter(context),
        build: (context) => [
          // The space name once, at the start of the document (not per page).
          pw.Text(
            name.isEmpty ? 'Space' : name,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          if (items.isEmpty) pw.Text('This space has no items.'),
          for (final item in items) ..._section(item),
        ],
      ),
    );
    return doc.save();
  }

  static Future<Uint8List> buildItem(SpaceItem item) async {
    final logo = _logoSvg();
    final stamp = _timestamp();
    final theme = await _theme();
    final doc = pw.Document(theme: theme);
    doc.addPage(
      pw.MultiPage(
        header: (context) => _pageHeader(logo, stamp),
        footer: (context) => _pageFooter(context),
        build: (context) => _section(item),
      ),
    );
    return doc.save();
  }

  // A monospace face (for code) with broad glyph coverage, kept for _body.
  static pw.Font? _mono;

  /// A theme using DejaVu (broad symbol/arrow coverage, unlike the built-in
  /// Helvetica), and the DejaVu mono face for code.
  static Future<pw.ThemeData> _theme() async {
    final base = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'));
    _mono = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSansMono.ttf'));
    return pw.ThemeData.withFont(base: base, bold: bold);
  }

  /// The ArcheSpace wordmark for the page corner: "Arche" in the mint accent,
  /// "Space" inked dark so it reads on the white PDF page.
  static String _logoSvg() =>
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="$kBrandWordmarkViewBox">'
      '<path d="$kBrandArchePath" fill="#32d3aa" fill-rule="evenodd"/>'
      '<path d="$kBrandSpacePath" fill="#0f1115" fill-rule="evenodd"/>'
      '</svg>';

  /// The export time, e.g. "9/19/26, 8:36 PM".
  static String _timestamp() {
    final n = DateTime.now();
    final h = n.hour % 12 == 0 ? 12 : n.hour % 12;
    final ampm = n.hour >= 12 ? 'PM' : 'AM';
    final mm = n.minute.toString().padLeft(2, '0');
    final yy = (n.year % 100).toString().padLeft(2, '0');
    return '${n.month}/${n.day}/$yy, $h:$mm $ampm';
  }

  static const pw.TextStyle _chromeStyle = pw.TextStyle(
    fontSize: 8,
    color: PdfColors.grey600,
  );

  /// Every page's header: export time top-left, logo top-right.
  static pw.Widget _pageHeader(String logoSvg, String stamp) => pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 12),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(stamp, style: _chromeStyle),
        pw.Spacer(),
        pw.SizedBox(width: 100, height: 15, child: pw.SvgImage(svg: logoSvg)),
      ],
    ),
  );

  /// Every page's footer: site URL bottom-left, page number bottom-right.
  static pw.Widget _pageFooter(pw.Context context) => pw.Container(
    margin: const pw.EdgeInsets.only(top: 8),
    child: pw.Row(
      children: [
        pw.Text('https://archespace.app/', style: _chromeStyle),
        pw.Spacer(),
        pw.Text(
          '${context.pageNumber}/${context.pagesCount}',
          style: _chromeStyle,
        ),
      ],
    ),
  );

  /// Text that page-breaks when it runs past the bottom of a page. pw.Text
  /// only splits with overflow: span; the default refuses and throws once the
  /// text is taller than a page.
  static pw.Text _text(String text, {pw.TextStyle? style}) =>
      pw.Text(text, style: style, overflow: pw.TextOverflow.span);

  // Each item contributes a FLAT list of top-level widgets to the MultiPage
  // build (never a single pw.Column). MultiPage can only page-break between
  // top-level widgets and inside splittable ones (spanning Text, Table); a
  // Column is atomic, so wrapping big content in one made MultiPage loop
  // forever. Container and Padding are atomic too: any text that can run long
  // (list rows, card descriptions) must be a bare _text, or one taller than a
  // page throws "Widget won't fit into the page". Spacing goes in SizedBoxes.
  static List<pw.Widget> _section(SpaceItem item) => [
    pw.SizedBox(height: 8),
    _text(
      item.title.isEmpty ? 'Untitled' : item.title,
      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
    ),
    pw.SizedBox(height: 4),
    ..._body(item),
    pw.Divider(),
  ];

  static List<pw.Widget> _body(SpaceItem item) {
    final c = item.content;
    switch (item.type) {
      case 'textbox':
      case 'markdown':
        final text = (c['text'] ?? '').toString();
        return [_text(text.isEmpty ? '(empty)' : text)];
      case 'richtext':
        final text = richHtmlToPlainText((c['html'] ?? '').toString());
        return [_text(text.isEmpty ? '(empty)' : text)];
      case 'code':
        final code = (c['code'] ?? '').toString();
        if (code.isEmpty) return [pw.Text('(empty)')];
        // Plain monospace text splits across pages (a decorated Container
        // cannot), so a long code block never hangs the export.
        return [
          _text(
            code,
            style: pw.TextStyle(font: _mono, fontSize: 9, lineSpacing: 2),
          ),
        ];
      case 'menu_list':
        return _bullets(c, ordered: false);
      case 'numbered_list':
        return _bullets(c, ordered: true);
      case 'checkbox_list':
        return _checklist(c);
      case 'card_list':
        return _cards(c);
      case 'table':
        return [_table(c)];
      case 'draw':
        return [_drawing(c)];
      default:
        return const [];
    }
  }

  static List<pw.Widget> _bullets(
    Map<String, dynamic> c, {
    required bool ordered,
  }) {
    final rows = (c['items'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => (e['text'] ?? '').toString())
        .where((t) => t.trim().isNotEmpty)
        .toList();
    if (rows.isEmpty) return [pw.Text('(empty)')];
    // One bare Text per row (a Padding wrapper can't split), so a long list
    // page-breaks between rows and a very long row splits within itself.
    return [
      for (var i = 0; i < rows.length; i++) ...[
        if (i > 0) pw.SizedBox(height: 2),
        _text(ordered ? '${i + 1}. ${rows[i]}' : '• ${rows[i]}'),
      ],
    ];
  }

  static List<pw.Widget> _checklist(Map<String, dynamic> c) {
    final items = (c['items'] as List? ?? const []).whereType<Map>().toList();
    if (items.isEmpty) return [pw.Text('(empty)')];
    return [
      for (final it in items)
        _text(
          '${(it['checked'] ?? false) == true ? '☑' : '☐'}  '
          '${(it['text'] ?? '').toString()}',
        ),
    ];
  }

  static List<pw.Widget> _cards(Map<String, dynamic> c) {
    final items = (c['items'] as List? ?? const []).whereType<Map>().toList();
    if (items.isEmpty) return [pw.Text('(empty)')];
    // Bare Texts per card, not a bordered Container: a Container can't split,
    // so one card with a long description overflowed the page. A thin rule
    // between cards keeps them visually separate.
    return [
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) pw.Divider(height: 10, thickness: 0.3),
        if ((items[i]['title'] ?? '').toString().isNotEmpty)
          _text(
            (items[i]['title']).toString(),
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        if ((items[i]['description'] ?? '').toString().isNotEmpty)
          _text((items[i]['description']).toString()),
      ],
    ];
  }

  static pw.Widget _table(Map<String, dynamic> c) {
    final columns = (c['columns'] as List? ?? const [])
        .map((e) => (e ?? '').toString())
        .toList();
    final rows = (c['rows'] as List? ?? const [])
        .map(
          (r) => r is List
              ? r.map((e) => (e ?? '').toString()).toList()
              : <String>[],
        )
        .toList();
    if (columns.isEmpty && rows.isEmpty) return pw.Text('(empty)');
    return pw.TableHelper.fromTextArray(
      headers: columns.isEmpty ? null : columns,
      data: rows,
    );
  }

  static pw.Widget _drawing(Map<String, dynamic> c) {
    final strokes = c['strokes'] as List? ?? const [];
    if (strokes.isEmpty) return pw.Text('(empty drawing)');
    final logical = drawLogicalSize(c['orientation']);
    final scale = 360 / max(logical.width, logical.height);
    return pw.SizedBox(
      width: logical.width * scale,
      height: logical.height * scale,
      child: pw.SvgImage(svg: _drawSvg(strokes, logical)),
    );
  }

  static String _drawSvg(List<dynamic> strokes, Size logical) {
    final w = logical.width.toInt();
    final h = logical.height.toInt();
    final buffer = StringBuffer(
      '<svg viewBox="0 0 $w $h" xmlns="http://www.w3.org/2000/svg">'
      '<rect width="$w" height="$h" fill="white"/>',
    );
    for (final s in strokes) {
      if (s is! Map) continue;
      final pts = s['points'] as List? ?? const [];
      if (pts.isEmpty) continue;
      final color = (s['color'] ?? '#1e293b').toString();
      final size = (s['size'] as num?)?.toDouble() ?? 8;
      final d = StringBuffer();
      var started = false;
      for (final p in pts) {
        if (p is! List || p.length < 2) continue;
        final x = (p[0] as num).toDouble();
        final y = (p[1] as num).toDouble();
        d.write(started ? ' L $x $y' : 'M $x $y');
        started = true;
      }
      buffer.write(
        '<path d="$d" stroke="$color" stroke-width="$size" '
        'fill="none" stroke-linecap="round" stroke-linejoin="round"/>',
      );
    }
    buffer.write('</svg>');
    return buffer.toString();
  }
}
