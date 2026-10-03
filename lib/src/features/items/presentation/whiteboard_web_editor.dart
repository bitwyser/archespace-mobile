import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Lets the item editor collect the board's last edit before it saves.
class WhiteboardController {
  Future<void> Function()? _flush;

  /// Send any edit the board hasn't reported yet (waits a few seconds at most).
  Future<void> flush() async => _flush?.call();
}

/// The Whiteboard editor: the web app's Excalidraw board, bundled offline into
/// `assets/whiteboard_editor.html` (built from the web repo with
/// `npm run build:mobile-editor`), filling the screen in a WebView. Both
/// platforms therefore save the same content (see domain/whiteboard.dart).
///
/// [onChanged] receives the new content, with a fresh preview, a moment after
/// each edit, and once on open when an old drawing was converted.
class WhiteboardWebEditor extends StatefulWidget {
  const WhiteboardWebEditor({
    super.key,
    required this.content,
    required this.onChanged,
    this.controller,
    this.readOnly = false,
  });

  final Map<String, dynamic> content;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final WhiteboardController? controller;
  final bool readOnly;

  @override
  State<WhiteboardWebEditor> createState() => _WhiteboardWebEditorState();
}

class _WhiteboardWebEditorState extends State<WhiteboardWebEditor> {
  late final WebViewController _web;
  bool _ready = false;
  bool _pageLoaded = false;
  Completer<void>? _flushed;

  @override
  void initState() {
    super.initState();
    widget.controller?._flush = _flush;
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // The board is always light (a white canvas), whatever the app theme.
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          // Only the bundled board loads; anything else (a tapped link) is
          // blocked. The page's own CSP also blocks the network.
          onNavigationRequest: (request) {
            if (_pageLoaded) return NavigationDecision.prevent;
            _pageLoaded = true;
            return NavigationDecision.navigate;
          },
        ),
      )
      ..addJavaScriptChannel('Arche', onMessageReceived: _onMessage)
      ..loadFlutterAsset('assets/whiteboard_editor.html');
  }

  @override
  void dispose() {
    if (widget.controller?._flush == _flush) widget.controller?._flush = null;
    super.dispose();
  }

  Future<void> _call(String js) async {
    try {
      await _web.runJavaScript(js);
    } catch (_) {
      // Page not ready or torn down: ignore.
    }
  }

  void _onMessage(JavaScriptMessage message) {
    final msg = jsonDecode(message.message);
    if (msg is! Map) return;
    switch (msg['type']) {
      case 'ready':
        _call(
          'whiteboardApi.load(${jsonEncode({'content': widget.content, 'editable': !widget.readOnly})})',
        );
        if (mounted) setState(() => _ready = true);
      case 'change':
        final content = msg['content'];
        if (content is Map) widget.onChanged(content.cast<String, dynamic>());
      case 'flushed':
        _flushed?.complete();
        _flushed = null;
    }
  }

  Future<void> _flush() async {
    if (!_ready || widget.readOnly) return;
    final done = _flushed ??= Completer<void>();
    await _call('whiteboardApi.flush()');
    await done.future.timeout(const Duration(seconds: 5), onTimeout: () {});
  }

  @override
  Widget build(BuildContext context) {
    // Framed like the card's preview: rounded, with a thin border.
    final radius = BorderRadius.circular(12);
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            WebViewWidget(controller: _web),
            if (!_ready) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
