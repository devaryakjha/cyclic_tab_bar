import 'package:example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('example switches content when a tab is tapped', (tester) async {
    await tester.pumpWidget(const ExampleApp());

    expect(find.text('Baseline source copy of Flutter tabs.'), findsOneWidget);
    expect(find.text('Interaction currently matches Flutter exactly.'), findsNothing);

    await tester.tap(find.text('Metrics'));
    await tester.pumpAndSettle();

    expect(find.text('Interaction currently matches Flutter exactly.'), findsOneWidget);
  });
}
