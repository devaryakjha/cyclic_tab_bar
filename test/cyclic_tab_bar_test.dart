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

  testWidgets('cyclic edge stretch commits with a shorter pull', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultTabController(
          length: 4,
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 240,
                child: CyclicTabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: const [
                    SizedBox(width: 100, child: Tab(text: 'One')),
                    SizedBox(width: 100, child: Tab(text: 'Two')),
                    SizedBox(width: 100, child: Tab(text: 'Three')),
                    SizedBox(width: 100, child: Tab(text: 'Four')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder scrollable = find.byType(SingleChildScrollView);
    await tester.drag(scrollable, const Offset(-500, 0));
    await tester.pumpAndSettle();

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(scrollable),
    );
    await gesture.moveBy(const Offset(-70, 0));
    await tester.pump();

    expect(find.text('One'), findsNWidgets(2));

    await gesture.up();
  });

  testWidgets('dynamic tab labels reset stale cyclic indicator offsets', (
    tester,
  ) async {
    var showCounts = false;

    Widget buildTabs() {
      return MaterialApp(
        home: DefaultTabController(
          initialIndex: 3,
          length: 4,
          child: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 360,
                    child: Column(
                      children: [
                        CyclicTabBar(
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          indicatorSize: TabBarIndicatorSize.label,
                          tabs: [
                            SizedBox(
                              width: showCounts ? 72 : 44,
                              child: Tab(text: showCounts ? 'IPO 2' : 'IPO'),
                            ),
                            SizedBox(
                              width: showCounts ? 152 : 120,
                              child: Tab(
                                text: showCounts
                                    ? 'Govt. securities 2'
                                    : 'Govt. securities',
                              ),
                            ),
                            SizedBox(
                              width: showCounts ? 112 : 80,
                              child: Tab(
                                text: showCounts ? 'Auctions 2' : 'Auctions',
                              ),
                            ),
                            SizedBox(
                              width: showCounts ? 172 : 140,
                              child: Tab(
                                text: showCounts
                                    ? 'Corporate Actions 5'
                                    : 'Corporate Actions',
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              showCounts = true;
                            });
                          },
                          child: const Text('load counts'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildTabs());
    await tester.pumpAndSettle();

    final Finder scrollable = find.byType(SingleChildScrollView);
    await tester.drag(scrollable, const Offset(-500, 0));
    await tester.pumpAndSettle();

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(scrollable),
    );
    await gesture.moveBy(const Offset(-300, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(find.text('IPO'), findsNWidgets(2));

    await tester.tap(find.text('load counts'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Auctions 2'));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
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
