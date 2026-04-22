import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('example cycles to the next tab', (tester) async {
    await tester.pumpWidget(const ExampleApp());

    expect(find.text('Overview'), findsNWidgets(2));
    expect(
      find.text('Metrics highlights the numbers that matter right now.'),
      findsNothing,
    );

    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Metrics'), findsNWidgets(2));
    expect(
      find.text('Metrics highlights the numbers that matter right now.'),
      findsOneWidget,
    );
  });
}
