import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../cyclic_tab_bar.dart';
import 'cycled_list_view.dart';

/// A widget that displays pages in a horizontally scrolling view with infinite scroll.
///
/// This is the page view component. Use [CyclicTabBar] to display
/// the corresponding tabs. Coordinate them using a [CyclicTabController].
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
///           pageBuilder: (context, index, isSelected) => Center(
///             child: Text('Page $index'),
///           ),
///         ),
///       ),
///     ],
///   ),
/// )
/// ```
class CyclicTabBarView extends StatefulWidget {
  /// Creates a cyclic tab bar view.
  const CyclicTabBarView({
    super.key,
    required this.contentLength,
    required this.pageBuilder,
    this.controller,
    this.scrollPhysics = const PageScrollPhysics(),
    this.onPageChanged,
  }) : assert(contentLength > 0, 'contentLength must be greater than 0');

  /// The total number of pages.
  final int contentLength;

  /// A callback for building page contents.
  ///
  /// `index` is the modulo index (0 to [contentLength] - 1).
  /// `isSelected` indicates whether this page is currently selected.
  final SelectIndexedWidgetBuilder pageBuilder;

  /// The controller that coordinates this view with a [CyclicTabBar].
  ///
  /// If null, uses [DefaultCyclicTabController.of] to find a controller.
  final CyclicTabController? controller;

  /// The scroll physics for the page view.
  final ScrollPhysics scrollPhysics;

  /// Callback when the page changes.
  final ValueChanged<int>? onPageChanged;

  @override
  State<CyclicTabBarView> createState() => _CyclicTabBarViewState();
}

class _CyclicTabBarViewState extends State<CyclicTabBarView> {
  CyclicTabController? _internalController;

  CyclicTabController get _controller {
    final explicitController = widget.controller;
    if (explicitController != null) {
      return explicitController;
    }

    // Try to find from DefaultCyclicTabController
    try {
      return DefaultCyclicTabController.of(context);
    } catch (e) {
      // If no controller found, create an internal one
      _internalController ??= CyclicTabController(
        contentLength: widget.contentLength,
      );
      return _internalController!;
    }
  }

  void _onIndexChange(int newIndex) {
    widget.onPageChanged?.call(newIndex);
    HapticFeedback.selectionClick();

    // Announce page change for accessibility
    if (mounted) {
      SemanticsService.announce(
        'Page ${newIndex + 1} of ${widget.contentLength}',
        Directionality.of(context),
      );
    }
  }

  @override
  void initState() {
    super.initState();

    // Add index change listener for callbacks
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.addIndexChangeListener(_onIndexChange);
      }
    });
  }

  @override
  void didUpdateWidget(CyclicTabBarView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If controller changed, update listeners
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller != null) {
        oldWidget.controller!.removeIndexChangeListener(_onIndexChange);
      }

      _controller.addIndexChangeListener(_onIndexChange);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Semantics(
      label: 'Content area',
      child: CycledListView.builder(
        scrollDirection: Axis.horizontal,
        contentCount: widget.contentLength,
        controller: _controller.pageScrollController,
        physics: widget.scrollPhysics,
        itemBuilder: (context, modIndex, rawIndex) => SizedBox(
          width: size.width,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final isSelected = _controller.index == modIndex;
              return Semantics(
                label: 'Page ${modIndex + 1}',
                liveRegion: isSelected,
                child: widget.pageBuilder(context, modIndex, isSelected),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeIndexChangeListener(_onIndexChange);
    _internalController?.dispose();
    super.dispose();
  }
}
