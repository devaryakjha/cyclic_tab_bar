import 'package:example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('example switches content when a tab is tapped', (tester) async {
    await tester.pumpWidget(const ExampleApp());

    expect(
      find.text('Source-synced Flutter tabs with package-owned edge cycling.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Pull either edge of the scrollable tab strip to reveal the next cycle.',
      ),
      findsNothing,
    );

    await tester.tap(find.text('Metrics'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Pull either edge of the scrollable tab strip to reveal the next cycle.',
      ),
      findsOneWidget,
    );
  });
}
