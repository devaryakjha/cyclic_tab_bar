import 'package:cyclic_tab_bar/cyclic_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizeCyclicIndex wraps positive and negative indexes', () {
    expect(normalizeCyclicIndex(0, 3), 0);
    expect(normalizeCyclicIndex(4, 3), 1);
    expect(normalizeCyclicIndex(-1, 3), 2);
  });

  test('normalizeCyclicIndex rejects empty collections', () {
    expect(() => normalizeCyclicIndex(0, 0), throwsA(isA<ArgumentError>()));
  });

  testWidgets('CyclicTabBar emits wrapped indexes from cycle buttons', (
    tester,
  ) async {
    int? tappedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CyclicTabBar(
            labels: const ['Home', 'Explore', 'Profile'],
            currentIndex: 0,
            onIndexChanged: (index) => tappedIndex = index,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    expect(tappedIndex, 2);

    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    expect(tappedIndex, 1);
  });
}
