import 'dart:convert';
import 'dart:typed_data';

/// The Whiteboard item's content (mirrors the web `src/lib/whiteboard/scene.js`):
/// an Excalidraw scene, `{ elements, files, background, preview }`, edited in
/// the WebView editor. `preview` is a PNG data URL of the board, made on each
/// save, so cards and PDFs show it without the editor.
///
/// A board made before Excalidraw (the old Drawing, `{ strokes }`) has no
/// preview yet; it converts the first time it opens.

/// A board saved before Excalidraw: freehand strokes only.
bool isLegacyBoard(Map<String, dynamic> content) =>
    content['elements'] is! List && content['strokes'] is List;

/// Whether the board has anything on it.
bool hasBoardContent(Map<String, dynamic> content) {
  if (isLegacyBoard(content)) return (content['strokes'] as List).isNotEmpty;
  final elements = content['elements'];
  return elements is List &&
      elements.any((e) => e is Map && e['isDeleted'] != true);
}

/// The saved preview as PNG bytes, or null when there is none.
Uint8List? boardPreviewBytes(Map<String, dynamic> content) {
  const prefix = 'data:image/png;base64,';
  final preview = content['preview'];
  if (isLegacyBoard(content) ||
      preview is! String ||
      !preview.startsWith(prefix)) {
    return null;
  }
  try {
    return base64Decode(preview.substring(prefix.length));
  } on FormatException {
    return null;
  }
}
