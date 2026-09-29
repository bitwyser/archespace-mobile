import 'package:flutter_test/flutter_test.dart';

import 'package:archespace_mobile/src/features/items/domain/space_item.dart';
import 'package:archespace_mobile/src/shared/export/pdf_exporter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Text far taller than one page, placed in item types whose blocks used to
  // be unsplittable (a bordered card, a padded list row). The export must
  // page-break through them instead of throwing "Widget won't fit into the
  // page".
  final longText = List.filled(
    400,
    'A long line of text that keeps on going.',
  ).join(' ');

  SpaceItem item(String type, Map<String, dynamic> content) => SpaceItem(
    id: type,
    type: type,
    title: type,
    content: content,
    pinned: false,
  );

  test('exports a space whose items are taller than a page', () async {
    final bytes = await PdfExporter.buildSpace('Overflow', [
      item('card_list', {
        'items': [
          {'title': 'Card', 'description': longText},
        ],
      }),
      item('menu_list', {
        'items': [
          {'text': longText},
        ],
      }),
      item('numbered_list', {
        'items': [
          {'text': longText},
        ],
      }),
      item('checkbox_list', {
        'items': [
          {'text': longText, 'checked': false},
        ],
      }),
      item('textbox', {'text': longText}),
      item('code', {'code': longText}),
    ]);
    expect(bytes, isNotEmpty);
  });

  test('exports a single over-long card item', () async {
    final bytes = await PdfExporter.buildItem(
      item('card_list', {
        'items': [
          {'title': 'Card', 'description': longText},
        ],
      }),
    );
    expect(bytes, isNotEmpty);
  });
}
