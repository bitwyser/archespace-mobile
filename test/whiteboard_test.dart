import 'package:flutter_test/flutter_test.dart';

import 'package:archespace_mobile/src/features/items/domain/space_item.dart';
import 'package:archespace_mobile/src/features/items/domain/whiteboard.dart';
import 'package:archespace_mobile/src/shared/export/pdf_exporter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A 1x1 PNG, standing in for the preview the board saves.
  const png =
      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

  test('reads boards, old drawings and their previews', () {
    final board = {
      'elements': [
        {'id': 'a', 'type': 'rectangle'},
      ],
      'files': <String, dynamic>{},
      'background': '#ffffff',
      'preview': png,
    };
    expect(isLegacyBoard(board), isFalse);
    expect(hasBoardContent(board), isTrue);
    expect(boardPreviewBytes(board), isNotNull);

    final legacy = {
      'strokes': [
        {
          'points': [
            [1, 2, 0.5],
          ],
        },
      ],
    };
    expect(isLegacyBoard(legacy), isTrue);
    expect(hasBoardContent(legacy), isTrue);
    expect(boardPreviewBytes(legacy), isNull);

    expect(hasBoardContent({'elements': <dynamic>[]}), isFalse);
    expect(
      hasBoardContent({
        'elements': [
          {'isDeleted': true},
        ],
      }),
      isFalse,
    );
    expect(boardPreviewBytes({'elements': [], 'preview': 'nope'}), isNull);
  });

  test('exports a whiteboard with its preview', () async {
    final bytes = await PdfExporter.buildItem(
      SpaceItem(
        id: 'w',
        type: 'whiteboard',
        title: 'Board',
        content: {
          'elements': [
            {'id': 'a', 'type': 'rectangle'},
          ],
          'preview': png,
        },
        pinned: false,
      ),
    );
    expect(bytes, isNotEmpty);
  });
}
