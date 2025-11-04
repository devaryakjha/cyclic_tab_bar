import 'package:flutter/material.dart';

import 'cyclic_tab_controller.dart';

/// An inherited widget that provides a [CyclicTabController] to its descendants.
///
/// This is a convenience widget that creates and manages a [CyclicTabController]
/// automatically, similar to Flutter's [DefaultTabController].
///
/// Example:
/// ```dart
/// DefaultCyclicTabController(
///   contentLength: 10,
///   child: Column(
///     children: [
///       CyclicTabBar(
///         contentLength: 10,
///         tabBuilder: (index, isSelected) => Text('Tab $index'),
///       ),
///       Expanded(
///         child: CyclicTabBarView(
///           contentLength: 10,
///           pageBuilder: (context, index, isSelected) {
///             return Center(child: Text('Page $index'));
///           },
///         ),
///       ),
///     ],
///   ),
/// )
/// ```
class DefaultCyclicTabController extends StatefulWidget {
  /// Creates a default tab controller.
  ///
  /// The [contentLength] must be greater than zero.
  /// The [initialIndex] must be between 0 and [contentLength] - 1.
  const DefaultCyclicTabController({
    super.key,
    required this.contentLength,
    required this.child,
    this.initialIndex = 0,
    this.animationDuration = const Duration(milliseconds: 550),
  })  : assert(contentLength > 0, 'contentLength must be greater than 0'),
        assert(
          initialIndex >= 0,
          'initialIndex must be greater than or equal to 0',
        );

  /// The total number of tabs/pages.
  final int contentLength;

  /// The child widget tree that will have access to the controller.
  final Widget child;

  /// The initial tab index (0-indexed).
  final int initialIndex;

  /// The duration of animations when switching tabs.
  final Duration animationDuration;

  /// Returns the [CyclicTabController] from the closest [DefaultCyclicTabController]
  /// ancestor.
  ///
  /// Throws an error if no [DefaultCyclicTabController] is found in the widget tree.
  static CyclicTabController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_CyclicTabControllerScope>();

    if (scope == null) {
      throw FlutterError(
        'DefaultCyclicTabController.of() called with a context that does not contain a DefaultCyclicTabController.\n'
        'No DefaultCyclicTabController ancestor could be found starting from the context that was passed to '
        'DefaultCyclicTabController.of(). This can happen if the context comes from a widget above the '
        'DefaultCyclicTabController.\n'
        'The context used was:\n'
        '  $context',
      );
    }

    return scope.controller;
  }

  /// Returns the [CyclicTabController] from the closest [DefaultCyclicTabController]
  /// ancestor, or null if there is no ancestor.
  static CyclicTabController? maybeOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_CyclicTabControllerScope>();
    return scope?.controller;
  }

  @override
  State<DefaultCyclicTabController> createState() =>
      _DefaultCyclicTabControllerState();
}

class _DefaultCyclicTabControllerState extends State<DefaultCyclicTabController>
    with SingleTickerProviderStateMixin {
  late CyclicTabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CyclicTabController(
      contentLength: widget.contentLength,
      initialIndex: widget.initialIndex,
      animationDuration: widget.animationDuration,
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(DefaultCyclicTabController oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If content length changed, we need to create a new controller
    if (oldWidget.contentLength != widget.contentLength) {
      _controller.dispose();
      _controller = CyclicTabController(
        contentLength: widget.contentLength,
        initialIndex: widget.initialIndex.clamp(0, widget.contentLength - 1),
        animationDuration: widget.animationDuration,
        vsync: this,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _CyclicTabControllerScope(
      controller: _controller,
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// The inherited widget that provides the [CyclicTabController] to descendants.
class _CyclicTabControllerScope extends InheritedWidget {
  const _CyclicTabControllerScope({
    required this.controller,
    required super.child,
  });

  final CyclicTabController controller;

  @override
  bool updateShouldNotify(_CyclicTabControllerScope oldWidget) {
    return controller != oldWidget.controller;
  }
}
