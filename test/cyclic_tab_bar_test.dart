import 'package:cyclic_tab_bar/cyclic_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CyclicTabBar and CyclicTabBarView stay in sync', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DefaultTabController(
          length: 3,
          child: Scaffold(
            body: Column(
              children: [
                CyclicTabBar(
                  tabs: [
                    Tab(text: 'Home'),
                    Tab(text: 'Explore'),
                    Tab(text: 'Profile'),
                  ],
                ),
                Expanded(
                  child: CyclicTabBarView(
                    children: [
                      Center(child: Text('Home panel')),
                      Center(child: Text('Explore panel')),
                      Center(child: Text('Profile panel')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Home panel'), findsOneWidget);
    expect(find.text('Explore panel'), findsNothing);

    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();

    expect(find.text('Explore panel'), findsOneWidget);
    expect(find.text('Home panel'), findsNothing);
  });

  testWidgets(
    'fixed indicator width aligns custom indicators within tab bounds',
    (tester) async {
      final record = _IndicatorPaintRecord();

      await tester.pumpWidget(
        MaterialApp(
          home: DefaultTabController(
            length: 3,
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  child: CyclicTabBar(
                    indicator: _RecordingIndicatorDecoration(record),
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorFixedWidth: 64,
                    indicatorFixedWidthAlignment: Alignment.centerRight,
                    tabs: const [
                      Tab(text: 'Home'),
                      Tab(text: 'Explore'),
                      Tab(text: 'Profile'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(record.lastRect, isNotNull);
      expect(record.lastRect!.width, closeTo(64.0, 0.01));
      expect(record.lastRect!.left, closeTo(36.0, 0.01));
    },
  );

  testWidgets('fixed indicator width clamps to narrow scrollable tabs', (
    tester,
  ) async {
    final record = _IndicatorPaintRecord();

    await tester.pumpWidget(
      MaterialApp(
        home: DefaultTabController(
          length: 2,
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: CyclicTabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelPadding: EdgeInsets.zero,
                indicator: _RecordingIndicatorDecoration(record),
                indicatorFixedWidth: 64,
                tabs: const [
                  SizedBox(
                    key: ValueKey('small-tab'),
                    width: 40,
                    child: Center(child: Text('A')),
                  ),
                  SizedBox(
                    width: 120,
                    child: Center(child: Text('Much Longer')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(record.lastRect, isNotNull);
    expect(record.lastRect!.width, closeTo(40.0, 0.01));
    expect(record.lastRect!.left, closeTo(0.0, 0.01));
  });

  testWidgets(
    'fixed indicator width uses label bounds when indicatorSize is label',
    (tester) async {
      final record = _IndicatorPaintRecord();

      await tester.pumpWidget(
        MaterialApp(
          home: DefaultTabController(
            length: 2,
            child: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: CyclicTabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelPadding: EdgeInsets.zero,
                  indicator: _RecordingIndicatorDecoration(record),
                  indicatorSize: TabBarIndicatorSize.label,
                  indicatorFixedWidth: 64,
                  indicatorFixedWidthAlignment: Alignment.centerRight,
                  tabs: const [
                    SizedBox(width: 100, child: Center(child: Text('Wide'))),
                    SizedBox(width: 80, child: Center(child: Text('Next'))),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(record.lastRect, isNotNull);
      expect(record.lastRect!.width, closeTo(64.0, 0.01));
      expect(record.lastRect!.left, closeTo(36.0, 0.01));
    },
  );
}

class _IndicatorPaintRecord {
  Rect? lastRect;
}

class _RecordingIndicatorDecoration extends Decoration {
  const _RecordingIndicatorDecoration(this.record);

  final _IndicatorPaintRecord record;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _RecordingIndicatorBoxPainter(record);
  }
}

class _RecordingIndicatorBoxPainter extends BoxPainter {
  _RecordingIndicatorBoxPainter(this.record);

  final _IndicatorPaintRecord record;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    record.lastRect = offset & (configuration.size ?? Size.zero);
  }
}
