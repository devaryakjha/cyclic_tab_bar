import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../cyclic_tab_bar.dart';
import 'cycled_list_view.dart';

@visibleForTesting
class InnerCyclicTabBar extends StatefulWidget {
  const InnerCyclicTabBar({
    super.key,
    required this.size,
    required this.contentLength,
    required this.tabBuilder,
    required this.pageBuilder,
    this.onTabTap,
    this.separator,
    required this.textScaler,
    required this.defaultTextStyle,
    required this.textDirection,
    this.backgroundColor,
    this.onPageChanged,
    required this.indicatorColor,
    this.indicatorHeight,
    required this.defaultLocale,
    required this.tabHeight,
    required this.tabPadding,
    required this.forceFixedTabWidth,
    required this.fixedTabWidthFraction,
    required this.tabAnimationDuration,
    required this.scrollPhysics,
  })  : assert(contentLength > 0, 'contentLength must be greater than 0'),
        assert(tabHeight > 0, 'tabHeight must be greater than 0'),
        assert(tabPadding >= 0, 'tabPadding must be non-negative'),
        assert(
          fixedTabWidthFraction > 0 && fixedTabWidthFraction <= 1.0,
          'fixedTabWidthFraction must be between 0 and 1.0',
        ),
        assert(
          indicatorHeight == null || indicatorHeight >= 1.0,
          'indicatorHeight must be >= 1.0 when specified',
        );

  final Size size;
  final int contentLength;
  final SelectIndexedTextBuilder tabBuilder;
  final SelectIndexedWidgetBuilder pageBuilder;
  final IndexedTapCallback? onTabTap;
  final BorderSide? separator;
  final TextScaler textScaler;
  final TextStyle defaultTextStyle;
  final TextDirection textDirection;
  final Color? backgroundColor;
  final ValueChanged<int>? onPageChanged;
  final Color indicatorColor;
  final double? indicatorHeight;
  final Locale defaultLocale;
  final double tabHeight;
  final double tabPadding;
  final bool forceFixedTabWidth;
  final double fixedTabWidthFraction;
  final Duration tabAnimationDuration;
  final ScrollPhysics scrollPhysics;

  @override
  InnerCyclicTabBarState createState() => InnerCyclicTabBarState();
}

@visibleForTesting
class InnerCyclicTabBarState extends State<InnerCyclicTabBar>
    with SingleTickerProviderStateMixin {
  late final _tabController = CycledScrollController(
    initialScrollOffset: centeringOffset(0),
  );
  late final _pageController = CycledScrollController();

  final ValueNotifier<bool> _isContentChangingByTab = ValueNotifier(false);
  bool _isTabForceScrolling = false;
  bool _isDisposed = false;

  late TextScaler _previousTextScaleFactor = widget.textScaler;

  late final ValueNotifier<double> _indicatorSize;
  final _isTabPositionAligned = ValueNotifier<bool>(true);
  final _selectedIndex = ValueNotifier<int>(0);

  final List<double> _tabTextSizes = [];
  List<double> get tabTextSizes => _tabTextSizes;

  final List<double> _tabSizesFromIndex = [];
  List<double> get tabSizesFromIndex => _tabSizesFromIndex;

  /// A list of Tweens for mapping page scroll positions to tab scroll positions.
  ///
  /// begin: Scroll position of the element at index i_x + centering offset
  /// end: Scroll position of the element at next index i_x+1 + centering offset
  /// (where 0 <= i < n)
  /// Note: For the last element, end = total tab length + centering offset
  final List<Tween<double>> _tabOffsets = [];
  List<Tween<double>> get tabOffsets => _tabOffsets;

  final List<Tween<double>> _tabSizeTweens = [];
  List<Tween<double>> get tabSizeTweens => _tabSizeTweens;

  double get indicatorHeight =>
      widget.indicatorHeight ?? widget.separator?.width ?? 2.0;

  late final AnimationController _indicatorAnimationController;
  Animation<double>? _indicatorAnimation;

  double _totalTabSizeCache = 0.0;
  double get _totalTabSize {
    if (_totalTabSizeCache != 0.0) return _totalTabSizeCache;
    _totalTabSizeCache = widget.forceFixedTabWidth
        ? _fixedTabWidth * widget.contentLength
        : _tabTextSizes.reduce((v, e) => v += e);
    return _totalTabSizeCache;
  }

  double get _fixedTabWidth => widget.size.width * widget.fixedTabWidthFraction;

  double _calculateTabSizeFromIndex(int index) {
    var size = 0.0;
    for (var i = 0; i < index; i++) {
      size += _tabTextSizes[i];
    }
    return size;
  }

  double centeringOffset(int index) {
    final tabSize =
        widget.forceFixedTabWidth ? _fixedTabWidth : _tabTextSizes[index];
    return -(widget.size.width - tabSize) / 2;
  }

  @visibleForTesting
  void calculateTabBehaviorElements(TextScaler textScaler) {
    // Safety check: ensure content length is valid
    assert(widget.contentLength > 0, 'contentLength must be greater than 0');
    if (widget.contentLength <= 0) {
      debugPrint(
          'Warning: calculateTabBehaviorElements called with contentLength <= 0');
      return;
    }

    _tabTextSizes.clear();
    _tabSizesFromIndex.clear();
    _tabOffsets.clear();
    _tabSizeTweens.clear();
    _totalTabSizeCache = 0.0;

    for (var i = 0; i < widget.contentLength; i++) {
      final text = widget.tabBuilder(i, false);
      final style = (text.style ?? widget.defaultTextStyle).copyWith(
        fontFamily:
            text.style?.fontFamily ?? widget.defaultTextStyle.fontFamily,
      );
      final layoutedText = TextPainter(
        text: TextSpan(text: text.data, style: style),
        maxLines: 1,
        locale: text.locale ?? widget.defaultLocale,
        // textScaleFactor: text.textScaleFactor ?? textScaleFactor,
        textScaler: text.textScaler ?? textScaler,
        textDirection: widget.textDirection,
      )..layout();
      final calculatedWidth = layoutedText.size.width + widget.tabPadding * 2;
      final sizeConstraint =
          widget.forceFixedTabWidth ? _fixedTabWidth : widget.size.width;
      _tabTextSizes.add(math.min(calculatedWidth, sizeConstraint));
      _tabSizesFromIndex.add(_calculateTabSizeFromIndex(i));
    }

    for (var i = 0; i < widget.contentLength; i++) {
      if (widget.forceFixedTabWidth) {
        final offsetBegin = _fixedTabWidth * i + centeringOffset(i);
        final offsetEnd = _fixedTabWidth * (i + 1) + centeringOffset(i);
        _tabOffsets.add(Tween(begin: offsetBegin, end: offsetEnd));
      } else {
        final offsetBegin = _tabSizesFromIndex[i] + centeringOffset(i);
        final offsetEnd = i == widget.contentLength - 1
            ? _totalTabSize + centeringOffset(0)
            : _tabSizesFromIndex[i + 1] + centeringOffset(i + 1);
        _tabOffsets.add(Tween(begin: offsetBegin, end: offsetEnd));
      }

      final sizeBegin = _tabTextSizes[i];
      final sizeEnd = _tabTextSizes[(i + 1) % widget.contentLength];
      _tabSizeTweens.add(Tween(
        begin: math.min(sizeBegin, _fixedTabWidth),
        end: math.min(sizeEnd, _fixedTabWidth),
      ));
    }
  }

  @override
  void didChangeDependencies() {
    final textScaler = MediaQuery.textScalerOf(context);
    if (_previousTextScaleFactor != textScaler) {
      _previousTextScaleFactor = textScaler;
      setState(() {
        calculateTabBehaviorElements(textScaler);
      });
    }
    super.didChangeDependencies();
  }

  @override
  void initState() {
    super.initState();

    calculateTabBehaviorElements(widget.textScaler);

    // Safety: Initialize indicator size with safe fallback
    _indicatorSize = ValueNotifier(
      _tabTextSizes.isNotEmpty ? _tabTextSizes[0] : 0.0,
    );

    // Initialize animation controller
    _indicatorAnimationController =
        AnimationController(vsync: this, duration: widget.tabAnimationDuration)
          ..addListener(() {
            // Null-safe access to indicator animation
            final animation = _indicatorAnimation;
            if (animation != null) {
              _indicatorSize.value = animation.value;
            }
          });

    _tabController.addListener(() {
      if (_isTabForceScrolling) return;

      if (_isTabPositionAligned.value) {
        _isTabPositionAligned.value = false;
      }
    });

    _pageController.addListener(() {
      if (_isContentChangingByTab.value) return;

      final currentIndexDouble = _pageController.offset / widget.size.width;
      final currentIndex = currentIndexDouble.floor();
      // Use round() for modIndex to trigger page changes at midpoint for symmetric behavior
      final modIndex = currentIndexDouble.round() % widget.contentLength;

      final currentIndexDecimal =
          currentIndexDouble - currentIndexDouble.floor();

      _tabController.jumpTo(_tabOffsets[currentIndex % widget.contentLength]
          .transform(currentIndexDecimal));

      _indicatorSize.value = _tabSizeTweens[currentIndex % widget.contentLength]
          .transform(currentIndexDecimal);

      if (!_isTabPositionAligned.value) {
        _isTabPositionAligned.value = true;
      }

      if (modIndex != _selectedIndex.value) {
        widget.onPageChanged?.call(modIndex);
        _selectedIndex.value = modIndex;
        HapticFeedback.selectionClick();

        // Accessibility: Announce page change to screen readers
        if (mounted) {
          SemanticsService.announce(
            'Page ${modIndex + 1} of ${widget.contentLength}',
            widget.textDirection,
          );
        }
      }
    });
  }

  Future<void> _onTapTab(int modIndex, int rawIndex) async {
    // Safety checks
    if (_isDisposed || _isContentChangingByTab.value) return;

    _isContentChangingByTab.value = true;

    try {
      widget.onTabTap?.call(modIndex);
      widget.onPageChanged?.call(modIndex);

      HapticFeedback.selectionClick();
      _isTabPositionAligned.value = true;

      final sizeOnIndex = widget.forceFixedTabWidth
          ? _fixedTabWidth * modIndex
          : _tabSizesFromIndex[modIndex];
      final section = rawIndex.isNegative
          ? (rawIndex + 1) ~/ widget.contentLength - 1
          : rawIndex ~/ widget.contentLength;
      final targetOffset = _totalTabSize * section + sizeOnIndex;
      _isTabForceScrolling = true;

      // Fire-and-forget tab animation with error handling
      unawaited(
        _tabController
            .animateTo(
              targetOffset + centeringOffset(modIndex),
              duration: widget.tabAnimationDuration,
              curve: Curves.ease,
            )
            .then((_) => _isTabForceScrolling = false)
            .catchError((error) {
          _isTabForceScrolling = false;
          debugPrint('Tab animation error: $error');
          return false;
        }),
      );

      _indicatorAnimation =
          Tween(begin: _indicatorSize.value, end: _tabTextSizes[modIndex])
              .animate(_indicatorAnimationController);
      _indicatorAnimationController.forward(from: 0);

      // Get current scroll position and page index
      final currentOffset = _pageController.offset;

      // Calculate distance to selected page considering wrap-around
      final move = calculateMoveIndexDistance(
          _selectedIndex.value, modIndex, widget.contentLength);
      final targetPageOffset = currentOffset + move * widget.size.width;

      _selectedIndex.value = modIndex;

      // Await page animation with timeout
      await _pageController.animateTo(
        targetPageOffset,
        duration: widget.tabAnimationDuration,
        curve: Curves.ease,
      );
    } catch (e) {
      debugPrint('Error in _onTapTab: $e');
    } finally {
      _isContentChangingByTab.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            final newIndex = (_selectedIndex.value - 1) % widget.contentLength;
            _onTapTab(newIndex, newIndex);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            final newIndex = (_selectedIndex.value + 1) % widget.contentLength;
            _onTapTab(newIndex, newIndex);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        children: [
          Stack(
            children: [
              SizedBox(
                height: widget.tabHeight + (widget.separator?.width ?? 0),
                child: ValueListenableBuilder<bool>(
                  valueListenable: _isContentChangingByTab,
                  builder: (context, value, _) => AbsorbPointer(
                    absorbing: value,
                    child: _buildTabSection(),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ValueListenableBuilder<bool>(
                  valueListenable: _isTabPositionAligned,
                  builder: (context, value, _) => Visibility(
                    visible: value,
                    child: _CenteredIndicator(
                      indicatorColor: widget.indicatorColor,
                      size: _indicatorSize,
                      indicatorHeight: indicatorHeight,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: Semantics(
              label: 'Content area',
              child: CycledListView.builder(
                scrollDirection: Axis.horizontal,
                contentCount: widget.contentLength,
                controller: _pageController,
                physics: widget.scrollPhysics,
                itemBuilder: (context, modIndex, rawIndex) => SizedBox(
                  width: widget.size.width,
                  child: ValueListenableBuilder<int>(
                    valueListenable: _selectedIndex,
                    builder: (context, value, _) => Semantics(
                      label: 'Page ${modIndex + 1}',
                      liveRegion: value == modIndex,
                      child: widget.pageBuilder(
                          context, modIndex, value == modIndex),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSection() {
    return CycledListView.builder(
      scrollDirection: Axis.horizontal,
      controller: _tabController,
      contentCount: widget.contentLength,
      itemBuilder: (context, modIndex, rawIndex) {
        final isSelected = _selectedIndex.value == modIndex;

        final tab = Semantics(
          button: true,
          selected: isSelected,
          enabled: !_isDisposed,
          label: 'Tab ${modIndex + 1} of ${widget.contentLength}',
          hint: isSelected ? 'Currently selected' : 'Double tap to activate',
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => _onTapTab(modIndex, rawIndex),
              child: ValueListenableBuilder<int>(
                valueListenable: _selectedIndex,
                builder: (context, index, _) => ValueListenableBuilder<bool>(
                  valueListenable: _isTabPositionAligned,
                  builder: (context, tab, _) => _TabContent(
                    isTabPositionAligned: tab,
                    selectedIndex: index,
                    indicatorColor: widget.indicatorColor,
                    tabPadding: widget.tabPadding,
                    modIndex: modIndex,
                    tabBuilder: widget.tabBuilder,
                    separator: widget.separator,
                    tabWidth: widget.forceFixedTabWidth
                        ? _fixedTabWidth
                        : _tabTextSizes[modIndex],
                    indicatorHeight: indicatorHeight,
                    indicatorWidth: _tabTextSizes[modIndex],
                  ),
                ),
              ),
            ),
          ),
        );

        return widget.forceFixedTabWidth
            ? SizedBox(width: _fixedTabWidth, child: tab)
            : tab;
      },
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _tabController.dispose();
    _pageController.dispose();
    _indicatorAnimationController.dispose();
    _isContentChangingByTab.dispose();
    _isTabPositionAligned.dispose();
    _selectedIndex.dispose();
    _indicatorSize.dispose();
    super.dispose();
  }
}

/// Calculates the distance to the selected page.
///
/// Adjusts the sign to point in the nearest direction,
/// taking into account wrapping around mod boundaries.
@visibleForTesting
int calculateMoveIndexDistance(int current, int selected, int length) {
  final tabDistance = selected - current;
  var move = tabDistance;
  if (tabDistance.abs() >= length ~/ 2) {
    move += (-tabDistance.sign * length);
  }

  return move;
}

class _TabContent extends StatelessWidget {
  const _TabContent({
    required this.isTabPositionAligned,
    required this.selectedIndex,
    required this.modIndex,
    required this.tabPadding,
    required this.indicatorColor,
    required this.tabBuilder,
    this.separator,
    required this.indicatorHeight,
    required this.indicatorWidth,
    required this.tabWidth,
  });

  final int modIndex;
  final int selectedIndex;
  final bool isTabPositionAligned;
  final double tabPadding;
  final Color indicatorColor;
  final SelectIndexedTextBuilder tabBuilder;
  final BorderSide? separator;
  final double indicatorHeight;
  final double indicatorWidth;
  final double tabWidth;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: tabWidth,
          padding: EdgeInsets.symmetric(horizontal: tabPadding),
          decoration: BoxDecoration(
            border: Border(bottom: separator ?? BorderSide.none),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: tabBuilder(modIndex, selectedIndex == modIndex),
            ),
          ),
        ),
        if (selectedIndex == modIndex && !isTabPositionAligned)
          Positioned(
            bottom: 0,
            height: indicatorHeight,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: indicatorWidth,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(indicatorHeight),
                  color: indicatorColor,
                ),
              ),
            ),
          )
      ],
    );
  }
}

class _CenteredIndicator extends StatelessWidget {
  const _CenteredIndicator({
    required this.indicatorColor,
    required this.size,
    required this.indicatorHeight,
  });

  final Color indicatorColor;
  final ValueNotifier<double> size;
  final double indicatorHeight;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: size,
      builder: (context, value, _) => Center(
        child: Container(
          height: indicatorHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(indicatorHeight),
            color: indicatorColor,
          ),
          width: value,
        ),
      ),
    );
  }
}
