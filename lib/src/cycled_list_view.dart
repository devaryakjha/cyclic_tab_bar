// ignore: unnecessary_import
import 'package:meta/meta.dart' show internal;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

typedef ModuloIndexedWidgetBuilder = Widget Function(
    BuildContext context, int modIndex, int rawIndex);

class CycledListView extends StatefulWidget {
  /// See [ListView.builder]
  const CycledListView.builder({
    super.key,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.controller,
    this.physics,
    this.padding,
    required this.itemBuilder,
    required this.contentCount,
    this.itemCount,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
    this.cacheExtent,
    this.anchor = 0.0,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
  }) : separatorBuilder = null;

  /// Creates a scrollable, linear array of widgets that are separated by separator widgets.
  ///
  /// Similar to [ListView.separated], but with infinite scrolling support.
  /// Separators appear between all items, including at the wrap-around boundary.
  const CycledListView.separated({
    super.key,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.controller,
    this.physics,
    this.padding,
    required this.itemBuilder,
    required this.separatorBuilder,
    required this.contentCount,
    this.itemCount,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
    this.cacheExtent,
    this.anchor = 0.0,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
  });

  /// See: [ScrollView.scrollDirection]
  final Axis scrollDirection;

  /// See: [ScrollView.reverse]
  final bool reverse;

  /// See: [ScrollView.controller]
  final CycledScrollController? controller;

  /// See: [ScrollView.physics]
  final ScrollPhysics? physics;

  /// See: [BoxScrollView.padding]
  final EdgeInsets? padding;

  /// See: [ListView.builder]
  final ModuloIndexedWidgetBuilder itemBuilder;

  /// Called to build separators between items.
  ///
  /// Only used when constructed with [CycledListView.separated].
  /// The separator builder receives both the modulo index (0 to contentCount-1)
  /// and the raw index for flexibility in building different separators.
  final ModuloIndexedWidgetBuilder? separatorBuilder;

  /// See: [SliverChildBuilderDelegate.childCount]
  final int? itemCount;

  /// See: [ScrollView.cacheExtent]
  final double? cacheExtent;

  /// See: [ScrollView.anchor]
  final double anchor;

  /// See: [SliverChildBuilderDelegate.addAutomaticKeepAlives]
  final bool addAutomaticKeepAlives;

  /// See: [SliverChildBuilderDelegate.addRepaintBoundaries]
  final bool addRepaintBoundaries;

  /// See: [SliverChildBuilderDelegate.addSemanticIndexes]
  final bool addSemanticIndexes;

  /// See: [ScrollView.dragStartBehavior]
  final DragStartBehavior dragStartBehavior;

  /// See: [ScrollView.keyboardDismissBehavior]
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  /// See: [ScrollView.restorationId]
  final String? restorationId;

  /// See: [ScrollView.clipBehavior]
  final Clip clipBehavior;

  final int contentCount;

  @override
  CycledListViewState createState() => CycledListViewState();
}

class CycledListViewState extends State<CycledListView> {
  CycledScrollController? _controller;

  CycledScrollController get _effectiveController =>
      widget.controller ?? _controller!;

  UniqueKey positiveListKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _controller = CycledScrollController(initialScrollOffset: 0.0);
    }
  }

  @override
  void didUpdateWidget(CycledListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller == null && oldWidget.controller != null) {
      _controller = CycledScrollController(initialScrollOffset: 0.0);
    } else if (widget.controller != null && oldWidget.controller == null) {
      _controller!.dispose();
      _controller = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> slivers = _buildSlivers(context);
    final AxisDirection axisDirection = _getDirection(context);
    final scrollPhysics =
        widget.physics ?? const AlwaysScrollableScrollPhysics();
    return Scrollable(
      axisDirection: axisDirection,
      controller: _effectiveController,
      physics: scrollPhysics,
      viewportBuilder: (BuildContext context, ViewportOffset offset) {
        return Viewport(
          axisDirection: axisDirection,
          anchor: widget.anchor,
          offset: offset,
          center: positiveListKey,
          slivers: slivers,
          cacheExtent: widget.cacheExtent,
        );
      },
    );
  }

  AxisDirection _getDirection(BuildContext context) {
    return getAxisDirectionFromAxisReverseAndDirectionality(
        context, widget.scrollDirection, widget.reverse);
  }

  List<Widget> _buildSlivers(BuildContext context) {
    return <Widget>[
      SliverList(
        delegate: negativeChildrenDelegate,
      ),
      SliverList(
        delegate: positiveChildrenDelegate,
        key: positiveListKey,
      ),
    ];
  }

  SliverChildDelegate get positiveChildrenDelegate {
    final itemCount = widget.itemCount;
    final separatorBuilder = widget.separatorBuilder;

    if (separatorBuilder != null) {
      // For separated list, we need items + separators
      final childCount = itemCount != null ? (2 * itemCount - 1) : null;
      return SliverChildBuilderDelegate(
        (context, index) {
          final itemIndex = index ~/ 2;
          if (index.isEven) {
            // Build item
            return widget.itemBuilder(
                context, itemIndex % widget.contentCount, itemIndex);
          } else {
            // Build separator - map to the item it follows
            return separatorBuilder(
                context, itemIndex % widget.contentCount, itemIndex);
          }
        },
        childCount: childCount,
        addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
        addRepaintBoundaries: widget.addRepaintBoundaries,
      );
    }

    return SliverChildBuilderDelegate(
      (context, index) {
        return widget.itemBuilder(context, index % widget.contentCount, index);
      },
      childCount: itemCount,
      addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
      addRepaintBoundaries: widget.addRepaintBoundaries,
    );
  }

  SliverChildDelegate get negativeChildrenDelegate {
    final itemCount = widget.itemCount;
    final separatorBuilder = widget.separatorBuilder;

    if (separatorBuilder != null) {
      // For separated list, we need items + separators
      final childCount = itemCount != null ? (2 * itemCount - 1) : null;
      return SliverChildBuilderDelegate(
        (context, index) {
          if (index == 0) return const SizedBox.shrink();
          final itemIndex = index ~/ 2;
          if (index.isEven) {
            // Build item
            return widget.itemBuilder(
                context, -itemIndex % widget.contentCount, -itemIndex);
          } else {
            // Build separator - map to the item it follows
            return separatorBuilder(
                context, -itemIndex % widget.contentCount, -itemIndex);
          }
        },
        childCount: childCount,
        addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
        addRepaintBoundaries: widget.addRepaintBoundaries,
      );
    }

    return SliverChildBuilderDelegate(
      (context, index) {
        if (index == 0) return const SizedBox.shrink();
        return widget.itemBuilder(
            context, -index % widget.contentCount, -index);
      },
      childCount: itemCount,
      addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
      addRepaintBoundaries: widget.addRepaintBoundaries,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
        .add(EnumProperty<Axis>('scrollDirection', widget.scrollDirection));
    properties.add(FlagProperty('reverse',
        value: widget.reverse, ifTrue: 'reversed', showName: true));
    properties.add(DiagnosticsProperty<ScrollController>(
        'controller', widget.controller,
        showName: false, defaultValue: null));
    properties.add(DiagnosticsProperty<ScrollPhysics>('physics', widget.physics,
        showName: false, defaultValue: null));
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>(
        'padding', widget.padding,
        defaultValue: null));
    properties.add(
        DoubleProperty('cacheExtent', widget.cacheExtent, defaultValue: null));
  }
}

/// Calculates the shortest movement distance between two indices in a cyclic list.
///
/// Given a [current] index and a [selected] target index in a list of [length] items,
/// this function determines the shortest path to move from current to selected,
/// taking into account wrapping around the bounds.
///
/// Returns:
/// - Positive values indicate forward movement
/// - Negative values indicate backward movement
/// - The magnitude indicates how many steps to move
///
/// Example: In a list of length 5:
/// - Moving from index 1 to 4: returns 3 (forward)
/// - Moving from index 4 to 1: returns -3 (backward, wrapping around)
int calculateMoveIndexDistance(int current, int selected, int length) {
  final tabDistance = selected - current;
  var move = tabDistance;
  if (tabDistance.abs() >= length ~/ 2) {
    move += (-tabDistance.sign * length);
  }

  return move;
}

class CycledScrollController extends ScrollController {
  /// Creates a new [CycledScrollController]
  ///
  /// Optional parameters:
  /// - [initialIndex]: Starting index (will be applied after widget builds)
  /// - [initialScrollOffset]: Starting scroll position in pixels
  /// - [keepScrollOffset]: Whether to save scroll position (default: true)
  /// - [debugLabel]: Label for debugging purposes
  CycledScrollController({
    this.initialIndex,
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
  });

  /// Initial index to scroll to after the widget builds.
  final int? initialIndex;

  /// Internal callback set by CyclicTabBar to handle index-based navigation.
  /// This is called by [scrollToIndex] and delegates to the widget's internal
  /// navigation logic which knows the actual page width and content length.
  @internal
  Future<void> Function(int index)? scrollToIndexCallback;

  /// Internal callback set by CyclicTabBar to get the current index.
  @internal
  int Function()? getCurrentIndexCallback;

  /// Gets the current index based on the scroll position.
  ///
  /// Returns the modulo index (0 to contentLength-1) of the currently
  /// visible/centered item.
  ///
  /// Throws assertion error if the controller is not attached to a CyclicTabBar.
  int get currentIndex {
    assert(getCurrentIndexCallback != null,
        'Controller must be attached to a CyclicTabBar to use currentIndex');
    return getCurrentIndexCallback?.call() ?? 0;
  }

  /// Animates the scroll position to show the item at [index].
  ///
  /// Uses the shortest path, wrapping around if necessary.
  ///
  /// Parameters:
  /// - [index]: Target index (any integer - will be wrapped to valid range using modulo)
  ///
  /// Example:
  /// ```dart
  /// controller.scrollToIndex(3);   // Navigate to page 3
  /// controller.scrollToIndex(10);  // For contentLength=5, navigates to page 0 (10 % 5)
  /// controller.scrollToIndex(-1);  // For contentLength=5, navigates to page 4 (-1 % 5)
  /// ```
  ///
  /// Throws assertion error if the controller is not attached to a CyclicTabBar.
  Future<void> scrollToIndex(int index) async {
    assert(scrollToIndexCallback != null,
        'Controller must be attached to a CyclicTabBar to use scrollToIndex');
    return scrollToIndexCallback?.call(index);
  }

  /// Gets the current scroll direction (forward, reverse, or idle).
  ScrollDirection get currentScrollDirection => position.userScrollDirection;

  @override
  ScrollPosition createScrollPosition(ScrollPhysics physics,
      ScrollContext context, ScrollPosition? oldPosition) {
    return _InfiniteScrollPosition(
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
    );
  }
}

class _InfiniteScrollPosition extends ScrollPositionWithSingleContext {
  _InfiniteScrollPosition({
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  @override
  double get minScrollExtent => double.negativeInfinity;

  @override
  double get maxScrollExtent => double.infinity;
}
