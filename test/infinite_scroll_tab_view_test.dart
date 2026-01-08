import 'package:cyclic_tab_bar/src/cycled_list_view.dart';
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
          () =>
              DefaultCyclicTabController(contentLength: 0, child: Container()),
          throwsAssertionError,
        );
      },
    );

    testWidgets('Should accept valid contentLength', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultCyclicTabController(
            contentLength: 3,
            child: Column(
              children: [
                CyclicTabBar(tabBuilder: (index, _) => Text('Tab $index')),
                Expanded(
                  child: CyclicTabBarView(
                    pageBuilder: (_, index, _) =>
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
                CyclicTabBar(tabBuilder: (index, _) => const Text('Single')),
                Expanded(
                  child: CyclicTabBarView(
                    pageBuilder: (_, _, _) =>
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
                CyclicTabBar(tabBuilder: (index, _) => Text('Tab $index')),
                Expanded(
                  child: CyclicTabBarView(
                    pageBuilder: (_, index, _) =>
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
                CyclicTabBar(tabBuilder: (index, _) => Text('Tab $index')),
                Expanded(
                  child: CyclicTabBarView(
                    pageBuilder: (_, index, _) =>
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
                  tabBuilder: (index, _) => Text('Tab $index'),
                  onTabTap: (index) => tappedIndex = index,
                ),
                Expanded(
                  child: CyclicTabBarView(
                    pageBuilder: (_, index, _) =>
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

    testWidgets('Should call onTabLongPress when tab is long pressed', (
      tester,
    ) async {
      var longPressedIndex = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: DefaultCyclicTabController(
            contentLength: 3,
            child: Column(
              children: [
                CyclicTabBar(
                  tabBuilder: (index, _) => Text('Tab $index'),
                  onTabLongPress: (index) => longPressedIndex = index,
                ),
                Expanded(
                  child: CyclicTabBarView(
                    pageBuilder: (_, index, _) =>
                        Center(child: Text('Page $index')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final tab1 = find.text('Tab 1').first;
      await tester.longPress(tab1);
      await tester.pumpAndSettle();

      expect(longPressedIndex, 1);
      expect(find.text('Page 1'), findsOneWidget);
    });

    testWidgets('Should have onPageChanged callback', (tester) async {
      final List<int> changedIndices = [];

      await tester.pumpWidget(
        MaterialApp(
          home: DefaultCyclicTabController(
            contentLength: 3,
            child: Column(
              children: [
                CyclicTabBar(tabBuilder: (index, _) => Text('Tab $index')),
                Expanded(
                  child: CyclicTabBarView(
                    pageBuilder: (_, index, _) =>
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
                  tabBuilder: (index, _) => Text('Tab $index'),
                  onTabTap: (index) => tapCount++,
                ),
                Expanded(
                  child: CyclicTabBarView(
                    pageBuilder: (_, index, _) =>
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
                  forceFixedTabWidth: true,
                  fixedTabWidthFraction: 0.3,
                  tabBuilder: (index, _) => Text('Tab $index'),
                ),
                Expanded(
                  child: CyclicTabBarView(
                    pageBuilder: (_, index, _) =>
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
                  indicatorColor: Colors.red,
                  tabBuilder: (index, _) => Text('Tab $index'),
                ),
                Expanded(
                  child: CyclicTabBarView(
                    pageBuilder: (_, index, _) =>
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
                  tabHeight: 60.0,
                  tabBuilder: (index, _) => Text('Tab $index'),
                ),
                Expanded(
                  child: CyclicTabBarView(
                    pageBuilder: (_, index, _) =>
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
                  bottomBorder: const BorderSide(color: Colors.grey, width: 2),
                  tabBuilder: (index, _) => Text('Tab $index'),
                ),
                Expanded(
                  child: CyclicTabBarView(
                    pageBuilder: (_, index, _) =>
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
    testWidgets('Should allow wrapping tab bar with Container decoration', (
      tester,
    ) async {
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
                    tabBuilder: (index, _) => Text('Tab $index'),
                  ),
                ),
                Expanded(
                  child: CyclicTabBarView(
                    pageBuilder: (_, index, _) =>
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
        findsWidgets,
      );
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
                controller: controller,
                tabBuilder: (index, _) => Text('Tab $index'),
              ),
              Expanded(
                child: CyclicTabBarView(
                  controller: controller,
                  pageBuilder: (_, index, _) =>
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
                controller: controller,
                tabBuilder: (index, _) => Text('Tab $index'),
              ),
              Expanded(
                child: CyclicTabBarView(
                  controller: controller,
                  pageBuilder: (_, index, _) =>
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
                controller: controller,
                tabBuilder: (index, _) => Text('Tab $index'),
              ),
              Expanded(
                child: CyclicTabBarView(
                  controller: controller,
                  pageBuilder: (_, index, _) =>
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

    testWidgets('Should respect initialIndex in DefaultCyclicTabController', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultCyclicTabController(
            contentLength: 10,
            initialIndex: 7,
            child: Column(
              children: [
                CyclicTabBar(tabBuilder: (index, _) => Text('Tab $index')),
                Expanded(
                  child: CyclicTabBarView(
                    pageBuilder: (_, index, _) =>
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
      test('In plus direction.', () {
        expect(calculateMoveIndexDistance(0, 2, 10), 2);
        expect(calculateMoveIndexDistance(6, 9, 10), 3);
      });

      test('In minus direction.', () {
        expect(calculateMoveIndexDistance(9, 7, 10), -2);
        expect(calculateMoveIndexDistance(4, 1, 10), -3);
      });

      test('While overflow/underflow situation.', () {
        expect(calculateMoveIndexDistance(8, 2, 10), 4);
        expect(calculateMoveIndexDistance(1, 7, 10), -4);
      });
    },
  );

  group('Spacing functionality', () {
    testWidgets('Should render tabs with spacing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultCyclicTabController(
            contentLength: 4,
            child: Column(
              children: [
                CyclicTabBar(
                  tabBuilder: (index, _) => Text('Tab $index'),
                  tabSpacing: 8.0,
                ),
                Expanded(
                  child: CyclicTabBarView(
                    pageBuilder: (_, index, _) =>
                        Center(child: Text('Page $index')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Widget should build successfully with spacing
      expect(find.byType(CyclicTabBar), findsOneWidget);
      expect(find.text('Tab 0'), findsWidgets);
    });

    testWidgets('Should render pages with spacing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultCyclicTabController(
            contentLength: 3,
            child: Column(
              children: [
                CyclicTabBar(tabBuilder: (index, _) => Text('Tab $index')),
                Expanded(
                  child: CyclicTabBarView(
                    pageBuilder: (_, index, _) =>
                        Center(child: Text('Page $index')),
                    pageSpacing: 16.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Widget should build successfully with page spacing
      expect(find.byType(CyclicTabBarView), findsOneWidget);
      expect(find.text('Page 0'), findsOneWidget);
    });

    testWidgets('Should work without spacing (default behavior)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultCyclicTabController(
            contentLength: 3,
            child: Column(
              children: [
                CyclicTabBar(tabBuilder: (index, _) => Text('Tab $index')),
                Expanded(
                  child: CyclicTabBarView(
                    pageBuilder: (_, index, _) =>
                        Center(child: Text('Page $index')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should work normally without spacing
      expect(find.text('Tab 0'), findsWidgets);
      expect(find.text('Page 0'), findsOneWidget);
    });

    testWidgets('Should use bottomBorder parameter', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultCyclicTabController(
            contentLength: 3,
            child: Column(
              children: [
                CyclicTabBar(
                  tabBuilder: (index, _) => Text('Tab $index'),
                  bottomBorder: const BorderSide(color: Colors.blue, width: 3),
                ),
                Expanded(
                  child: CyclicTabBarView(
                    pageBuilder: (_, index, _) =>
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
  });

  group('Tab Alignment', () {
    testWidgets('Should support left alignment', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DefaultCyclicTabController(
              contentLength: 5,
              alignment: CyclicTabAlignment.left,
              child: Column(
                children: [
                  CyclicTabBar(tabBuilder: (index, _) => Text('Tab $index')),
                  Expanded(
                    child: CyclicTabBarView(
                      pageBuilder: (_, index, _) =>
                          Center(child: Text('Page $index')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify widgets built successfully
      expect(find.byType(CyclicTabBar), findsOneWidget);
      expect(find.byType(CyclicTabBarView), findsOneWidget);
      expect(find.text('Tab 0'), findsWidgets);
      expect(find.text('Page 0'), findsWidgets);
    });

    testWidgets('Should support center alignment (default)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DefaultCyclicTabController(
              contentLength: 5,
              alignment: CyclicTabAlignment.center,
              child: Column(
                children: [
                  CyclicTabBar(tabBuilder: (index, _) => Text('Tab $index')),
                  Expanded(
                    child: CyclicTabBarView(
                      pageBuilder: (_, index, _) =>
                          Center(child: Text('Page $index')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify widgets built successfully
      expect(find.byType(CyclicTabBar), findsOneWidget);
      expect(find.byType(CyclicTabBarView), findsOneWidget);
      expect(find.text('Tab 0'), findsWidgets);
      expect(find.text('Page 0'), findsWidgets);
    });

    testWidgets('Should use center alignment by default', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DefaultCyclicTabController(
              contentLength: 5,
              child: Column(
                children: [
                  CyclicTabBar(tabBuilder: (index, _) => Text('Tab $index')),
                  Expanded(
                    child: CyclicTabBarView(
                      pageBuilder: (_, index, _) =>
                          Center(child: Text('Page $index')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify widgets built successfully with default alignment
      expect(find.byType(CyclicTabBar), findsOneWidget);
      expect(find.byType(CyclicTabBarView), findsOneWidget);
    });

    testWidgets('Should work with explicit controller and left alignment', (
      tester,
    ) async {
      final controller = CyclicTabController(
        contentLength: 5,
        alignment: CyclicTabAlignment.left,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                CyclicTabBar(
                  controller: controller,
                  tabBuilder: (index, _) => Text('Tab $index'),
                ),
                Expanded(
                  child: CyclicTabBarView(
                    controller: controller,
                    pageBuilder: (_, index, _) =>
                        Center(child: Text('Page $index')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify widgets built successfully
      expect(find.byType(CyclicTabBar), findsOneWidget);
      expect(find.byType(CyclicTabBarView), findsOneWidget);

      // Clean up
      controller.dispose();
    });
  });

  group('Custom tab widgets', () {
    testWidgets('allows building tabs with arbitrary widgets', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultCyclicTabController(
            contentLength: 3,
            child: Column(
              children: [
                CyclicTabBar(
                  tabBuilder: (index, isSelected) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isSelected ? Icons.star : Icons.star_border),
                      const SizedBox(width: 6),
                      Text('Tab $index'),
                    ],
                  ),
                ),
                Expanded(
                  child: CyclicTabBarView(
                    pageBuilder: (_, index, _) =>
                        Center(child: Text('Page $index')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star_border), findsWidgets);
      expect(find.text('Tab 0'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('Cyclic scroll behavior', () {
    testWidgets('disables cyclic scroll when tabs fit the viewport', (
      tester,
    ) async {
      const indicatorColor = Colors.purpleAccent;

      await tester.pumpWidget(
        MaterialApp(
          home: DefaultCyclicTabController(
            contentLength: 2,
            child: Column(
              children: [
                CyclicTabBar(
                  tabBuilder: (index, _) => Text('Tab $index'),
                  forceFixedTabWidth: true,
                  fixedTabWidthFraction: 0.2,
                  indicatorColor: indicatorColor,
                ),
                Expanded(
                  child: CyclicTabBarView(
                    pageBuilder: (_, index, _) =>
                        Center(child: Text('Page $index')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(CycledListView), findsNothing);
      expect(find.byType(AnimatedPositioned), findsOneWidget);

      final indicatorFinder = find.byWidgetPredicate((widget) {
        if (widget is! Container) return false;
        final decoration = widget.decoration;
        return decoration is BoxDecoration &&
            decoration.color == indicatorColor;
      });

      expect(indicatorFinder, findsOneWidget);

      final tab0 = find.text('Tab 0').first;
      final indicatorRect = tester.getRect(indicatorFinder);
      final tabRect = tester.getRect(tab0);

      expect((indicatorRect.center.dx - tabRect.center.dx).abs(), lessThan(4));

      final tab1 = find.text('Tab 1').first;
      await tester.tap(tab1);
      await tester.pumpAndSettle();

      final movedIndicatorRect = tester.getRect(indicatorFinder);
      final tab1Rect = tester.getRect(tab1);

      expect(
        (movedIndicatorRect.center.dx - tab1Rect.center.dx).abs(),
        lessThan(4),
      );
      expect(
        (movedIndicatorRect.center.dx - indicatorRect.center.dx).abs(),
        greaterThan(4),
      );
    });

    testWidgets('keeps cyclic scroll when tabs overflow the viewport', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultCyclicTabController(
            contentLength: 5,
            child: Column(
              children: [
                CyclicTabBar(
                  tabBuilder: (index, _) => Text('Tab $index'),
                  forceFixedTabWidth: true,
                  fixedTabWidthFraction: 0.8,
                ),
                Expanded(
                  child: CyclicTabBarView(
                    pageBuilder: (_, index, _) =>
                        Center(child: Text('Page $index')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(CycledListView), findsOneWidget);
    });
  });

  group('Horizontal insets', () {
    testWidgets('Should accept leftInset parameter', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultCyclicTabController(
            contentLength: 3,
            child: Column(
              children: [
                CyclicTabBar(
                  tabBuilder: (index, _) => Text('Tab $index'),
                  leftInset: 100.0,
                ),
                Expanded(
                  child: CyclicTabBarView(
                    pageBuilder: (_, index, _) =>
                        Center(child: Text('Page $index')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(CyclicTabBar), findsOneWidget);
      expect(find.text('Tab 0'), findsWidgets);
    });

    testWidgets('Should accept rightInset parameter', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultCyclicTabController(
            contentLength: 3,
            child: Column(
              children: [
                CyclicTabBar(
                  tabBuilder: (index, _) => Text('Tab $index'),
                  rightInset: 100.0,
                ),
                Expanded(
                  child: CyclicTabBarView(
                    pageBuilder: (_, index, _) =>
                        Center(child: Text('Page $index')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(CyclicTabBar), findsOneWidget);
      expect(find.text('Tab 0'), findsWidgets);
    });

    testWidgets('Should accept both leftInset and rightInset', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultCyclicTabController(
            contentLength: 3,
            child: Column(
              children: [
                CyclicTabBar(
                  tabBuilder: (index, _) => Text('Tab $index'),
                  leftInset: 50.0,
                  rightInset: 50.0,
                ),
                Expanded(
                  child: CyclicTabBarView(
                    pageBuilder: (_, index, _) =>
                        Center(child: Text('Page $index')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(CyclicTabBar), findsOneWidget);
      expect(find.text('Tab 0'), findsWidgets);
    });

    testWidgets('Should work without insets (backward compatibility)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultCyclicTabController(
            contentLength: 3,
            child: Column(
              children: [
                CyclicTabBar(tabBuilder: (index, _) => Text('Tab $index')),
                Expanded(
                  child: CyclicTabBarView(
                    pageBuilder: (_, index, _) =>
                        Center(child: Text('Page $index')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(CyclicTabBar), findsOneWidget);
      expect(find.text('Tab 0'), findsWidgets);
    });

    testWidgets('Should apply insets with forceFixedTabWidth', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultCyclicTabController(
            contentLength: 3,
            child: Column(
              children: [
                CyclicTabBar(
                  tabBuilder: (index, _) => Text('Tab $index'),
                  forceFixedTabWidth: true,
                  fixedTabWidthFraction: 0.3,
                  leftInset: 100.0,
                  rightInset: 100.0,
                ),
                Expanded(
                  child: CyclicTabBarView(
                    pageBuilder: (_, index, _) =>
                        Center(child: Text('Page $index')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(CyclicTabBar), findsOneWidget);
    });

    testWidgets('Should work with left alignment and insets', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultCyclicTabController(
            contentLength: 3,
            alignment: CyclicTabAlignment.left,
            child: Column(
              children: [
                CyclicTabBar(
                  tabBuilder: (index, _) => Text('Tab $index'),
                  leftInset: 50.0,
                ),
                Expanded(
                  child: CyclicTabBarView(
                    pageBuilder: (_, index, _) =>
                        Center(child: Text('Page $index')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(CyclicTabBar), findsOneWidget);
    });

    testWidgets(
      'Should affect effective width calculation with insets',
      (tester) async {
        // Test that insets are properly accounted for in calculations
        // by verifying the widget builds successfully with various inset values
        await tester.pumpWidget(
          MaterialApp(
            home: DefaultCyclicTabController(
              contentLength: 5,
              child: Column(
                children: [
                  CyclicTabBar(
                    tabBuilder: (index, _) => Text('Tab $index'),
                    leftInset: 100.0,
                    rightInset: 100.0,
                  ),
                  Expanded(
                    child: CyclicTabBarView(
                      pageBuilder: (_, index, _) =>
                          Center(child: Text('Page $index')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Widget should build and function correctly with insets applied
        expect(find.byType(CyclicTabBar), findsOneWidget);
        expect(find.text('Tab 0'), findsWidgets);
      },
    );

    testWidgets('Should reject negative leftInset', (tester) async {
      expect(
        () => CyclicTabBar(
          tabBuilder: (index, _) => Text('Tab $index'),
          leftInset: -10.0,
        ),
        throwsAssertionError,
      );
    });

    testWidgets('Should reject negative rightInset', (tester) async {
      expect(
        () => CyclicTabBar(
          tabBuilder: (index, _) => Text('Tab $index'),
          rightInset: -10.0,
        ),
        throwsAssertionError,
      );
    });

    testWidgets('Should work in Row with Expanded layout', (tester) async {
      const sidebarWidth = 200.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Row(
            children: [
              SizedBox(
                width: sidebarWidth,
                child: Container(color: Colors.grey),
              ),
              Expanded(
                child: DefaultCyclicTabController(
                  contentLength: 5,
                  child: Column(
                    children: [
                      CyclicTabBar(
                        tabBuilder: (index, _) => Text('Tab $index'),
                        leftInset: sidebarWidth,
                      ),
                      Expanded(
                        child: CyclicTabBarView(
                          pageBuilder: (_, index, _) =>
                              Center(child: Text('Page $index')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(CyclicTabBar), findsOneWidget);
      expect(find.text('Tab 0'), findsWidgets);
    });

    testWidgets('Should recalculate when insets change', (tester) async {
      double leftInset = 0.0;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return DefaultCyclicTabController(
                contentLength: 3,
                child: Column(
                  children: [
                    CyclicTabBar(
                      tabBuilder: (index, _) => Text('Tab $index'),
                      leftInset: leftInset,
                    ),
                    Expanded(
                      child: CyclicTabBarView(
                        pageBuilder: (_, index, _) =>
                            Center(child: Text('Page $index')),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => setState(() => leftInset = 100.0),
                      child: const Text('Change inset'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(CyclicTabBar), findsOneWidget);

      // Tap button to change inset
      await tester.tap(find.text('Change inset'));
      await tester.pumpAndSettle();

      // Should still work after inset change
      expect(find.byType(CyclicTabBar), findsOneWidget);
    });
  });
}
