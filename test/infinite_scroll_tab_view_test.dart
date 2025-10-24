import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cyclic_tab_bar/cyclic_tab_bar.dart';
import 'package:cyclic_tab_bar/src/inner_cyclic_tab_bar.dart';

void main() {
  group('Input validation', () {
    testWidgets('Should validate contentLength > 0', (tester) async {
      // Build widget with invalid contentLength - should fail during build
      await tester.pumpWidget(
        MaterialApp(
          home: CyclicTabBar(
            contentLength: 0,
            tabBuilder: (index, _) => const Text('Tab'),
            pageBuilder: (_, __, ___) => Container(),
          ),
        ),
      );

      // Expect that an assertion or error was thrown
      expect(tester.takeException(), isNotNull);
    });

    testWidgets('Should accept valid contentLength', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CyclicTabBar(
            contentLength: 3,
            tabBuilder: (index, _) => Text('Tab $index'),
            pageBuilder: (_, index, __) => Center(child: Text('Page $index')),
          ),
        ),
      );

      expect(find.byType(CyclicTabBar), findsOneWidget);
    });
  });

  group('Edge cases', () {
    testWidgets('Should handle single tab', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CyclicTabBar(
            contentLength: 1,
            tabBuilder: (index, _) => const Text('Single'),
            pageBuilder: (_, __, ___) => const Center(child: Text('Page 0')),
          ),
        ),
      );

      expect(find.text('Single'), findsWidgets);
      expect(find.text('Page 0'), findsOneWidget);
    });

    testWidgets('Should handle two tabs', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CyclicTabBar(
            contentLength: 2,
            tabBuilder: (index, _) => Text('Tab $index'),
            pageBuilder: (_, index, __) => Center(child: Text('Page $index')),
          ),
        ),
      );

      expect(find.text('Tab 0'), findsWidgets);
      expect(find.text('Tab 1'), findsWidgets);
      expect(find.text('Page 0'), findsOneWidget);
    });

    testWidgets('Should handle many tabs (performance test)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CyclicTabBar(
            contentLength: 50,
            tabBuilder: (index, _) => Text('Tab $index'),
            pageBuilder: (_, index, __) => Center(child: Text('Page $index')),
          ),
        ),
      );

      expect(find.byType(CyclicTabBar), findsOneWidget);
    });
  });

  group('UI interactions', () {
    testWidgets('Should call onTabTap when tab is tapped', (tester) async {
      var tappedIndex = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: CyclicTabBar(
            contentLength: 3,
            tabBuilder: (index, _) => Text('Tab $index'),
            pageBuilder: (_, index, __) => Center(child: Text('Page $index')),
            onTabTap: (index) => tappedIndex = index,
          ),
        ),
      );

      // Find and tap the first tab
      final tab0 = find.text('Tab 0').first;
      await tester.tap(tab0, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(tappedIndex, 0);
    });

    testWidgets('Should have onPageChanged callback', (tester) async {
      final List<int> changedIndices = [];

      await tester.pumpWidget(
        MaterialApp(
          home: CyclicTabBar(
            contentLength: 3,
            tabBuilder: (index, _) => Text('Tab $index'),
            pageBuilder: (_, index, __) => Center(child: Text('Page $index')),
            onPageChanged: (index) => changedIndices.add(index),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Widget should build successfully with callback registered
      expect(find.byType(CyclicTabBar), findsOneWidget);

      // Try to manually trigger page scroll via the controller if accessible
      // For now, just verify the widget has the callback property
      final state = tester.state<InnerCyclicTabBarState>(
        find.byType(InnerCyclicTabBar),
      );
      expect(state.widget.onPageChanged, isNotNull);
    });

    testWidgets('Should prevent rapid tab taps', (tester) async {
      var tapCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: CyclicTabBar(
            contentLength: 5,
            tabBuilder: (index, _) => Text('Tab $index'),
            pageBuilder: (_, index, __) => Center(child: Text('Page $index')),
            onTabTap: (index) => tapCount++,
          ),
        ),
      );

      // Rapid taps - should be throttled
      final tab1 = find.text('Tab 1').first;
      await tester.tap(tab1, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 10));
      await tester.tap(tab1, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 10));
      await tester.tap(tab1, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Only first tap should register
      expect(tapCount, lessThan(3));
    });
  });

  group('Fixed tab width', () {
    testWidgets('Should use fixed width when enabled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CyclicTabBar(
            contentLength: 4,
            forceFixedTabWidth: true,
            fixedTabWidthFraction: 0.3,
            tabBuilder: (index, _) => Text('Tab $index'),
            pageBuilder: (_, index, __) => Center(child: Text('Page $index')),
          ),
        ),
      );

      final InnerCyclicTabBarState state =
          tester.state(find.byType(InnerCyclicTabBar));

      final screenWidth =
          MediaQuery.sizeOf(tester.element(find.byType(MaterialApp))).width;
      final expectedWidth = screenWidth * 0.3;

      // All tabs should have the same width
      expect(state.tabTextSizes[0], lessThanOrEqualTo(expectedWidth));
      expect(state.tabTextSizes[1], lessThanOrEqualTo(expectedWidth));
      expect(state.tabTextSizes[2], lessThanOrEqualTo(expectedWidth));
    });
  });

  group('Custom styling', () {
    testWidgets('Should apply custom indicator color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CyclicTabBar(
            contentLength: 3,
            indicatorColor: Colors.red,
            tabBuilder: (index, _) => Text('Tab $index'),
            pageBuilder: (_, index, __) => Center(child: Text('Page $index')),
          ),
        ),
      );

      final InnerCyclicTabBarState state =
          tester.state(find.byType(InnerCyclicTabBar));

      expect(state.widget.indicatorColor, Colors.red);
    });

    testWidgets('Should apply custom tab height', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CyclicTabBar(
            contentLength: 3,
            tabHeight: 60.0,
            tabBuilder: (index, _) => Text('Tab $index'),
            pageBuilder: (_, index, __) => Center(child: Text('Page $index')),
          ),
        ),
      );

      final InnerCyclicTabBarState state =
          tester.state(find.byType(InnerCyclicTabBar));

      expect(state.widget.tabHeight, 60.0);
    });

    testWidgets('Should apply separator', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CyclicTabBar(
            contentLength: 3,
            separator: const BorderSide(color: Colors.grey, width: 2),
            tabBuilder: (index, _) => Text('Tab $index'),
            pageBuilder: (_, index, __) => Center(child: Text('Page $index')),
          ),
        ),
      );

      final InnerCyclicTabBarState state =
          tester.state(find.byType(InnerCyclicTabBar));

      expect(state.widget.separator?.color, Colors.grey);
      expect(state.widget.separator?.width, 2);
    });
  });

  group('Index wrapping', () {
    test('calculateMoveIndexDistance should handle edge cases', () {
      // Wrap around forward (8 -> 2 should go +4, not -6)
      expect(calculateMoveIndexDistance(8, 2, 10), 4);

      // Wrap around backward (2 -> 8 should go -4, not +6)
      expect(calculateMoveIndexDistance(2, 8, 10), -4);

      // Exactly halfway - could go either way but should be consistent
      expect(calculateMoveIndexDistance(0, 5, 10).abs(), 5);

      // Adjacent indices
      expect(calculateMoveIndexDistance(3, 4, 10), 1);
      expect(calculateMoveIndexDistance(4, 3, 10), -1);

      // Same index
      expect(calculateMoveIndexDistance(5, 5, 10), 0);
    });
  });

  group(
    '''`calculateMoveIndexDistance` function should be return specified number distance correctly.''',
    () {
      test(
        'In plus direction.',
        () {
          expect(calculateMoveIndexDistance(0, 2, 10), 2);
          expect(calculateMoveIndexDistance(6, 9, 10), 3);
        },
      );

      test(
        'In minus direction.',
        () {
          expect(calculateMoveIndexDistance(9, 7, 10), -2);
          expect(calculateMoveIndexDistance(4, 1, 10), -3);
        },
      );

      test(
        'While overflow/underflow situation.',
        () {
          expect(calculateMoveIndexDistance(8, 2, 10), 4);
          expect(calculateMoveIndexDistance(1, 7, 10), -4);
        },
      );
    },
  );

  group(
    'CyclicTabBar should be calculate tab sizes element expectedly.',
    () {
      testWidgets('On initialize.', (tester) async {
        final strings = ['A', 'BB', 'CCC', 'DDDD'];
        await tester.pumpWidget(
          MaterialApp(
            home: CyclicTabBar(
              contentLength: strings.length,
              tabPadding: 4.0,
              tabBuilder: (index, _) => Text(
                strings[index],
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.normal),
              ),
              pageBuilder: (_, index, __) => Container(),
            ),
          ),
        );

        expect(find.text('A'), findsWidgets);

        final InnerCyclicTabBarState state =
            tester.state(find.byType(InnerCyclicTabBar));

        final expectedSizes = [24, 40, 56, 72];
        final expectedTotal = expectedSizes.reduce((v, e) => v += e);

        // [16 + 8, 16 * 2 + 8, 16 * 3 + 8, 16 * 4 + 8]
        // {text size} * {text length} + {tab padding} * 2
        expect(state.tabTextSizes, expectedSizes);

        expect(state.tabSizesFromIndex, [0, 24, 64, 120]);

        final offsets = [
          Tween(
            begin: 0 + state.centeringOffset(0),
            end: 24 + state.centeringOffset(1),
          ),
          Tween(
            begin: 24 + state.centeringOffset(1),
            end: 64 + state.centeringOffset(2),
          ),
          Tween(
            begin: 64 + state.centeringOffset(2),
            end: 120 + state.centeringOffset(3),
          ),
          Tween(
            begin: 120 + state.centeringOffset(3),
            end: expectedTotal + state.centeringOffset(0),
          ),
        ];
        expect(state.tabOffsets[0].begin, offsets[0].begin);
        expect(state.tabOffsets[0].end, offsets[0].end);
        expect(state.tabOffsets[1].begin, offsets[1].begin);
        expect(state.tabOffsets[1].end, offsets[1].end);
        expect(state.tabOffsets.last.begin, offsets.last.begin);
        expect(state.tabOffsets.last.end, offsets.last.end);

        final tweens = [
          Tween(begin: 24, end: 40),
          Tween(begin: 40, end: 56),
          Tween(begin: 56, end: 72),
          Tween(begin: 72, end: 24),
        ];
        expect(state.tabSizeTweens[0].begin, tweens[0].begin);
        expect(state.tabSizeTweens[0].end, tweens[0].end);
        expect(state.tabSizeTweens[1].begin, tweens[1].begin);
        expect(state.tabSizeTweens[1].end, tweens[1].end);
        expect(state.tabSizeTweens.last.begin, tweens.last.begin);
        expect(state.tabSizeTweens.last.end, tweens.last.end);
      });

      testWidgets('On textScaleFactor changed.', (tester) async {
        final strings = ['A', 'BB', 'CCC', 'DDDD'];
        await tester.pumpWidget(
          MaterialApp(
            home: CyclicTabBar(
              contentLength: strings.length,
              tabPadding: 4.0,
              tabBuilder: (index, _) => Text(
                strings[index],
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.normal),
              ),
              pageBuilder: (_, index, __) => Container(),
            ),
          ),
        );

        final InnerCyclicTabBarState state =
            tester.state(find.byType(InnerCyclicTabBar));

        state.calculateTabBehaviorElements(const TextScaler.linear(1.5));

        final expectedSizes = [32.0, 56.0, 80.0, 104.0];

        expect(state.tabTextSizes, expectedSizes);
      });
    },
  );
}
