import 'package:cyclic_tab_bar/cyclic_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _build({
  required TabController controller,
  required bool loop,
  int count = 4,
  bool scrollableStrip = false,
  bool? enableFeedback,
}) {
  return MaterialApp(
    theme: ThemeData(platform: TargetPlatform.android),
    home: Scaffold(
      body: SizedBox(
        width: 300,
        child: Column(
          children: [
            SizedBox(
              height: 46,
              child: CyclicTabBar(
                controller: controller,
                isScrollable: scrollableStrip,
                tabAlignment: scrollableStrip ? TabAlignment.start : null,
                dividerColor: Colors.transparent,
                tabs: [
                  for (var i = 0; i < count; i++)
                    scrollableStrip
                        ? SizedBox(width: 100, child: Tab(text: 'T$i'))
                        : Tab(text: 'T$i'),
                ],
              ),
            ),
            Expanded(
              child: CyclicTabBarView(
                controller: controller,
                loop: loop,
                enableFeedback: enableFeedback,
                children: [
                  for (var i = 0; i < count; i++) Center(child: Text('P$i')),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _swipe(WidgetTester tester, double dx) async {
  await tester.fling(find.byType(PageView), Offset(dx, 0), 1200);
  await tester.pumpAndSettle();
}

List<MethodCall> _recordHaptics() {
  final calls = <MethodCall>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') calls.add(call);
        return null;
      });
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });
  return calls;
}

void main() {
  testWidgets('a swipe that wraps gives a heavy haptic', (tester) async {
    final haptics = _recordHaptics();
    final controller = TabController(length: 4, vsync: tester, initialIndex: 2);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_build(controller: controller, loop: true));
    await tester.pumpAndSettle();

    // An ordinary page change stays silent.
    await _swipe(tester, -200);
    expect(controller.index, 3);
    expect(haptics, isEmpty);

    await _swipe(tester, -200);
    expect(controller.index, 0);
    expect(haptics.map((call) => call.arguments), [
      'HapticFeedbackType.heavyImpact',
    ]);

    // A wrap driven by the controller, like a tab tap, stays silent.
    await tester.tap(find.text('T3'));
    await tester.pumpAndSettle();
    expect(controller.index, 3);
    expect(haptics, hasLength(1));
  });

  testWidgets('wrap haptics respect enableFeedback false', (tester) async {
    final haptics = _recordHaptics();
    final controller = TabController(length: 4, vsync: tester, initialIndex: 3);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _build(controller: controller, loop: true, enableFeedback: false),
    );
    await tester.pumpAndSettle();

    await _swipe(tester, -200);
    expect(controller.index, 0);
    expect(haptics, isEmpty);
  });

  testWidgets('pages do not loop by default', (tester) async {
    final controller = TabController(length: 4, vsync: tester, initialIndex: 3);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_build(controller: controller, loop: false));
    await tester.pumpAndSettle();

    expect(find.text('P3'), findsOneWidget);
    await _swipe(tester, -200);
    expect(controller.index, 3);
    expect(find.text('P3'), findsOneWidget);
    expect(find.text('P0'), findsNothing);

    controller.animateTo(0);
    await tester.pumpAndSettle();
    await _swipe(tester, 200);
    expect(controller.index, 0);
    expect(find.text('P0'), findsOneWidget);
  });

  testWidgets('swiping past the last page continues to the first', (
    tester,
  ) async {
    final controller = TabController(length: 4, vsync: tester, initialIndex: 3);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_build(controller: controller, loop: true));
    await tester.pumpAndSettle();
    expect(find.text('P3'), findsOneWidget);

    await _swipe(tester, -200);
    expect(tester.takeException(), isNull);
    expect(controller.index, 0);
    expect(controller.animation!.value, 0.0);
    expect(find.text('P0'), findsOneWidget);
    expect(find.text('P3'), findsNothing);

    // And keep going round.
    await _swipe(tester, -200);
    expect(controller.index, 1);
    expect(find.text('P1'), findsOneWidget);
  });

  testWidgets('swiping before the first page continues to the last', (
    tester,
  ) async {
    final controller = TabController(length: 4, vsync: tester);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_build(controller: controller, loop: true));
    await tester.pumpAndSettle();

    await _swipe(tester, 200);
    expect(tester.takeException(), isNull);
    expect(controller.index, 3);
    expect(find.text('P3'), findsOneWidget);
    expect(find.text('P0'), findsNothing);
  });

  testWidgets('a wrap swipe reports its progress through the controller', (
    tester,
  ) async {
    final controller = TabController(length: 4, vsync: tester, initialIndex: 3);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_build(controller: controller, loop: true));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PageView)),
    );
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-120, 0));
    await tester.pump();
    // Past the last tab, toward the sentinel copy of the first page, which
    // is on screen with it.
    expect(controller.index, 3);
    expect(controller.offset, inExclusiveRange(0.2, 0.8));
    expect(controller.animation!.value, greaterThan(3.0));
    expect(find.text('P3'), findsOneWidget);
    expect(find.text('P0'), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.index, 0);
    expect(find.text('P0'), findsOneWidget);
  });

  testWidgets('tapping across the wrap animates the short way', (tester) async {
    final controller = TabController(length: 4, vsync: tester, initialIndex: 3);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_build(controller: controller, loop: true));
    await tester.pumpAndSettle();

    await tester.tap(find.text('T0'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Mid-animation both the last page and the (sentinel) first page are
    // visible: the view did not travel back through P2 and P1.
    expect(find.text('P3'), findsOneWidget);
    expect(find.text('P0'), findsOneWidget);
    expect(find.text('P1'), findsNothing);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(controller.index, 0);
    expect(find.text('P0'), findsOneWidget);
    expect(find.text('P3'), findsNothing);

    await tester.tap(find.text('T3'));
    await tester.pumpAndSettle();
    expect(controller.index, 3);
    expect(find.text('P3'), findsOneWidget);
  });

  testWidgets('non-adjacent taps still warp through the middle', (
    tester,
  ) async {
    final controller = TabController(length: 4, vsync: tester);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_build(controller: controller, loop: true));
    await tester.pumpAndSettle();

    await tester.tap(find.text('T2'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(controller.index, 2);
    expect(find.text('P2'), findsOneWidget);
    await tester.tap(find.text('T0'));
    await tester.pumpAndSettle();
    expect(controller.index, 0);
    expect(find.text('P0'), findsOneWidget);
  });

  testWidgets('a scrollable strip follows the wrap cyclically', (tester) async {
    final controller = TabController(length: 4, vsync: tester, initialIndex: 3);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _build(controller: controller, loop: true, scrollableStrip: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('T0'), findsOneWidget);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PageView)),
    );
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-120, 0));
    await tester.pump();
    await tester.pump();
    // The strip extended itself so T0 can follow in after T3.
    expect(find.text('T0'), findsNWidgets(2));
    final List<double> t0Lefts = find
        .text('T0')
        .evaluate()
        .map((e) => tester.getRect(find.byWidget(e.widget)).left)
        .where((left) => left > 0 && left < 300)
        .toList();
    final double t3Left = find
        .text('T3')
        .evaluate()
        .map((e) => tester.getRect(find.byWidget(e.widget)).left)
        .where((left) => left > -100 && left < 300)
        .single;
    expect(t0Lefts, hasLength(1));
    expect(t0Lefts.single, greaterThan(t3Left));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(controller.index, 0);
    // Settled: the selected (first) tab is on screen.
    final List<double> settled = find
        .text('T0')
        .evaluate()
        .map((e) => tester.getRect(find.byWidget(e.widget)).left)
        .where((left) => left > -50 && left < 300)
        .toList();
    expect(settled, hasLength(1));
  });

  testWidgets('loop is ignored with a single page', (tester) async {
    final controller = TabController(length: 1, vsync: tester);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _build(controller: controller, loop: true, count: 1),
    );
    await tester.pumpAndSettle();
    expect(find.text('P0'), findsOneWidget);
    await _swipe(tester, -200);
    expect(tester.takeException(), isNull);
    expect(find.text('P0'), findsOneWidget);
  });

  testWidgets('toggling loop keeps the current page', (tester) async {
    final controller = TabController(length: 4, vsync: tester, initialIndex: 2);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_build(controller: controller, loop: false));
    await tester.pumpAndSettle();
    expect(find.text('P2'), findsOneWidget);
    await tester.pumpWidget(_build(controller: controller, loop: true));
    await tester.pumpAndSettle();
    expect(find.text('P2'), findsOneWidget);
    expect(controller.index, 2);
    await tester.pumpWidget(_build(controller: controller, loop: false));
    await tester.pumpAndSettle();
    expect(find.text('P2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
