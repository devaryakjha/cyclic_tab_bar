import 'package:cyclic_tab_bar/cyclic_tab_bar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a scrollable strip the way the consuming app does: fresh (non-const)
/// tab widgets on every build, a fixed-width label indicator, centred
/// alignment, and the platform's own scroll physics. Tabs are 100 px wide
/// with 12 px label padding either side, so one tab pitch is 124 px.
Widget _buildStrip({
  required TargetPlatform platform,
  int tabCount = 4,
  double tabWidth = 100,
  double viewportWidth = 300,
  TabAlignment tabAlignment = TabAlignment.center,
  EdgeInsetsGeometry? padding,
  TextDirection textDirection = TextDirection.ltr,
  TabController? controller,
  Widget? below,
  void Function(StateSetter setState)? onBuild,
  int initialIndex = 0,
}) {
  Widget strip = StatefulBuilder(
    builder: (context, setState) {
      onBuild?.call(setState);
      return CyclicTabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: tabAlignment,
        padding: padding,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.label,
        indicatorFixedWidth: 24,
        indicatorFixedWidthAlignment: Alignment.centerLeft,
        labelPadding: const EdgeInsets.symmetric(horizontal: 12),
        tabs: [
          for (var i = 0; i < tabCount; i++)
            SizedBox(
              width: tabWidth,
              child: Tab(text: 'T$i'),
            ),
        ],
      );
    },
  );
  strip = SizedBox(width: viewportWidth, height: 36, child: strip);
  if (below != null) {
    strip = SizedBox(
      width: viewportWidth,
      child: Column(
        children: [
          strip,
          Expanded(child: below),
        ],
      ),
    );
  }
  Widget home = Scaffold(
    body: Align(alignment: Alignment.topLeft, child: strip),
  );
  if (controller == null) {
    home = DefaultTabController(
      length: tabCount,
      initialIndex: initialIndex,
      child: home,
    );
  }
  return MaterialApp(
    theme: ThemeData(platform: platform),
    home: Directionality(textDirection: textDirection, child: home),
  );
}

ScrollPosition _stripPosition(WidgetTester tester) {
  return tester
      .state<ScrollableState>(
        find.descendant(
          of: find.byType(CyclicTabBar),
          matching: find.byType(Scrollable),
        ),
      )
      .position;
}

/// Left edges of every rendered copy of the given label, in viewport
/// coordinates, sorted.
List<double> _lefts(WidgetTester tester, String label) {
  return find
      .text(label)
      .evaluate()
      .map((e) => tester.getRect(find.byWidget(e.widget)).left)
      .toList()
    ..sort();
}

/// Left edges of the copies of [label] whose text is at least partly inside
/// a viewport of [width].
List<double> _visibleLefts(WidgetTester tester, String label, double width) {
  return _lefts(
    tester,
    label,
  ).where((left) => left > -30 && left < width).toList();
}

/// Rects of the 100 px tab boxes, in viewport coordinates.
List<Rect> _tabBoxes(WidgetTester tester) {
  return find
      .byWidgetPredicate((widget) => widget is SizedBox && widget.width == 100)
      .evaluate()
      .map((e) {
        final RenderBox box = e.renderObject! as RenderBox;
        return box.localToGlobal(Offset.zero) & box.size;
      })
      .toList();
}

/// Time stamp of the last event the most recent [_pull] sent, so follow-up
/// moves can be stamped consistently.
Duration _pullElapsed = Duration.zero;

/// Holds a finger on the strip and pulls it [distance] px (negative drags
/// toward the end) at [speed] px/s, one event per 16 ms frame like a real
/// finger, so the strip's speed gate and the gesture's velocity tracker see
/// realistic input. The finger stays down.
Future<TestGesture> _pull(
  WidgetTester tester,
  double distance, {
  double speed = 300,
}) async {
  const Duration frame = Duration(milliseconds: 16);
  final int steps = (distance.abs() / (speed * 0.016)).ceil().clamp(1, 1000);
  final gesture = await tester.startGesture(
    tester.getCenter(find.byType(SingleChildScrollView)),
  );
  var elapsed = Duration.zero;
  for (var i = 0; i < steps; i++) {
    elapsed += frame;
    await gesture.moveBy(Offset(distance / steps, 0), timeStamp: elapsed);
    await tester.pump(frame);
  }
  _pullElapsed = elapsed;
  return gesture;
}

/// A fast swipe: [distance] px at about 3000 px/s, released at that speed.
Future<void> _swipe(WidgetTester tester, double distance) async {
  final gesture = await _pull(tester, distance, speed: 3000);
  await gesture.up(timeStamp: _pullElapsed);
}

bool _isExtended(WidgetTester tester, double normalMax) =>
    _stripPosition(tester).maxScrollExtent > normalMax + 0.5;

Future<void> _scrollToEnd(WidgetTester tester) async {
  final ScrollPosition position = _stripPosition(tester);
  position.jumpTo(position.maxScrollExtent);
  await tester.pumpAndSettle();
}

/// The strip is a plain single strip again, at rest, inside its range, with
/// no stretch preview left behind.
void _expectNormalRestingStrip(WidgetTester tester, {int tabCount = 4}) {
  expect(tester.takeException(), isNull);
  for (var i = 0; i < tabCount; i++) {
    expect(find.text('T$i'), findsOneWidget, reason: 'single copy of T$i');
  }
  expect(find.byType(OverflowBox), findsNothing);
  final ScrollPosition position = _stripPosition(tester);
  expect(position.isScrollingNotifier.value, isFalse);
  expect(position.pixels, greaterThanOrEqualTo(position.minScrollExtent));
  expect(position.pixels, lessThanOrEqualTo(position.maxScrollExtent));
}

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('one deliberate pull wraps once, then the strip has edges again', () {
    testWidgets('clamping: a held pull past the threshold wraps exactly once', (
      tester,
    ) async {
      await tester.pumpWidget(_buildStrip(platform: TargetPlatform.android));
      await tester.pumpAndSettle();
      await _scrollToEnd(tester);
      expect(_visibleLefts(tester, 'T0', 300), isEmpty);

      final gesture = await _pull(tester, -150);
      // Mid-pull the next cycle is laid out after the strip.
      expect(_isExtended(tester, 196.0), isTrue);
      await gesture.up();
      await tester.pumpAndSettle();

      // Settled: a single strip again, resting with the pulled-in first tab
      // flush against the start of the viewport.
      _expectNormalRestingStrip(tester);
      expect(_stripPosition(tester).pixels, 0.0);
      expect(_tabBoxes(tester).first.left, 12.0);
      expect(_visibleLefts(tester, 'T3', 300), isEmpty);
    });

    testWidgets(
      'a pull-wrap rests on the pulled-in tabs whatever is selected',
      (tester) async {
        // T3 selected and pulled past: the user pulled T0 in, so that is where
        // the strip rests, even though T3 then scrolls out of view like after
        // any other scroll.
        await tester.pumpWidget(
          _buildStrip(platform: TargetPlatform.android, initialIndex: 3),
        );
        await tester.pumpAndSettle();
        await _scrollToEnd(tester);

        final gesture = await _pull(tester, -150);
        expect(_isExtended(tester, 196.0), isTrue);
        await gesture.up();
        await tester.pumpAndSettle();
        _expectNormalRestingStrip(tester);
        expect(_stripPosition(tester).pixels, 0.0);
        expect(_tabBoxes(tester).first.left, 12.0);
        expect(
          DefaultTabController.of(
            tester.element(find.byType(CyclicTabBar)),
          ).index,
          3,
        );
      },
    );

    testWidgets('a second wrap needs another deliberate pull', (tester) async {
      await tester.pumpWidget(_buildStrip(platform: TargetPlatform.android));
      await tester.pumpAndSettle();
      await _scrollToEnd(tester);

      var gesture = await _pull(tester, -150);
      await gesture.up();
      await tester.pumpAndSettle();
      _expectNormalRestingStrip(tester);

      // Dragging on toward the end again simply scrolls to the edge: no
      // second cycle appears, and the strip stops at its last tab.
      gesture = await _pull(tester, -300, speed: 1500);
      // Only the stretch preview, no second cycle laid out.
      expect(_isExtended(tester, 196.0), isFalse);
      await gesture.up();
      await tester.pumpAndSettle();
      _expectNormalRestingStrip(tester);
      final ScrollPosition position = _stripPosition(tester);
      expect(position.pixels, position.maxScrollExtent);
      expect(_visibleLefts(tester, 'T3', 300), isNotEmpty);

      // A short pull springs back without wrapping...
      gesture = await _pull(tester, -40);
      await gesture.up();
      await tester.pumpAndSettle();
      _expectNormalRestingStrip(tester);
      expect(position.pixels, position.maxScrollExtent);

      // ...and a deliberate one wraps again.
      gesture = await _pull(tester, -150);
      await gesture.up();
      await tester.pumpAndSettle();
      _expectNormalRestingStrip(tester);
      expect(position.pixels, 0.0);
      expect(_tabBoxes(tester).first.left, 12.0);
    });

    testWidgets('bouncing: a held pull past the threshold wraps exactly once', (
      tester,
    ) async {
      await tester.pumpWidget(_buildStrip(platform: TargetPlatform.iOS));
      await tester.pumpAndSettle();
      await _scrollToEnd(tester);

      // The stretch is the finger's own travel past the edge, so bouncing
      // physics need the same pull as clamping physics.
      var gesture = await _pull(tester, -60);
      expect(find.text('T0'), findsNWidgets(2));
      expect(_isExtended(tester, 196.0), isFalse);
      await gesture.up();
      await tester.pumpAndSettle();
      _expectNormalRestingStrip(tester);
      expect(_stripPosition(tester).pixels, 196.0);

      gesture = await _pull(tester, -140);
      expect(_isExtended(tester, 196.0), isTrue);
      await gesture.up();
      await tester.pumpAndSettle();
      _expectNormalRestingStrip(tester);
      expect(_stripPosition(tester).pixels, 0.0);
      expect(_tabBoxes(tester).first.left, 12.0);
    });

    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      for (final direction in TextDirection.values) {
        testWidgets(
          '$platform $direction: the wrap rests at the strip start, padding showing',
          (tester) async {
            // Asymmetric padding: 28 px before the first tab, 16 after the
            // last, the way the consuming app's home strip is laid out.
            await tester.pumpWidget(
              _buildStrip(
                platform: platform,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsetsDirectional.only(start: 28, end: 16),
                textDirection: direction,
              ),
            );
            await tester.pumpAndSettle();
            await _scrollToEnd(tester);
            final double sign = direction == TextDirection.ltr ? -1 : 1;

            final gesture = await _pull(tester, 150 * sign);
            expect(_isExtended(tester, 240.0), isTrue);
            await gesture.up();
            // No frame may show a jump. Tab boxes sit one 124 px pitch
            // apart, so the on-screen phase of the boxes (position modulo
            // the pitch) must move smoothly between frames, whichever boxes
            // happen to be on screen.
            const double pitch = 124.0;
            double? lastPhase;
            for (var i = 0; i < 80; i++) {
              await tester.pump(const Duration(milliseconds: 16));
              final List<double> lefts = _tabBoxes(tester)
                  .map((rect) => rect.left)
                  .where((left) => left > -100 && left < 300)
                  .toList();
              if (lefts.isEmpty) {
                continue;
              }
              final double phase = lefts.first % pitch;
              if (lastPhase != null) {
                double step = (phase - lastPhase).abs();
                step = step > pitch / 2 ? pitch - step : step;
                expect(step, lessThan(40.0), reason: 'frame $i');
              }
              lastPhase = phase;
            }
            await tester.pumpAndSettle();
            _expectNormalRestingStrip(tester);
            // The strip is at its start: 28 px padding, then the first
            // tab's 12 px label padding.
            expect(_stripPosition(tester).pixels, 0.0);
            final List<Rect> boxes = _tabBoxes(tester);
            if (direction == TextDirection.ltr) {
              expect(boxes.first.left, 40.0);
            } else {
              expect(boxes.first.right, 300.0 - 40.0);
            }
          },
        );
      }
    }

    testWidgets('scrolling back during the settle rests where it lands', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildStrip(
          platform: TargetPlatform.android,
          tabCount: 6,
          tabAlignment: TabAlignment.start,
          padding: const EdgeInsets.only(left: 28),
        ),
      );
      await tester.pumpAndSettle();
      await _scrollToEnd(tester);
      const double normalMax = 6 * 124.0 + 28.0 - 300.0;

      // Wrap, lift, and shortly after take over: drag well back into the
      // original cycle, hold, lift.
      final gesture = await _pull(tester, -150);
      expect(_isExtended(tester, normalMax), isTrue);
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));
      final again = await _pull(tester, 300);
      await tester.pump(const Duration(milliseconds: 200));
      await again.up(
        timeStamp: _pullElapsed + const Duration(milliseconds: 200),
      );
      await tester.pump();
      final List<double> onRelease = _tabBoxes(tester)
          .map((rect) => rect.left)
          .where((left) => left > -100 && left < 300)
          .toList();
      await tester.pumpAndSettle();

      // Collapsed in place: nothing moved after the finger left, and no
      // ease away to the strip's start.
      _expectNormalRestingStrip(tester, tabCount: 6);
      expect(
        _tabBoxes(tester)
            .map((rect) => rect.left)
            .where((left) => left > -100 && left < 300)
            .toList(),
        onRelease,
      );
      expect(_stripPosition(tester).pixels, greaterThan(100.0));
    });

    testWidgets('a leading wrap rests at the strip end, padding showing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildStrip(
          platform: TargetPlatform.android,
          tabAlignment: TabAlignment.start,
          padding: const EdgeInsets.only(left: 28, right: 16),
        ),
      );
      await tester.pumpAndSettle();
      final gesture = await _pull(tester, 150);
      expect(_isExtended(tester, 240.0), isTrue);
      await gesture.up();
      await tester.pumpAndSettle();
      _expectNormalRestingStrip(tester);
      final ScrollPosition position = _stripPosition(tester);
      expect(position.pixels, position.maxScrollExtent);
      expect(_tabBoxes(tester).last.right, 300.0 - 16.0 - 12.0);
    });

    testWidgets('a leading pull wraps to the last tab', (tester) async {
      // The leading pull wraps T3 in before T0, and the strip rests on it,
      // flush against the end of the viewport.
      await tester.pumpWidget(_buildStrip(platform: TargetPlatform.android));
      await tester.pumpAndSettle();
      final ScrollPosition position = _stripPosition(tester);
      position.jumpTo(0.0);
      await tester.pumpAndSettle();

      final gesture = await _pull(tester, 150);
      expect(_isExtended(tester, 196.0), isTrue);
      await gesture.up();
      await tester.pumpAndSettle();
      _expectNormalRestingStrip(tester);
      expect(position.pixels, position.maxScrollExtent);
      expect(_tabBoxes(tester).last.right, 300.0 - 12.0);
      expect(_visibleLefts(tester, 'T0', 300), isEmpty);
    });
  });

  group('short pulls and flings spring back without wrapping', () {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      for (final distance in <double>[20, 40, 60]) {
        testWidgets('$platform: a $distance px pull springs back', (
          tester,
        ) async {
          await tester.pumpWidget(_buildStrip(platform: platform));
          await tester.pumpAndSettle();
          await _scrollToEnd(tester);
          final ScrollPosition position = _stripPosition(tester);
          final double end = position.maxScrollExtent;

          final gesture = await _pull(tester, -distance);
          await gesture.up();
          await tester.pump();
          await tester.pumpAndSettle();

          _expectNormalRestingStrip(tester);
          expect(position.pixels, moreOrLessEquals(end));
          expect(_visibleLefts(tester, 'T0', 300), isEmpty);
          expect(_visibleLefts(tester, 'T3', 300), isNotEmpty);
        });
      }

      for (final velocity in <double>[1500, 2800, 4000, 8000]) {
        for (final atStart in [false, true]) {
          testWidgets('$platform: a fling at $velocity px/s from the '
              '${atStart ? 'start' : 'end'} never wraps', (tester) async {
            await tester.pumpWidget(_buildStrip(platform: platform));
            await tester.pumpAndSettle();
            final ScrollPosition position = _stripPosition(tester);
            final double edge = atStart ? 0.0 : position.maxScrollExtent;
            position.jumpTo(edge);
            await tester.pumpAndSettle();

            await tester.fling(
              find.byType(SingleChildScrollView),
              Offset(atStart ? 200 : -200, 0),
              velocity,
            );
            // The strip never extends at any point of the bounce.
            for (var i = 0; i < 60; i++) {
              await tester.pump(const Duration(milliseconds: 16));
              expect(_isExtended(tester, 196.0), isFalse, reason: 'frame $i');
            }
            await tester.pumpAndSettle();

            _expectNormalRestingStrip(tester);
            expect(position.pixels, moreOrLessEquals(edge));
            expect(_visibleLefts(tester, atStart ? 'T3' : 'T0', 300), isEmpty);
          });
        }
      }

      testWidgets('$platform: a fast swipe from the edge never wraps', (
        tester,
      ) async {
        await tester.pumpWidget(_buildStrip(platform: platform));
        await tester.pumpAndSettle();
        await _scrollToEnd(tester);
        final ScrollPosition position = _stripPosition(tester);
        final double end = position.maxScrollExtent;

        // Far past the commit distance, but at flick speed.
        await _swipe(tester, -250);
        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(_isExtended(tester, 196.0), isFalse, reason: 'frame $i');
        }
        await tester.pumpAndSettle();
        _expectNormalRestingStrip(tester);
        expect(position.pixels, moreOrLessEquals(end));
        expect(_visibleLefts(tester, 'T0', 300), isEmpty);
      });

      testWidgets('$platform: a fast swipe that stops and holds commits', (
        tester,
      ) async {
        await tester.pumpWidget(_buildStrip(platform: platform));
        await tester.pumpAndSettle();
        await _scrollToEnd(tester);

        final gesture = await _pull(
          tester,
          platform == TargetPlatform.iOS ? -350 : -200,
          speed: 3000,
        );
        expect(_isExtended(tester, 196.0), isFalse);
        // Then a slow nudge past the threshold: deliberate after all.
        await tester.pump(const Duration(milliseconds: 200));
        await gesture.moveBy(
          const Offset(-4, 0),
          timeStamp: _pullElapsed + const Duration(milliseconds: 216),
        );
        await tester.pump(const Duration(milliseconds: 48));
        expect(_isExtended(tester, 196.0), isTrue);
        await gesture.up();
        await tester.pumpAndSettle();
        _expectNormalRestingStrip(tester);
        expect(_stripPosition(tester).pixels, 0.0);
      });
    }

    testWidgets(
      'a held pull released gently commits even without a slow frame',
      (tester) async {
        await tester.pumpWidget(_buildStrip(platform: TargetPlatform.android));
        await tester.pumpAndSettle();
        await _scrollToEnd(tester);

        // Above the speed limit frame by frame, then held still and let go.
        final gesture = await _pull(tester, -150, speed: 750);
        expect(_isExtended(tester, 196.0), isFalse);
        await tester.pump(const Duration(milliseconds: 300));
        await gesture.up();
        await tester.pumpAndSettle();
        _expectNormalRestingStrip(tester);
        expect(_stripPosition(tester).pixels, 0.0);
      },
    );

    testWidgets('bouncing: the strip tracks the overscroll, not more', (
      tester,
    ) async {
      await tester.pumpWidget(_buildStrip(platform: TargetPlatform.iOS));
      await tester.pumpAndSettle();
      await _scrollToEnd(tester);
      final ScrollPosition position = _stripPosition(tester);
      final double restingRight = _tabBoxes(
        tester,
      ).map((rect) => rect.right).reduce((a, b) => a > b ? a : b);

      final gesture = await _pull(tester, -80);
      final double overscroll = position.pixels - position.maxScrollExtent;
      expect(overscroll, greaterThan(0.0));
      final List<Rect> boxes = _tabBoxes(tester);
      // The strip's own last tab moved by exactly the viewport's overscroll.
      final double lastTabRight = boxes
          .map((rect) => rect.right)
          .where((right) => right <= 300)
          .reduce((a, b) => a > b ? a : b);
      expect(restingRight - lastTabRight, moreOrLessEquals(overscroll));
      // The preview's first tab starts right after it (12 + 12 px padding).
      final double previewLeft = boxes
          .map((rect) => rect.left)
          .where((left) => left > lastTabRight)
          .reduce((a, b) => a < b ? a : b);
      expect(previewLeft - lastTabRight, moreOrLessEquals(24.0));
      await gesture.up();
      await tester.pumpAndSettle();
      _expectNormalRestingStrip(tester);
    });

    testWidgets('clamping: a small move back shrinks the preview', (
      tester,
    ) async {
      await tester.pumpWidget(_buildStrip(platform: TargetPlatform.android));
      await tester.pumpAndSettle();
      await _scrollToEnd(tester);

      final gesture = await _pull(tester, -60);
      expect(find.text('T0'), findsNWidgets(2));
      final double before = _lefts(tester, 'T0').last;
      await gesture.moveBy(
        const Offset(4, 0),
        timeStamp: _pullElapsed + const Duration(milliseconds: 16),
      );
      await tester.pump();
      expect(find.text('T0'), findsNWidgets(2));
      expect(_lefts(tester, 'T0').last, greaterThan(before));
      await gesture.up();
      await tester.pumpAndSettle();
      _expectNormalRestingStrip(tester);
    });
  });

  group('speed gate: only a deliberate pull commits', () {
    /// Drives a pointer by hand with explicit time stamps.
    Future<TestGesture> finger(WidgetTester tester) async {
      final gesture = await tester.createGesture();
      await gesture.down(
        tester.getCenter(find.byType(SingleChildScrollView)),
        timeStamp: Duration.zero,
      );
      return gesture;
    }

    Future<Duration> move(
      WidgetTester tester,
      TestGesture gesture, {
      required double dx,
      required Duration from,
      required int frames,
    }) async {
      const Duration frame = Duration(milliseconds: 16);
      var at = from;
      for (var i = 0; i < frames; i++) {
        at += frame;
        await gesture.moveBy(Offset(dx, 0), timeStamp: at);
        await tester.pump(frame);
      }
      return at;
    }

    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      // The same finger travel past the edge on both physics: well past the
      // 64 px threshold once the 18 px touch slop is taken off.
      const double travel = 160;

      testWidgets('$platform: a slow frame past the threshold commits', (
        tester,
      ) async {
        await tester.pumpWidget(_buildStrip(platform: platform));
        await tester.pumpAndSettle();
        await _scrollToEnd(tester);
        final gesture = await finger(tester);
        // 5 px per 16 ms: about 310 px/s.
        await move(
          tester,
          gesture,
          dx: -5,
          from: Duration.zero,
          frames: (travel / 5).round(),
        );
        // Committed while the finger is still down.
        expect(_isExtended(tester, 196.0), isTrue);
        await gesture.up();
        await tester.pumpAndSettle();
        _expectNormalRestingStrip(tester);
        expect(_stripPosition(tester).pixels, 0.0);
      });

      testWidgets('$platform: fast frames and a fast lift never commit', (
        tester,
      ) async {
        await tester.pumpWidget(_buildStrip(platform: platform));
        await tester.pumpAndSettle();
        await _scrollToEnd(tester);
        final ScrollPosition position = _stripPosition(tester);
        final double end = position.maxScrollExtent;
        final gesture = await finger(tester);
        // 24 px per 16 ms: 1500 px/s of finger, which bouncing physics
        // scale down to a few hundred px/s of scroll.
        final Duration at = await move(
          tester,
          gesture,
          dx: -24,
          from: Duration.zero,
          frames: (travel / 24).ceil(),
        );
        expect(_isExtended(tester, 196.0), isFalse);
        await gesture.up(timeStamp: at);
        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(_isExtended(tester, 196.0), isFalse, reason: 'frame $i');
        }
        await tester.pumpAndSettle();
        _expectNormalRestingStrip(tester);
        expect(position.pixels, moreOrLessEquals(end));
      });

      testWidgets('$platform: fast frames, then hold and lift, commits', (
        tester,
      ) async {
        await tester.pumpWidget(_buildStrip(platform: platform));
        await tester.pumpAndSettle();
        await _scrollToEnd(tester);
        final gesture = await finger(tester);
        final Duration at = await move(
          tester,
          gesture,
          dx: -24,
          from: Duration.zero,
          frames: (travel / 24).ceil(),
        );
        expect(_isExtended(tester, 196.0), isFalse);
        // Held still for a while, then lifted: a release at rest.
        await tester.pump(const Duration(milliseconds: 300));
        await gesture.up(timeStamp: at + const Duration(milliseconds: 300));
        await tester.pump();
        expect(_isExtended(tester, 196.0), isTrue);
        await tester.pumpAndSettle();
        _expectNormalRestingStrip(tester);
        expect(_stripPosition(tester).pixels, 0.0);
      });

      testWidgets('$platform: a commit followed by a fast lift settles', (
        tester,
      ) async {
        await tester.pumpWidget(_buildStrip(platform: platform));
        await tester.pumpAndSettle();
        await _scrollToEnd(tester);
        final gesture = await finger(tester);
        Duration at = await move(
          tester,
          gesture,
          dx: -5,
          from: Duration.zero,
          frames: (travel / 5).round(),
        );
        expect(_isExtended(tester, 196.0), isTrue);
        // Then a flick onward and a fast lift.
        at = await move(tester, gesture, dx: -24, from: at, frames: 4);
        await gesture.up(timeStamp: at);
        await tester.pumpAndSettle();
        // No coasting into the next cycle: at rest on the pulled-in tab.
        _expectNormalRestingStrip(tester);
        expect(_stripPosition(tester).pixels, 0.0);
        expect(_tabBoxes(tester).first.left, 12.0);
      });

      testWidgets('$platform: 100 px of finger wraps, 60 px does not', (
        tester,
      ) async {
        await tester.pumpWidget(_buildStrip(platform: platform));
        await tester.pumpAndSettle();
        await _scrollToEnd(tester);
        var gesture = await finger(tester);
        await move(tester, gesture, dx: -5, from: Duration.zero, frames: 12);
        expect(_isExtended(tester, 196.0), isFalse);
        await gesture.up();
        await tester.pumpAndSettle();
        _expectNormalRestingStrip(tester);
        expect(_visibleLefts(tester, 'T0', 300), isEmpty);

        gesture = await finger(tester);
        await move(tester, gesture, dx: -5, from: Duration.zero, frames: 20);
        expect(_isExtended(tester, 196.0), isTrue);
        await gesture.up();
        await tester.pumpAndSettle();
        _expectNormalRestingStrip(tester);
        expect(_stripPosition(tester).pixels, 0.0);
      });
    }

    testWidgets('a cancelled drag is not a release', (tester) async {
      await tester.pumpWidget(_buildStrip(platform: TargetPlatform.android));
      await tester.pumpAndSettle();
      await _scrollToEnd(tester);
      final gesture = await finger(tester);
      final Duration at = await move(
        tester,
        gesture,
        dx: -24,
        from: Duration.zero,
        frames: 7,
      );
      expect(_isExtended(tester, 196.0), isFalse);
      await gesture.cancel(timeStamp: at);
      await tester.pumpAndSettle();
      _expectNormalRestingStrip(tester);
      final ScrollPosition position = _stripPosition(tester);
      expect(position.pixels, position.maxScrollExtent);
    });
  });

  group('bug 1: stretch and wrap survive equivalent rebuilds', () {
    testWidgets('stretch preview survives a rebuild with equivalent tabs', (
      tester,
    ) async {
      StateSetter? rebuild;
      await tester.pumpWidget(
        _buildStrip(
          platform: TargetPlatform.iOS,
          onBuild: (setState) => rebuild = setState,
        ),
      );
      await tester.pumpAndSettle();
      await _scrollToEnd(tester);
      final ScrollPosition position = _stripPosition(tester);

      final gesture = await _pull(tester, -60);
      expect(position.pixels, greaterThan(position.maxScrollExtent));
      expect(find.text('T0'), findsNWidgets(2));
      final List<double> before = _lefts(tester, 'T0');

      rebuild!(() {});
      await tester.pump();

      expect(find.text('T0'), findsNWidgets(2));
      expect(_lefts(tester, 'T0'), before);

      await gesture.up();
      await tester.pumpAndSettle();
      _expectNormalRestingStrip(tester);
      expect(position.pixels, moreOrLessEquals(position.maxScrollExtent));
    });

    testWidgets('a held wrap survives a rebuild with equivalent tabs', (
      tester,
    ) async {
      StateSetter? rebuild;
      await tester.pumpWidget(
        _buildStrip(
          platform: TargetPlatform.android,
          onBuild: (setState) => rebuild = setState,
        ),
      );
      await tester.pumpAndSettle();
      await _scrollToEnd(tester);

      final gesture = await _pull(tester, -150);
      expect(_isExtended(tester, 196.0), isTrue);
      final List<double> before = _visibleLefts(tester, 'T0', 300);
      final double pixelsBefore = _stripPosition(tester).pixels;
      expect(before, isNotEmpty);

      rebuild!(() {});
      await tester.pump();
      expect(find.text('T0'), findsNWidgets(2));
      expect(_visibleLefts(tester, 'T0', 300), before);
      expect(_stripPosition(tester).pixels, pixelsBefore);

      await gesture.up();
      await tester.pumpAndSettle();
      _expectNormalRestingStrip(tester);
      expect(_stripPosition(tester).pixels, 0.0);
    });

    testWidgets('a settling stretch preview survives a rebuild', (
      tester,
    ) async {
      StateSetter? rebuild;
      await tester.pumpWidget(
        _buildStrip(
          platform: TargetPlatform.android,
          onBuild: (setState) => rebuild = setState,
        ),
      );
      await tester.pumpAndSettle();
      await _scrollToEnd(tester);

      final gesture = await _pull(tester, -50);
      expect(find.text('T0'), findsNWidgets(2));
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      // Still animating back.
      expect(find.text('T0'), findsNWidgets(2));

      rebuild!(() {});
      await tester.pump();
      expect(find.text('T0'), findsNWidgets(2));

      await tester.pumpAndSettle();
      _expectNormalRestingStrip(tester);
    });

    testWidgets('a rebuild during the resting animation does not jump', (
      tester,
    ) async {
      StateSetter? rebuild;
      await tester.pumpWidget(
        _buildStrip(
          platform: TargetPlatform.android,
          onBuild: (setState) => rebuild = setState,
        ),
      );
      await tester.pumpAndSettle();
      await _scrollToEnd(tester);

      final gesture = await _pull(tester, -100);
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_isExtended(tester, 196.0), isTrue);
      final List<double> before = _visibleLefts(tester, 'T0', 300);
      rebuild!(() {});
      await tester.pump();
      expect(_isExtended(tester, 196.0), isTrue);
      expect(_visibleLefts(tester, 'T0', 300), before);
      await tester.pumpAndSettle();
      _expectNormalRestingStrip(tester);
      expect(_stripPosition(tester).pixels, 0.0);
    });
  });

  group('bug 3: the strip never gets stuck in its wrap', () {
    testWidgets('releasing on the seam settles and the next pull wraps', (
      tester,
    ) async {
      await tester.pumpWidget(_buildStrip(platform: TargetPlatform.android));
      await tester.pumpAndSettle();
      await _scrollToEnd(tester);

      for (var round = 0; round < 4; round++) {
        // Commit, then let go with the viewport straddling the seam.
        final gesture = await _pull(tester, -100);
        expect(_isExtended(tester, 196.0), isTrue, reason: 'round $round');
        await gesture.up();
        await tester.pumpAndSettle();
        _expectNormalRestingStrip(tester);
        expect(_stripPosition(tester).pixels, 0.0, reason: 'round $round');
        await _scrollToEnd(tester);
      }
    });

    testWidgets('a wrap pulled back toward the original cycle settles there', (
      tester,
    ) async {
      await tester.pumpWidget(_buildStrip(platform: TargetPlatform.android));
      await tester.pumpAndSettle();
      await _scrollToEnd(tester);

      final gesture = await _pull(tester, -100);
      expect(_isExtended(tester, 196.0), isTrue);
      // Back until the original cycle fills the whole viewport again.
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(
          const Offset(20, 0),
          timeStamp: _pullElapsed + Duration(milliseconds: 48 * (i + 1)),
        );
        await tester.pump(const Duration(milliseconds: 48));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      _expectNormalRestingStrip(tester);
      final ScrollPosition position = _stripPosition(tester);
      expect(position.pixels, lessThan(position.maxScrollExtent));
      expect(_visibleLefts(tester, 'T3', 300), isNotEmpty);
      expect(_visibleLefts(tester, 'T0', 300), isEmpty);

      // And it can still wrap.
      final again = await _pull(tester, -150);
      await again.up();
      await tester.pumpAndSettle();
      _expectNormalRestingStrip(tester);
      expect(position.pixels, 0.0);
    });

    testWidgets('a cancelled stretch does not block the next wrap', (
      tester,
    ) async {
      await tester.pumpWidget(_buildStrip(platform: TargetPlatform.android));
      await tester.pumpAndSettle();
      await _scrollToEnd(tester);

      for (var i = 0; i < 3; i++) {
        final gesture = await _pull(tester, -40);
        await gesture.up();
        await tester.pumpAndSettle();
        _expectNormalRestingStrip(tester);
      }

      final gesture = await _pull(tester, -150);
      await gesture.up();
      await tester.pumpAndSettle();
      _expectNormalRestingStrip(tester);
      expect(_stripPosition(tester).pixels, 0.0);
    });

    testWidgets('dragging on through the wrap collapses at the far edge', (
      tester,
    ) async {
      await tester.pumpWidget(_buildStrip(platform: TargetPlatform.android));
      await tester.pumpAndSettle();
      await _scrollToEnd(tester);

      // Commit and keep dragging a whole cycle and more in one gesture: the
      // extended strip has a hard edge at the end of the second copy, and
      // letting go there collapses onto the normal strip's end.
      final gesture = await _pull(tester, -800);
      await gesture.up();
      await tester.pumpAndSettle();
      _expectNormalRestingStrip(tester);
      final ScrollPosition position = _stripPosition(tester);
      expect(position.pixels, position.maxScrollExtent);

      final again = await _pull(tester, -150);
      expect(_isExtended(tester, 196.0), isTrue);
      await again.up();
      await tester.pumpAndSettle();
      _expectNormalRestingStrip(tester);
      expect(position.pixels, 0.0);
    });

    testWidgets('bouncing: a wrap released with a fling settles', (
      tester,
    ) async {
      await tester.pumpWidget(_buildStrip(platform: TargetPlatform.iOS));
      await tester.pumpAndSettle();
      await _scrollToEnd(tester);

      final gesture = await _pull(tester, -400);
      expect(_isExtended(tester, 196.0), isTrue);
      await gesture.up();
      await tester.pumpAndSettle();
      _expectNormalRestingStrip(tester);

      final again = await _pull(tester, -400);
      expect(_isExtended(tester, 196.0), isTrue);
      await again.up();
      await tester.pumpAndSettle();
      _expectNormalRestingStrip(tester);
    });

    testWidgets('leading wraps settle in RTL as well', (tester) async {
      for (final direction in TextDirection.values) {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          _buildStrip(
            platform: TargetPlatform.android,
            textDirection: direction,
          ),
        );
        await tester.pumpAndSettle();
        final ScrollPosition position = _stripPosition(tester);
        position.jumpTo(0.0);
        await tester.pumpAndSettle();
        expect(position.pixels, 0.0);

        // Pulling toward the start (visually to the right in LTR, left in
        // RTL) past the first tab, twice in a row.
        final double sign = direction == TextDirection.ltr ? 1 : -1;
        for (var round = 0; round < 2; round++) {
          final gesture = await _pull(tester, 150 * sign);
          expect(_isExtended(tester, 196.0), isTrue, reason: '$direction');
          await gesture.up();
          await tester.pumpAndSettle();
          _expectNormalRestingStrip(tester);
          expect(position.pixels, position.maxScrollExtent);
          position.jumpTo(0.0);
          await tester.pumpAndSettle();
        }
      }
    });

    testWidgets('a strip no wider than the viewport does not wrap', (
      tester,
    ) async {
      // Two tabs (248 px) in a 300 px viewport only overflow because of
      // the padding, so there is no second cycle worth showing.
      await tester.pumpWidget(
        _buildStrip(
          platform: TargetPlatform.android,
          tabCount: 2,
          tabAlignment: TabAlignment.start,
          padding: const EdgeInsets.symmetric(horizontal: 40),
        ),
      );
      await tester.pumpAndSettle();
      await _scrollToEnd(tester);
      final gesture = await _pull(tester, -150);
      await gesture.up();
      await tester.pumpAndSettle();
      _expectNormalRestingStrip(tester, tabCount: 2);
      final ScrollPosition position = _stripPosition(tester);
      expect(position.pixels, position.maxScrollExtent);
    });
  });

  group('bug 2: strip follows page swipes', () {
    testWidgets('strip tracks the page view smoothly through a wrap', (
      tester,
    ) async {
      final controller = TabController(length: 6, vsync: tester);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _buildStrip(
          platform: TargetPlatform.android,
          tabCount: 6,
          tabWidth: 70,
          controller: controller,
          below: TabBarView(
            controller: controller,
            children: [for (var i = 0; i < 6; i++) Center(child: Text('P$i'))],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _scrollToEnd(tester);

      // Leave the strip wrapped mid-gesture... then release so it settles,
      // and swipe pages while it is doing so and afterwards.
      final gesture = await _pull(tester, -120);
      expect(_isExtended(tester, 6 * 94.0 - 300.0), isTrue);
      await gesture.up();
      await tester.pump();

      // Pixels shift by whole cycles when the strip collapses, which is
      // invisible; measure modulo the cycle width (6 tabs of 94 px). Sample
      // every change of the strip's position, settle animation included.
      const double seam = 6 * 94.0;
      final ScrollPosition strip = _stripPosition(tester);
      double? lastPixels;
      var maxStep = 0.0;
      void onTick() {
        final double pixels = strip.pixels % seam;
        if (lastPixels != null) {
          double step = (pixels - lastPixels!).abs();
          step = step > seam / 2 ? seam - step : step;
          maxStep = step.clamp(maxStep, double.infinity);
        }
        lastPixels = pixels;
      }

      strip.addListener(onTick);
      await tester.pumpAndSettle();
      for (var i = 0; i < 5; i++) {
        await tester.fling(
          find.byType(TabBarView),
          const Offset(-200, 0),
          1500,
        );
        await tester.pumpAndSettle();
      }
      expect(controller.index, 5);
      for (var i = 0; i < 5; i++) {
        await tester.fling(find.byType(TabBarView), const Offset(200, 0), 1500);
        await tester.pumpAndSettle();
      }
      strip.removeListener(onTick);
      expect(controller.index, 0);
      _expectNormalRestingStrip(tester, tabCount: 6);
      // A page-swipe tick moves the strip by a fraction of a tab, and the
      // settle ease covers at most a few tabs in 300 ms (about 100 px on its
      // fastest frame); nothing moves by anything like a whole cycle.
      expect(maxStep, lessThan(150.0));
      expect(_visibleLefts(tester, 'T0', 300), isNotEmpty);
    });

    // Released past halfway it lands on the last page; short of it, it
    // springs back to the first.
    for (final (distance, landing) in [(300.0, 5), (120.0, 0)]) {
      testWidgets('a looping page swipe held across the wrap keeps the strip '
          'still (lands on $landing)', (tester) async {
        final controller = TabController(length: 6, vsync: tester);
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _buildStrip(
            platform: TargetPlatform.android,
            tabCount: 6,
            tabWidth: 70,
            controller: controller,
            below: CyclicTabBarView(
              controller: controller,
              loop: true,
              enableFeedback: false,
              children: [
                for (var i = 0; i < 6; i++) Center(child: Text('P$i')),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Swipe from the first page towards the last and hold halfway.
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(CyclicTabBarView)),
        );
        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(Offset(distance / 10, 0));
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(controller.animation!.value, lessThan(0.0));
        // The strip has widened to follow the page past its first tab.
        expect(_isExtended(tester, 6 * 94.0 - 300.0), isTrue);

        // Holding still, with the odd tremor, must leave the strip where the
        // swipe put it rather than settling and re-extending it over and over.
        final ScrollPosition strip = _stripPosition(tester);
        final double held = strip.pixels;
        for (var i = 0; i < 30; i++) {
          await gesture.moveBy(Offset(i.isEven ? 0.5 : -0.5, 0));
          await tester.pump(const Duration(milliseconds: 16));
          expect(strip.pixels, closeTo(held, 2.0), reason: 'frame $i');
        }

        await gesture.up();
        await tester.pumpAndSettle();
        expect(controller.index, landing);
        _expectNormalRestingStrip(tester, tabCount: 6);
      });
    }

    testWidgets('after a pull-wrap, paging back keeps the selected tab', (
      tester,
    ) async {
      final controller = TabController(
        length: 6,
        vsync: tester,
        initialIndex: 5,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _buildStrip(
          platform: TargetPlatform.android,
          tabCount: 6,
          tabWidth: 70,
          controller: controller,
          below: TabBarView(
            controller: controller,
            children: [for (var i = 0; i < 6; i++) Center(child: Text('P$i'))],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _scrollToEnd(tester);

      // Wrap at T5 and, while the strip is still settling, swipe the page
      // back to T4.
      final gesture = await _pull(tester, -120);
      expect(_isExtended(tester, 6 * 94.0 - 300.0), isTrue);
      await gesture.up();
      await tester.pump();
      await tester.fling(find.byType(TabBarView), const Offset(200, 0), 1500);
      await tester.pumpAndSettle();

      expect(controller.index, 4);
      _expectNormalRestingStrip(tester, tabCount: 6);
      expect(_visibleLefts(tester, 'T4', 300), isNotEmpty);
    });

    testWidgets('tabs relabelled mid-swipe do not jump the strip', (
      tester,
    ) async {
      StateSetter? rebuild;
      final controller = TabController(length: 6, vsync: tester);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _buildStrip(
          platform: TargetPlatform.android,
          tabCount: 6,
          tabWidth: 70,
          controller: controller,
          onBuild: (setState) => rebuild = setState,
          below: TabBarView(
            controller: controller,
            children: [for (var i = 0; i < 6; i++) Center(child: Text('P$i'))],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final drag = await tester.startGesture(
        tester.getCenter(find.byType(TabBarView)),
      );
      await drag.moveBy(const Offset(-150, 0));
      await tester.pump();
      final double midPixels = _stripPosition(tester).pixels;
      rebuild!(() {});
      await tester.pump();
      expect(_stripPosition(tester).pixels, midPixels);
      await drag.moveBy(const Offset(-20, 0));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(controller.index, 1);
    });
  });
}
