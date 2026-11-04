// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// This file vendors Flutter's material tabs implementation from Flutter 3.41.7
// and renames TabBar/TabBarView to CyclicTabBar/CyclicTabBarView as the
// baseline for future cyclic behavior changes.

import 'dart:math' as math;
import 'dart:ui' show SemanticsRole, lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart'
    show Drag, DragStartBehavior, PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

const double _kTabHeight = 46.0;
const double _kTextAndIconTabHeight = 72.0;
const double _kStartOffset = 52.0;

class _TabStyle extends AnimatedWidget {
  const _TabStyle({
    required Animation<double> animation,
    required this.isSelected,
    required this.isPrimary,
    required this.labelColor,
    required this.unselectedLabelColor,
    required this.labelStyle,
    required this.unselectedLabelStyle,
    required this.defaults,
    required this.child,
  }) : super(listenable: animation);

  final TextStyle? labelStyle;
  final TextStyle? unselectedLabelStyle;
  final bool isSelected;
  final bool isPrimary;
  final Color? labelColor;
  final Color? unselectedLabelColor;
  final TabBarThemeData defaults;
  final Widget child;

  WidgetStateColor _resolveWithLabelColor(
    BuildContext context, {
    IconThemeData? iconTheme,
  }) {
    final ThemeData themeData = Theme.of(context);
    final TabBarThemeData tabBarTheme = TabBarTheme.of(context);
    final animation = listenable as Animation<double>;

    // labelStyle.color (and tabBarTheme.labelStyle.color) is not considered
    // as it'll be a breaking change without a possible migration plan. for
    // details: https://github.com/flutter/flutter/pull/109541#issuecomment-1294241417
    Color selectedColor =
        labelColor ??
        tabBarTheme.labelColor ??
        labelStyle?.color ??
        tabBarTheme.labelStyle?.color ??
        defaults.labelColor!;

    final Color unselectedColor;

    if (selectedColor is WidgetStateColor) {
      unselectedColor = selectedColor.resolve(const <WidgetState>{});
      selectedColor = selectedColor.resolve(const <WidgetState>{
        WidgetState.selected,
      });
    } else {
      // unselectedLabelColor and tabBarTheme.unselectedLabelColor are ignored
      // when labelColor is a WidgetStateColor.
      unselectedColor =
          unselectedLabelColor ??
          tabBarTheme.unselectedLabelColor ??
          unselectedLabelStyle?.color ??
          tabBarTheme.unselectedLabelStyle?.color ??
          iconTheme?.color ??
          (themeData.useMaterial3
              ? defaults.unselectedLabelColor!
              : selectedColor.withAlpha(0xB2)); // 70% alpha
    }

    return WidgetStateColor.resolveWith((Set<WidgetState> states) {
      if (states.contains(WidgetState.selected)) {
        return Color.lerp(selectedColor, unselectedColor, animation.value)!;
      }
      return Color.lerp(unselectedColor, selectedColor, animation.value)!;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TabBarThemeData tabBarTheme = TabBarTheme.of(context);
    final animation = listenable as Animation<double>;

    final states = isSelected
        ? const <WidgetState>{WidgetState.selected}
        : const <WidgetState>{};

    // To enable TextStyle.lerp(style1, style2, value), both styles must have
    // the same value of inherit. Force that to be inherit=true here.
    final TextStyle selectedStyle = defaults.labelStyle!
        .merge(labelStyle ?? tabBarTheme.labelStyle)
        .copyWith(inherit: true);
    final TextStyle unselectedStyle = defaults.unselectedLabelStyle!
        .merge(
          unselectedLabelStyle ??
              tabBarTheme.unselectedLabelStyle ??
              labelStyle,
        )
        .copyWith(inherit: true);
    final TextStyle textStyle = isSelected
        ? TextStyle.lerp(selectedStyle, unselectedStyle, animation.value)!
        : TextStyle.lerp(unselectedStyle, selectedStyle, animation.value)!;
    final Color defaultIconColor = switch (theme.colorScheme.brightness) {
      Brightness.light => kDefaultIconDarkColor,
      Brightness.dark => kDefaultIconLightColor,
    };
    final IconThemeData? customIconTheme = switch (IconTheme.of(context)) {
      final IconThemeData iconTheme when iconTheme.color != defaultIconColor =>
        iconTheme,
      _ => null,
    };
    final Color iconColor = _resolveWithLabelColor(
      context,
      iconTheme: customIconTheme,
    ).resolve(states);
    final Color labelColor = _resolveWithLabelColor(context).resolve(states);

    return DefaultTextStyle(
      style: textStyle.copyWith(color: labelColor),
      child: IconTheme.merge(
        data: IconThemeData(
          size: customIconTheme?.size ?? 24.0,
          color: iconColor,
        ),
        child: child,
      ),
    );
  }
}

typedef _LayoutCallback =
    void Function(
      List<double> xOffsets,
      TextDirection textDirection,
      double width,
    );

class _TabLabelBarRenderer extends RenderFlex {
  _TabLabelBarRenderer({
    required super.direction,
    required super.mainAxisSize,
    required super.mainAxisAlignment,
    required super.crossAxisAlignment,
    required TextDirection super.textDirection,
    required super.verticalDirection,
    required this.onPerformLayout,
  });

  _LayoutCallback onPerformLayout;

  @override
  void performLayout() {
    super.performLayout();
    // xOffsets will contain childCount+1 values, giving the offsets of the
    // leading edge of the first tab as the first value, of the leading edge of
    // the each subsequent tab as each subsequent value, and of the trailing
    // edge of the last tab as the last value.
    RenderBox? child = firstChild;
    final xOffsets = <double>[];
    while (child != null) {
      final childParentData = child.parentData! as FlexParentData;
      xOffsets.add(childParentData.offset.dx);
      assert(child.parentData == childParentData);
      child = childParentData.nextSibling;
    }
    assert(textDirection != null);
    switch (textDirection!) {
      case TextDirection.rtl:
        xOffsets.insert(0, size.width);
      case TextDirection.ltr:
        xOffsets.add(size.width);
    }
    onPerformLayout(xOffsets, textDirection!, size.width);
  }
}

// This class and its renderer class only exist to report the widths of the tabs
// upon layout. The tab widths are only used at paint time (see _IndicatorPainter)
// or in response to input.
class _TabLabelBar extends Flex {
  const _TabLabelBar({
    super.children,
    required this.onPerformLayout,
    required super.mainAxisSize,
  }) : super(
         direction: Axis.horizontal,
         mainAxisAlignment: MainAxisAlignment.start,
         crossAxisAlignment: CrossAxisAlignment.center,
         verticalDirection: VerticalDirection.down,
       );

  final _LayoutCallback onPerformLayout;

  @override
  RenderFlex createRenderObject(BuildContext context) {
    return _TabLabelBarRenderer(
      direction: direction,
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: mainAxisSize,
      crossAxisAlignment: crossAxisAlignment,
      textDirection: getEffectiveTextDirection(context)!,
      verticalDirection: verticalDirection,
      onPerformLayout: onPerformLayout,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _TabLabelBarRenderer renderObject,
  ) {
    super.updateRenderObject(context, renderObject);
    renderObject.onPerformLayout = onPerformLayout;
  }
}

double _indexChangeProgress(TabController controller) {
  final double controllerValue = controller.animation!.value;
  final double previousIndex = controller.previousIndex.toDouble();
  final double currentIndex = controller.index.toDouble();

  // The controller's offset is changing because the user is dragging the
  // TabBarView's PageView to the left or right.
  if (!controller.indexIsChanging) {
    return clampDouble((currentIndex - controllerValue).abs(), 0.0, 1.0);
  }

  // The TabController animation's value is changing from previousIndex to currentIndex.
  return (controllerValue - currentIndex).abs() /
      (currentIndex - previousIndex).abs();
}

class _DividerPainter extends CustomPainter {
  _DividerPainter({required this.dividerColor, required this.dividerHeight});

  final Color dividerColor;
  final double dividerHeight;

  @override
  void paint(Canvas canvas, Size size) {
    if (dividerHeight <= 0.0) {
      return;
    }

    final paint = Paint()
      ..color = dividerColor
      ..strokeWidth = dividerHeight;

    canvas.drawLine(
      Offset(0, size.height - (paint.strokeWidth / 2)),
      Offset(size.width, size.height - (paint.strokeWidth / 2)),
      paint,
    );
  }

  @override
  bool shouldRepaint(_DividerPainter oldDelegate) {
    return oldDelegate.dividerColor != dividerColor ||
        oldDelegate.dividerHeight != dividerHeight;
  }
}

// A ChangeNotifier for triggering repaints when async resources load.
class _IndicatorPainterNotifier extends ChangeNotifier {
  void notify() {
    notifyListeners();
  }

  @override
  String toString() => describeIdentity(this);
}

class _IndicatorPainter extends CustomPainter {
  factory _IndicatorPainter({
    required TabController controller,
    required Decoration indicator,
    required TabBarIndicatorSize indicatorSize,
    required List<GlobalKey> tabKeys,
    required _IndicatorPainter? old,
    required EdgeInsetsGeometry indicatorPadding,
    double? indicatorFixedWidth,
    required AlignmentGeometry indicatorFixedWidthAlignment,
    required List<EdgeInsetsGeometry> labelPaddings,
    Color? dividerColor,
    double? dividerHeight,
    required bool showDivider,
    double? devicePixelRatio,
    required TabIndicatorAnimation indicatorAnimation,
    required List<int> indexOffsets,
    required TextDirection textDirection,
  }) {
    /// Initializing [_IndicatorPainterNotifier] here that allows the
    /// repaint notifier to be used in the super constructor call
    /// (within [Listenable.merge]) while also being stored as a private field.
    ///
    /// The notifier is to trigger a repaint when asynchronous resources,
    /// like images in the indicator [Decoration], are finished loading.
    return _IndicatorPainter._(
      controller: controller,
      indicator: indicator,
      indicatorSize: indicatorSize,
      tabKeys: tabKeys,
      old: old,
      indicatorPadding: indicatorPadding,
      indicatorFixedWidth: indicatorFixedWidth,
      indicatorFixedWidthAlignment: indicatorFixedWidthAlignment,
      labelPaddings: labelPaddings,
      dividerColor: dividerColor,
      dividerHeight: dividerHeight,
      showDivider: showDivider,
      devicePixelRatio: devicePixelRatio,
      indicatorAnimation: indicatorAnimation,
      indexOffsets: indexOffsets,
      textDirection: textDirection,
      repaint: _IndicatorPainterNotifier(),
    );
  }

  _IndicatorPainter._({
    required this.controller,
    required this.indicator,
    required this.indicatorSize,
    required this.tabKeys,
    required _IndicatorPainter? old,
    required this.indicatorPadding,
    this.indicatorFixedWidth,
    required this.indicatorFixedWidthAlignment,
    required this.labelPaddings,
    this.dividerColor,
    this.dividerHeight,
    required this.showDivider,
    this.devicePixelRatio,
    required this.indicatorAnimation,
    required this.indexOffsets,
    required this.textDirection,
    required _IndicatorPainterNotifier repaint,
  }) : _repaint = repaint,
       super(
         repaint: Listenable.merge(<Listenable?>[
           controller.animation,
           repaint,
         ]),
       ) {
    assert(debugMaybeDispatchCreated('material', '_IndicatorPainter', this));
    if (old != null) {
      saveTabOffsets(old._currentTabOffsets, old._currentTextDirection);
    }
  }

  final TabController controller;
  final Decoration indicator;
  final TabBarIndicatorSize indicatorSize;
  final EdgeInsetsGeometry indicatorPadding;
  final double? indicatorFixedWidth;
  final AlignmentGeometry indicatorFixedWidthAlignment;
  final List<GlobalKey> tabKeys;
  final List<EdgeInsetsGeometry> labelPaddings;
  final Color? dividerColor;
  final double? dividerHeight;
  final bool showDivider;
  final double? devicePixelRatio;
  final TabIndicatorAnimation indicatorAnimation;
  final List<int> indexOffsets;
  final TextDirection textDirection;
  final _IndicatorPainterNotifier _repaint;

  // _currentTabOffsets and _currentTextDirection are set each time TabBar
  // layout is completed. These values can be null when TabBar contains no
  // tabs, since there are nothing to lay out.
  List<double>? _currentTabOffsets;
  TextDirection? _currentTextDirection;

  BoxPainter? _painter;
  bool _needsPaint = false;
  void markNeedsPaint() {
    _needsPaint = true;
    _repaint.notify();
  }

  void dispose() {
    assert(debugMaybeDispatchDisposed(this));
    _painter?.dispose();
    _repaint.dispose();
  }

  void saveTabOffsets(List<double>? tabOffsets, TextDirection? textDirection) {
    _currentTabOffsets = tabOffsets;
    _currentTextDirection = textDirection;
  }

  // _currentTabOffsets[index] is the offset of the start edge of the tab at index, and
  // _currentTabOffsets[_currentTabOffsets.length] is the end edge of the last tab.
  int get maxTabIndex => _currentTabOffsets!.length - 2;

  double centerOf(int tabIndex) {
    assert(_currentTabOffsets != null);
    assert(_currentTabOffsets!.isNotEmpty);
    assert(tabIndex >= 0);
    assert(tabIndex <= maxTabIndex);
    return (_currentTabOffsets![tabIndex] + _currentTabOffsets![tabIndex + 1]) /
        2.0;
  }

  // The rect of the tab one past either end of the rendered strip: the
  // first or last tab shifted by the strip's width, as if the strip repeated.
  // A looping tab view drives the controller's value past the ends, and
  // sliding the indicator off the strip toward that phantom tab reads as the
  // wrap even when the strip itself has not been extended.
  Rect _phantomIndicatorRect(Size tabBarSize, int tabIndex) {
    assert(tabIndex == -1 || tabIndex == maxTabIndex + 1);
    final double stripWidth =
        (_currentTabOffsets!.last - _currentTabOffsets!.first).abs();
    final bool pastEnd = tabIndex > maxTabIndex;
    final Rect rect = indicatorRect(tabBarSize, pastEnd ? 0 : maxTabIndex);
    final double shift = switch (_currentTextDirection!) {
      TextDirection.ltr => pastEnd ? stripWidth : -stripWidth,
      TextDirection.rtl => pastEnd ? -stripWidth : stripWidth,
    };
    return rect.shift(Offset(shift, 0.0));
  }

  Rect indicatorRect(Size tabBarSize, int tabIndex) {
    assert(_currentTabOffsets != null);
    assert(_currentTextDirection != null);
    assert(_currentTabOffsets!.isNotEmpty);
    if (tabIndex == -1 || tabIndex == maxTabIndex + 1) {
      return _phantomIndicatorRect(tabBarSize, tabIndex);
    }
    assert(tabIndex >= 0);
    assert(tabIndex <= maxTabIndex);
    double tabLeft, tabRight;
    (tabLeft, tabRight) = switch (_currentTextDirection!) {
      TextDirection.rtl => (
        _currentTabOffsets![tabIndex + 1],
        _currentTabOffsets![tabIndex],
      ),
      TextDirection.ltr => (
        _currentTabOffsets![tabIndex],
        _currentTabOffsets![tabIndex + 1],
      ),
    };

    if (indicatorSize == TabBarIndicatorSize.label) {
      final double tabWidth = tabKeys[tabIndex].currentContext!.size!.width;
      final EdgeInsetsGeometry labelPadding = labelPaddings[tabIndex];
      final EdgeInsets insets = labelPadding.resolve(_currentTextDirection);
      final double delta =
          ((tabRight - tabLeft) - (tabWidth + insets.horizontal)) / 2.0;
      tabLeft += delta + insets.left;
      tabRight = tabLeft + tabWidth;
    }

    final EdgeInsets insets = indicatorPadding.resolve(_currentTextDirection);
    final rect = Rect.fromLTWH(
      tabLeft,
      0.0,
      tabRight - tabLeft,
      tabBarSize.height,
    );

    if (!(rect.size >= insets.collapsedSize)) {
      throw FlutterError(
        'indicatorPadding insets should be less than Tab Size\n'
        'Rect Size : ${rect.size}, Insets: $insets',
      );
    }
    return _applyFixedIndicatorWidth(insets.deflateRect(rect));
  }

  Rect _applyFixedIndicatorWidth(Rect rect) {
    final double? fixedWidth = indicatorFixedWidth;
    if (fixedWidth == null) {
      return rect;
    }

    final Alignment resolvedAlignment = indicatorFixedWidthAlignment.resolve(
      _currentTextDirection,
    );
    final double clampedWidth = math.min(fixedWidth, rect.width);
    final double horizontalFactor = clampDouble(
      (resolvedAlignment.x + 1.0) / 2.0,
      0.0,
      1.0,
    );
    final double left =
        rect.left + ((rect.width - clampedWidth) * horizontalFactor);
    return Rect.fromLTWH(left, rect.top, clampedWidth, rect.height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    _needsPaint = false;
    _painter ??= indicator.createBoxPainter(markNeedsPaint);

    if (showDivider && dividerHeight! > 0) {
      final dividerPaint = Paint()
        ..color = dividerColor!
        ..strokeWidth = dividerHeight!;
      final dividerP1 = Offset(0, size.height - (dividerPaint.strokeWidth / 2));
      final dividerP2 = Offset(
        size.width,
        size.height - (dividerPaint.strokeWidth / 2),
      );
      canvas.drawLine(dividerP1, dividerP2, dividerPaint);
    }

    final List<Rect> indicatorRects = indexOffsets
        .map(
          (int indexOffset) =>
              _indicatorRectForOffset(size: size, indexOffset: indexOffset),
        )
        .whereType<Rect>()
        .toList(growable: false);
    assert(indicatorRects.isNotEmpty);

    for (final Rect indicatorRect in indicatorRects) {
      final configuration = ImageConfiguration(
        size: indicatorRect.size,
        textDirection: _currentTextDirection,
        devicePixelRatio: devicePixelRatio,
      );
      _painter!.paint(canvas, indicatorRect.topLeft, configuration);
    }
  }

  Rect? _indicatorRectForOffset({
    required Size size,
    required int indexOffset,
  }) {
    final double value = controller.animation!.value + indexOffset;
    return switch (indicatorAnimation) {
      TabIndicatorAnimation.linear => _applyLinearEffect(
        size: size,
        value: value,
        indexOffset: indexOffset,
      ),
      TabIndicatorAnimation.elastic => _applyElasticEffect(
        size: size,
        value: value,
        indexOffset: indexOffset,
      ),
    };
  }

  /// Applies the linear effect to the indicator.
  Rect? _applyLinearEffect({
    required Size size,
    required double value,
    required int indexOffset,
  }) {
    final double index = controller.index.toDouble() + indexOffset;
    final bool ltr = index > value;
    // One phantom tab past either end so a looping page wrap slides the
    // indicator off the strip instead of back toward the wrong neighbour.
    final int from = (ltr ? value.floor() : value.ceil()).clamp(
      -1,
      maxTabIndex + 1,
    );
    final int to = (ltr ? from + 1 : from - 1).clamp(-1, maxTabIndex + 1);
    final Rect fromRect = indicatorRect(size, from);
    final Rect toRect = indicatorRect(size, to);
    return Rect.lerp(fromRect, toRect, (value - from).abs());
  }

  // Ease out sine (decelerating).
  double decelerateInterpolation(double fraction) {
    return math.sin((fraction * math.pi) / 2.0);
  }

  // Ease in sine (accelerating).
  double accelerateInterpolation(double fraction) {
    return 1.0 - math.cos((fraction * math.pi) / 2.0);
  }

  /// Applies the elastic effect to the indicator.
  Rect? _applyElasticEffect({
    required Size size,
    required double value,
    required int indexOffset,
  }) {
    final double index = controller.index.toDouble() + indexOffset;
    double progressLeft = (index - value).abs();

    final int to = progressLeft == 0.0 || !controller.indexIsChanging
        ? switch (textDirection) {
            TextDirection.ltr => value.ceil(),
            TextDirection.rtl => value.floor(),
          }.clamp(-1, maxTabIndex + 1)
        : controller.index + indexOffset;
    final int from = progressLeft == 0.0 || !controller.indexIsChanging
        ? switch (textDirection) {
            TextDirection.ltr => (to - 1),
            TextDirection.rtl => (to + 1),
          }.clamp(-1, maxTabIndex + 1)
        : controller.previousIndex + indexOffset;
    final Rect toRect = indicatorRect(size, to);
    final Rect fromRect = indicatorRect(size, from);
    final Rect rect = Rect.lerp(fromRect, toRect, (value - from).abs())!;

    // If the tab animation is completed, there is no need to stretch the indicator
    // This only works for the tab change animation via tab index, not when
    // dragging a [CyclicTabBarView], but it's still ok, to avoid unnecessary calculations.
    if (controller.animation!.isCompleted) {
      return rect;
    }

    final double tabChangeProgress;

    if (controller.indexIsChanging) {
      final int tabsDelta = (controller.index - controller.previousIndex).abs();
      if (tabsDelta != 0) {
        progressLeft /= tabsDelta;
      }
      tabChangeProgress = 1 - clampDouble(progressLeft, 0.0, 1.0);
    } else {
      tabChangeProgress = (index - value).abs();
    }

    // If the animation has finished, there is no need to apply the stretch effect.
    if (tabChangeProgress == 1.0) {
      return rect;
    }

    final double leftFraction;
    final double rightFraction;
    final bool isMovingRight = switch (textDirection) {
      TextDirection.ltr =>
        controller.indexIsChanging ? index > value : value > index,
      TextDirection.rtl =>
        controller.indexIsChanging ? value > index : index > value,
    };
    if (isMovingRight) {
      leftFraction = accelerateInterpolation(tabChangeProgress);
      rightFraction = decelerateInterpolation(tabChangeProgress);
    } else {
      leftFraction = decelerateInterpolation(tabChangeProgress);
      rightFraction = accelerateInterpolation(tabChangeProgress);
    }

    final double lerpRectLeft;
    final double lerpRectRight;

    // The controller.indexIsChanging is true when the Tab is pressed, instead of swipe to change tabs.
    // If the tab is pressed then only lerp between fromRect and toRect.
    if (controller.indexIsChanging) {
      lerpRectLeft = lerpDouble(fromRect.left, toRect.left, leftFraction)!;
      lerpRectRight = lerpDouble(fromRect.right, toRect.right, rightFraction)!;
    } else {
      // Switch the Rect left and right lerp order based on swipe direction.
      lerpRectLeft = switch (isMovingRight) {
        true => lerpDouble(fromRect.left, toRect.left, leftFraction)!,
        false => lerpDouble(toRect.left, fromRect.left, leftFraction)!,
      };
      lerpRectRight = switch (isMovingRight) {
        true => lerpDouble(fromRect.right, toRect.right, rightFraction)!,
        false => lerpDouble(toRect.right, fromRect.right, rightFraction)!,
      };
    }

    return Rect.fromLTRB(lerpRectLeft, rect.top, lerpRectRight, rect.bottom);
  }

  @override
  bool shouldRepaint(_IndicatorPainter old) {
    return _needsPaint ||
        controller != old.controller ||
        indicator != old.indicator ||
        tabKeys.length != old.tabKeys.length ||
        !listEquals(indexOffsets, old.indexOffsets) ||
        (!listEquals(_currentTabOffsets, old._currentTabOffsets)) ||
        _currentTextDirection != old._currentTextDirection;
  }
}

class _ChangeAnimation extends Animation<double>
    with AnimationWithParentMixin<double> {
  _ChangeAnimation(this.controller);

  final TabController controller;

  @override
  Animation<double> get parent => controller.animation!;

  @override
  void removeStatusListener(AnimationStatusListener listener) {
    if (controller.animation != null) {
      super.removeStatusListener(listener);
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    if (controller.animation != null) {
      super.removeListener(listener);
    }
  }

  @override
  double get value => _indexChangeProgress(controller);
}

class _DragAnimation extends Animation<double>
    with AnimationWithParentMixin<double> {
  _DragAnimation(this.controller, this.index);

  final TabController controller;
  final int index;

  @override
  Animation<double> get parent => controller.animation!;

  @override
  void removeStatusListener(AnimationStatusListener listener) {
    if (controller.animation != null) {
      super.removeStatusListener(listener);
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    if (controller.animation != null) {
      super.removeListener(listener);
    }
  }

  @override
  double get value {
    assert(!controller.indexIsChanging);
    final double controllerValue = controller.animation!.value;
    final double length = controller.length.toDouble();
    // Distance to this tab, also measured across the wrap, so that while a
    // looping tab view carries the value past the last tab the first tab
    // fades in. Within the normal range the wrapped distances are at least a
    // whole tab, so the result is unchanged there.
    final double distance = (controllerValue - index.toDouble()).abs();
    final double wrappedDistance = math.min(
      (controllerValue - index.toDouble() - length).abs(),
      (controllerValue - index.toDouble() + length).abs(),
    );
    return clampDouble(math.min(distance, wrappedDistance), 0.0, 1.0);
  }
}

// This class, and TabBarScrollController, only exist to handle the case
// where a scrollable TabBar has a non-zero initialIndex. In that case we can
// only compute the scroll position's initial scroll offset (the "correct"
// pixels value) after the TabBar viewport width and scroll limits are known.
class _TabBarScrollPosition extends ScrollPositionWithSingleContext {
  _TabBarScrollPosition({
    required super.physics,
    required super.context,
    required super.oldPosition,
    required this.tabBar,
  }) : super(initialPixels: null);

  final _TabBarState tabBar;

  bool _viewportDimensionWasNonZero = false;

  // The scroll position should be adjusted at least once.
  bool _needsPixelsCorrection = true;

  // How far the activity in progress has moved pixels since the tab bar
  // scheduled a pixels correction, so the correction can carry that motion
  // over instead of snapping back by the frames in between. Only activity
  // driven motion goes through setPixels; the viewport's own clamping during
  // layout does not and must not count.
  double _driftSinceCorrection = 0.0;

  // Mirrors the private activity so a drag can be told apart from a fling or
  // a driven animation without touching test-only API.
  ScrollActivity? _trackedActivity;

  bool get isDriven => _trackedActivity is DrivenScrollActivity;

  @override
  void beginActivity(ScrollActivity? newActivity) {
    if (newActivity != null) {
      _trackedActivity = newActivity;
    }
    super.beginActivity(newActivity);
  }

  // The drag controller of the drag in progress, to tell a finger lift
  // (lastDetails is a DragEndDetails) from a cancelled drag.
  ScrollDragController? _dragController;

  @override
  Drag drag(DragStartDetails details, VoidCallback dragCancelCallback) {
    final Drag drag = super.drag(details, dragCancelCallback);
    _dragController = drag is ScrollDragController ? drag : null;
    return drag;
  }

  // A drag ends by going ballistic with the finger's release velocity; that
  // velocity decides whether a stretch was a deliberate pull or a flick. A
  // cancelled drag (another recognizer won the arena) goes ballistic too,
  // with zero velocity, but is no release at all.
  @override
  void goBallistic(double velocity) {
    final bool releasedDrag =
        _trackedActivity is DragScrollActivity &&
        _dragController?.lastDetails is DragEndDetails;
    super.goBallistic(velocity);
    if (releasedDrag) {
      tabBar._handleDragReleased(velocity);
    }
  }

  @override
  double setPixels(double newPixels) {
    final double before = hasPixels ? pixels : newPixels;
    final double result = super.setPixels(newPixels);
    _driftSinceCorrection += pixels - before;
    return result;
  }

  void markNeedsPixelsCorrection() {
    _needsPixelsCorrection = true;
    _driftSinceCorrection = 0.0;
  }

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    var result = true;
    if (!_viewportDimensionWasNonZero) {
      _viewportDimensionWasNonZero = viewportDimension != 0.0;
    }
    final double? pendingPixelsCorrection = tabBar
        ._consumePendingPixelsCorrection(
          _driftSinceCorrection,
          minScrollExtent,
          maxScrollExtent,
        );
    _driftSinceCorrection = 0.0;
    // If the viewport never had a non-zero dimension, we just want to jump
    // to the initial scroll position to avoid strange scrolling effects in
    // release mode: the viewport temporarily may have a dimension of zero
    // before the actual dimension is calculated. In that scenario, setting
    // the actual dimension would cause a strange scroll effect without this
    // guard because the super call below would start a ballistic scroll activity.
    if (pendingPixelsCorrection != null) {
      _needsPixelsCorrection = false;
      correctPixels(pendingPixelsCorrection);
      result = false;
    } else if (!_viewportDimensionWasNonZero || _needsPixelsCorrection) {
      _needsPixelsCorrection = false;
      correctPixels(
        tabBar._initialScrollOffset(
          viewportDimension,
          minScrollExtent,
          maxScrollExtent,
        ),
      );
      result = false;
    }
    return super.applyContentDimensions(minScrollExtent, maxScrollExtent) &&
        result;
  }
}

// This class, and TabBarScrollPosition, only exist to handle the case
// where a scrollable TabBar has a non-zero initialIndex.
class _TabBarScrollController extends ScrollController {
  _TabBarScrollController(this.tabBar);

  final _TabBarState tabBar;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _TabBarScrollPosition(
      physics: physics,
      context: context,
      oldPosition: oldPosition,
      tabBar: tabBar,
    );
  }
}

/// A Material Design primary tab bar.
///
/// Primary tabs are placed at the top of the content pane under a top app bar.
/// They display the main content destinations.
///
/// Typically created as the [AppBar.bottom] part of an [AppBar] and in
/// conjunction with a [CyclicTabBarView].
///
/// {@youtube 560 315 https://www.youtube.com/watch?v=POtoEH-5l40}
/// Requires one of its ancestors to be a [Material] widget.
///
/// Uses values from [TabBarThemeData] if it is set in the current context.
///
/// {@tool dartpad}
/// This sample shows the implementation of [CyclicTabBar] and [CyclicTabBarView] using a [DefaultTabController].
/// Each [Tab] corresponds to a child of the [CyclicTabBarView] in the order they are written.
///
/// ** See code in examples/api/lib/material/tabs/tab_bar.0.dart **
/// {@end-tool}
///
/// {@tool dartpad}
/// [CyclicTabBar] can also be implemented by using a [TabController] which provides more options
/// to control the behavior of the [CyclicTabBar] and [CyclicTabBarView]. This can be used instead of
/// a [DefaultTabController], demonstrated below.
///
/// ** See code in examples/api/lib/material/tabs/tab_bar.1.dart **
/// {@end-tool}
///
/// {@tool dartpad}
/// This sample showcases nested Material 3 [CyclicTabBar]s. It consists of a primary
/// [CyclicTabBar] with nested a secondary [CyclicTabBar]. The primary [CyclicTabBar] uses a
/// [DefaultTabController] while the secondary [CyclicTabBar] uses a [TabController].
///
/// ** See code in examples/api/lib/material/tabs/tab_bar.2.dart **
/// {@end-tool}
///
/// See also:
///
///  * [CyclicTabBar.secondary], for a secondary tab bar.
///  * [CyclicTabBarView], which displays page views that correspond to each tab.
///  * [TabController], which coordinates tab selection between a [CyclicTabBar] and a [CyclicTabBarView].
///  * https://m3.material.io/components/tabs/overview, the Material 3
///     tab bar specification.
class CyclicTabBar extends StatefulWidget implements PreferredSizeWidget {
  /// Creates a Material Design primary tab bar.
  ///
  /// The length of the [tabs] argument must match the [controller]'s
  /// [TabController.length].
  ///
  /// If a [TabController] is not provided, then there must be a
  /// [DefaultTabController] ancestor.
  ///
  /// The [indicatorWeight] parameter defaults to 2.
  ///
  /// The [indicatorPadding] parameter defaults to [EdgeInsets.zero].
  ///
  /// If [indicator] is not null or provided from [TabBarTheme],
  /// then [indicatorWeight] and [indicatorColor] are ignored.
  const CyclicTabBar({
    super.key,
    required this.tabs,
    this.controller,
    this.isScrollable = false,
    this.padding,
    this.indicatorColor,
    this.automaticIndicatorColorAdjustment = true,
    this.indicatorWeight = 2.0,
    this.indicatorPadding = EdgeInsets.zero,
    this.indicator,
    this.indicatorSize,
    this.indicatorFixedWidth,
    this.indicatorFixedWidthAlignment = Alignment.center,
    this.dividerColor,
    this.dividerHeight,
    this.labelColor,
    this.labelStyle,
    this.labelPadding,
    this.unselectedLabelColor,
    this.unselectedLabelStyle,
    this.dragStartBehavior = DragStartBehavior.start,
    this.overlayColor,
    this.mouseCursor,
    this.enableFeedback,
    this.onTap,
    this.onHover,
    this.onFocusChange,
    this.physics,
    this.splashFactory,
    this.splashBorderRadius,
    this.tabAlignment,
    this.textScaler,
    this.indicatorAnimation,
  }) : _isPrimary = true,
       assert(indicator != null || (indicatorWeight > 0.0)),
       assert(indicatorFixedWidth == null || indicatorFixedWidth > 0.0);

  /// Creates a Material Design secondary tab bar.
  ///
  /// Secondary tabs are used within a content area to further separate related
  /// content and establish hierarchy.
  ///
  /// {@tool dartpad}
  /// This sample showcases nested Material 3 [CyclicTabBar]s. It consists of a primary
  /// [CyclicTabBar] with nested a secondary [CyclicTabBar]. The primary [CyclicTabBar] uses a
  /// [DefaultTabController] while the secondary [CyclicTabBar] uses a [TabController].
  ///
  /// ** See code in examples/api/lib/material/tabs/tab_bar.2.dart **
  /// {@end-tool}
  ///
  /// See also:
  ///
  ///  * [CyclicTabBar], for a primary tab bar.
  ///  * [CyclicTabBarView], which displays page views that correspond to each tab.
  ///  * [TabController], which coordinates tab selection between a [CyclicTabBar] and a [CyclicTabBarView].
  ///  * https://m3.material.io/components/tabs/overview, the Material 3
  ///     tab bar specification.
  const CyclicTabBar.secondary({
    super.key,
    required this.tabs,
    this.controller,
    this.isScrollable = false,
    this.padding,
    this.indicatorColor,
    this.automaticIndicatorColorAdjustment = true,
    this.indicatorWeight = 2.0,
    this.indicatorPadding = EdgeInsets.zero,
    this.indicator,
    this.indicatorSize,
    this.indicatorFixedWidth,
    this.indicatorFixedWidthAlignment = Alignment.center,
    this.dividerColor,
    this.dividerHeight,
    this.labelColor,
    this.labelStyle,
    this.labelPadding,
    this.unselectedLabelColor,
    this.unselectedLabelStyle,
    this.dragStartBehavior = DragStartBehavior.start,
    this.overlayColor,
    this.mouseCursor,
    this.enableFeedback,
    this.onTap,
    this.onHover,
    this.onFocusChange,
    this.physics,
    this.splashFactory,
    this.splashBorderRadius,
    this.tabAlignment,
    this.textScaler,
    this.indicatorAnimation,
  }) : _isPrimary = false,
       assert(indicator != null || (indicatorWeight > 0.0)),
       assert(indicatorFixedWidth == null || indicatorFixedWidth > 0.0);

  /// Typically a list of two or more [Tab] widgets.
  ///
  /// The length of this list must match the [controller]'s [TabController.length]
  /// and the length of the [CyclicTabBarView.children] list.
  final List<Widget> tabs;

  /// This widget's selection and animation state.
  ///
  /// If [TabController] is not provided, then the value of [DefaultTabController.of]
  /// will be used.
  final TabController? controller;

  /// Whether this tab bar can be scrolled horizontally.
  ///
  /// If [isScrollable] is true, then each tab is as wide as needed for its label
  /// and the entire [CyclicTabBar] is scrollable. Otherwise each tab gets an equal
  /// share of the available space.
  final bool isScrollable;

  /// The amount of space by which to inset the tab bar.
  ///
  /// When [isScrollable] is false, this will yield the same result as if [CyclicTabBar] was wrapped
  /// in a [Padding] widget. When [isScrollable] is true, the scrollable itself is inset,
  /// allowing the padding to scroll with the tab bar, rather than enclosing it.
  final EdgeInsetsGeometry? padding;

  /// The color of the line that appears below the selected tab.
  ///
  /// If this parameter is null, then the value of the Theme's indicatorColor
  /// property is used.
  ///
  /// If [indicator] is specified or provided from [TabBarThemeData],
  /// this property is ignored.
  final Color? indicatorColor;

  /// The thickness of the line that appears below the selected tab.
  ///
  /// The value of this parameter must be greater than zero.
  ///
  /// If [ThemeData.useMaterial3] is true and [CyclicTabBar] is used to create a
  /// primary tab bar, the default value is 3.0. If the provided value is less
  /// than 3.0, the default value is used.
  ///
  /// If [ThemeData.useMaterial3] is true and [CyclicTabBar.secondary] is used to
  /// create a secondary tab bar, the default value is 2.0.
  ///
  /// If [ThemeData.useMaterial3] is false, the default value is 2.0.
  ///
  /// If [indicator] is specified or provided from [TabBarThemeData],
  /// this property is ignored.
  final double indicatorWeight;

  /// The padding for the indicator.
  ///
  /// The default value of this property is [EdgeInsets.zero].
  ///
  /// For [isScrollable] tab bars, specifying [kTabLabelPadding] will align
  /// the indicator with the tab's text for [Tab] widgets and all but the
  /// shortest [Tab.text] values.
  final EdgeInsetsGeometry indicatorPadding;

  /// Defines the appearance of the selected tab indicator.
  ///
  /// If [indicator] is specified or provided from [TabBarThemeData],
  /// the [indicatorColor] and [indicatorWeight] properties are ignored.
  ///
  /// The default, underline-style, selected tab indicator can be defined with
  /// [UnderlineTabIndicator].
  ///
  /// The indicator's size is based on the tab's bounds. If [indicatorSize]
  /// is [TabBarIndicatorSize.tab] the tab's bounds are as wide as the space
  /// occupied by the tab in the tab bar. If [indicatorSize] is
  /// [TabBarIndicatorSize.label], then the tab's bounds are only as wide as
  /// the tab widget itself.
  ///
  /// See also:
  ///
  ///  * [splashBorderRadius], which defines the clipping radius of the splash
  ///    and is generally used with [BoxDecoration.borderRadius].
  final Decoration? indicator;

  /// Whether this tab bar should automatically adjust the [indicatorColor].
  ///
  /// The default value of this property is true.
  ///
  /// If [automaticIndicatorColorAdjustment] is true,
  /// then the [indicatorColor] will be automatically adjusted to [Colors.white]
  /// when the [indicatorColor] is same as [Material.color] of the [Material]
  /// parent widget.
  final bool automaticIndicatorColorAdjustment;

  /// Defines how the selected tab indicator's size is computed.
  ///
  /// The size of the selected tab indicator is defined relative to the
  /// tab's overall bounds if [indicatorSize] is [TabBarIndicatorSize.tab]
  /// (the default) or relative to the bounds of the tab's widget if
  /// [indicatorSize] is [TabBarIndicatorSize.label].
  ///
  /// The selected tab's location appearance can be refined further with
  /// the [indicatorColor], [indicatorWeight], [indicatorPadding], and
  /// [indicator] properties.
  final TabBarIndicatorSize? indicatorSize;

  /// The fixed width for the selected tab indicator.
  ///
  /// When non-null, the indicator width is clamped to the available tab or
  /// label bounds after [indicatorPadding] is applied, so narrow tabs never
  /// overflow. This sizing is applied to both the default underline indicator
  /// and custom [indicator] decorations.
  final double? indicatorFixedWidth;

  /// The horizontal alignment for a fixed-width tab indicator.
  ///
  /// This is only used when [indicatorFixedWidth] is non-null. The vertical
  /// component is ignored.
  final AlignmentGeometry indicatorFixedWidthAlignment;

  /// The color of the divider.
  ///
  /// If the [dividerColor] is [Colors.transparent], then the divider will not be drawn.
  ///
  /// If null and [ThemeData.useMaterial3] is false, [TabBarThemeData.dividerColor]
  /// color is used. If that is null and [ThemeData.useMaterial3] is true,
  /// [ColorScheme.outlineVariant] will be used, otherwise divider will not be drawn.
  final Color? dividerColor;

  /// The height of the divider.
  ///
  /// If the [dividerHeight] is zero or negative, then the divider will not be drawn.
  ///
  /// If null and [ThemeData.useMaterial3] is true, [TabBarThemeData.dividerHeight] is used.
  /// If that is also null and [ThemeData.useMaterial3] is true, 1.0 will be used.
  /// Otherwise divider will not be drawn.
  final double? dividerHeight;

  /// The color of selected tab labels.
  ///
  /// If null, then [TabBarThemeData.labelColor] is used. If that is also null and
  /// [ThemeData.useMaterial3] is true, [ColorScheme.primary] will be used,
  /// otherwise the color of the [ThemeData.primaryTextTheme]'s
  /// [TextTheme.bodyLarge] text color is used.
  ///
  /// If [labelColor] (or, if null, [TabBarThemeData.labelColor]) is a
  /// [WidgetStateColor], then the effective tab color will depend on the
  /// [WidgetState.selected] state, i.e. if the [Tab] is selected or not,
  /// ignoring [unselectedLabelColor] even if it's non-null.
  ///
  /// When this color or the [TabBarThemeData.labelColor] is specified, it overrides
  /// the [TextStyle.color] specified for the [labelStyle] or the
  /// [TabBarThemeData.labelStyle].
  ///
  /// See also:
  ///
  ///   * [unselectedLabelColor], for color of unselected tab labels.
  final Color? labelColor;

  /// The color of unselected tab labels.
  ///
  /// If [labelColor] (or, if null, [TabBarThemeData.labelColor]) is a
  /// [WidgetStateColor], then the unselected tabs are rendered with
  /// that [WidgetStateColor]'s resolved color for unselected state, even if
  /// [unselectedLabelColor] is non-null.
  ///
  /// If null, then [TabBarThemeData.unselectedLabelColor] is used. If that is also
  /// null and [ThemeData.useMaterial3] is true, [ColorScheme.onSurfaceVariant]
  /// will be used, otherwise unselected tab labels are rendered with
  /// [labelColor] at 70% opacity.
  ///
  /// When this color or the [TabBarThemeData.unselectedLabelColor] is specified, it
  /// overrides the [TextStyle.color] specified for the [unselectedLabelStyle]
  /// or the [TabBarThemeData.unselectedLabelStyle].
  ///
  /// See also:
  ///
  ///  * [labelColor], for color of selected tab labels.
  final Color? unselectedLabelColor;

  /// The text style of the selected tab labels.
  ///
  /// The color specified in [labelStyle] and [TabBarThemeData.labelStyle] is used
  /// to style the label when [labelColor] or [TabBarThemeData.labelColor] are not
  /// specified.
  ///
  /// If [unselectedLabelStyle] is null, then this text style will be used for
  /// both selected and unselected label styles.
  ///
  /// If this property is null, then [TabBarThemeData.labelStyle] will be used.
  ///
  /// If that is also null and [ThemeData.useMaterial3] is true, [TextTheme.titleSmall]
  /// will be used, otherwise the text style of the [ThemeData.primaryTextTheme]'s
  /// [TextTheme.bodyLarge] definition is used.
  final TextStyle? labelStyle;

  /// The text style of the unselected tab labels.
  ///
  /// The color specified in [unselectedLabelStyle] and [TabBarThemeData.unselectedLabelStyle]
  /// is used to style the label when [unselectedLabelColor] or [TabBarThemeData.unselectedLabelColor]
  /// are not specified.
  ///
  /// If this property is null, then [TabBarThemeData.unselectedLabelStyle] will be used.
  ///
  /// If that is also null and [ThemeData.useMaterial3] is true, [TextTheme.titleSmall]
  /// will be used, otherwise then the [labelStyle] value is used. If [labelStyle] is null,
  /// the text style of the [ThemeData.primaryTextTheme]'s [TextTheme.bodyLarge]
  /// definition is used.
  final TextStyle? unselectedLabelStyle;

  /// The padding added to each of the tab labels.
  ///
  /// If there are few tabs with both icon and text and few
  /// tabs with only icon or text, this padding is vertically
  /// adjusted to provide uniform padding to all tabs.
  ///
  /// If this property is null, then [kTabLabelPadding] is used.
  final EdgeInsetsGeometry? labelPadding;

  /// Defines the ink response focus, hover, and splash colors.
  ///
  /// If non-null, it is resolved against one of [WidgetState.focused],
  /// [WidgetState.hovered], and [WidgetState.pressed].
  ///
  /// [WidgetState.pressed] triggers a ripple (an ink splash), per
  /// the current Material Design spec.
  ///
  /// If the overlay color is null or resolves to null, then if [ThemeData.useMaterial3] is
  /// false, the default values for [InkResponse.focusColor], [InkResponse.hoverColor], [InkResponse.splashColor],
  /// and [InkResponse.highlightColor] will be used instead. If [ThemeData.useMaterial3]
  /// if true, the default values are:
  /// * selected:
  ///   * pressed - ThemeData.colorScheme.primary(0.1)
  ///   * hovered - ThemeData.colorScheme.primary(0.08)
  ///   * focused - ThemeData.colorScheme.primary(0.1)
  /// * pressed - ThemeData.colorScheme.primary(0.1)
  /// * hovered - ThemeData.colorScheme.onSurface(0.08)
  /// * focused - ThemeData.colorScheme.onSurface(0.1)
  final WidgetStateProperty<Color?>? overlayColor;

  /// {@macro flutter.widgets.scrollable.dragStartBehavior}
  final DragStartBehavior dragStartBehavior;

  /// {@template flutter.material.tabs.mouseCursor}
  /// The cursor for a mouse pointer when it enters or is hovering over the
  /// individual tab widgets.
  ///
  /// If [mouseCursor] is a [WidgetStateMouseCursor],
  /// [WidgetStateProperty.resolve] is used for the following [WidgetState]s:
  ///
  ///  * [WidgetState.selected].
  /// {@endtemplate}
  ///
  /// If null, then the value of [TabBarThemeData.mouseCursor] is used. If
  /// that is also null, then [WidgetStateMouseCursor.clickable] is used.
  final MouseCursor? mouseCursor;

  /// Whether detected gestures should provide acoustic and/or haptic feedback.
  ///
  /// For example, on Android a tap will produce a clicking sound and a long-press
  /// will produce a short vibration, when feedback is enabled.
  ///
  /// Defaults to true.
  final bool? enableFeedback;

  /// An optional callback that's called when the [CyclicTabBar] is tapped.
  ///
  /// The callback is applied to the index of the tab where the tap occurred.
  ///
  /// This callback has no effect on the default handling of taps. It's for
  /// applications that want to do a little extra work when a tab is tapped,
  /// even if the tap doesn't change the TabController's index. TabBar [onTap]
  /// callbacks should not make changes to the TabController since that would
  /// interfere with the default tap handler.
  final ValueChanged<int>? onTap;

  /// An optional callback that's called when a [Tab]'s hover state in the
  /// [CyclicTabBar] changes.
  ///
  /// Called when a pointer enters or exits the ink response area of the [Tab].
  ///
  /// The value passed to the callback is true if a pointer has entered the
  /// [Tab] at `index` and false if a pointer has exited.
  ///
  /// When hover is moved from one tab directly to another, this will be called
  /// twice. First to represent hover exiting the initial tab, and then second
  /// for the pointer entering hover over the next tab.
  ///
  /// {@tool dartpad}
  /// This sample shows how to customize a [Tab] in response to hovering over a
  /// [CyclicTabBar].
  ///
  /// ** See code in examples/api/lib/material/tabs/tab_bar.onHover.dart **
  /// {@end-tool}
  final TabValueChanged<bool>? onHover;

  /// An optional callback that's called when a [Tab]'s focus state in the
  /// [CyclicTabBar] changes.
  ///
  /// Called when the node for the [Tab] at `index` gains or loses focus.
  ///
  /// The value passed to the callback is true if the node has gained focus for
  /// the [Tab] at `index` and false if focus has been lost.
  ///
  /// When focus is moved from one tab directly to another, this will be called
  /// twice. First to represent focus being lost by the initially focused tab,
  /// and then second for the next tab gaining focus.
  ///
  /// {@tool dartpad}
  /// This sample shows how to customize a [Tab] based on focus traversal in
  /// enclosing [CyclicTabBar].
  ///
  /// ** See code in examples/api/lib/material/tabs/tab_bar.onFocusChange.dart **
  /// {@end-tool}
  final TabValueChanged<bool>? onFocusChange;

  /// How the [CyclicTabBar]'s scroll view should respond to user input.
  ///
  /// For example, determines how the scroll view continues to animate after the
  /// user stops dragging the scroll view.
  ///
  /// Defaults to matching platform conventions.
  final ScrollPhysics? physics;

  /// Creates the tab bar's [InkWell] splash factory, which defines
  /// the appearance of "ink" splashes that occur in response to taps.
  ///
  /// Use [NoSplash.splashFactory] to defeat ink splash rendering. For example
  /// to defeat both the splash and the hover/pressed overlay, but not the
  /// keyboard focused overlay:
  ///
  /// ```dart
  /// TabBar(
  ///   splashFactory: NoSplash.splashFactory,
  ///   overlayColor: WidgetStateProperty.resolveWith<Color?>(
  ///     (Set<WidgetState> states) {
  ///       return states.contains(WidgetState.focused) ? null : Colors.transparent;
  ///     },
  ///   ),
  ///   tabs: const <Widget>[
  ///     // ...
  ///   ],
  /// )
  /// ```
  final InteractiveInkFeatureFactory? splashFactory;

  /// Defines the clipping radius of splashes that extend outside the bounds of the tab.
  ///
  /// This can be useful to match the [BoxDecoration.borderRadius] provided as [indicator].
  ///
  /// ```dart
  /// TabBar(
  ///   indicator: BoxDecoration(
  ///     borderRadius: BorderRadius.circular(40),
  ///   ),
  ///   splashBorderRadius: BorderRadius.circular(40),
  ///   tabs: const <Widget>[
  ///     // ...
  ///   ],
  /// )
  /// ```
  ///
  /// If this property is null, it is interpreted as [BorderRadius.zero].
  final BorderRadius? splashBorderRadius;

  /// Specifies the horizontal alignment of the tabs within a [CyclicTabBar].
  ///
  /// If [CyclicTabBar.isScrollable] is false, only [TabAlignment.fill] and
  /// [TabAlignment.center] are supported. Otherwise an exception is thrown.
  ///
  /// If [CyclicTabBar.isScrollable] is true, only [TabAlignment.start], [TabAlignment.startOffset],
  /// and [TabAlignment.center] are supported. Otherwise an exception is thrown.
  ///
  /// If this is null, then the value of [TabBarThemeData.tabAlignment] is used.
  ///
  /// If [TabBarThemeData.tabAlignment] is null and [ThemeData.useMaterial3] is true,
  /// then [TabAlignment.startOffset] is used if [isScrollable] is true,
  /// otherwise [TabAlignment.fill] is used.
  ///
  /// If [TabBarThemeData.tabAlignment] is null and [ThemeData.useMaterial3] is false,
  /// then [TabAlignment.center] is used if [isScrollable] is true,
  /// otherwise [TabAlignment.fill] is used.
  final TabAlignment? tabAlignment;

  /// Specifies the text scaling behavior for the [Tab] label.
  ///
  /// If this is null, then the value of [TabBarThemeData.textScaler] is used. If that is
  /// also null, then the text scaling behavior is determined by the [MediaQueryData.textScaler]
  /// from the ambient [MediaQuery], or 1.0 if there is no [MediaQuery] in scope.
  ///
  /// See also:
  ///   * [TextScaler], which is used to scale text based on the device's text scale factor.
  final TextScaler? textScaler;

  /// Specifies the animation behavior of the tab indicator.
  ///
  /// If this is null, then the value of [TabBarThemeData.indicatorAnimation] is used.
  /// If that is also null, then the tab indicator will animate linearly if the
  /// [indicatorSize] is [TabBarIndicatorSize.tab], otherwise it will animate
  /// with an elastic effect if the [indicatorSize] is [TabBarIndicatorSize.label].
  ///
  /// {@tool dartpad}
  /// This sample shows how to customize the animation behavior of the tab indicator
  /// by using the [indicatorAnimation] property.
  ///
  /// ** See code in examples/api/lib/material/tabs/tab_bar.indicator_animation.0.dart **
  /// {@end-tool}
  ///
  /// See also:
  ///
  ///  * [TabIndicatorAnimation], which specifies the animation behavior of the tab indicator.
  final TabIndicatorAnimation? indicatorAnimation;

  /// A size whose height depends on if the tabs have both icons and text.
  ///
  /// [AppBar] uses this size to compute its own preferred size.
  @override
  Size get preferredSize {
    double maxHeight = _kTabHeight;
    for (final Widget item in tabs) {
      if (item is PreferredSizeWidget) {
        final double itemHeight = item.preferredSize.height;
        maxHeight = math.max(itemHeight, maxHeight);
      }
    }
    return Size.fromHeight(maxHeight + indicatorWeight);
  }

  /// Returns whether the [CyclicTabBar] contains a tab with both text and icon.
  ///
  /// [CyclicTabBar] uses this to give uniform padding to all tabs in cases where
  /// there are some tabs with both text and icon and some which contain only
  /// text or icon.
  bool get tabHasTextAndIcon {
    for (final Widget item in tabs) {
      if (item is PreferredSizeWidget) {
        if (item.preferredSize.height == _kTextAndIconTabHeight) {
          return true;
        }
      }
    }
    return false;
  }

  /// Whether this tab bar is a primary tab bar.
  ///
  /// Otherwise, it is a secondary tab bar.
  final bool _isPrimary;

  @override
  State<CyclicTabBar> createState() => _TabBarState();
}

enum _CyclicStretchDirection { leading, trailing }

// `normal` is the plain Flutter strip with hard edges. The extended modes
// render two copies of the tabs for the duration of one wrap: the original
// cycle first and the next one after it (`extendedTrailing`), or the previous
// cycle first and the original after it (`extendedLeading`). They last only
// until the scroll settles; then the strip rests inside one copy and collapses
// back to `normal`, edges included, so the next wrap needs another deliberate
// pull.
enum _CyclicTabStripMode { normal, extendedLeading, extendedTrailing }

class _RenderedTabEntry {
  const _RenderedTabEntry({
    required this.sourceIndex,
    required this.renderCycleIndex,
  });

  final int sourceIndex;
  final int renderCycleIndex;
}

class _TabBarState extends State<CyclicTabBar>
    with SingleTickerProviderStateMixin {
  static const double _kCyclicCommitThreshold = 64.0;
  static const double _kCyclicPointerCommitThreshold = 84.0;
  static const double _kCyclicMaxStretch = 128.0;
  static const double _kCyclicNormalizationEpsilon = 0.5;
  static const double _kCyclicPointerOverscrollFactor = 0.35;
  static const double _kCyclicPointerOverscrollContributionCap = 18.0;
  static const double _kCyclicDragStretchExponent = 1.2;
  static const double _kCyclicPointerStretchExponent = 1.9;
  // A stretch past the threshold only commits while the finger is moving no
  // faster than this, or is released no faster than this: a flick into the
  // edge is not a deliberate pull and must spring back.
  static const double _kCyclicCommitMaxVelocity = 500.0;
  // Copies of the tab cycle rendered while extended.
  static const int _kCyclicRenderedCycles = 2;

  ScrollController? _scrollController;
  TabController? _controller;
  _IndicatorPainter? _indicatorPainter;
  _IndicatorPainter? _stretchPreviewIndicatorPainter;
  int? _currentIndex;
  double _tabStripWidth = 0.0;
  double _singleCycleTabStripWidth = 0.0;
  late List<GlobalKey> _tabKeys;
  late List<GlobalKey> _stretchPreviewTabKeys;
  late List<EdgeInsetsGeometry> _labelPaddings;
  late List<EdgeInsetsGeometry> _stretchPreviewLabelPaddings;
  late final AnimationController _stretchController;
  _CyclicStretchDirection? _stretchDirection;
  _CyclicTabStripMode _stripMode = _CyclicTabStripMode.normal;
  bool _extensionCommitPending = false;
  bool _normalizationPending = false;
  // Whether the scroll in progress was started by a trackpad, whose
  // overscroll may commit through the pointer thresholds. Fling frames after
  // a touch drag carry no drag details either, but never commit.
  bool _scrollStartedByTrackpad = false;
  // The selected index when a pull committed the current wrap, or null when
  // the wrap was driven by a looping page view. While the selection has not
  // changed since, letting go rests on the tabs the user pulled in.
  int? _wrapSelectedIndexAtCommit;
  // Time stamp of the previous drag frame, to measure the finger's speed.
  Duration? _lastDragTimeStamp;
  // The stretch and the viewport's overscroll at the moment the finger left
  // under bouncing physics, so the bounce-back frames can scale the stretch
  // down with the overscroll instead of switching curves.
  double _releaseStretchExtent = 0.0;
  double _releaseOverscroll = 0.0;
  // After a pull-wrap comes to rest on the pulled-in tabs, where the normal
  // strip should ease to once collapsed: its start (0) or its end, so the
  // tabs sit where they do when the screen opens, padding included.
  double? _restAtStripEdge;
  // Effective strip padding, resolved once per build (see
  // _effectiveScrollPadding).
  EdgeInsetsGeometry? _effectiveScrollPaddingValue;
  // Pixels to jump to at the next layout, plus whatever the user scrolls in
  // the meantime (see _TabBarScrollPosition._driftSinceCorrection).
  double? _pendingPixelsCorrection;
  ValueNotifier<bool>? _scrollingNotifier;
  bool _debugHasScheduledValidTabsCountCheck = false;

  @override
  void initState() {
    super.initState();
    _stretchController = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
    // If indicatorSize is TabIndicatorSize.label, _tabKeys[i] is used to find
    // the width of tab widget i. See _IndicatorPainter.indicatorRect().
    _tabKeys = <GlobalKey>[];
    _stretchPreviewTabKeys = <GlobalKey>[];
    _labelPaddings = <EdgeInsetsGeometry>[];
    _stretchPreviewLabelPaddings = <EdgeInsetsGeometry>[];
    _syncRenderedTabArtifacts();
    _syncStretchPreviewArtifacts();
  }

  int get _renderedCycleCount => switch (_stripMode) {
    _CyclicTabStripMode.normal => 1,
    _CyclicTabStripMode.extendedLeading ||
    _CyclicTabStripMode.extendedTrailing => _kCyclicRenderedCycles,
  };

  List<_RenderedTabEntry> get _renderedTabEntries {
    final int tabCount = widget.tabs.length;
    return List<_RenderedTabEntry>.generate(
      tabCount * _renderedCycleCount,
      (int index) => _RenderedTabEntry(
        sourceIndex: index % tabCount,
        renderCycleIndex: index ~/ tabCount,
      ),
      growable: false,
    );
  }

  // The copy that holds the tabs the controller index refers to; the other
  // copy is the one being wrapped to.
  int get _activeRenderCycleIndex => switch (_stripMode) {
    _CyclicTabStripMode.normal || _CyclicTabStripMode.extendedTrailing => 0,
    _CyclicTabStripMode.extendedLeading => 1,
  };

  // Whether the painter's saved tab offsets describe the strip as it is
  // currently rendered. They lag one layout behind a strip mode change, during
  // which scroll targets computed from them would be off by whole cycles.
  bool get _tabOffsetsMatchRenderedTabs {
    final List<double>? offsets = _indicatorPainter?._currentTabOffsets;
    return offsets != null &&
        offsets.length == widget.tabs.length * _renderedCycleCount + 1;
  }

  // The rendered copy of [sourceIndex] a scroll should go to. While extended
  // this is the copy nearest to the viewport, so following a page swipe or a
  // tap never drags the strip a whole cycle across the seam.
  int _renderIndexFor(int sourceIndex) {
    final int tabCount = widget.tabs.length;
    final int middle = sourceIndex + _activeRenderCycleIndex * tabCount;
    if (_stripMode == _CyclicTabStripMode.normal ||
        !_tabOffsetsMatchRenderedTabs ||
        _scrollController == null ||
        !_scrollController!.hasClients ||
        !_scrollController!.position.hasPixels) {
      return middle;
    }
    final ScrollPosition position = _scrollController!.position;
    final TextDirection textDirection = Directionality.of(context);
    final double viewportCenter =
        position.pixels + position.viewportDimension / 2.0;
    int nearest = middle;
    double nearestDistance = double.infinity;
    for (int cycle = 0; cycle < _renderedCycleCount; cycle += 1) {
      final int renderIndex = sourceIndex + cycle * tabCount;
      final double distance =
          (_tabCenterScrollPosition(renderIndex, textDirection) -
                  viewportCenter)
              .abs();
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = renderIndex;
      }
    }
    return nearest;
  }

  int get _selectedRenderIndex => _renderIndexFor(_currentIndex!);

  double get _stretchExtent => _stretchController.value;

  bool get _hasStretchPreview =>
      widget.isScrollable &&
      _stripMode == _CyclicTabStripMode.normal &&
      _stretchDirection != null &&
      _stretchExtent > 0.0;

  void _syncRenderedTabArtifacts() {
    final int renderedTabCount = _renderedTabEntries.length;
    if (_tabKeys.length < renderedTabCount) {
      _tabKeys.addAll(
        List<GlobalKey>.generate(
          renderedTabCount - _tabKeys.length,
          (int index) => GlobalKey(),
        ),
      );
    } else if (_tabKeys.length > renderedTabCount) {
      _tabKeys.removeRange(renderedTabCount, _tabKeys.length);
    }

    if (_labelPaddings.length < renderedTabCount) {
      _labelPaddings.addAll(
        List<EdgeInsetsGeometry>.filled(
          renderedTabCount - _labelPaddings.length,
          EdgeInsets.zero,
        ),
      );
    } else if (_labelPaddings.length > renderedTabCount) {
      _labelPaddings.removeRange(renderedTabCount, _labelPaddings.length);
    }
  }

  void _syncStretchPreviewArtifacts() {
    final int tabCount = widget.tabs.length;
    if (_stretchPreviewTabKeys.length < tabCount) {
      _stretchPreviewTabKeys.addAll(
        List<GlobalKey>.generate(
          tabCount - _stretchPreviewTabKeys.length,
          (int index) => GlobalKey(),
        ),
      );
    } else if (_stretchPreviewTabKeys.length > tabCount) {
      _stretchPreviewTabKeys.removeRange(
        tabCount,
        _stretchPreviewTabKeys.length,
      );
    }

    if (_stretchPreviewLabelPaddings.length < tabCount) {
      _stretchPreviewLabelPaddings.addAll(
        List<EdgeInsetsGeometry>.filled(
          tabCount - _stretchPreviewLabelPaddings.length,
          EdgeInsets.zero,
        ),
      );
    } else if (_stretchPreviewLabelPaddings.length > tabCount) {
      _stretchPreviewLabelPaddings.removeRange(
        tabCount,
        _stretchPreviewLabelPaddings.length,
      );
    }
  }

  TabBarThemeData get _defaults {
    if (Theme.of(context).useMaterial3) {
      return widget._isPrimary
          ? _TabsPrimaryDefaultsM3(context, widget.isScrollable)
          : _TabsSecondaryDefaultsM3(context, widget.isScrollable);
    } else {
      return _TabsDefaultsM2(context, widget.isScrollable);
    }
  }

  Decoration _getIndicator(TabBarIndicatorSize indicatorSize) {
    final ThemeData theme = Theme.of(context);
    final TabBarThemeData tabBarTheme = TabBarTheme.of(context);

    if (widget.indicator != null) {
      return widget.indicator!;
    }
    if (tabBarTheme.indicator != null) {
      return tabBarTheme.indicator!;
    }

    Color color =
        widget.indicatorColor ??
        tabBarTheme.indicatorColor ??
        _defaults.indicatorColor!;
    // ThemeData tries to avoid this by having indicatorColor avoid being the
    // primaryColor. However, it's possible that the tab bar is on a
    // Material that isn't the primaryColor. In that case, if the indicator
    // color ends up matching the material's color, then this overrides it.
    // When that happens, automatic transitions of the theme will likely look
    // ugly as the indicator color suddenly snaps to white at one end, but it's
    // not clear how to avoid that any further.
    //
    // The material's color might be null (if it's a transparency). In that case
    // there's no good way for us to find out what the color is so we don't.
    //
    // TODO(xu-baolin): Remove automatic adjustment to white color indicator
    // with a better long-term solution.
    // https://github.com/flutter/flutter/pull/68171#pullrequestreview-517753917
    if (widget.automaticIndicatorColorAdjustment &&
        color.toARGB32() == Material.maybeOf(context)?.color?.toARGB32()) {
      color = Colors.white;
    }

    final double effectiveIndicatorWeight = theme.useMaterial3
        ? math.max(widget.indicatorWeight, switch (widget._isPrimary) {
            true => _TabsPrimaryDefaultsM3.indicatorWeight(indicatorSize),
            false => _TabsSecondaryDefaultsM3.indicatorWeight,
          })
        : widget.indicatorWeight;
    // Only Material 3 primary TabBar with label indicatorSize should be rounded.
    final bool primaryWithLabelIndicator = switch (indicatorSize) {
      TabBarIndicatorSize.label => widget._isPrimary,
      TabBarIndicatorSize.tab => false,
    };
    final BorderRadius? effectiveBorderRadius =
        theme.useMaterial3 && primaryWithLabelIndicator
        ? BorderRadius.only(
            topLeft: Radius.circular(effectiveIndicatorWeight),
            topRight: Radius.circular(effectiveIndicatorWeight),
          )
        : null;
    return UnderlineTabIndicator(
      borderRadius: effectiveBorderRadius,
      borderSide: BorderSide(
        // TODO(tahatesser): Make sure this value matches Material 3 Tabs spec
        // when `preferredSize`and `indicatorWeight` are updated to support Material 3
        // https://m3.material.io/components/tabs/specs#149a189f-9039-4195-99da-15c205d20e30,
        // https://github.com/flutter/flutter/issues/116136
        width: effectiveIndicatorWeight,
        color: color,
      ),
    );
  }

  // If the TabBar is rebuilt with a new tab controller, the caller should
  // dispose the old one. In that case the old controller's animation will be
  // null and should not be accessed.
  bool get _controllerIsValid => _controller?.animation != null;

  void _updateTabController() {
    final TabController? newController =
        widget.controller ?? DefaultTabController.maybeOf(context);
    assert(() {
      if (newController == null) {
        throw FlutterError(
          'No TabController for ${widget.runtimeType}.\n'
          'When creating a ${widget.runtimeType}, you must either provide an explicit '
          'TabController using the "controller" property, or you must ensure that there '
          'is a DefaultTabController above the ${widget.runtimeType}.\n'
          'In this case, there was neither an explicit controller nor a default controller.',
        );
      }
      return true;
    }());

    if (newController == _controller) {
      return;
    }

    if (_controllerIsValid) {
      _controller!.animation!.removeListener(_handleTabControllerAnimationTick);
      _controller!.removeListener(_handleTabControllerTick);
    }
    _controller = newController;
    if (_controller != null) {
      _controller!.animation!.addListener(_handleTabControllerAnimationTick);
      _controller!.addListener(_handleTabControllerTick);
      _currentIndex = _controller!.index;
    }
  }

  void _initIndicatorPainter() {
    final ThemeData theme = Theme.of(context);
    final TabBarThemeData tabBarTheme = TabBarTheme.of(context);
    final TabBarIndicatorSize indicatorSize =
        widget.indicatorSize ??
        tabBarTheme.indicatorSize ??
        _defaults.indicatorSize!;

    final _IndicatorPainter? oldPainter = _indicatorPainter;

    final TabIndicatorAnimation defaultTabIndicatorAnimation =
        switch (indicatorSize) {
          TabBarIndicatorSize.label => TabIndicatorAnimation.elastic,
          TabBarIndicatorSize.tab => TabIndicatorAnimation.linear,
        };
    // One indicator per rendered copy of the cycle.
    final List<int> indicatorOffsets = List<int>.generate(
      _renderedCycleCount,
      (int cycle) => cycle * widget.tabs.length,
      growable: false,
    );

    _indicatorPainter = !_controllerIsValid
        ? null
        : _IndicatorPainter(
            controller: _controller!,
            indicator: _getIndicator(indicatorSize),
            indicatorSize: indicatorSize,
            indicatorPadding: widget.indicatorPadding,
            indicatorFixedWidth: widget.indicatorFixedWidth,
            indicatorFixedWidthAlignment: widget.indicatorFixedWidthAlignment,
            tabKeys: _tabKeys,
            // Passing old painter so that the constructor can copy some values from it.
            old: oldPainter,
            labelPaddings: _labelPaddings,
            dividerColor:
                widget.dividerColor ??
                tabBarTheme.dividerColor ??
                _defaults.dividerColor,
            dividerHeight:
                widget.dividerHeight ??
                tabBarTheme.dividerHeight ??
                _defaults.dividerHeight,
            showDivider: theme.useMaterial3 && !widget.isScrollable,
            devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
            indicatorAnimation:
                widget.indicatorAnimation ??
                tabBarTheme.indicatorAnimation ??
                defaultTabIndicatorAnimation,
            indexOffsets: indicatorOffsets,
            textDirection: Directionality.of(context),
          );

    oldPainter?.dispose();
  }

  void _initStretchPreviewIndicatorPainter() {
    final TabBarThemeData tabBarTheme = TabBarTheme.of(context);
    final TabBarIndicatorSize indicatorSize =
        widget.indicatorSize ??
        tabBarTheme.indicatorSize ??
        _defaults.indicatorSize!;

    final _IndicatorPainter? oldPainter = _stretchPreviewIndicatorPainter;

    final TabIndicatorAnimation defaultTabIndicatorAnimation =
        switch (indicatorSize) {
          TabBarIndicatorSize.label => TabIndicatorAnimation.elastic,
          TabBarIndicatorSize.tab => TabIndicatorAnimation.linear,
        };

    _stretchPreviewIndicatorPainter = !_controllerIsValid
        ? null
        : _IndicatorPainter(
            controller: _controller!,
            indicator: _getIndicator(indicatorSize),
            indicatorSize: indicatorSize,
            indicatorPadding: widget.indicatorPadding,
            indicatorFixedWidth: widget.indicatorFixedWidth,
            indicatorFixedWidthAlignment: widget.indicatorFixedWidthAlignment,
            tabKeys: _stretchPreviewTabKeys,
            old: oldPainter,
            labelPaddings: _stretchPreviewLabelPaddings,
            dividerColor: null,
            dividerHeight: null,
            showDivider: false,
            devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
            indicatorAnimation:
                widget.indicatorAnimation ??
                tabBarTheme.indicatorAnimation ??
                defaultTabIndicatorAnimation,
            indexOffsets: const <int>[0],
            textDirection: Directionality.of(context),
          );

    oldPainter?.dispose();
  }

  void _updateStripMode(_CyclicTabStripMode stripMode) {
    if (_stripMode == stripMode) {
      return;
    }
    setState(() {
      _stripMode = stripMode;
      _syncRenderedTabArtifacts();
    });
    _initIndicatorPainter();
    // The painter copied the previous layout's offsets, which describe a strip
    // with a different number of copies; drop them so nothing scrolls by whole
    // cycles before the next layout reports the real ones.
    _indicatorPainter?.saveTabOffsets(null, null);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateTabController();
    _initIndicatorPainter();
    _initStretchPreviewIndicatorPainter();
  }

  @override
  void didUpdateWidget(CyclicTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only a change in the number of tabs invalidates the cyclic geometry.
    // Apps commonly rebuild with a fresh but equivalent tabs list (counts in
    // labels, prices ticking), and resetting on every such rebuild wiped an
    // in-progress edge stretch or committed extension and yanked the strip
    // back to the selected tab. Width-only changes are handled at layout time
    // by _saveTabOffsets, which anchors the selected tab instead.
    if (widget.tabs.length != oldWidget.tabs.length) {
      final bool wasExtended = _stripMode != _CyclicTabStripMode.normal;
      _stretchController.value = 0.0;
      _stretchDirection = null;
      final int wasActiveCycle = _activeRenderCycleIndex;
      _stripMode = _CyclicTabStripMode.normal;
      _extensionCommitPending = false;
      _normalizationPending = false;
      _restAtStripEdge = null;
      _pendingPixelsCorrection = null;
      _syncRenderedTabArtifacts();
      _syncStretchPreviewArtifacts();
      _initIndicatorPainter();
      _indicatorPainter?.saveTabOffsets(null, null);
      _initStretchPreviewIndicatorPainter();
      if (wasExtended &&
          _scrollController != null &&
          _scrollController!.hasClients &&
          _scrollController!.position.hasPixels) {
        // Collapse the extension in place onto the copy that held the
        // original tabs.
        final ScrollPosition position = _scrollController!.position;
        _schedulePixelsCorrection(
          position.pixels - _singleCycleTabStripWidth * wasActiveCycle,
        );
        if (position is _TabBarScrollPosition && position.isDriven) {
          // A resting animation still heading for an extended-coordinate
          // target would overshoot the collapsed strip; stop it where the
          // collapse lands it.
          WidgetsBinding.instance.addPostFrameCallback((Duration duration) {
            if (!mounted ||
                _scrollController == null ||
                !_scrollController!.hasClients) {
              return;
            }
            final ScrollPosition current = _scrollController!.position;
            if (current is _TabBarScrollPosition && current.isDriven) {
              current.jumpTo(
                clampDouble(
                  current.pixels,
                  current.minScrollExtent,
                  current.maxScrollExtent,
                ),
              );
            }
          });
        }
      }
      _singleCycleTabStripWidth = 0.0;
    }

    if (widget.controller != oldWidget.controller) {
      _updateTabController();
      _initIndicatorPainter();
      _initStretchPreviewIndicatorPainter();
      // Adjust scroll position.
      if (_scrollController != null && _scrollController!.hasClients) {
        final ScrollPosition position = _scrollController!.position;
        if (position is _TabBarScrollPosition) {
          position.markNeedsPixelsCorrection();
        }
      }
    } else if (widget.indicatorColor != oldWidget.indicatorColor ||
        widget.indicatorWeight != oldWidget.indicatorWeight ||
        widget.indicatorSize != oldWidget.indicatorSize ||
        widget.indicatorPadding != oldWidget.indicatorPadding ||
        widget.indicatorFixedWidth != oldWidget.indicatorFixedWidth ||
        widget.indicatorFixedWidthAlignment !=
            oldWidget.indicatorFixedWidthAlignment ||
        widget.indicator != oldWidget.indicator ||
        widget.dividerColor != oldWidget.dividerColor ||
        widget.dividerHeight != oldWidget.dividerHeight ||
        widget.indicatorAnimation != oldWidget.indicatorAnimation) {
      _initIndicatorPainter();
      _initStretchPreviewIndicatorPainter();
    }
  }

  @override
  void dispose() {
    _indicatorPainter?.dispose();
    _stretchPreviewIndicatorPainter?.dispose();
    if (_controllerIsValid) {
      _controller!.animation!.removeListener(_handleTabControllerAnimationTick);
      _controller!.removeListener(_handleTabControllerTick);
    }
    _detachScrollingNotifier();
    _controller = null;
    _stretchController.dispose();
    _scrollController?.dispose();
    // We don't own the _controller Animation, so it's not disposed here.
    super.dispose();
  }

  void _handleScrollActivityChanged() {
    // Fires when a drag, fling or animation ends: the user's own idle
    // transition, so the strip may ease onto its resting position.
    _settleCyclicExtensionIfIdle(animate: true);
  }

  void _detachScrollingNotifier() {
    _scrollingNotifier?.removeListener(_handleScrollActivityChanged);
    _scrollingNotifier = null;
  }

  void _syncScrollingNotifier() {
    if (_scrollController == null || !_scrollController!.hasClients) {
      _detachScrollingNotifier();
      return;
    }

    final ValueNotifier<bool> notifier =
        _scrollController!.position.isScrollingNotifier;
    if (identical(_scrollingNotifier, notifier)) {
      return;
    }

    _detachScrollingNotifier();
    _scrollingNotifier = notifier;
    notifier.addListener(_handleScrollActivityChanged);
  }

  void _schedulePixelsCorrection(double pixels) {
    _pendingPixelsCorrection = pixels;
    final ScrollPosition? position =
        _scrollController != null && _scrollController!.hasClients
        ? _scrollController!.position
        : null;
    if (position is _TabBarScrollPosition) {
      position.markNeedsPixelsCorrection();
    }
  }

  double? _consumePendingPixelsCorrection(
    double drift,
    double minScrollExtent,
    double maxScrollExtent,
  ) {
    final double? pendingPixelsCorrection = _pendingPixelsCorrection;
    if (pendingPixelsCorrection == null) {
      return null;
    }
    _pendingPixelsCorrection = null;
    return clampDouble(
      pendingPixelsCorrection + drift,
      minScrollExtent,
      maxScrollExtent,
    );
  }

  EdgeInsetsGeometry _effectiveLabelPaddingForTab(
    Widget tab,
    TabBarThemeData tabBarTheme,
  ) {
    EdgeInsetsGeometry padding =
        widget.labelPadding ?? tabBarTheme.labelPadding ?? kTabLabelPadding;
    const double verticalAdjustment =
        (_kTextAndIconTabHeight - _kTabHeight) / 2.0;

    if (tab is PreferredSizeWidget &&
        tab.preferredSize.height == _kTabHeight &&
        widget.tabHasTextAndIcon) {
      padding = padding.add(
        const EdgeInsets.symmetric(vertical: verticalAdjustment),
      );
    }

    return padding;
  }

  void _setStretchPreview(_CyclicStretchDirection direction, double extent) {
    if (_stretchDirection != direction) {
      setState(() {
        _stretchDirection = direction;
      });
    }
    _stretchController.stop();
    _stretchController.value = extent;
  }

  void _clearStretchPreview({required bool animated}) {
    if (_stretchDirection == null && _stretchExtent == 0.0) {
      return;
    }

    void clearDirectionIfNeeded() {
      if (!mounted ||
          _stretchExtent != 0.0 ||
          _stripMode != _CyclicTabStripMode.normal) {
        return;
      }
      setState(() {
        _stretchDirection = null;
      });
    }

    _stretchController.stop();
    if (!animated || _stretchExtent == 0.0) {
      _stretchController.value = 0.0;
      clearDirectionIfNeeded();
      return;
    }

    _stretchController
        .animateTo(
          0.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        )
        .whenCompleteOrCancel(clearDirectionIfNeeded);
  }

  // Resolved padding around the tab strip, in scroll coordinates: the strip
  // itself begins after the start inset. The cyclic seam math works in those
  // coordinates.
  (double start, double end) _resolvedScrollPadding(
    TextDirection textDirection,
  ) {
    final EdgeInsetsGeometry? padding = _effectiveScrollPadding();
    if (padding == null) {
      return (0.0, 0.0);
    }
    final EdgeInsets resolved = padding.resolve(textDirection);
    return switch (textDirection) {
      TextDirection.ltr => (resolved.left, resolved.right),
      TextDirection.rtl => (resolved.right, resolved.left),
    };
  }

  double _paddingStart(TextDirection textDirection) =>
      _resolvedScrollPadding(textDirection).$1;

  // The padding the scroll view is built with, cached by build. Note that it
  // includes the startOffset inset while the upstream _tabScrollOffset
  // centering math only looks at widget.padding; the seam and resting math
  // here must match the layout, so they use this one.
  EdgeInsetsGeometry? _effectiveScrollPadding() => _effectiveScrollPaddingValue;

  void _commitCyclicExtension(
    _CyclicStretchDirection direction, {
    required bool fromDrag,
    bool released = false,
  }) {
    if (_stripMode != _CyclicTabStripMode.normal ||
        _stretchExtent == 0.0 ||
        _singleCycleTabStripWidth == 0.0 ||
        _scrollController == null ||
        !_scrollController!.hasClients) {
      return;
    }

    final ScrollPosition position = _scrollController!.position;
    if (_singleCycleTabStripWidth <= position.viewportDimension) {
      // A cycle that fits the viewport has nothing to wrap to; a wrap would
      // only show the same tabs twice.
      return;
    }
    final double currentPixels = position.pixels;
    // The preview that the stretch translated in becomes real content, so the
    // viewport moves by that translation (zero under bouncing physics, where
    // the viewport's own overscroll already made room for the preview and is
    // already part of currentPixels); when the previous cycle is laid out in
    // front of the original one, the original also moves one cycle width.
    // Either way the picture does not change.
    final double translation = _stretchTranslationExtent(
      position,
    ).clamp(0.0, _singleCycleTabStripWidth);
    final double targetPixels = switch (direction) {
      _CyclicStretchDirection.leading =>
        currentPixels + _singleCycleTabStripWidth - translation,
      _CyclicStretchDirection.trailing => currentPixels + translation,
    };
    _stretchController.stop();
    _stretchController.value = 0.0;
    _stretchDirection = null;
    _wrapSelectedIndexAtCommit = _currentIndex;
    _enterExtendedMode(
      switch (direction) {
        _CyclicStretchDirection.leading => _CyclicTabStripMode.extendedLeading,
        _CyclicStretchDirection.trailing =>
          _CyclicTabStripMode.extendedTrailing,
      },
      targetPixels,
      feedback: widget.enableFeedback ?? true,
      // A fling that wrapped would otherwise keep its momentum and race on
      // through the next cycle, and a release under bouncing physics would
      // spring part of the way back; ease onto the resting position instead.
      settleAtOnce: !fromDrag || released,
    );
  }

  void _enterExtendedMode(
    _CyclicTabStripMode stripMode,
    double targetPixels, {
    required bool feedback,
    bool settleAtOnce = false,
  }) {
    _extensionCommitPending = true;
    _restAtStripEdge = null;
    _schedulePixelsCorrection(targetPixels);
    _updateStripMode(stripMode);

    // The correction is applied by the layout that the mode change schedules.
    // Nothing here may jump the position: that would end a drag that is still
    // in progress.
    WidgetsBinding.instance.addPostFrameCallback((Duration duration) {
      _extensionCommitPending = false;
      if (!mounted) {
        return;
      }
      if (feedback) {
        HapticFeedback.heavyImpact();
      }
      // The user may already have let go.
      _settleCyclicExtensionIfIdle(animate: true, interruptFling: settleAtOnce);
    });
  }

  void _saveStretchPreviewTabOffsets(
    List<double> tabOffsets,
    TextDirection textDirection,
    double _,
  ) {
    _stretchPreviewIndicatorPainter?.saveTabOffsets(tabOffsets, textDirection);
  }

  // Where the extended strip should come to rest, as the pixels the normal
  // strip needs to show the same thing. `collapseNow` is true when the
  // viewport already shows what the normal strip can show (it lies inside
  // one copy, or in the padding beyond the strip's ends), so the collapse is
  // invisible; otherwise `extendedPixels` is the position to animate the
  // extended strip to first. After a pull whose selection has not changed
  // that is the wrapped-to copy with its edge tab flush against the viewport
  // edge: the tabs the user pulled in. Otherwise (the page view moved the
  // selection, or drove the wrap itself) it is the nearest position inside
  // the copy that holds the copy of the selected tab nearest the viewport, so
  // the selected tab stays in view and the strip moves as little as
  // possible.
  ({
    double normalPixels,
    double extendedPixels,
    bool collapseNow,
    double? stripEdgePixels,
  })?
  _cyclicRestingPosition(ScrollMetrics metrics) {
    if (_stripMode == _CyclicTabStripMode.normal ||
        _singleCycleTabStripWidth == 0.0 ||
        !_tabOffsetsMatchRenderedTabs ||
        _currentIndex == null ||
        !metrics.hasPixels ||
        !metrics.hasViewportDimension) {
      return null;
    }
    final double seam = _singleCycleTabStripWidth;
    final (double paddingStart, double paddingEnd) = _resolvedScrollPadding(
      Directionality.of(context),
    );
    final double viewport = metrics.viewportDimension;
    final double normalMaxExtent = math.max(
      0.0,
      seam + paddingStart + paddingEnd - viewport,
    );
    // The range of extended pixels at which the viewport shows exactly what
    // the normal strip shows at `pixels - copy * seam`.
    (double, double) copyRange(int copy) => switch (copy) {
      0 => (0.0, paddingStart + seam - viewport),
      _ => (paddingStart + seam, metrics.maxScrollExtent),
    };

    for (int copy = 0; copy < _kCyclicRenderedCycles; copy += 1) {
      final (double low, double high) = copyRange(copy);
      if (metrics.pixels >= low - _kCyclicNormalizationEpsilon &&
          metrics.pixels <= high + _kCyclicNormalizationEpsilon) {
        return (
          normalPixels: clampDouble(
            metrics.pixels - copy * seam,
            0.0,
            normalMaxExtent,
          ),
          extendedPixels: metrics.pixels,
          collapseNow: true,
          stripEdgePixels: null,
        );
      }
    }

    final bool restOnPulledTabs = _wrapSelectedIndexAtCommit == _currentIndex;
    final int copy = restOnPulledTabs
        ? switch (_stripMode) {
            _CyclicTabStripMode.extendedTrailing => 1,
            _CyclicTabStripMode.extendedLeading ||
            _CyclicTabStripMode.normal => 0,
          }
        : _renderIndexFor(_currentIndex!) ~/ widget.tabs.length;
    final (double low, double high) = copyRange(copy);
    final double extendedPixels = high < low
        ? low
        : restOnPulledTabs
        // The wrapped-to copy's edge tab flush against the viewport edge.
        ? (copy == 1 ? low : high)
        : clampDouble(metrics.pixels, low, high);
    return (
      normalPixels: clampDouble(
        extendedPixels - copy * seam,
        0.0,
        normalMaxExtent,
      ),
      extendedPixels: extendedPixels,
      collapseNow: false,
      // The pulled-in tabs rest where they sit when the screen opens: at the
      // strip's start (leading padding showing) or end. That picture has no
      // counterpart in the extended strip when there is padding, so it is
      // reached after the collapse, in single-strip coordinates.
      stripEdgePixels: restOnPulledTabs
          ? (copy == 1 ? 0.0 : normalMaxExtent)
          : null,
    );
  }

  // Once the user has let go and the strip is still, bring the wrap to an
  // end: collapse to the normal strip where that is invisible, or first ease
  // the extended strip onto a clean resting position (`animate`) and collapse
  // when that animation ends. Called from every idle transition, so no commit
  // or cancelled stretch can leave the strip extended with its edge pulls
  // ignored.
  void _settleCyclicExtensionIfIdle({
    required bool animate,
    bool interruptFling = false,
  }) {
    if (_stripMode == _CyclicTabStripMode.normal ||
        _extensionCommitPending ||
        _normalizationPending ||
        _scrollController == null ||
        !_scrollController!.hasClients) {
      return;
    }
    final ScrollPosition position = _scrollController!.position;
    if (position.isScrollingNotifier.value && !interruptFling) {
      return;
    }
    final resting = _cyclicRestingPosition(position);
    if (resting == null) {
      return;
    }
    if (!resting.collapseNow && !animate) {
      return;
    }

    // Deferred: scroll notifications can arrive during layout, collapsing the
    // strip rebuilds it, and starting an animation from inside the activity
    // change that ended the previous one is not allowed.
    _normalizationPending = true;
    WidgetsBinding.instance.ensureVisualUpdate();
    WidgetsBinding.instance.addPostFrameCallback((Duration duration) {
      _normalizationPending = false;
      if (!mounted ||
          _stripMode == _CyclicTabStripMode.normal ||
          _scrollController == null ||
          !_scrollController!.hasClients) {
        return;
      }
      final ScrollPosition position = _scrollController!.position;
      // Recheck now: the user may have started scrolling again, in which case
      // the next idle transition settles the strip instead.
      if (position.isScrollingNotifier.value && !interruptFling) {
        return;
      }
      final resting = _cyclicRestingPosition(position);
      if (resting == null) {
        return;
      }
      if (resting.collapseNow) {
        _collapseCyclicExtension(resting.normalPixels);
        return;
      }
      _restAtStripEdge = resting.stripEdgePixels;
      final double target = clampDouble(
        resting.extendedPixels,
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if ((position.pixels - target).abs() <= _kCyclicNormalizationEpsilon) {
        // Already there but not inside one copy (the strip barely overflows
        // the viewport): collapse anyway, accepting the small shift.
        _collapseCyclicExtension(resting.normalPixels);
        return;
      }
      // The collapse follows from the idle transition at the end of this
      // animation. Any ease to the strip's edge after it runs the other way,
      // so this one decelerates into the collapse rather than easing in.
      _scrollController!.animateTo(
        target,
        duration: kTabScrollDuration,
        curve: Curves.ease,
      );
    });
  }

  // Replaces the extended strip with the normal one at [normalPixels], which
  // shows the same picture, and then, after a pull-wrap, eases on to the
  // strip's start or end so the pulled-in tabs sit where they do when the
  // screen opens.
  void _collapseCyclicExtension(double normalPixels) {
    final double? stripEdge = _restAtStripEdge;
    _restAtStripEdge = null;
    _normalizationPending = true;
    _schedulePixelsCorrection(normalPixels);
    _updateStripMode(_CyclicTabStripMode.normal);
    WidgetsBinding.instance.addPostFrameCallback((Duration duration) {
      _normalizationPending = false;
      if (stripEdge == null ||
          !mounted ||
          _scrollController == null ||
          !_scrollController!.hasClients) {
        return;
      }
      final ScrollPosition position = _scrollController!.position;
      final double target = clampDouble(
        stripEdge,
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if ((position.pixels - target).abs() <= _kCyclicNormalizationEpsilon) {
        return;
      }
      position.animateTo(
        target,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    });
  }

  double _outOfRangeExtent(ScrollMetrics metrics) {
    if (metrics.pixels < metrics.minScrollExtent) {
      return metrics.minScrollExtent - metrics.pixels;
    }
    if (metrics.pixels > metrics.maxScrollExtent) {
      return metrics.pixels - metrics.maxScrollExtent;
    }
    return 0.0;
  }

  double _applyStretchResistance(
    double extent, {
    required bool isPointerDriven,
  }) {
    final double clampedExtent = clampDouble(extent, 0.0, _kCyclicMaxStretch);
    if (clampedExtent == 0.0) {
      return 0.0;
    }
    final double progress = clampedExtent / _kCyclicMaxStretch;
    final double exponent = isPointerDriven
        ? _kCyclicPointerStretchExponent
        : _kCyclicDragStretchExponent;
    return _kCyclicMaxStretch * math.pow(progress, exponent);
  }

  _CyclicStretchDirection? _directionForMetrics(
    ScrollMetrics metrics, {
    double? overscroll,
  }) {
    if (metrics.pixels < metrics.minScrollExtent) {
      return _CyclicStretchDirection.leading;
    }
    if (metrics.pixels > metrics.maxScrollExtent) {
      return _CyclicStretchDirection.trailing;
    }
    if (overscroll == null) {
      return null;
    }
    if (metrics.pixels <= metrics.minScrollExtent + 0.5 &&
        overscroll.isNegative) {
      return _CyclicStretchDirection.leading;
    }
    if (metrics.pixels >= metrics.maxScrollExtent - 0.5 &&
        !overscroll.isNegative) {
      return _CyclicStretchDirection.trailing;
    }
    return null;
  }

  // Whether this frame of a stretch may commit the wrap. Only a deliberate
  // pull commits: a finger frame moving no faster than
  // _kCyclicCommitMaxVelocity past the drag threshold, a trackpad overscroll
  // past the deeper pointer threshold that was already visible on a previous
  // frame, or (see _handleDragReleased) a slow release. Fast swipes and the
  // fling frames that follow them only stretch and spring back.
  bool _canCommitStretch({
    required bool isPointerDriven,
    required double previousStretchExtent,
    required double stretchExtent,
    required double? dragSpeed,
  }) {
    if (isPointerDriven) {
      return _scrollStartedByTrackpad &&
          previousStretchExtent > 0.0 &&
          stretchExtent >= _kCyclicPointerCommitThreshold;
    }
    return dragSpeed != null &&
        dragSpeed <= _kCyclicCommitMaxVelocity &&
        stretchExtent >= _kCyclicCommitThreshold;
  }

  // The finger's movement in this drag frame, in px. Measured on the finger
  // rather than the scroll: bouncing physics scale the scroll down past the
  // edge, which would make a flick read as a slow pull and a long pull as a
  // short one.
  double _fingerDelta(DragUpdateDetails? dragDetails) => dragDetails == null
      ? 0.0
      : (dragDetails.primaryDelta ?? dragDetails.delta.dx);

  // Finger speed over this drag frame in px/s, or null when it cannot be
  // measured (first frame, or no time stamps), which counts as fast.
  double? _measureDragSpeed(DragUpdateDetails? dragDetails) {
    final Duration? timeStamp = dragDetails?.sourceTimeStamp;
    final double distance = _fingerDelta(dragDetails);
    final Duration? previous = _lastDragTimeStamp;
    _lastDragTimeStamp = timeStamp;
    if (timeStamp == null || previous == null) {
      return null;
    }
    final int microseconds = (timeStamp - previous).inMicroseconds;
    if (microseconds <= 0) {
      return null;
    }
    return distance.abs() * Duration.microsecondsPerSecond / microseconds;
  }

  // Called by the scroll position when a drag ends. A pull held past the
  // threshold and let go gently commits here even if no single frame was
  // slow enough; a flick does not.
  void _handleDragReleased(double velocity) {
    if (!mounted || !widget.isScrollable) {
      return;
    }
    if (_stripMode != _CyclicTabStripMode.normal) {
      // A wrap committed during the drag: however the finger left, ease
      // onto the resting position rather than coasting on into the next
      // cycle.
      _settleCyclicExtensionIfIdle(animate: true, interruptFling: true);
      return;
    }
    if (_hasStretchPreview &&
        _scrollController != null &&
        _scrollController!.hasClients) {
      _releaseStretchExtent = _stretchExtent;
      _releaseOverscroll = _outOfRangeExtent(_scrollController!.position);
    }
    if (velocity.abs() > _kCyclicCommitMaxVelocity ||
        !_hasStretchPreview ||
        _stretchExtent < _kCyclicCommitThreshold) {
      return;
    }
    _commitCyclicExtension(_stretchDirection!, fromDrag: true, released: true);
  }

  bool _handleScrollableNotification(ScrollNotification notification) {
    if (!widget.isScrollable ||
        _scrollController == null ||
        !_scrollController!.hasClients ||
        notification.depth != 0) {
      return false;
    }

    _syncScrollingNotifier();

    if (notification is ScrollStartNotification) {
      _scrollStartedByTrackpad =
          notification.dragDetails?.kind == PointerDeviceKind.trackpad;
      _lastDragTimeStamp = notification.dragDetails?.sourceTimeStamp;
      _releaseStretchExtent = 0.0;
      _releaseOverscroll = 0.0;
    }

    final bool isIdleNotification =
        notification is ScrollEndNotification ||
        (notification is UserScrollNotification &&
            notification.direction == ScrollDirection.idle);

    if (_stripMode != _CyclicTabStripMode.normal) {
      if (_extensionCommitPending) {
        return false;
      }
      if (notification is ScrollUpdateNotification &&
          notification.dragDetails != null) {
        // The user took over from the resting animation: wherever this
        // scroll ends up is where the strip rests, not the strip's edge.
        // (A drag that starts mid-animation sends no ScrollStart.)
        _restAtStripEdge = null;
      }
      if (isIdleNotification) {
        // A bare ScrollEnd also follows every jumpTo that keeps the strip in
        // step with a page swipe; only collapse invisibly then, and leave the
        // resting animation to the user's own idle transition.
        _settleCyclicExtensionIfIdle(
          animate: notification is UserScrollNotification,
        );
      }
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      final bool isPointerDrivenUpdate = notification.dragDetails == null;
      final _CyclicStretchDirection? direction = _directionForMetrics(
        notification.metrics,
      );
      final double previousStretchExtent = _stretchDirection == direction
          ? _stretchExtent
          : 0.0;
      final double overscroll = _outOfRangeExtent(notification.metrics);
      final double extent;
      if (!isPointerDrivenUpdate) {
        // Bouncing physics: the stretch is the finger's own travel past the
        // edge, so a wrap takes the same pull as under clamping physics,
        // however much the physics resist the scroll.
        final double fingerDelta = _fingerDelta(notification.dragDetails);
        final double scrollDelta = notification.scrollDelta ?? 0.0;
        final bool outward = switch (direction) {
          _CyclicStretchDirection.trailing => scrollDelta > 0.0,
          _CyclicStretchDirection.leading => scrollDelta < 0.0,
          null => false,
        };
        extent = direction == null
            ? 0.0
            : clampDouble(
                previousStretchExtent +
                    (outward ? fingerDelta.abs() : -fingerDelta.abs()),
                0.0,
                _kCyclicMaxStretch,
              );
      } else if (_scrollStartedByTrackpad || _releaseOverscroll <= 0.0) {
        extent = _applyStretchResistance(overscroll, isPointerDriven: true);
      } else {
        // Bounce-back after a touch drag: retreat with the overscroll.
        extent = clampDouble(
          _releaseStretchExtent * overscroll / _releaseOverscroll,
          0.0,
          _kCyclicMaxStretch,
        );
      }
      final double? dragSpeed = isPointerDrivenUpdate
          ? null
          : _measureDragSpeed(notification.dragDetails);
      if (direction != null && extent > 0.0) {
        _setStretchPreview(direction, extent);
        if (_canCommitStretch(
          isPointerDriven: isPointerDrivenUpdate,
          previousStretchExtent: previousStretchExtent,
          stretchExtent: extent,
          dragSpeed: dragSpeed,
        )) {
          _commitCyclicExtension(direction, fromDrag: !isPointerDrivenUpdate);
        }
        return false;
      }

      if (_hasStretchPreview && !_scrollController!.position.outOfRange) {
        if (notification.dragDetails != null) {
          // The finger came back inside the range: let the preview retreat
          // with it instead of vanishing on a jitter.
          final double remaining =
              _stretchExtent - _fingerDelta(notification.dragDetails).abs();
          if (remaining > 0.0) {
            _setStretchPreview(_stretchDirection!, remaining);
          } else {
            _clearStretchPreview(animated: false);
          }
        } else {
          _clearStretchPreview(animated: false);
        }
      }
    }

    if (notification is OverscrollNotification) {
      final _CyclicStretchDirection? direction = _directionForMetrics(
        notification.metrics,
        overscroll: notification.overscroll,
      );
      if (direction == null) {
        return false;
      }

      final bool isPointerDrivenOverscroll = notification.dragDetails == null;
      final double? dragSpeed = isPointerDrivenOverscroll
          ? null
          : _measureDragSpeed(notification.dragDetails);
      final double previousStretchExtent = _stretchDirection == direction
          ? _stretchExtent
          : 0.0;
      final double overscrollContribution = isPointerDrivenOverscroll
          ? clampDouble(
              notification.overscroll.abs() * _kCyclicPointerOverscrollFactor,
              0.0,
              _kCyclicPointerOverscrollContributionCap,
            )
          : notification.overscroll.abs();
      double stretchExtent = math.max(
        _applyStretchResistance(
          _outOfRangeExtent(notification.metrics),
          isPointerDriven: isPointerDrivenOverscroll,
        ),
        previousStretchExtent + overscrollContribution,
      );
      stretchExtent = clampDouble(stretchExtent, 0.0, _kCyclicMaxStretch);
      _setStretchPreview(direction, stretchExtent);
      if (_canCommitStretch(
        isPointerDriven: isPointerDrivenOverscroll,
        previousStretchExtent: previousStretchExtent,
        stretchExtent: stretchExtent,
        dragSpeed: dragSpeed,
      )) {
        _commitCyclicExtension(direction, fromDrag: !isPointerDrivenOverscroll);
      }
      return false;
    }

    if (isIdleNotification) {
      _clearStretchPreview(animated: true);
    }

    return false;
  }

  bool _previewAppearsOnLeft(TextDirection textDirection) {
    return switch ((textDirection, _stretchDirection)) {
      (TextDirection.ltr, _CyclicStretchDirection.leading) => true,
      (TextDirection.rtl, _CyclicStretchDirection.trailing) => true,
      _ => false,
    };
  }

  // How far the strip is pushed in to make room for the preview. Under
  // bouncing physics the viewport's own overscroll already moves the strip
  // with the finger (plus the physics' resistance) and opens a gap at the
  // edge; the preview fills that gap, so the strip is not pushed any further
  // and does not run ahead of the finger. Under clamping physics the viewport
  // never moves past the edge, so the whole stretch is a push.
  double _stretchTranslationExtent(ScrollMetrics metrics) {
    if (!_hasStretchPreview) {
      return 0.0;
    }
    return _outOfRangeExtent(metrics) > 0.0 ? 0.0 : _stretchExtent;
  }

  double _stretchTranslationX(TextDirection textDirection) {
    if (!_hasStretchPreview ||
        _scrollController == null ||
        !_scrollController!.hasClients ||
        !_scrollController!.position.hasPixels) {
      return 0.0;
    }
    final double translation = _stretchTranslationExtent(
      _scrollController!.position,
    );
    return _previewAppearsOnLeft(textDirection) ? translation : -translation;
  }

  Widget _buildStretchPreview(
    TabBarThemeData tabBarTheme,
    TextDirection textDirection,
  ) {
    if (!_hasStretchPreview) {
      return const SizedBox.shrink();
    }

    _syncStretchPreviewArtifacts();
    final bool previewOnLeft = _previewAppearsOnLeft(textDirection);
    // Keep the preview flush against the end of the strip. Under bouncing
    // physics the strip has moved past the edge by the viewport's overscroll;
    // the preview shows as much of the next cycle as fits in that gap (the
    // stretch itself may be larger, being the finger's travel), and when the
    // gap is wider the remainder stays empty, like any overscroll.
    final ScrollPosition? position =
        _scrollController != null && _scrollController!.hasClients
        ? _scrollController!.position
        : null;
    final double overscroll = position != null && position.hasPixels
        ? _outOfRangeExtent(position)
        : 0.0;
    final double previewWidth = overscroll > 0.0
        ? math.min(_stretchExtent, overscroll)
        : _stretchExtent;
    final double previewInset = math.max(0.0, overscroll - previewWidth);
    final List<Widget> previewTabs = List<Widget>.generate(widget.tabs.length, (
      int index,
    ) {
      final EdgeInsetsGeometry padding = _effectiveLabelPaddingForTab(
        widget.tabs[index],
        tabBarTheme,
      );
      _stretchPreviewLabelPaddings[index] = padding;
      Widget previewTab = Center(
        heightFactor: 1.0,
        child: Padding(
          padding: padding,
          child: KeyedSubtree(
            key: _stretchPreviewTabKeys[index],
            child: widget.tabs[index],
          ),
        ),
      );
      previewTab = _buildStyledTab(
        previewTab,
        index == _currentIndex,
        kAlwaysDismissedAnimation,
        _defaults,
      );
      return previewTab;
    });

    final Widget previewStrip = CustomPaint(
      painter: _stretchPreviewIndicatorPainter,
      child: _TabLabelBar(
        onPerformLayout: _saveStretchPreviewTabOffsets,
        mainAxisSize: MainAxisSize.min,
        children: previewTabs,
      ),
    );

    return ExcludeSemantics(
      child: IgnorePointer(
        child: Align(
          alignment: previewOnLeft
              ? Alignment.centerLeft
              : Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(
              left: previewOnLeft ? previewInset : 0.0,
              right: previewOnLeft ? 0.0 : previewInset,
            ),
            child: SizedBox(
              width: previewWidth,
              height: widget.preferredSize.height,
              child: ClipRect(
                child: OverflowBox(
                  minWidth: 0.0,
                  maxWidth: double.infinity,
                  minHeight: widget.preferredSize.height,
                  maxHeight: widget.preferredSize.height,
                  alignment: previewOnLeft
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: previewStrip,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  int get maxTabIndex => _indicatorPainter!.maxTabIndex;

  // Scroll coordinate (distance from the scroll start, padding included) of
  // the center of the rendered tab at [index].
  double _tabCenterScrollPosition(int index, TextDirection textDirection) {
    double tabCenter = _indicatorPainter!.centerOf(index);
    double paddingStart;
    switch (textDirection) {
      case TextDirection.rtl:
        paddingStart = widget.padding?.resolve(TextDirection.rtl).right ?? 0;
        tabCenter = _tabStripWidth - tabCenter;
      case TextDirection.ltr:
        paddingStart = widget.padding?.resolve(TextDirection.ltr).left ?? 0;
    }
    return tabCenter + paddingStart;
  }

  double _tabScrollOffset(
    int index,
    double viewportWidth,
    double minExtent,
    double maxExtent,
  ) {
    if (!widget.isScrollable) {
      return 0.0;
    }
    final TextDirection textDirection = Directionality.of(context);
    final double offset = clampDouble(
      _tabCenterScrollPosition(index, textDirection) - viewportWidth / 2.0,
      minExtent,
      maxExtent,
    );
    if (_stripMode == _CyclicTabStripMode.normal ||
        _singleCycleTabStripWidth == 0.0) {
      return offset;
    }
    // While extended, keep the target inside the copy that holds the tab so
    // the strip comes to rest showing only what the normal strip can show,
    // and the collapse that follows is invisible.
    final int copy = index ~/ widget.tabs.length;
    final double paddingStart = _paddingStart(textDirection);
    final (double low, double high) = switch (copy) {
      0 => (
        minExtent,
        paddingStart + _singleCycleTabStripWidth - viewportWidth,
      ),
      _ => (paddingStart + _singleCycleTabStripWidth, maxExtent),
    };
    return high < low ? offset : clampDouble(offset, low, high);
  }

  double _tabCenteredScrollOffset(int index) {
    final ScrollPosition position = _scrollController!.position;
    return _tabScrollOffset(
      index,
      position.viewportDimension,
      position.minScrollExtent,
      position.maxScrollExtent,
    );
  }

  double _initialScrollOffset(
    double viewportWidth,
    double minExtent,
    double maxExtent,
  ) {
    return _tabScrollOffset(
      _selectedRenderIndex,
      viewportWidth,
      minExtent,
      maxExtent,
    );
  }

  void _scrollToCurrentIndex() {
    if (!_tabOffsetsMatchRenderedTabs) {
      // The strip is between modes; the pending pixels correction will place
      // the selected tab once the new layout is in.
      return;
    }
    final double offset = _tabCenteredScrollOffset(_selectedRenderIndex);
    _scrollController!.animateTo(
      offset,
      duration: kTabScrollDuration,
      curve: Curves.ease,
    );
  }

  void _scrollToControllerValue() {
    if (!_tabOffsetsMatchRenderedTabs) {
      return;
    }
    final int currentRenderIndex = _selectedRenderIndex;
    // While extended, the neighbours of the first and last tab are the
    // adjacent copies' last and first tab, so a page bounce past either end
    // (or a looping tab view) moves the strip the natural way.
    final bool cyclicNeighbours = _stripMode != _CyclicTabStripMode.normal;
    final double? leadingPosition = cyclicNeighbours || _currentIndex! > 0
        ? _tabCenteredScrollOffset(currentRenderIndex - 1)
        : null;
    final double middlePosition = _tabCenteredScrollOffset(currentRenderIndex);
    final double? trailingPosition =
        cyclicNeighbours || _currentIndex! < widget.tabs.length - 1
        ? _tabCenteredScrollOffset(currentRenderIndex + 1)
        : null;

    final double index = _controller!.index.toDouble();
    final double value = _controller!.animation!.value;
    final double offset = switch (value - index) {
      -1.0 => leadingPosition ?? middlePosition,
      1.0 => trailingPosition ?? middlePosition,
      0 => middlePosition,
      < 0 =>
        leadingPosition == null
            ? middlePosition
            : lerpDouble(middlePosition, leadingPosition, index - value)!,
      _ =>
        trailingPosition == null
            ? middlePosition
            : lerpDouble(middlePosition, trailingPosition, value - index)!,
    };

    _scrollController!.jumpTo(offset);
  }

  void _handleTabControllerAnimationTick() {
    assert(mounted);
    if (!_controller!.indexIsChanging && widget.isScrollable) {
      // Sync the TabBar's scroll position with the TabBarView's PageView.
      _currentIndex = _controller!.index;
      _extendForPageWrapIfNeeded();
      _scrollToControllerValue();
    }
  }

  // A looping page view drives the controller's value past the first or last
  // tab. The plain strip has no tab there to follow, so extend it (at the
  // same picture) and let the cyclic neighbours take over.
  void _extendForPageWrapIfNeeded() {
    if (_stripMode != _CyclicTabStripMode.normal ||
        _extensionCommitPending ||
        _singleCycleTabStripWidth == 0.0 ||
        _scrollController == null ||
        !_scrollController!.hasClients) {
      return;
    }
    final double value = _controller!.animation!.value;
    if (value >= 0.0 && value <= widget.tabs.length - 1) {
      return;
    }
    final ScrollPosition position = _scrollController!.position;
    if (!position.hasPixels ||
        position.maxScrollExtent <= position.minScrollExtent ||
        _singleCycleTabStripWidth <= position.viewportDimension) {
      // Nothing to scroll: a second copy would just widen a strip that fits.
      // The indicator and label styles still follow the wrap off the strip.
      return;
    }
    _wrapSelectedIndexAtCommit = null;
    if (value > widget.tabs.length - 1) {
      _enterExtendedMode(
        _CyclicTabStripMode.extendedTrailing,
        position.pixels,
        feedback: false,
      );
    } else {
      _enterExtendedMode(
        _CyclicTabStripMode.extendedLeading,
        position.pixels + _singleCycleTabStripWidth,
        feedback: false,
      );
    }
  }

  void _handleTabControllerTick() {
    if (_controller!.index != _currentIndex) {
      _currentIndex = _controller!.index;
      if (widget.isScrollable) {
        _scrollToCurrentIndex();
      }
    }
    setState(() {
      // Rebuild the tabs after a (potentially animated) index change
      // has completed.
    });
  }

  // Called each time layout completes.
  void _saveTabOffsets(
    List<double> tabOffsets,
    TextDirection textDirection,
    double width,
  ) {
    final List<double>? previousTabOffsets =
        _indicatorPainter?._currentTabOffsets;
    final TextDirection? previousTextDirection =
        _indicatorPainter?._currentTextDirection;
    final double previousWidth = _tabStripWidth;
    _tabStripWidth = width;
    if (widget.tabs.isNotEmpty && tabOffsets.length > widget.tabs.length) {
      _singleCycleTabStripWidth =
          (tabOffsets[widget.tabs.length] - tabOffsets[0]).abs();
    }
    _indicatorPainter?.saveTabOffsets(tabOffsets, textDirection);
    if (previousTextDirection == textDirection) {
      _anchorSelectedTabAfterRelayout(
        previousTabOffsets,
        previousWidth,
        tabOffsets,
        width,
        textDirection,
      );
    }
  }

  // When tab widths change under a resting strip (a count appearing in a
  // label, say), keep the selected tab where it was on screen rather than
  // letting the content slide under it or re-centering, which both read as
  // the strip jumping. Runs inside the viewport's layout, before it applies
  // the content dimensions, so the correction lands in the same frame.
  void _anchorSelectedTabAfterRelayout(
    List<double>? previousTabOffsets,
    double previousWidth,
    List<double> tabOffsets,
    double width,
    TextDirection textDirection,
  ) {
    if (!widget.isScrollable ||
        previousTabOffsets == null ||
        previousTabOffsets.length != tabOffsets.length ||
        listEquals(previousTabOffsets, tabOffsets) ||
        _pendingPixelsCorrection != null ||
        _currentIndex == null ||
        _scrollController == null ||
        !_scrollController!.hasClients) {
      return;
    }
    final ScrollPosition position = _scrollController!.position;
    if (!position.hasPixels ||
        !position.hasViewportDimension ||
        position.isScrollingNotifier.value) {
      return;
    }
    final int renderIndex = _selectedRenderIndex;
    if (renderIndex + 1 >= tabOffsets.length) {
      return;
    }
    // Offsets are paint coordinates; in RTL the scroll start is the right
    // edge, so convert both layouts to scroll coordinates before comparing.
    double scrollCenter(List<double> offsets, double stripWidth) {
      final double paintCenter =
          (offsets[renderIndex] + offsets[renderIndex + 1]) / 2.0;
      return switch (textDirection) {
        TextDirection.ltr => paintCenter,
        TextDirection.rtl => stripWidth - paintCenter,
      };
    }

    final double paddingStart = _paddingStart(textDirection);
    final double previousCenter =
        scrollCenter(previousTabOffsets, previousWidth) + paddingStart;
    final double center = scrollCenter(tabOffsets, width) + paddingStart;
    final double delta = center - previousCenter;
    if (delta.abs() <= _kCyclicNormalizationEpsilon) {
      return;
    }
    final bool wasOnScreen =
        previousCenter >= position.pixels &&
        previousCenter <= position.pixels + position.viewportDimension;
    if (!wasOnScreen) {
      return;
    }
    _schedulePixelsCorrection(position.pixels + delta);
  }

  void _handleTap(_RenderedTabEntry entry) {
    assert(entry.sourceIndex >= 0 && entry.sourceIndex < widget.tabs.length);
    _controller!.animateTo(entry.sourceIndex);
    widget.onTap?.call(entry.sourceIndex);
  }

  Widget _buildStyledTab(
    Widget child,
    bool isSelected,
    Animation<double> animation,
    TabBarThemeData defaults,
  ) {
    return _TabStyle(
      animation: animation,
      isSelected: isSelected,
      isPrimary: widget._isPrimary,
      labelColor: widget.labelColor,
      unselectedLabelColor: widget.unselectedLabelColor,
      labelStyle: widget.labelStyle,
      unselectedLabelStyle: widget.unselectedLabelStyle,
      defaults: defaults,
      child: child,
    );
  }

  bool _debugScheduleCheckHasValidTabsCount() {
    if (_debugHasScheduledValidTabsCountCheck) {
      return true;
    }
    WidgetsBinding.instance.addPostFrameCallback((Duration duration) {
      _debugHasScheduledValidTabsCountCheck = false;
      if (!mounted) {
        return;
      }
      assert(() {
        if (_controller!.length != widget.tabs.length) {
          throw FlutterError(
            "Controller's length property (${_controller!.length}) does not match the "
            "number of tabs (${widget.tabs.length}) present in CyclicTabBar's tabs property.",
          );
        }
        return true;
      }());
    }, debugLabel: 'CyclicTabBar.tabsCountCheck');
    _debugHasScheduledValidTabsCountCheck = true;
    return true;
  }

  bool _debugTabAlignmentIsValid(TabAlignment tabAlignment) {
    assert(() {
      if (widget.isScrollable && tabAlignment == TabAlignment.fill) {
        throw FlutterError(
          '$tabAlignment is only valid for non-scrollable tab bars.',
        );
      }
      if (!widget.isScrollable &&
          (tabAlignment == TabAlignment.start ||
              tabAlignment == TabAlignment.startOffset)) {
        throw FlutterError(
          '$tabAlignment is only valid for scrollable tab bars.',
        );
      }
      return true;
    }());
    return true;
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMaterialLocalizations(context));
    assert(_debugScheduleCheckHasValidTabsCount());
    final ThemeData theme = Theme.of(context);
    final TabBarThemeData tabBarTheme = TabBarTheme.of(context);
    final TextDirection textDirection = Directionality.of(context);
    final TabAlignment effectiveTabAlignment =
        widget.tabAlignment ??
        tabBarTheme.tabAlignment ??
        _defaults.tabAlignment!;
    assert(_debugTabAlignmentIsValid(effectiveTabAlignment));

    final MaterialLocalizations localizations = MaterialLocalizations.of(
      context,
    );
    if (_controller!.length == 0) {
      return LimitedBox(
        maxWidth: 0.0,
        child: SizedBox(
          width: double.infinity,
          height: _kTabHeight + widget.indicatorWeight,
        ),
      );
    }

    _syncRenderedTabArtifacts();
    final List<_RenderedTabEntry> renderedTabEntries = _renderedTabEntries;
    final wrappedTabs = List<Widget>.generate(renderedTabEntries.length, (
      int renderedIndex,
    ) {
      final _RenderedTabEntry entry = renderedTabEntries[renderedIndex];
      final Widget tab = widget.tabs[entry.sourceIndex];
      final EdgeInsetsGeometry padding = _effectiveLabelPaddingForTab(
        tab,
        tabBarTheme,
      );
      _labelPaddings[renderedIndex] = padding;

      return Center(
        heightFactor: 1.0,
        child: Padding(
          padding: _labelPaddings[renderedIndex],
          child: KeyedSubtree(key: _tabKeys[renderedIndex], child: tab),
        ),
      );
    });

    // If the controller was provided by DefaultTabController and we're part
    // of a Hero (typically the AppBar), then we will not be able to find the
    // controller during a Hero transition. See https://github.com/flutter/flutter/issues/213.
    if (_controller != null) {
      final int selectedRenderIndex = _selectedRenderIndex;
      final int previousRenderIndex =
          _controller!.previousIndex +
          (_activeRenderCycleIndex * widget.tabs.length);
      final int tabCount = widget.tabs.length;

      void applyStyledTab(
        int renderIndex,
        bool isSelected,
        Animation<double> animation,
      ) {
        // Every rendered copy of the tab shares its style, so the
        // duplicated cycles read as one continuous strip.
        final int sourceIndex = renderIndex % tabCount;
        for (int cycle = 0; cycle < _renderedCycleCount; cycle += 1) {
          final int mirrorIndex = sourceIndex + cycle * tabCount;
          if (mirrorIndex < 0 || mirrorIndex >= wrappedTabs.length) {
            continue;
          }
          wrappedTabs[mirrorIndex] = _buildStyledTab(
            wrappedTabs[mirrorIndex],
            isSelected,
            animation,
            _defaults,
          );
        }
      }

      if (_controller!.indexIsChanging) {
        // The user tapped on a tab, the tab controller's animation is running.
        assert(selectedRenderIndex != previousRenderIndex);
        final Animation<double> animation = _ChangeAnimation(_controller!);
        applyStyledTab(selectedRenderIndex, true, animation);
        applyStyledTab(previousRenderIndex, false, animation);
      } else {
        // The user is dragging the TabBarView's PageView left or right.
        final Animation<double> centerAnimation = _DragAnimation(
          _controller!,
          _currentIndex!,
        );
        applyStyledTab(selectedRenderIndex, true, centerAnimation);
        // Neighbours across the wrap matter only to a looping tab view;
        // applyStyledTab styles every copy of a tab, so the wrapped index
        // works in the plain strip too.
        if (_currentIndex! > 0 || tabCount > 2) {
          final int previousIndex = (_currentIndex! - 1 + tabCount) % tabCount;
          final Animation<double> previousAnimation = ReverseAnimation(
            _DragAnimation(_controller!, previousIndex),
          );
          applyStyledTab(previousIndex, false, previousAnimation);
        }
        if (_currentIndex! < tabCount - 1 || tabCount > 2) {
          final int nextIndex = (_currentIndex! + 1) % tabCount;
          final Animation<double> nextAnimation = ReverseAnimation(
            _DragAnimation(_controller!, nextIndex),
          );
          applyStyledTab(nextIndex, false, nextAnimation);
        }
      }
    }

    // Add the tap handler to each tab. If the tab bar is not scrollable,
    // then give all of the tabs equal flexibility so that they each occupy
    // the same share of the tab bar's overall width.
    final int renderedTabCount = renderedTabEntries.length;
    for (
      var renderedIndex = 0;
      renderedIndex < renderedTabCount;
      renderedIndex += 1
    ) {
      final _RenderedTabEntry entry = renderedTabEntries[renderedIndex];
      final bool isSelected = entry.sourceIndex == _currentIndex;
      final selectedState = <WidgetState>{if (isSelected) WidgetState.selected};

      final MouseCursor effectiveMouseCursor =
          WidgetStateProperty.resolveAs<MouseCursor?>(
            widget.mouseCursor,
            selectedState,
          ) ??
          tabBarTheme.mouseCursor?.resolve(selectedState) ??
          WidgetStateMouseCursor.clickable.resolve(selectedState);

      final WidgetStateProperty<Color?> defaultOverlay =
          WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
            final Set<WidgetState> effectiveStates = selectedState.toSet()
              ..addAll(states);
            return _defaults.overlayColor?.resolve(effectiveStates);
          });
      wrappedTabs[renderedIndex] = InkWell(
        mouseCursor: effectiveMouseCursor,
        onTap: () {
          _handleTap(entry);
        },
        onHover: (bool value) {
          widget.onHover?.call(value, entry.sourceIndex);
        },
        onFocusChange: (bool value) {
          widget.onFocusChange?.call(value, entry.sourceIndex);
        },
        enableFeedback: widget.enableFeedback ?? true,
        overlayColor:
            widget.overlayColor ?? tabBarTheme.overlayColor ?? defaultOverlay,
        splashFactory:
            widget.splashFactory ??
            tabBarTheme.splashFactory ??
            _defaults.splashFactory,
        borderRadius:
            widget.splashBorderRadius ??
            tabBarTheme.splashBorderRadius ??
            _defaults.splashBorderRadius,
        child: Padding(
          padding: EdgeInsets.only(bottom: widget.indicatorWeight),
          child: Semantics(
            // This has to be wrapped above the Stack to override any role set by the child.
            role: SemanticsRole.tab,
            child: Stack(
              children: <Widget>[
                wrappedTabs[renderedIndex],
                Semantics(
                  selected: isSelected,
                  label: kIsWeb
                      ? null
                      : localizations.tabLabel(
                          tabIndex: entry.sourceIndex + 1,
                          tabCount: widget.tabs.length,
                        ),
                ),
              ],
            ),
          ),
        ),
      );
      wrappedTabs[renderedIndex] = MergeSemantics(
        child: wrappedTabs[renderedIndex],
      );
      if (_stripMode != _CyclicTabStripMode.normal &&
          entry.renderCycleIndex != _activeRenderCycleIndex) {
        wrappedTabs[renderedIndex] = ExcludeSemantics(
          child: wrappedTabs[renderedIndex],
        );
      }
      if (!widget.isScrollable && effectiveTabAlignment == TabAlignment.fill) {
        wrappedTabs[renderedIndex] = Expanded(
          child: wrappedTabs[renderedIndex],
        );
      }
    }

    Widget tabBar = Semantics(
      role: SemanticsRole.tabBar,
      container: true,
      explicitChildNodes: true,
      child: CustomPaint(
        painter: _indicatorPainter,
        child: _TabStyle(
          animation: kAlwaysDismissedAnimation,
          isSelected: false,
          isPrimary: widget._isPrimary,
          labelColor: widget.labelColor,
          unselectedLabelColor: widget.unselectedLabelColor,
          labelStyle: widget.labelStyle,
          unselectedLabelStyle: widget.unselectedLabelStyle,
          defaults: _defaults,
          child: _TabLabelBar(
            onPerformLayout: _saveTabOffsets,
            mainAxisSize: effectiveTabAlignment == TabAlignment.fill
                ? MainAxisSize.max
                : MainAxisSize.min,
            children: wrappedTabs,
          ),
        ),
      ),
    );

    if (widget.isScrollable) {
      final EdgeInsetsGeometry? effectivePadding =
          effectiveTabAlignment == TabAlignment.startOffset
          ? const EdgeInsetsDirectional.only(
              start: _kStartOffset,
            ).add(widget.padding ?? EdgeInsets.zero)
          : widget.padding;
      _effectiveScrollPaddingValue = effectivePadding;
      _scrollController ??= _TabBarScrollController(this);
      tabBar = NotificationListener<ScrollNotification>(
        onNotification: _handleScrollableNotification,
        child: Stack(
          fit: StackFit.passthrough,
          children: <Widget>[
            if (_hasStretchPreview)
              Padding(
                padding: effectivePadding ?? EdgeInsets.zero,
                child: _buildStretchPreview(tabBarTheme, textDirection),
              ),
            ScrollConfiguration(
              // The scrolling tabs should not show an overscroll indicator.
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(overscroll: false),
              child: SingleChildScrollView(
                dragStartBehavior: widget.dragStartBehavior,
                scrollDirection: Axis.horizontal,
                controller: _scrollController,
                padding: effectivePadding,
                physics: widget.physics,
                child: Transform.translate(
                  offset: Offset(_stretchTranslationX(textDirection), 0.0),
                  child: tabBar,
                ),
              ),
            ),
          ],
        ),
      );
      if (theme.useMaterial3) {
        final AlignmentGeometry effectiveAlignment =
            switch (effectiveTabAlignment) {
              TabAlignment.center => Alignment.center,
              TabAlignment.start ||
              TabAlignment.startOffset ||
              TabAlignment.fill => AlignmentDirectional.centerStart,
            };

        final Color dividerColor =
            widget.dividerColor ??
            tabBarTheme.dividerColor ??
            _defaults.dividerColor!;
        final double dividerHeight =
            widget.dividerHeight ??
            tabBarTheme.dividerHeight ??
            _defaults.dividerHeight!;

        tabBar = Align(
          heightFactor: 1.0,
          widthFactor: dividerHeight > 0 ? null : 1.0,
          alignment: effectiveAlignment,
          child: tabBar,
        );

        if (dividerColor != Colors.transparent && dividerHeight > 0) {
          tabBar = CustomPaint(
            painter: _DividerPainter(
              dividerColor: dividerColor,
              dividerHeight: dividerHeight,
            ),
            child: tabBar,
          );
        }
      }
    } else if (widget.padding != null) {
      tabBar = Padding(padding: widget.padding!, child: tabBar);
    }

    return Material(
      type: MaterialType.transparency,
      child: MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: widget.textScaler ?? tabBarTheme.textScaler),
        child: tabBar,
      ),
    );
  }
}

/// A page view that displays the widget which corresponds to the currently
/// selected tab.
///
/// This widget is typically used in conjunction with a [CyclicTabBar].
///
/// {@youtube 560 315 https://www.youtube.com/watch?v=POtoEH-5l40}
///
/// If a [TabController] is not provided, then there must be a [DefaultTabController]
/// ancestor.
///
/// The tab controller's [TabController.length] must equal the length of the
/// [children] list and the length of the [CyclicTabBar.tabs] list.
///
/// To see a sample implementation, visit the [TabController] documentation.
class CyclicTabBarView extends StatefulWidget {
  /// Creates a page view with one child per tab.
  ///
  /// The length of [children] must be the same as the [controller]'s length.
  const CyclicTabBarView({
    super.key,
    required this.children,
    this.controller,
    this.physics,
    this.dragStartBehavior = DragStartBehavior.start,
    this.viewportFraction = 1.0,
    this.clipBehavior = Clip.hardEdge,
    this.loop = false,
    this.loopSentinelBuilder,
    this.enableFeedback,
  });

  /// This widget's selection and animation state.
  ///
  /// If [TabController] is not provided, then the value of [DefaultTabController.of]
  /// will be used.
  final TabController? controller;

  /// One widget per tab.
  ///
  /// Its length must match the length of the [CyclicTabBar.tabs]
  /// list, as well as the [controller]'s [TabController.length].
  final List<Widget> children;

  /// How the page view should respond to user input.
  ///
  /// For example, determines how the page view continues to animate after the
  /// user stops dragging the page view.
  ///
  /// The physics are modified to snap to page boundaries using
  /// [PageScrollPhysics] prior to being used.
  ///
  /// Defaults to matching platform conventions.
  final ScrollPhysics? physics;

  /// {@macro flutter.widgets.scrollable.dragStartBehavior}
  final DragStartBehavior dragStartBehavior;

  /// {@macro flutter.widgets.pageview.viewportFraction}
  final double viewportFraction;

  /// {@macro flutter.material.Material.clipBehavior}
  ///
  /// Defaults to [Clip.hardEdge].
  final Clip clipBehavior;

  /// Whether swiping past the last page continues to the first page and
  /// swiping before the first page continues to the last.
  ///
  /// The [controller] keeps its normal index range. The wrap is done by
  /// scrolling onto a sentinel copy of the neighbouring page and jumping to
  /// the real one once the scroll settles, so the first and last page are
  /// built a second time while a wrap is in flight and that page's state is
  /// rebuilt at the wrap. By default the sentinel is the same widget as the
  /// real page; a page that holds a [GlobalKey] or a controller meant for a
  /// single instance would then fail or share state, so such pages must
  /// supply [loopSentinelBuilder]. Programmatic changes between the first and
  /// last tab animate across the wrap as well; a paired [CyclicTabBar] still
  /// moves its indicator and scroll position the long way round for those.
  /// A paired scrollable [CyclicTabBar] that overflows its viewport follows a
  /// swiped wrap cyclically; a strip that fits slides its indicator off the
  /// end toward the wrapped-to tab instead.
  ///
  /// Has no effect with fewer than two [children]. Defaults to false.
  final bool loop;

  /// Builds the sentinel copy of the page at [index] (always `0` or
  /// `children.length - 1`) that is shown while a wrap is in flight when
  /// [loop] is true.
  ///
  /// Use it when the real page cannot be built twice, for instance because
  /// it holds a [GlobalKey] or a single-instance controller. The sentinel is
  /// never the current page, is not interactive for long, and is excluded
  /// from semantics, so a lightweight stand-in that looks like the page is
  /// enough. When null, the real page widget is reused.
  final Widget Function(BuildContext context, int index)? loopSentinelBuilder;

  /// Whether a swipe that wraps around gives haptic feedback, like a
  /// [CyclicTabBar] pulled past its edge, when [loop] is true.
  ///
  /// Wraps driven by the [controller], such as a tap on the paired tab bar,
  /// stay silent.
  ///
  /// Defaults to true.
  final bool? enableFeedback;

  @override
  State<CyclicTabBarView> createState() => _TabBarViewState();
}

class _TabBarViewState extends State<CyclicTabBarView> {
  TabController? _controller;
  PageController? _pageController;
  late List<Widget> _childrenWithKey;
  int? _currentIndex;
  int _warpUnderwayCount = 0;
  int _scrollUnderwayCount = 0;
  bool _debugHasScheduledValidChildrenCountCheck = false;

  // If the TabBarView is rebuilt with a new tab controller, the caller should
  // dispose the old one. In that case the old controller's animation will be
  // null and should not be accessed.
  bool get _controllerIsValid => _controller?.animation != null;

  // Looping renders a sentinel copy of the last page before the first and of
  // the first page after the last, so a swipe past either end has somewhere
  // to go. Once such a swipe settles on a sentinel the view jumps to the real
  // page, which paints the same thing. Page indices in the PageView are
  // therefore offset by one from the controller's indices while looping.
  bool get _loops => widget.loop && widget.children.length > 1;

  int get _pageOffset => _loops ? 1 : 0;

  int _wrapIndex(int index) {
    final int length = widget.children.length;
    return ((index % length) + length) % length;
  }

  void _updateTabController() {
    final TabController? newController =
        widget.controller ?? DefaultTabController.maybeOf(context);
    assert(() {
      if (newController == null) {
        throw FlutterError(
          'No TabController for ${widget.runtimeType}.\n'
          'When creating a ${widget.runtimeType}, you must either provide an explicit '
          'TabController using the "controller" property, or you must ensure that there '
          'is a DefaultTabController above the ${widget.runtimeType}.\n'
          'In this case, there was neither an explicit controller nor a default controller.',
        );
      }
      return true;
    }());

    if (newController == _controller) {
      return;
    }

    if (_controllerIsValid) {
      _controller!.animation!.removeListener(_handleTabControllerAnimationTick);
    }
    _controller = newController;
    if (_controller != null) {
      _controller!.animation!.addListener(_handleTabControllerAnimationTick);
    }
  }

  void _jumpToPage(int page) {
    _warpUnderwayCount += 1;
    _pageController!.jumpToPage(page);
    _warpUnderwayCount -= 1;
  }

  Future<void> _animateToPage(
    int page, {
    required Duration duration,
    required Curve curve,
  }) async {
    _warpUnderwayCount += 1;
    await _pageController!.animateToPage(
      page,
      duration: duration,
      curve: curve,
    );
    _warpUnderwayCount -= 1;
  }

  @override
  void initState() {
    super.initState();
    _updateChildren();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateTabController();
    _currentIndex = _controller!.index;
    if (_pageController == null) {
      _pageController = PageController(
        initialPage: _currentIndex! + _pageOffset,
        viewportFraction: widget.viewportFraction,
      );
    } else {
      _pageController!.jumpToPage(_currentIndex! + _pageOffset);
    }
  }

  @override
  void didUpdateWidget(CyclicTabBarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _updateTabController();
      _currentIndex = _controller!.index;
      _jumpToPage(_currentIndex! + _pageOffset);
    }
    if (widget.viewportFraction != oldWidget.viewportFraction) {
      _pageController?.dispose();
      _pageController = PageController(
        initialPage: _currentIndex! + _pageOffset,
        viewportFraction: widget.viewportFraction,
      );
    }
    final bool loopChanged =
        widget.loop != oldWidget.loop ||
        widget.children.length != oldWidget.children.length;
    // While a warp is under way, we stop updating the tab page contents.
    // This is tracked in https://github.com/flutter/flutter/issues/31269.
    if ((widget.children != oldWidget.children || loopChanged) &&
        _warpUnderwayCount == 0) {
      _updateChildren();
    }
    if (loopChanged && _pageController!.hasClients) {
      // The sentinel page shifts every real page by one.
      _jumpToPage(_currentIndex! + _pageOffset);
    }
  }

  @override
  void dispose() {
    if (_controllerIsValid) {
      _controller!.animation!.removeListener(_handleTabControllerAnimationTick);
    }
    _controller = null;
    _pageController?.dispose();
    // We don't own the _controller Animation, so it's not disposed here.
    super.dispose();
  }

  void _updateChildren() {
    final List<Widget> pages = widget.children.map<Widget>((Widget child) {
      return Semantics(role: SemanticsRole.tabPanel, child: child);
    }).toList();
    if (_loops) {
      final int lastIndex = widget.children.length - 1;
      Widget sentinel(int index) {
        final Widget Function(BuildContext, int)? builder =
            widget.loopSentinelBuilder;
        if (builder != null) {
          return Builder(
            builder: (BuildContext context) => builder(context, index),
          );
        }
        final Widget page = widget.children[index];
        assert(() {
          if (page.key is GlobalKey) {
            throw FlutterError(
              'CyclicTabBarView(loop: true) needs a loopSentinelBuilder.\n'
              'The ${index == 0 ? 'first' : 'last'} child carries a GlobalKey, '
              'and looping builds a second copy of it while a wrap is in '
              'flight. Provide loopSentinelBuilder to build a stand-in for it.',
            );
          }
          return true;
        }());
        return page;
      }

      // Sentinels are only ever on screen mid-swipe, and never the current
      // page, so they stay out of the semantics tree.
      pages.insert(0, ExcludeSemantics(child: sentinel(lastIndex)));
      pages.add(ExcludeSemantics(child: sentinel(0)));
    }
    _childrenWithKey = KeyedSubtree.ensureUniqueKeysForList(pages);
  }

  void _handleTabControllerAnimationTick() {
    if (_scrollUnderwayCount > 0 || !_controller!.indexIsChanging) {
      return;
    } // This widget is driving the controller's animation.

    if (_controller!.index != _currentIndex) {
      _currentIndex = _controller!.index;
      _warpToCurrentIndex();
    }
  }

  void _warpToCurrentIndex() {
    if (!mounted ||
        _pageController!.page == (_currentIndex! + _pageOffset).toDouble()) {
      return;
    }

    final int previousIndex = _controller!.previousIndex;
    final int delta = _currentIndex! - previousIndex;
    final adjacentDestination = delta.abs() == 1;
    if (adjacentDestination) {
      _warpToAdjacentTab(_controller!.animationDuration);
    } else if (_loops && delta.abs() == widget.children.length - 1) {
      // First and last tab are neighbours across the wrap: animate onto the
      // sentinel copy next door, then jump to the real page.
      _warpAcrossWrap(delta > 0 ? -1 : 1, _controller!.animationDuration);
    } else {
      _warpToNonAdjacentTab(_controller!.animationDuration);
    }
  }

  Future<void> _warpAcrossWrap(int direction, Duration duration) async {
    final int sentinelPage =
        _controller!.previousIndex + _pageOffset + direction;
    if (duration == Duration.zero) {
      _jumpToPage(_currentIndex! + _pageOffset);
    } else {
      await _animateToPage(
        sentinelPage,
        duration: duration,
        curve: Curves.ease,
      );
      if (!mounted) {
        return;
      }
      _jumpToPage(_currentIndex! + _pageOffset);
    }
    if (mounted) {
      setState(() {
        _updateChildren();
      });
    }
  }

  Future<void> _warpToAdjacentTab(Duration duration) async {
    if (duration == Duration.zero) {
      _jumpToPage(_currentIndex! + _pageOffset);
    } else {
      await _animateToPage(
        _currentIndex! + _pageOffset,
        duration: duration,
        curve: Curves.ease,
      );
    }
    if (mounted) {
      setState(() {
        _updateChildren();
      });
    }
    return Future<void>.value();
  }

  Future<void> _warpToNonAdjacentTab(Duration duration) async {
    final int previousIndex = _controller!.previousIndex;
    assert((_currentIndex! - previousIndex).abs() > 1);

    // initialPage defines which page is shown when starting the animation.
    // This page is adjacent to the destination page.
    final int initialPage = _currentIndex! > previousIndex
        ? _currentIndex! - 1
        : _currentIndex! + 1;

    setState(() {
      // Needed for `RenderSliverMultiBoxAdaptor.move` and kept alive children.
      // For motivation, see https://github.com/flutter/flutter/pull/29188 and
      // https://github.com/flutter/flutter/issues/27010#issuecomment-486475152.
      _childrenWithKey = List<Widget>.of(_childrenWithKey, growable: false);
      final Widget temp = _childrenWithKey[initialPage + _pageOffset];
      _childrenWithKey[initialPage + _pageOffset] =
          _childrenWithKey[previousIndex + _pageOffset];
      _childrenWithKey[previousIndex + _pageOffset] = temp;
    });

    // Make a first jump to the adjacent page.
    _jumpToPage(initialPage + _pageOffset);

    // Jump or animate to the destination page.
    if (duration == Duration.zero) {
      _jumpToPage(_currentIndex! + _pageOffset);
    } else {
      await _animateToPage(
        _currentIndex! + _pageOffset,
        duration: duration,
        curve: Curves.ease,
      );
    }

    if (mounted) {
      setState(() {
        _updateChildren();
      });
    }
  }

  void _syncControllerOffset() {
    _controller!.offset = clampDouble(
      _pageController!.page! - _pageOffset - _controller!.index,
      -1.0,
      1.0,
    );
  }

  // Called when the PageView scrolls
  bool _handleScrollNotification(ScrollNotification notification) {
    if (_warpUnderwayCount > 0 || _scrollUnderwayCount > 0) {
      return false;
    }

    if (notification.depth != 0) {
      return false;
    }

    if (!_controllerIsValid) {
      return false;
    }

    _scrollUnderwayCount += 1;
    final double page = _pageController!.page! - _pageOffset;
    if (notification is ScrollUpdateNotification &&
        !_controller!.indexIsChanging) {
      final bool pageChanged = (page - _controller!.index).abs() > 1.0;
      if (pageChanged) {
        _controller!.index = _wrapIndex(page.round());
        _currentIndex = _controller!.index;
      }
      _syncControllerOffset();
    } else if (notification is ScrollEndNotification) {
      final int settledPage = page.round();
      final int index = _wrapIndex(settledPage);
      if (_loops && settledPage != index) {
        if (widget.enableFeedback ?? true) {
          HapticFeedback.heavyImpact();
        }
        // Settled on a sentinel: swap in the identical real page. Deferred,
        // since this notification comes from the activity change that just
        // ended the scroll.
        WidgetsBinding.instance.addPostFrameCallback((Duration duration) {
          if (!mounted || _pageController == null) {
            return;
          }
          final double? current = _pageController!.page;
          if (current != null &&
              (current - (settledPage + _pageOffset)).abs() < 0.5) {
            _jumpToPage(index + _pageOffset);
          }
        });
      }
      _controller!.index = index;
      _currentIndex = _controller!.index;
      if (!_controller!.indexIsChanging) {
        if (_loops && settledPage != index) {
          // The sentinel is the real page's stand-in: the wrap is complete.
          _controller!.offset = 0.0;
        } else {
          _syncControllerOffset();
        }
      }
    }
    _scrollUnderwayCount -= 1;

    return false;
  }

  bool _debugScheduleCheckHasValidChildrenCount() {
    if (_debugHasScheduledValidChildrenCountCheck) {
      return true;
    }
    WidgetsBinding.instance.addPostFrameCallback((Duration duration) {
      _debugHasScheduledValidChildrenCountCheck = false;
      if (!mounted) {
        return;
      }
      assert(() {
        if (_controller!.length != widget.children.length) {
          throw FlutterError(
            "Controller's length property (${_controller!.length}) does not match the "
            "number of children (${widget.children.length}) present in CyclicTabBarView's children property.",
          );
        }
        return true;
      }());
    }, debugLabel: 'CyclicTabBarView.validChildrenCountCheck');
    _debugHasScheduledValidChildrenCountCheck = true;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    assert(_debugScheduleCheckHasValidChildrenCount());

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: PageView(
        dragStartBehavior: widget.dragStartBehavior,
        clipBehavior: widget.clipBehavior,
        controller: _pageController,
        physics: widget.physics == null
            ? const PageScrollPhysics().applyTo(const ClampingScrollPhysics())
            : const PageScrollPhysics().applyTo(widget.physics),
        children: _childrenWithKey,
      ),
    );
  }
}

class _TabsDefaultsM2 extends TabBarThemeData {
  _TabsDefaultsM2(this.context, this.isScrollable)
    : super(indicatorSize: TabBarIndicatorSize.tab);

  final BuildContext context;
  late final ColorScheme _colors = Theme.of(context).colorScheme;
  late final bool isDark = Theme.brightnessOf(context) == Brightness.dark;
  late final Color primaryColor = isDark ? Colors.grey[900]! : Colors.blue;
  final bool isScrollable;

  @override
  Color? get indicatorColor =>
      _colors.secondary == primaryColor ? Colors.white : _colors.secondary;

  @override
  Color? get labelColor => Theme.of(context).primaryTextTheme.bodyLarge!.color!;

  @override
  TextStyle? get labelStyle => Theme.of(context).primaryTextTheme.bodyLarge;

  @override
  TextStyle? get unselectedLabelStyle =>
      Theme.of(context).primaryTextTheme.bodyLarge;

  @override
  InteractiveInkFeatureFactory? get splashFactory =>
      Theme.of(context).splashFactory;

  @override
  TabAlignment? get tabAlignment =>
      isScrollable ? TabAlignment.start : TabAlignment.fill;
}

// BEGIN GENERATED TOKEN PROPERTIES - Tabs

// Do not edit by hand. The code between the "BEGIN GENERATED" and
// "END GENERATED" comments are generated from data in the Material
// Design token database by the script:
//   dev/tools/gen_defaults/bin/gen_defaults.dart.

// dart format off
class _TabsPrimaryDefaultsM3 extends TabBarThemeData {
  _TabsPrimaryDefaultsM3(this.context, this.isScrollable)
    : super(indicatorSize: TabBarIndicatorSize.label);

  final BuildContext context;
  late final ColorScheme _colors = Theme.of(context).colorScheme;
  late final TextTheme _textTheme = Theme.of(context).textTheme;
  final bool isScrollable;

  // This value comes from Divider widget defaults. Token db deprecated 'primary-navigation-tab.divider.color' token.
  @override
  Color? get dividerColor => _colors.outlineVariant;

  // This value comes from Divider widget defaults. Token db deprecated 'primary-navigation-tab.divider.height' token.
  @override
  double? get dividerHeight => 1.0;

  @override
  Color? get indicatorColor => _colors.primary;

  @override
  Color? get labelColor => _colors.primary;

  @override
  TextStyle? get labelStyle => _textTheme.titleSmall;

  @override
  Color? get unselectedLabelColor => _colors.onSurfaceVariant;

  @override
  TextStyle? get unselectedLabelStyle => _textTheme.titleSmall;

  @override
  WidgetStateProperty<Color?> get overlayColor {
    return WidgetStateProperty.resolveWith((Set<WidgetState> states) {
      if (states.contains(WidgetState.selected)) {
        if (states.contains(WidgetState.pressed)) {
          return _colors.primary.withValues(alpha: 0.1);
        }
        if (states.contains(WidgetState.hovered)) {
          return _colors.primary.withValues(alpha: 0.08);
        }
        if (states.contains(WidgetState.focused)) {
          return _colors.primary.withValues(alpha: 0.1);
        }
        return null;
      }
      if (states.contains(WidgetState.pressed)) {
        return _colors.primary.withValues(alpha: 0.1);
      }
      if (states.contains(WidgetState.hovered)) {
        return _colors.onSurface.withValues(alpha: 0.08);
      }
      if (states.contains(WidgetState.focused)) {
        return _colors.onSurface.withValues(alpha: 0.1);
      }
      return null;
    });
  }

  @override
  InteractiveInkFeatureFactory? get splashFactory => Theme.of(context).splashFactory;

  @override
  TabAlignment? get tabAlignment => isScrollable ? TabAlignment.startOffset : TabAlignment.fill;

  static double indicatorWeight(TabBarIndicatorSize indicatorSize) {
    return switch (indicatorSize) {
      TabBarIndicatorSize.label => 3.0,
      TabBarIndicatorSize.tab   => 2.0,
    };
  }

}

class _TabsSecondaryDefaultsM3 extends TabBarThemeData {
  _TabsSecondaryDefaultsM3(this.context, this.isScrollable)
    : super(indicatorSize: TabBarIndicatorSize.tab);

  final BuildContext context;
  late final ColorScheme _colors = Theme.of(context).colorScheme;
  late final TextTheme _textTheme = Theme.of(context).textTheme;
  final bool isScrollable;

  // This value comes from Divider widget defaults. Token db deprecated 'secondary-navigation-tab.divider.color' token.
  @override
  Color? get dividerColor => _colors.outlineVariant;

  // This value comes from Divider widget defaults. Token db deprecated 'secondary-navigation-tab.divider.height' token.
  @override
  double? get dividerHeight => 1.0;

  @override
  Color? get indicatorColor => _colors.primary;

  @override
  Color? get labelColor => _colors.onSurface;

  @override
  TextStyle? get labelStyle => _textTheme.titleSmall;

  @override
  Color? get unselectedLabelColor => _colors.onSurfaceVariant;

  @override
  TextStyle? get unselectedLabelStyle => _textTheme.titleSmall;

  @override
  WidgetStateProperty<Color?> get overlayColor {
    return WidgetStateProperty.resolveWith((Set<WidgetState> states) {
      if (states.contains(WidgetState.selected)) {
        if (states.contains(WidgetState.pressed)) {
          return _colors.onSurface.withValues(alpha: 0.1);
        }
        if (states.contains(WidgetState.hovered)) {
          return _colors.onSurface.withValues(alpha: 0.08);
        }
        if (states.contains(WidgetState.focused)) {
          return _colors.onSurface.withValues(alpha: 0.1);
        }
        return null;
      }
      if (states.contains(WidgetState.pressed)) {
        return _colors.onSurface.withValues(alpha: 0.1);
      }
      if (states.contains(WidgetState.hovered)) {
        return _colors.onSurface.withValues(alpha: 0.08);
      }
      if (states.contains(WidgetState.focused)) {
        return _colors.onSurface.withValues(alpha: 0.1);
      }
      return null;
    });
  }

  @override
  InteractiveInkFeatureFactory? get splashFactory => Theme.of(context).splashFactory;

  @override
  TabAlignment? get tabAlignment => isScrollable ? TabAlignment.startOffset : TabAlignment.fill;

  static double indicatorWeight = 2.0;
}
// dart format on

// END GENERATED TOKEN PROPERTIES - Tabs
