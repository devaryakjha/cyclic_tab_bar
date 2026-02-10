import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../cyclic_tab_bar.dart';

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
    required this.pageBuilder,
    this.controller,
    this.scrollPhysics = const PageScrollPhysics(),
    this.onPageChanged,
    this.pageSpacing = 0.0,
  });

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

  /// Horizontal spacing between pages in pixels.
  ///
  /// Adds space between each page. Useful for creating visual separation
  /// or peek effects where adjacent pages are partially visible.
  /// Defaults to 0 (no spacing).
  ///
  /// Example:
  /// ```dart
  /// CyclicTabBarView(
  ///   pageSpacing: 16.0,
  ///   // ... other parameters
  /// )
  /// ```
  final double pageSpacing;

  @override
  State<CyclicTabBarView> createState() => _CyclicTabBarViewState();
}

class _CyclicTabBarViewState extends State<CyclicTabBarView> {
  static const int _initialPageSection = 100000;

  late final ValueNotifier<int> _selectedIndexNotifier = ValueNotifier<int>(
    widget.controller?.index ?? 0,
  );
  CyclicTabController? _attachedController;
  int? _lastReportedContentLength;
  PageController? _pageController;
  int _pageControllerContentLength = 0;

  int get _contentLength => _controller.contentLength;

  CyclicTabController get _controller {
    final explicitController = widget.controller;
    if (explicitController != null) {
      return explicitController;
    }

    // Try to find from DefaultCyclicTabController
    try {
      return DefaultCyclicTabController.of(context);
    } catch (e) {
      rethrow;
    }
  }

  void _onIndexChange(int newIndex) {
    widget.onPageChanged?.call(newIndex);
    if (_selectedIndexNotifier.value != newIndex) {
      _selectedIndexNotifier.value = newIndex;
    }
    HapticFeedback.selectionClick();

    // // Announce page change for accessibility
    // if (mounted) {
    //   SemanticsService.sendAnnouncement(
    //     View.of(context),
    //     'Page ${newIndex + 1} of $_contentLength',
    //     Directionality.of(context),
    //   );
    // }
  }

  @override
  void initState() {
    super.initState();

    // Add index change listener for callbacks
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _selectedIndexNotifier.value = _controller.index;
        _controller.addIndexChangeListener(_onIndexChange);
        _attachControllerChangeListener();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _selectedIndexNotifier.value = _controller.index;
    _attachControllerChangeListener();
    _ensurePageController();
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
      _selectedIndexNotifier.value = _controller.index;
      _attachControllerChangeListener(force: true);
      _ensurePageController(forced: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    _ensurePageController();

    return Semantics(
      label: 'Content area',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewportWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          _controller.updatePageViewportWidth(viewportWidth);

          Widget buildPage(BuildContext context, int rawIndex) {
            final modIndex = _normalizeIndex(rawIndex, _contentLength);
            return SizedBox(
              width: viewportWidth,
              child: ValueListenableBuilder<int>(
                valueListenable: _selectedIndexNotifier,
                builder: (context, selectedIndex, _) {
                  final isSelected = selectedIndex == modIndex;
                  return Semantics(
                    label: 'Page ${modIndex + 1} of $_contentLength',
                    liveRegion: isSelected,
                    child: Padding(
                      padding: EdgeInsets.only(right: widget.pageSpacing),
                      child: widget.pageBuilder(context, modIndex, isSelected),
                    ),
                  );
                },
              ),
            );
          }

          return PageView.builder(
            controller: _pageController,
            physics: widget.scrollPhysics,
            itemBuilder: (context, rawIndex) => buildPage(context, rawIndex),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    // Use cached controller reference to avoid looking up deactivated ancestor
    _attachedController?.removeIndexChangeListener(_onIndexChange);
    _attachedController?.removeListener(_handleControllerChange);
    _attachedController?.detachPageAdapter();
    _pageController?.removeListener(_handlePageTick);
    _pageController?.dispose();
    _selectedIndexNotifier.dispose();
    super.dispose();
  }

  void _attachControllerChangeListener({bool force = false}) {
    final controller = _controller;
    if (!force && identical(_attachedController, controller)) {
      return;
    }
    _attachedController?.removeListener(_handleControllerChange);
    _attachedController?.detachPageAdapter();
    _attachedController = controller;
    _attachedController?.addListener(_handleControllerChange);
    _attachedController?.attachPageAdapter(
      navigateToRawPage: _navigateToRawPage,
      currentRawPage: _currentRawPage,
    );
    _lastReportedContentLength = controller.contentLength;
  }

  void _handleControllerChange() {
    final controller = _attachedController;
    if (controller == null) return;
    final length = controller.contentLength;
    if (_lastReportedContentLength == length) {
      return;
    }
    _lastReportedContentLength = length;
    if (mounted) {
      _ensurePageController(forced: true);
      setState(() {});
    }
  }

  Future<void> _navigateToRawPage(double targetRawPage, bool animated) async {
    final pageController = _pageController;
    if (pageController == null || !pageController.hasClients) {
      return;
    }

    final targetPage = targetRawPage.round();
    if (animated) {
      await pageController.animateToPage(
        targetPage,
        duration: _controller.animationDuration,
        curve: Curves.ease,
      );
      return;
    }
    pageController.jumpToPage(targetPage);
  }

  double _currentRawPage() {
    final pageController = _pageController;
    if (pageController == null) {
      return _controller.index.toDouble();
    }
    return pageController.page ?? pageController.initialPage.toDouble();
  }

  void _handlePageTick() {
    final pageController = _pageController;
    if (pageController == null || !pageController.hasClients) {
      return;
    }
    final page = pageController.page;
    if (page == null) {
      return;
    }
    _controller.onPagePositionChanged(page);
  }

  void _ensurePageController({bool forced = false}) {
    final contentLength = _contentLength;
    if (contentLength <= 0) {
      return;
    }

    final pageController = _pageController;
    if (!forced &&
        pageController != null &&
        _pageControllerContentLength == contentLength) {
      return;
    }

    var initialPage = _initialPageSection * contentLength + _controller.index;
    if (pageController != null) {
      final previousLength = _pageControllerContentLength;
      final previousRawPage = pageController.hasClients
          ? (pageController.page ?? pageController.initialPage.toDouble())
          : pageController.initialPage.toDouble();

      if (previousLength > 0) {
        final previousSection = (previousRawPage / previousLength).floor();
        initialPage = previousSection * contentLength + _controller.index;
      }

      pageController.removeListener(_handlePageTick);
      pageController.dispose();
    }

    _pageControllerContentLength = contentLength;
    _pageController = PageController(initialPage: initialPage);
    _pageController?.addListener(_handlePageTick);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _handlePageTick();
    });
  }

  int _normalizeIndex(int index, int length) {
    var modIndex = index % length;
    if (modIndex < 0) {
      modIndex += length;
    }
    return modIndex;
  }
}
