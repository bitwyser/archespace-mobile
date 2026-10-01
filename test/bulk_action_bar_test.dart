import 'package:archespace_mobile/src/shared/widgets/bulk_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the count, runs actions, marks deletes red, clears', (
    tester,
  ) async {
    var archived = 0;
    var cleared = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: BulkActionBar(
            count: 3,
            onClear: () => cleared++,
            actions: [
              BulkAction(
                icon: Icons.archive_outlined,
                label: 'Archive',
                onPressed: () => archived++,
              ),
              BulkAction(
                icon: Icons.delete_outline,
                label: 'Delete',
                onPressed: () {},
                destructive: true,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('3 selected'), findsOneWidget);
    await tester.tap(find.byTooltip('Archive'));
    expect(archived, 1);

    final context = tester.element(find.byType(BulkActionBar));
    final delete = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.delete_outline),
        matching: find.byType(IconButton),
      ),
    );
    expect(delete.color, Theme.of(context).colorScheme.error);

    await tester.tap(find.byTooltip('Clear selection'));
    expect(cleared, 1);
  });
}
