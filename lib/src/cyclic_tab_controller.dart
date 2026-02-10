import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:meta/meta.dart';

import '../cyclic_tab_bar.dart';

/// The alignment of tabs within the viewport.
enum CyclicTabAlignment {
  /// Tabs are aligned to the left edge of the viewport.
  left,

  /// Tabs are centered within the viewport (default).
  center,
}

/// A controller for coordinating the selection of tabs and pages in a
/// [CyclicTabBar] and [CyclicTabBarView].
///
/// Similar to Flutter's [TabController], this controller manages the state
/// and synchronization between the tab bar and page view components.
///
/// You can create a controller manually or use [DefaultCyclicTabController]
/// to have one created automatically.
class CyclicTabController extends ChangeNotifier {
  static const double _metricsChangeTolerance = 0.5;
  static const int _maxInitialNavigationRetries = 10;
  bool _isDisposed = false;
  bool _isViewportRealignmentScheduled = false;
  bool _isDeferredNotifyScheduled = false;
  bool _isDeferredJumpScheduled = false;
  double? _pendingViewportRealignmentOffset;
  int? _pendingJumpIndex;

  /// Creates a controller for cyclic tab bar and tab bar view.
  ///
  /// The [contentLength] must be greater than zero.
  /// The [initialIndex] must be between 0 and [contentLength] - 1.
  /// The [alignment] determines how tabs are positioned (default: center).
  CyclicTabController({
    required int contentLength,
    int initialIndex = 0,
    this.animationDuration = const Duration(milliseconds: 550),
    this.alignment = CyclicTabAlignment.center,
    TickerProvider? vsync,
  }) : assert(contentLength > 0, 'contentLength must be greater than 0'),
       assert(
         initialIndex >= 0 && initialIndex < contentLength,
         'initialIndex must be between 0 and contentLength - 1',
       ),
       _contentLength = contentLength,
       _selectedIndex = initialIndex,
       _tabScrollController = CycledScrollController(),
       _pageScrollController = CycledScrollController() {
    if (vsync != null) {
      _indicatorAnimationController = AnimationController(
        vsync: vsync,
        duration: animationDuration,
      )..addListener(_onIndicatorAnimationTick);
    }

    // Set up scroll listeners
    _pageScrollController.addListener(_handlePageScroll);
    _tabScrollController.addListener(_handleTabScroll);
  }

  /// The total number of tabs/pages.
  int get contentLength => _contentLength;
  int _contentLength;

  /// The duration of the animation when switching tabs.
  final Duration animationDuration;

  /// The alignment of tabs within the viewport.
  final CyclicTabAlignment alignment;

  /// The currently selected tab index (0-indexed, modulo [contentLength]).
  int get index => _selectedIndex;
  int _selectedIndex;

  /// Scroll controller for the tab bar.
  CycledScrollController get tabScrollController => _tabScrollController;
  final CycledScrollController _tabScrollController;
  bool _isCyclicScrollingEnabled = true;

  bool get _canAdjustTabScroll =>
      _isCyclicScrollingEnabled && _tabScrollController.hasClients;

  /// Scroll controller for the page view.
  CycledScrollController get pageScrollController => _pageScrollController;
  final CycledScrollController _pageScrollController;

  /// Animation controller for indicator size transitions.
  AnimationController? _indicatorAnimationController;
  Animation<double>? _indicatorAnimation;

  /// Current size of the indicator.
  double get indicatorSize => _indicatorSize;
  double _indicatorSize = 0.0;

  /// Whether tab and page positions are aligned (for indicator visibility).
  bool get isTabPositionAligned => _isTabPositionAligned;
  bool _isTabPositionAligned = true;

  /// Whether content is currently changing due to a tab tap.
  bool get isContentChangingByTab => _isContentChangingByTab;
  bool _isContentChangingByTab = false;

  /// Whether tab scrolling is being forced programmatically.
  bool _isTabForceScrolling = false;

  /// Tab size information (set by CyclicTabBar).
  final List<double> _tabTextSizes = [];
  final List<double> _tabSizesFromIndex = [];
  final List<Tween<double>> _tabOffsets = [];
  final List<Tween<double>> _tabSizeTweens = [];

  /// Current viewport width used for page offset/index calculations.
  double _pageViewportWidth = 0.0;

  /// Effective tab bar width (screen width minus insets).
  double _effectiveTabWidth = 0.0;

  /// Fixed tab width (if using fixed width mode).
  double _fixedTabWidth = 0.0;

  /// Whether to force fixed tab width.
  bool _forceFixedTabWidth = false;

  /// Total size of all tabs.
  double _totalTabSize = 0.0;

  /// Previous tab section for detecting scroll cycles.
  /// Used to trigger haptic feedback when manually scrolling wraps around.
  int? _previousTabSection;

  /// Whether the controller has been initialized with tab size data.
  bool get isInitialized => _tabTextSizes.isNotEmpty;

  /// Whether we need to navigate to initial index on first initialization.
  bool _needsInitialNavigation = true;

  /// Callbacks for page scrolling and tab selection.
  final List<VoidCallback> _pageScrollListeners = [];
  final List<ValueChanged<int>> _indexChangeListeners = [];

  /// Animates to the specified tab index.
  ///
  /// This is the primary way to programmatically change the selected tab.
  Future<void> animateToIndex(int index) async {
    if (!isInitialized) {
      debugPrint('Warning: animateToIndex called before initialization');
      return;
    }

    final modIndex = _normalizeIndex(index, contentLength);
    await onTapTabWithRawIndex(modIndex, modIndex);
  }

  /// Immediately changes to the specified tab index without animation.
  void jumpToIndex(int index) {
    if (!isInitialized) {
      debugPrint('Warning: jumpToIndex called before initialization');
      return;
    }

    final modIndex = _normalizeIndex(index, contentLength);
    _selectedIndex = modIndex;
    final phase = SchedulerBinding.instance.schedulerPhase;
    final shouldDeferJump =
        phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks;

    if (shouldDeferJump) {
      _scheduleDeferredJump(modIndex);
      _notifyListenersSafely();
      return;
    }

    _applyJumpToIndex(modIndex);
    _notifyListenersSafely();
  }

  /// Sets the selected index, optionally animating to it.
  Future<void> setIndex(int index, {bool animated = true}) async {
    final targetIndex = _normalizeIndex(index, contentLength);
    if (!isInitialized) {
      _selectedIndex = targetIndex;
      _needsInitialNavigation = true;
      notifyListeners();
      return;
    }
    if (animated) {
      await animateToIndex(targetIndex);
    } else {
      jumpToIndex(targetIndex);
    }
  }

  /// Updates the total content length and optionally the selected index.
  ///
  /// When [selectedIndex] is omitted, the current index is clamped to the new
  /// range. Set [animated] to true to animate scroll positions to the new index
  /// (only when metrics are already initialized).
  Future<void> setContentLength(
    int newLength, {
    int? selectedIndex,
    bool animated = false,
    bool force = false,
  }) async {
    assert(newLength > 0, 'contentLength must be greater than 0');
    final lengthChanged = force || newLength != _contentLength;
    final targetIndex = _normalizeIndex(
      selectedIndex ?? _selectedIndex,
      newLength,
    );

    if (!lengthChanged) {
      await setIndex(targetIndex, animated: animated);
      return;
    }

    _contentLength = newLength;
    _resetTabMetrics();
    _needsInitialNavigation = true;

    if (!isInitialized) {
      _selectedIndex = targetIndex;
      notifyListeners();
      return;
    }

    if (animated) {
      await animateToIndex(targetIndex);
    } else {
      jumpToIndex(targetIndex);
    }
  }

  /// Adds a listener for page scroll events.
  void addPageScrollListener(VoidCallback listener) {
    _pageScrollListeners.add(listener);
  }

  /// Removes a page scroll listener.
  void removePageScrollListener(VoidCallback listener) {
    _pageScrollListeners.remove(listener);
  }

  /// Adds a listener for index change events.
  void addIndexChangeListener(ValueChanged<int> listener) {
    _indexChangeListeners.add(listener);
  }

  /// Removes an index change listener.
  void removeIndexChangeListener(ValueChanged<int> listener) {
    _indexChangeListeners.remove(listener);
  }

  /// Internal: Updates tab size information from CyclicTabBar.
  void updateTabSizes({
    required List<double> tabTextSizes,
    required List<double> tabSizesFromIndex,
    required List<Tween<double>> tabOffsets,
    required List<Tween<double>> tabSizeTweens,
    required double effectiveTabWidth,
    required bool forceFixedTabWidth,
    required double fixedTabWidth,
    required double totalTabSize,
    required bool isCyclicScrollingEnabled,
  }) {
    final wasUninitialized = !isInitialized;

    _tabTextSizes.clear();
    _tabTextSizes.addAll(tabTextSizes);

    _tabSizesFromIndex.clear();
    _tabSizesFromIndex.addAll(tabSizesFromIndex);

    _tabOffsets.clear();
    _tabOffsets.addAll(tabOffsets);

    _tabSizeTweens.clear();
    _tabSizeTweens.addAll(tabSizeTweens);

    _effectiveTabWidth = effectiveTabWidth;
    _forceFixedTabWidth = forceFixedTabWidth;
    _fixedTabWidth = fixedTabWidth;
    _totalTabSize = totalTabSize;
    _isCyclicScrollingEnabled = isCyclicScrollingEnabled;

    // Initialize indicator size
    if (_tabTextSizes.isNotEmpty) {
      _indicatorSize = _tabTextSizes[_selectedIndex];
    }

    // If this is the first initialization, position at the initial index
    if (wasUninitialized && _needsInitialNavigation) {
      _needsInitialNavigation = false;
      // Use a post-frame callback to ensure the scroll controllers are ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isInitialized) {
          _jumpToIndexWhenReady(_selectedIndex);
        }
      });
    }

    notifyListeners();
  }

  /// Internal: Updates the page viewport width from [CyclicTabBarView].
  @internal
  void updatePageViewportWidth(double width) {
    if (_isDisposed || width <= 0) {
      return;
    }

    final previousWidth = _pageViewportWidth;
    _pageViewportWidth = width;

    if (!_didValueChange(previousWidth, width) ||
        !_pageScrollController.hasClients) {
      return;
    }

    final currentOffset = _pageScrollController.offset;
    final oldWidth = previousWidth > 0 ? previousWidth : width;
    final logicalPage = currentOffset / oldWidth;
    final snappedRawIndex = _nearestRawIndexForSelected(
      logicalPage: logicalPage,
      selectedIndex: _selectedIndex,
      length: contentLength,
    );
    final targetOffset = snappedRawIndex * width;

    if (_didValueChange(currentOffset, targetOffset)) {
      _scheduleViewportRealignment(targetOffset);
    }
  }

  double _nearestRawIndexForSelected({
    required double logicalPage,
    required int selectedIndex,
    required int length,
  }) {
    if (length <= 0) {
      return logicalPage.roundToDouble();
    }

    final section = (logicalPage / length).floor();
    final candidate = section * length + selectedIndex;
    final candidateAbove = candidate + length;
    final candidateBelow = candidate - length;

    var best = candidate.toDouble();
    var bestDistance = (best - logicalPage).abs();

    final aboveDistance = (candidateAbove - logicalPage).abs();
    if (aboveDistance < bestDistance) {
      best = candidateAbove.toDouble();
      bestDistance = aboveDistance;
    }

    final belowDistance = (candidateBelow - logicalPage).abs();
    if (belowDistance < bestDistance) {
      best = candidateBelow.toDouble();
    }

    return best;
  }

  void _scheduleViewportRealignment(double targetOffset) {
    _pendingViewportRealignmentOffset = targetOffset;
    if (_isViewportRealignmentScheduled) {
      return;
    }

    _isViewportRealignmentScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isViewportRealignmentScheduled = false;
      if (_isDisposed || !_pageScrollController.hasClients) {
        _pendingViewportRealignmentOffset = null;
        return;
      }

      final pendingOffset = _pendingViewportRealignmentOffset;
      _pendingViewportRealignmentOffset = null;
      if (pendingOffset == null) {
        return;
      }

      if (_didValueChange(_pageScrollController.offset, pendingOffset)) {
        _pageScrollController.jumpTo(pendingOffset);
      }
    });
  }

  void _scheduleDeferredJump(int modIndex) {
    _pendingJumpIndex = modIndex;
    if (_isDeferredJumpScheduled) {
      return;
    }

    _isDeferredJumpScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isDeferredJumpScheduled = false;
      if (_isDisposed) {
        _pendingJumpIndex = null;
        return;
      }

      final pendingIndex = _pendingJumpIndex;
      _pendingJumpIndex = null;
      if (pendingIndex == null) {
        return;
      }

      _applyJumpToIndex(pendingIndex);
      _notifyListenersSafely();
    });
  }

  void _applyJumpToIndex(int modIndex) {
    // Jump both controllers to the target position.
    if (_canAdjustTabScroll) {
      final targetTabOffset = _calculateTabOffset(modIndex);
      _tabScrollController.jumpTo(targetTabOffset);
    }

    final pageWidth = _currentPageViewportWidth;
    if (_pageScrollController.hasClients && pageWidth > 0) {
      final targetPageOffset = modIndex * pageWidth;
      _pageScrollController.jumpTo(targetPageOffset);
    }
  }

  double get _currentPageViewportWidth {
    if (_pageScrollController.hasClients) {
      final viewportWidth = _pageScrollController.position.viewportDimension;
      if (viewportWidth > 0) {
        return viewportWidth;
      }
    }
    return _pageViewportWidth;
  }

  bool _didValueChange(double previous, double next) {
    return (previous - next).abs() > _metricsChangeTolerance;
  }

  void _jumpToIndexWhenReady(int index, {int retryCount = 0}) {
    if (_isDisposed || !isInitialized) {
      return;
    }

    if (_pageScrollController.hasClients && _currentPageViewportWidth > 0) {
      jumpToIndex(index);
      return;
    }

    if (retryCount >= _maxInitialNavigationRetries) {
      _selectedIndex = _normalizeIndex(index, contentLength);
      if (!_isDisposed) {
        notifyListeners();
      }
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isDisposed) {
        return;
      }
      _jumpToIndexWhenReady(index, retryCount: retryCount + 1);
    });
  }

  /// Internal: Handles page scroll controller events.
  void _handlePageScroll() {
    final pageWidth = _currentPageViewportWidth;
    if (!isInitialized || _isContentChangingByTab || pageWidth <= 0) {
      return;
    }

    final offset = _pageScrollController.offset;
    final currentIndexDouble = offset / pageWidth;
    final currentIndex = currentIndexDouble.floor();
    final modIndex = currentIndexDouble.round() % contentLength;
    final currentIndexDecimal = currentIndexDouble - currentIndexDouble.floor();

    // Update tab position
    if (_canAdjustTabScroll) {
      _tabScrollController.jumpTo(
        _tabOffsets[currentIndex % contentLength].transform(
          currentIndexDecimal,
        ),
      );
    }

    // Update indicator size
    _indicatorSize = _tabSizeTweens[currentIndex % contentLength].transform(
      currentIndexDecimal,
    );

    // Update alignment state
    if (!_isTabPositionAligned) {
      _isTabPositionAligned = true;
    }

    // Notify page scroll listeners
    for (final listener in _pageScrollListeners) {
      listener();
    }

    // Check for index change
    if (modIndex != _selectedIndex) {
      _selectedIndex = modIndex;

      // Notify index change listeners
      for (final listener in _indexChangeListeners) {
        listener(modIndex);
      }

      _notifyListenersSafely();
    }
  }

  /// Internal: Called by CyclicTabBarView when page scroll position changes.
  /// DEPRECATED: Use _handlePageScroll instead (called automatically).
  void onPageScroll(double offset) {
    // This method is now deprecated but kept for backwards compatibility
    // The scroll listener handles this automatically
  }

  /// Internal: Called when a tab is tapped with both mod and raw indices.
  /// This version preserves the raw index for proper section calculation.
  ///
  /// This should only be called by CyclicTabBar internally.
  @internal
  Future<void> onTapTabWithRawIndex(int modIndex, int rawIndex) async {
    if (_isContentChangingByTab) return;

    _isContentChangingByTab = true;

    try {
      _isTabPositionAligned = true;

      if (_canAdjustTabScroll) {
        final sizeOnIndex = _forceFixedTabWidth
            ? _fixedTabWidth * modIndex
            : _tabSizesFromIndex[modIndex];
        final section = rawIndex.isNegative
            ? (rawIndex + 1) ~/ contentLength - 1
            : rawIndex ~/ contentLength;
        final targetOffset = _totalTabSize * section + sizeOnIndex;
        _isTabForceScrolling = true;

        // Animate tab scroll
        unawaited(
          _tabScrollController
              .animateTo(
                targetOffset + _alignmentOffset(modIndex),
                duration: animationDuration,
                curve: Curves.ease,
              )
              .then((_) => _isTabForceScrolling = false)
              .catchError((error) {
                _isTabForceScrolling = false;
                debugPrint('Tab animation error: $error');
                return false;
              }),
        );
      } else {
        _isTabForceScrolling = false;
      }

      // Animate indicator size
      if (_indicatorAnimationController != null) {
        _indicatorAnimation = Tween(
          begin: _indicatorSize,
          end: _tabTextSizes[modIndex],
        ).animate(_indicatorAnimationController!);
        _indicatorAnimationController!.forward(from: 0);
      } else {
        _indicatorSize = _tabTextSizes[modIndex];
      }

      double? targetPageOffset;
      final pageWidth = _currentPageViewportWidth;
      if (_pageScrollController.hasClients && pageWidth > 0) {
        final currentOffset = _pageScrollController.offset;
        final move = calculateMoveIndexDistance(
          _selectedIndex,
          modIndex,
          contentLength,
        );
        targetPageOffset = currentOffset + move * pageWidth;
      }

      _selectedIndex = modIndex;

      // Notify index change listeners
      for (final listener in _indexChangeListeners) {
        listener(modIndex);
      }

      notifyListeners();

      // Animate page scroll
      if (targetPageOffset == null) {
        return;
      }
      await _pageScrollController.animateTo(
        targetPageOffset,
        duration: animationDuration,
        curve: Curves.ease,
      );
    } catch (e) {
      debugPrint('Error in _onTapTab: $e');
    } finally {
      _isContentChangingByTab = false;
      _notifyListenersSafely();
    }
  }

  /// Internal: Handles tab scroll controller events.
  void _handleTabScroll() {
    if (!_isCyclicScrollingEnabled || _isTabForceScrolling) {
      return;
    }

    // Detect scroll cycles and provide haptic feedback
    if (_totalTabSize > 0 && _tabScrollController.hasClients) {
      final offset = _tabScrollController.offset;
      final currentSection = (offset / _totalTabSize).floor();

      if (_previousTabSection != null &&
          currentSection != _previousTabSection) {
        // User manually scrolled across a cycle boundary - provide feedback
        HapticFeedback.selectionClick();
      }
      _previousTabSection = currentSection;
    }

    if (_isTabPositionAligned) {
      _isTabPositionAligned = false;
      _notifyListenersSafely();
    }
  }

  /// Internal: Called when tab scrolling occurs (not programmatically).
  /// DEPRECATED: Use _handleTabScroll instead (called automatically).
  void onTabScroll() {
    _handleTabScroll();
  }

  /// Internal: Callback for indicator animation ticks.
  void _onIndicatorAnimationTick() {
    final animation = _indicatorAnimation;
    if (animation != null) {
      _indicatorSize = animation.value;
      _notifyListenersSafely();
    }
  }

  void _notifyListenersSafely() {
    if (_isDisposed) {
      return;
    }

    final phase = SchedulerBinding.instance.schedulerPhase;
    final shouldDefer =
        phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks;

    if (!shouldDefer) {
      notifyListeners();
      return;
    }

    if (_isDeferredNotifyScheduled) {
      return;
    }
    _isDeferredNotifyScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isDeferredNotifyScheduled = false;
      if (_isDisposed) {
        return;
      }
      notifyListeners();
    });
  }

  /// Calculates the alignment offset for a given tab index.
  double _alignmentOffset(int index) {
    if (alignment == CyclicTabAlignment.left) {
      return -0;
    }
    // Center alignment - use effective tab width, not full screen width
    final tabSize = _forceFixedTabWidth ? _fixedTabWidth : _tabTextSizes[index];
    return -(_effectiveTabWidth - tabSize) / 2;
  }

  /// Calculates the tab scroll offset for a given index.
  double _calculateTabOffset(int modIndex) {
    final sizeOnIndex = _forceFixedTabWidth
        ? _fixedTabWidth * modIndex
        : _tabSizesFromIndex[modIndex];
    return sizeOnIndex + _alignmentOffset(modIndex);
  }

  /// Calculates the page scroll offset for a given index.
  double _calculatePageOffset(int modIndex) {
    return modIndex * _currentPageViewportWidth;
  }

  void _resetTabMetrics() {
    _tabTextSizes.clear();
    _tabSizesFromIndex.clear();
    _tabOffsets.clear();
    _tabSizeTweens.clear();
    _totalTabSize = 0.0;
    _previousTabSection = null;
    _indicatorSize = 0.0;
  }

  int _normalizeIndex(int index, int length) {
    if (length == 0) {
      return 0;
    }
    var modIndex = index % length;
    if (modIndex < 0) {
      modIndex += length;
    }
    return modIndex;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _tabScrollController.dispose();
    _pageScrollController.dispose();
    _indicatorAnimationController?.dispose();
    _pageScrollListeners.clear();
    _indexChangeListeners.clear();
    super.dispose();
  }
}
