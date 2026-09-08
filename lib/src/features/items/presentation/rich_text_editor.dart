import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:archespace_mobile/src/features/items/domain/rich_text_html.dart';

/// A [TextEditingController] that carries per-character formatting (bold,
/// italic, underline, font size) alongside the plain text, renders it as styled
/// spans, and serialises to the same sanitised HTML subset the web app stores.
///
/// The formatting buffer ([_attrs]) is kept the same length as [text] by
/// diffing each edit (common prefix/suffix), so inserted characters inherit the
/// pending "typing" style and deletions drop the right attributes.
class RichTextEditingController extends TextEditingController {
  RichTextEditingController.fromHtml(String? html) {
    final spans = parseRichHtml(html);
    final buf = StringBuffer();
    final attrs = <CharAttr>[];
    for (final s in spans) {
      buf.write(s.text);
      for (var i = 0; i < s.text.length; i++) {
        attrs.add(
          CharAttr(
            bold: s.bold,
            italic: s.italic,
            underline: s.underline,
            size: s.size,
          ),
        );
      }
    }
    _attrs = attrs;
    // Bypass our own value setter so the parsed attrs are not overwritten.
    final text = buf.toString();
    super.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  List<CharAttr> _attrs = [];
  CharAttr _typing = const CharAttr();

  @override
  set value(TextEditingValue newValue) {
    final oldText = text;
    final oldSelection = selection;
    _syncAttrs(oldText, newValue.text);
    super.value = newValue;
    // On a pure caret move, adopt the style of the neighbouring character so
    // the next typed character matches its surroundings.
    if (oldText == newValue.text &&
        oldSelection != newValue.selection &&
        newValue.selection.isCollapsed) {
      final off = newValue.selection.baseOffset;
      if (off > 0 && off <= _attrs.length) {
        _typing = _attrs[off - 1];
      } else if (off == 0 && _attrs.isNotEmpty) {
        _typing = _attrs[0];
      }
    }
  }

  void _syncAttrs(String oldText, String newText) {
    if (oldText == newText) {
      _fixLength(newText.length);
      return;
    }
    final minLen = math.min(oldText.length, newText.length);
    var p = 0;
    while (p < minLen && oldText[p] == newText[p]) {
      p++;
    }
    var s = 0;
    while (s < minLen - p &&
        oldText[oldText.length - 1 - s] == newText[newText.length - 1 - s]) {
      s++;
    }
    final removed = oldText.length - p - s;
    final inserted = newText.length - p - s;
    _fixLength(oldText.length);
    final next = <CharAttr>[
      ..._attrs.take(p),
      for (var k = 0; k < inserted; k++) _typing,
      ..._attrs.skip(p + removed),
    ];
    _attrs = next;
    _fixLength(newText.length);
  }

  void _fixLength(int len) {
    if (_attrs.length == len) return;
    if (_attrs.length > len) {
      _attrs = _attrs.sublist(0, len);
    } else {
      _attrs = [
        ..._attrs,
        for (var k = _attrs.length; k < len; k++) const CharAttr(),
      ];
    }
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final t = text;
    _fixLength(t.length);
    final children = <InlineSpan>[];
    var i = 0;
    while (i < t.length) {
      var j = i + 1;
      while (j < t.length && _attrs[j].same(_attrs[i])) {
        j++;
      }
      final a = _attrs[i];
      children.add(
        TextSpan(
          text: t.substring(i, j),
          style: TextStyle(
            fontWeight: a.bold ? FontWeight.bold : null,
            fontStyle: a.italic ? FontStyle.italic : null,
            decoration: a.underline ? TextDecoration.underline : null,
            fontSize: fontSizeForLevel(a.size),
          ),
        ),
      );
      i = j;
    }
    return TextSpan(style: style, children: children);
  }

  // ── Formatting commands (driven by the toolbar) ────────────

  ({int start, int end}) get _targetRange {
    final sel = selection;
    if (sel.isValid && !sel.isCollapsed) {
      return (start: sel.start, end: sel.end);
    }
    return (start: 0, end: text.length); // whole content when nothing selected
  }

  bool _allInRange(int start, int end, bool Function(CharAttr) test) {
    if (start >= end) return false;
    for (var k = start; k < end && k < _attrs.length; k++) {
      if (!test(_attrs[k])) return false;
    }
    return true;
  }

  void _toggle(
    bool Function(CharAttr) get,
    CharAttr Function(CharAttr, bool) set,
  ) {
    final sel = selection;
    if (sel.isValid && !sel.isCollapsed) {
      final on = !_allInRange(sel.start, sel.end, get);
      for (var k = sel.start; k < sel.end && k < _attrs.length; k++) {
        _attrs[k] = set(_attrs[k], on);
      }
      notifyListeners();
    } else {
      _typing = set(_typing, !get(_typing));
      notifyListeners();
    }
  }

  void toggleBold() => _toggle((a) => a.bold, (a, v) => a.copyWith(bold: v));
  void toggleItalic() =>
      _toggle((a) => a.italic, (a, v) => a.copyWith(italic: v));
  void toggleUnderline() =>
      _toggle((a) => a.underline, (a, v) => a.copyWith(underline: v));

  /// Step the font size. With no selection it applies to the whole content
  /// (matching the web), so the buttons work without selecting first.
  void changeFontSize(int delta) {
    final r = _targetRange;
    int clampLevel(int n) => n.clamp(kMinFontLevel, kMaxFontLevel);
    if (r.start >= r.end) {
      _typing = _typing.copyWith(size: clampLevel(_typing.size + delta));
      notifyListeners();
      return;
    }
    for (var k = r.start; k < r.end && k < _attrs.length; k++) {
      _attrs[k] = _attrs[k].copyWith(size: clampLevel(_attrs[k].size + delta));
    }
    _typing = _typing.copyWith(size: clampLevel(_typing.size + delta));
    notifyListeners();
  }

  void clearFormatting() {
    final r = _targetRange;
    for (var k = r.start; k < r.end && k < _attrs.length; k++) {
      _attrs[k] = const CharAttr();
    }
    _typing = const CharAttr();
    notifyListeners();
  }

  // ── Toolbar active states ──────────────────────────────────

  bool get boldActive {
    final sel = selection;
    if (sel.isValid && !sel.isCollapsed) {
      return _allInRange(sel.start, sel.end, (a) => a.bold);
    }
    return _typing.bold;
  }

  bool get italicActive {
    final sel = selection;
    if (sel.isValid && !sel.isCollapsed) {
      return _allInRange(sel.start, sel.end, (a) => a.italic);
    }
    return _typing.italic;
  }

  bool get underlineActive {
    final sel = selection;
    if (sel.isValid && !sel.isCollapsed) {
      return _allInRange(sel.start, sel.end, (a) => a.underline);
    }
    return _typing.underline;
  }

  /// Current HTML for `{ html }` storage.
  String toHtml() {
    final t = text;
    _fixLength(t.length);
    final spans = <RichSpan>[];
    var i = 0;
    while (i < t.length) {
      var j = i + 1;
      while (j < t.length && _attrs[j].same(_attrs[i])) {
        j++;
      }
      final a = _attrs[i];
      spans.add(
        RichSpan(
          t.substring(i, j),
          bold: a.bold,
          italic: a.italic,
          underline: a.underline,
          size: a.size,
        ),
      );
      i = j;
    }
    return richSpansToHtml(spans);
  }
}

/// Rich Text editor: a formatting toolbar over a styled multiline field.
/// Writes the serialised HTML into `content['html']` on every change.
class RichTextEditorField extends StatefulWidget {
  const RichTextEditorField({super.key, required this.content});

  final Map<String, dynamic> content;

  @override
  State<RichTextEditorField> createState() => _RichTextEditorFieldState();
}

class _RichTextEditorFieldState extends State<RichTextEditorField> {
  late final RichTextEditingController _controller =
      RichTextEditingController.fromHtml(
        (widget.content['html'] ?? '').toString(),
      );

  @override
  void initState() {
    super.initState();
    _controller.addListener(_persist);
  }

  void _persist() => widget.content['html'] = _controller.toHtml();

  @override
  void dispose() {
    _controller.removeListener(_persist);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => _Toolbar(controller: _controller),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: TextField(
            controller: _controller,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              hintText: 'Start writing…',
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.controller});

  final RichTextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget btn(
      IconData icon,
      String tooltip,
      VoidCallback onTap, {
      bool active = false,
    }) {
      return IconButton(
        icon: Icon(icon, size: 20),
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        isSelected: active,
        color: active ? scheme.primary : scheme.onSurfaceVariant,
        onPressed: onTap,
      );
    }

    Widget divider() => Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: scheme.outlineVariant,
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          btn(
            Icons.format_bold,
            'Bold',
            controller.toggleBold,
            active: controller.boldActive,
          ),
          btn(
            Icons.format_italic,
            'Italic',
            controller.toggleItalic,
            active: controller.italicActive,
          ),
          btn(
            Icons.format_underlined,
            'Underline',
            controller.toggleUnderline,
            active: controller.underlineActive,
          ),
          divider(),
          btn(
            Icons.text_increase,
            'Increase font size',
            () => controller.changeFontSize(1),
          ),
          btn(
            Icons.text_decrease,
            'Decrease font size',
            () => controller.changeFontSize(-1),
          ),
          divider(),
          btn(
            Icons.format_clear,
            'Clear formatting',
            controller.clearFormatting,
          ),
        ],
      ),
    );
  }
}
