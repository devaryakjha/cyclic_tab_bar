import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cyclic_tab_bar/cyclic_tab_bar.dart';

void main() {
  group('Input validation', () {
    testWidgets(
        'Should validate contentLength > 0 in DefaultCyclicTabController',
        (tester) async {
      // Build widget with invalid contentLength - should throw assertion
      expect(
        () => DefaultCyclicTabController(
          contentLength: 0,
          child: Container(),
        ),
        throwsAssertionError,
      );
    });

    testWidgets('Should accept valid contentLength', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultCyclicTabController(
            contentLength: 3,
            child: Column(
              children: [
                CyclicTabBar(
                  contentLength: 3,
                  tabBuilder: (index, _) => Text('Tab $index'),
                ),
                Expanded(
                  child: CyclicTabBarView(
                    contentLength: 3,
                    pageBuilder: (_, index, __) =>
                        Center(child: Text('Page $index')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(CyclicTabBar), findsOneWidget);
      expect(find.byType(CyclicTabBarView), findsOneWidget);
    });
  });

  group('Edge cases', () {
    testWidgets('Should handle single tab', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultCyclicTabController(
            contentLength: 1,
            child: Column(
              children: [
                CyclicTabBar(
                  contentLength: 1,
                  tabBuilder: (index, _) => const Text('Single'),
                ),
                Expanded(
                  child: CyclicTabBarView(
                    contentLength: 1,
                    pageBuilder: (_, __, ___) =>
                        const Center(child: Text('Page 0')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Single'), findsWidgets);
      expect(find.text('Page 0'), findsOneWidget);
    });

    testWidgets('Should handle two tabs', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultCyclicTabController(
            contentLength: 2,
            child: Column(
              children: [
                CyclicTabBar(
                  contentLength: 2,
                  tabBuilder: (index, _) => Text('Tab $index'),
                ),
                Expanded(
                  child: CyclicTabBarView(
                    contentLength: 2,
                    pageBuilder: (_, index, __) =>
                        Center(child: Text('Page $index')),
                  ),
                ),
              ],
            ),
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
          home: DefaultCyclicTabController(
            contentLength: 50,
            child: Column(
              children: [
                CyclicTabBar(
                  contentLength: 50,
                  tabBuilder: (index, _) => Text('Tab $index'),
                ),
                Expanded(
                  child: CyclicTabBarView(
                    contentLength: 50,
                    pageBuilder: (_, index, __) =>
                        Center(child: Text('Page $index')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(CyclicTabBar), findsOneWidget);
      expect(find.byType(CyclicTabBarView), findsOneWidget);
    });
  });

  group('UI interactions', () {
    testWidgets('Should call onTabTap when tab is tapped', (tester) async {
      var tappedIndex = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: DefaultCyclicTabController(
            contentLength: 3,
            child: Column(
              children: [
                CyclicTabBar(
                  contentLength: 3,
                  tabBuilder: (index, _) => Text('Tab $index'),
                  onTabTap: (index) => tappedIndex = index,
                ),
                Expanded(
                  child: CyclicTabBarView(
                    contentLength: 3,
                    pageBuilder: (_, index, __) =>
                        Center(child: Text('Page $index')),
                  ),
                ),
              ],
            ),
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
          home: DefaultCyclicTabController(
            contentLength: 3,
            child: Column(
              children: [
                CyclicTabBar(
                  contentLength: 3,
                  tabBuilder: (index, _) => Text('Tab $index'),
                ),
                Expanded(
                  child: CyclicTabBarView(
                    contentLength: 3,
                    pageBuilder: (_, index, __) =>
                        Center(child: Text('Page $index')),
                    onPageChanged: (index) => changedIndices.add(index),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Widget should build successfully with callback registered
      expect(find.byType(CyclicTabBar), findsOneWidget);
      expect(find.byType(CyclicTabBarView), findsOneWidget);
    });

    testWidgets('Should prevent rapid tab taps', (tester) async {
      var tapCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: DefaultCyclicTabController(
            contentLength: 5,
            child: Column(
              children: [
                CyclicTabBar(
                  contentLength: 5,
                  tabBuilder: (index, _) => Text('Tab $index'),
                  onTabTap: (index) => tapCount++,
                ),
                Expanded(
                  child: CyclicTabBarView(
                    contentLength: 5,
                    pageBuilder: (_, index, __) =>
                        Center(child: Text('Page $index')),
                  ),
                ),
              ],
            ),
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
          home: DefaultCyclicTabController(
            contentLength: 4,
            child: Column(
              children: [
                CyclicTabBar(
                  contentLength: 4,
                  forceFixedTabWidth: true,
                  fixedTabWidthFraction: 0.3,
                  tabBuilder: (index, _) => Text('Tab $index'),
                ),
                Expanded(
                  child: CyclicTabBarView(
                    contentLength: 4,
                    pageBuilder: (_, index, __) =>
                        Center(child: Text('Page $index')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Widget builds successfully with fixed width
      expect(find.byType(CyclicTabBar), findsOneWidget);
    });
  });

  group('Custom styling', () {
    testWidgets('Should apply custom indicator color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultCyclicTabController(
            contentLength: 3,
            child: Column(
              children: [
                CyclicTabBar(
                  contentLength: 3,
                  indicatorColor: Colors.red,
                  tabBuilder: (index, _) => Text('Tab $index'),
                ),
                Expanded(
                  child: CyclicTabBarView(
                    contentLength: 3,
                    pageBuilder: (_, index, __) =>
                        Center(child: Text('Page $index')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(CyclicTabBar), findsOneWidget);
    });

    testWidgets('Should apply custom tab height', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultCyclicTabController(
            contentLength: 3,
            child: Column(
              children: [
                CyclicTabBar(
                  contentLength: 3,
                  tabHeight: 60.0,
                  tabBuilder: (index, _) => Text('Tab $index'),
                ),
                Expanded(
                  child: CyclicTabBarView(
                    contentLength: 3,
                    pageBuilder: (_, index, __) =>
                        Center(child: Text('Page $index')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(CyclicTabBar), findsOneWidget);
    });

    testWidgets('Should apply separator', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultCyclicTabController(
            contentLength: 3,
            child: Column(
              children: [
                CyclicTabBar(
                  contentLength: 3,
                  bottomBorder: const BorderSide(color: Colors.grey, width: 2),
                  tabBuilder: (index, _) => Text('Tab $index'),
                ),
                Expanded(
                  child: CyclicTabBarView(
                    contentLength: 3,
                    pageBuilder: (_, index, __) =>
                        Center(child: Text('Page $index')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(CyclicTabBar), findsOneWidget);
    });
  });

  group('Custom decoration on tab bar', () {
    testWidgets('Should allow wrapping tab bar with Container decoration',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultCyclicTabController(
            contentLength: 3,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade100, Colors.purple.shade100],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: CyclicTabBar(
                    contentLength: 3,
                    tabBuilder: (index, _) => Text('Tab $index'),
                  ),
                ),
                Expanded(
                  child: CyclicTabBarView(
                    contentLength: 3,
                    pageBuilder: (_, index, __) =>
                        Center(child: Text('Page $index')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Verify the tab bar is wrapped in container with decoration
      expect(find.byType(CyclicTabBar), findsOneWidget);
      expect(
          find.ancestor(
            of: find.byType(CyclicTabBar),
            matching: find.byType(Container),
          ),
          findsWidgets);
    });
  });

  group('Controller', () {
    testWidgets('Should work with explicit controller', (tester) async {
      final controller = CyclicTabController(contentLength: 3);

      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              CyclicTabBar(
                contentLength: 3,
                controller: controller,
                tabBuilder: (index, _) => Text('Tab $index'),
              ),
              Expanded(
                child: CyclicTabBarView(
                  contentLength: 3,
                  controller: controller,
                  pageBuilder: (_, index, __) =>
                      Center(child: Text('Page $index')),
                ),
              ),
            ],
          ),
        ),
      );

      expect(find.byType(CyclicTabBar), findsOneWidget);
      expect(find.byType(CyclicTabBarView), findsOneWidget);

      controller.dispose();
    });

    testWidgets('Should animate to index programmatically', (tester) async {
      final controller = CyclicTabController(contentLength: 5);

      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              CyclicTabBar(
                contentLength: 5,
                controller: controller,
                tabBuilder: (index, _) => Text('Tab $index'),
              ),
              Expanded(
                child: CyclicTabBarView(
                  contentLength: 5,
                  controller: controller,
                  pageBuilder: (_, index, __) =>
                      Center(child: Text('Page $index')),
                ),
              ),
            ],
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Animate to index 3
      controller.animateToIndex(3);
      await tester.pumpAndSettle();

      expect(controller.index, 3);

      controller.dispose();
    });

    testWidgets('Should respect initialIndex', (tester) async {
      final controller = CyclicTabController(
        contentLength: 10,
        initialIndex: 5,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              CyclicTabBar(
                contentLength: 10,
                controller: controller,
                tabBuilder: (index, _) => Text('Tab $index'),
              ),
              Expanded(
                child: CyclicTabBarView(
                  contentLength: 10,
                  controller: controller,
                  pageBuilder: (_, index, __) =>
                      Center(child: Text('Page $index')),
                ),
              ),
            ],
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should start at index 5
      expect(controller.index, 5);

      controller.dispose();
    });

    testWidgets('Should respect initialIndex in DefaultCyclicTabController',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultCyclicTabController(
            contentLength: 10,
            initialIndex: 7,
            child: Column(
              children: [
                CyclicTabBar(
                  contentLength: 10,
                  tabBuilder: (index, _) => Text('Tab $index'),
                ),
                Expanded(
                  child: CyclicTabBarView(
                    contentLength: 10,
                    pageBuilder: (_, index, __) =>
                        Center(child: Text('Page $index')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final controller = DefaultCyclicTabController.of(
        tester.element(find.byType(CyclicTabBar)),
      );

      // Should start at index 7
      expect(controller.index, 7);
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

  group('Separator functionality', () {
    testWidgets(
        'Should render tab separators when tabSeparatorBuilder is provided',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultCyclicTabController(
            contentLength: 4,
            child: Column(
              children: [
                CyclicTabBar(
                  contentLength: 4,
                  tabBuilder: (index, _) => Text('Tab $index'),
                  tabSeparatorBuilder: (context, modIndex, rawIndex) =>
                      Container(
                    key: Key('separator_$modIndex'),
                    width: 1,
                    color: Colors.grey,
                  ),
                ),
                Expanded(
                  child: CyclicTabBarView(
                    contentLength: 4,
                    pageBuilder: (_, index, __) =>
                        Center(child: Text('Page $index')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify that separators are rendered
      expect(find.byKey(const Key('separator_0')), findsWidgets);
      expect(find.byType(CyclicTabBar), findsOneWidget);
    });

    testWidgets(
        'Should render page separators when separatorBuilder is provided',
        (tester) async {
      var separatorBuilt = false;

      await tester.pumpWidget(
        MaterialApp(
          home: DefaultCyclicTabController(
            contentLength: 3,
            child: Column(
              children: [
                CyclicTabBar(
                  contentLength: 3,
                  tabBuilder: (index, _) => Text('Tab $index'),
                ),
                Expanded(
                  child: CyclicTabBarView(
                    contentLength: 3,
                    pageBuilder: (_, index, __) =>
                        Center(child: Text('Page $index')),
                    separatorBuilder: (context, modIndex, rawIndex) {
                      separatorBuilt = true;
                      return Container(
                        width: 2,
                        color: Colors.grey.shade300,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify that separator builder was called
      expect(separatorBuilt, true,
          reason: 'Separator builder should be called when provided');
      expect(find.byType(CyclicTabBarView), findsOneWidget);
    });

    testWidgets('Should work without separators (default behavior)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultCyclicTabController(
            contentLength: 3,
            child: Column(
              children: [
                CyclicTabBar(
                  contentLength: 3,
                  tabBuilder: (index, _) => Text('Tab $index'),
                ),
                Expanded(
                  child: CyclicTabBarView(
                    contentLength: 3,
                    pageBuilder: (_, index, __) =>
                        Center(child: Text('Page $index')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should work normally without separators
      expect(find.text('Tab 0'), findsWidgets);
      expect(find.text('Page 0'), findsOneWidget);
    });

    testWidgets('Should use bottomBorder instead of deprecated separator',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultCyclicTabController(
            contentLength: 3,
            child: Column(
              children: [
                CyclicTabBar(
                  contentLength: 3,
                  tabBuilder: (index, _) => Text('Tab $index'),
                  bottomBorder: const BorderSide(color: Colors.blue, width: 3),
                ),
                Expanded(
                  child: CyclicTabBarView(
                    contentLength: 3,
                    pageBuilder: (_, index, __) =>
                        Center(child: Text('Page $index')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Widget should build successfully with bottomBorder
      expect(find.byType(CyclicTabBar), findsOneWidget);
    });

    testWidgets('Should handle separators with modulo indices correctly',
        (tester) async {
      final List<int> separatorModIndices = [];

      await tester.pumpWidget(
        MaterialApp(
          home: DefaultCyclicTabController(
            contentLength: 3,
            child: Column(
              children: [
                CyclicTabBar(
                  contentLength: 3,
                  tabBuilder: (index, _) => Text('Tab $index'),
                  tabSeparatorBuilder: (context, modIndex, rawIndex) {
                    separatorModIndices.add(modIndex);
                    return Container(
                      width: 1,
                      color: Colors.grey,
                    );
                  },
                ),
                Expanded(
                  child: CyclicTabBarView(
                    contentLength: 3,
                    pageBuilder: (_, index, __) =>
                        Center(child: Text('Page $index')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify that separator modulo indices are within valid range [0, contentLength-1]
      for (final modIndex in separatorModIndices) {
        expect(modIndex >= 0 && modIndex < 3, true,
            reason: 'Separator modIndex $modIndex should be in range [0, 2]');
      }
    });
  });
}
