import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../cyclic_tab_bar.dart';
import 'cycled_list_view.dart';

/// A widget that displays a horizontally scrolling cyclic tab bar.
///
/// This is the tab bar component only. Use [CyclicTabBarView] to display
/// the corresponding pages. Coordinate them using a [CyclicTabController].
///
/// Example:
/// ```dart
/// DefaultCyclicTabController(
///   contentLength: 10,
///   child: Column(
///     children: [
///       Container(
///         decoration: BoxDecoration(
///           gradient: LinearGradient(...),
///         ),
///         child: CyclicTabBar(
///           contentLength: 10,
///           tabBuilder: (index, isSelected) => Text('Tab $index'),
///         ),
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
class CyclicTabBar extends StatefulWidget {
  /// Creates a cyclic tab bar.
  const CyclicTabBar({
    super.key,
    required this.contentLength,
    required this.tabBuilder,
    this.controller,
    this.onTabTap,
    this.tabSeparatorBuilder,
    @Deprecated('Use bottomBorder instead. separator will be removed in a future version.')
    BorderSide? separator,
    BorderSide? bottomBorder,
    this.backgroundColor,
    this.indicatorColor = Colors.blueAccent,
    this.indicatorHeight,
    this.tabHeight = 44.0,
    this.tabPadding = 12.0,
    this.forceFixedTabWidth = false,
    this.fixedTabWidthFraction = 0.5,
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
        ), bottomBorder = bottomBorder ?? separator;

  /// The total number of tabs.
  final int contentLength;

  /// A callback for building tab contents.
  ///
  /// Must return a [Text] widget.
  /// `index` is the modulo index (0 to [contentLength] - 1).
  /// `isSelected` indicates whether this tab is currently selected.
  final SelectIndexedTextBuilder tabBuilder;

  /// The controller that coordinates this tab bar with a [CyclicTabBarView].
  ///
  /// If null, uses [DefaultCyclicTabController.of] to find a controller.
  final CyclicTabController? controller;

  /// Callback when a tab is tapped.
  final IndexedTapCallback? onTabTap;

  /// Builder for separators between tabs.
  ///
  /// If provided, the tab bar will display separators between each tab.
  /// The builder receives both the modulo index (0 to [contentLength] - 1)
  /// and the raw index for flexibility.
  ///
  /// Example:
  /// ```dart
  /// tabSeparatorBuilder: (context, modIndex, rawIndex) => Container(
  ///   width: 1,
  ///   color: Colors.grey,
  /// ),
  /// ```
  final ModuloIndexedWidgetBuilder? tabSeparatorBuilder;

  /// Border line displayed at the bottom of the tab bar.
  ///
  final BorderSide? bottomBorder;

  /// Background color of the tab bar.
  final Color? backgroundColor;

  /// Color of the selection indicator.
  final Color indicatorColor;

  /// Height of the selection indicator.
  ///
  /// If null, uses [bottomBorder] width, or defaults to 2.0.
  final double? indicatorHeight;

  /// Height of the tab bar.
  final double tabHeight;

  /// Horizontal padding for each tab.
  final double tabPadding;

  /// Whether to force all tabs to have fixed width.
  final bool forceFixedTabWidth;

  /// Fraction of screen width to use for fixed tab width.
  ///
  /// Only used when [forceFixedTabWidth] is true.
  final double fixedTabWidthFraction;

  @override
  State<CyclicTabBar> createState() => _CyclicTabBarState();
}

class _CyclicTabBarState extends State<CyclicTabBar>
    with SingleTickerProviderStateMixin {
  CyclicTabController? _internalController;
  TextScaler _previousTextScaler = TextScaler.noScaling;

  // Tab size calculation results
  final List<double> _tabTextSizes = [];
  final List<double> _tabSizesFromIndex = [];
  final List<Tween<double>> _tabOffsets = [];
  final List<Tween<double>> _tabSizeTweens = [];
  double _totalTabSize = 0.0;

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
        vsync: this,
      );
      return _internalController!;
    }
  }

  double get _indicatorHeight =>
      widget.indicatorHeight ?? widget.bottomBorder?.width ?? 2.0;

  double get _fixedTabWidth {
    final size = MediaQuery.sizeOf(context);
    return size.width * widget.fixedTabWidthFraction;
  }

  double _centeringOffset(int index) {
    final size = MediaQuery.sizeOf(context);
    final tabSize =
        widget.forceFixedTabWidth ? _fixedTabWidth : _tabTextSizes[index];
    return -(size.width - tabSize) / 2;
  }

  double _calculateTabSizeFromIndex(int index) {
    var size = 0.0;
    for (var i = 0; i < index; i++) {
      size += _tabTextSizes[i];
    }
    return size;
  }

  void _calculateTabSizes() {
    if (widget.contentLength <= 0) return;

    final size = MediaQuery.sizeOf(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final defaultTextStyle = DefaultTextStyle.of(context).style;
    final textDirection = Directionality.of(context);
    final defaultLocale = Localizations.localeOf(context);

    _tabTextSizes.clear();
    _tabSizesFromIndex.clear();
    _tabOffsets.clear();
    _tabSizeTweens.clear();
    _totalTabSize = 0.0;

    // Calculate text sizes
    for (var i = 0; i < widget.contentLength; i++) {
      final text = widget.tabBuilder(i, false);
      final style = (text.style ?? defaultTextStyle).copyWith(
        fontFamily: text.style?.fontFamily ?? defaultTextStyle.fontFamily,
      );
      final layoutedText = TextPainter(
        text: TextSpan(text: text.data, style: style),
        maxLines: 1,
        locale: text.locale ?? defaultLocale,
        textScaler: text.textScaler ?? textScaler,
        textDirection: textDirection,
      )..layout();

      final calculatedWidth = layoutedText.size.width + widget.tabPadding * 2;
      final sizeConstraint =
          widget.forceFixedTabWidth ? _fixedTabWidth : size.width;
      _tabTextSizes.add(math.min(calculatedWidth, sizeConstraint));
      _tabSizesFromIndex.add(_calculateTabSizeFromIndex(i));
    }

    // Calculate total size
    _totalTabSize = widget.forceFixedTabWidth
        ? _fixedTabWidth * widget.contentLength
        : _tabTextSizes.reduce((v, e) => v += e);

    // Calculate offset tweens
    for (var i = 0; i < widget.contentLength; i++) {
      if (widget.forceFixedTabWidth) {
        final offsetBegin = _fixedTabWidth * i + _centeringOffset(i);
        final offsetEnd = _fixedTabWidth * (i + 1) + _centeringOffset(i);
        _tabOffsets.add(Tween(begin: offsetBegin, end: offsetEnd));
      } else {
        final offsetBegin = _tabSizesFromIndex[i] + _centeringOffset(i);
        final offsetEnd = i == widget.contentLength - 1
            ? _totalTabSize + _centeringOffset(0)
            : _tabSizesFromIndex[i + 1] + _centeringOffset(i + 1);
        _tabOffsets.add(Tween(begin: offsetBegin, end: offsetEnd));
      }

      final sizeBegin = _tabTextSizes[i];
      final sizeEnd = _tabTextSizes[(i + 1) % widget.contentLength];
      _tabSizeTweens.add(Tween(
        begin: math.min(sizeBegin, _fixedTabWidth),
        end: math.min(sizeEnd, _fixedTabWidth),
      ));
    }

    // Update controller with size information
    _controller.updateTabSizes(
      tabTextSizes: _tabTextSizes,
      tabSizesFromIndex: _tabSizesFromIndex,
      tabOffsets: _tabOffsets,
      tabSizeTweens: _tabSizeTweens,
      size: size,
      forceFixedTabWidth: widget.forceFixedTabWidth,
      fixedTabWidth: _fixedTabWidth,
      totalTabSize: _totalTabSize,
    );
  }

  @override
  void initState() {
    super.initState();

    // Calculate sizes after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _calculateTabSizes();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final textScaler = MediaQuery.textScalerOf(context);
    if (_previousTextScaler != textScaler) {
      _previousTextScaler = textScaler;
      _calculateTabSizes();
    }
  }

  @override
  void didUpdateWidget(CyclicTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Recalculate if relevant properties changed
    if (oldWidget.contentLength != widget.contentLength ||
        oldWidget.forceFixedTabWidth != widget.forceFixedTabWidth ||
        oldWidget.fixedTabWidthFraction != widget.fixedTabWidthFraction ||
        oldWidget.tabPadding != widget.tabPadding) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _calculateTabSizes();
        }
      });
    }
  }

  void _onTabTap(int modIndex, int rawIndex) {
    widget.onTabTap?.call(modIndex);

    // Trigger tab animation via controller with raw index preserved
    _controller.onTapTabWithRawIndex(modIndex, rawIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (!_controller.isInitialized) return KeyEventResult.ignored;

        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            final newIndex = (_controller.index - 1) % widget.contentLength;
            _controller.animateToIndex(newIndex);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            final newIndex = (_controller.index + 1) % widget.contentLength;
            _controller.animateToIndex(newIndex);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Material(
        color: widget.backgroundColor,
        child: Stack(
          children: [
            SizedBox(
              height: widget.tabHeight + (widget.bottomBorder?.width ?? 0),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => AbsorbPointer(
                  absorbing: _controller.isContentChangingByTab,
                  child: _buildTabSection(),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => Visibility(
                  visible: _controller.isTabPositionAligned,
                  child: _CenteredIndicator(
                    indicatorColor: widget.indicatorColor,
                    size: _controller.indicatorSize,
                    indicatorHeight: _indicatorHeight,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSection() {
    if (!_controller.isInitialized) {
      return const SizedBox.shrink();
    }

    // Use the effective bottom border (bottomBorder takes precedence over deprecated separator)
    final effectiveBottomBorder = widget.bottomBorder;

    Widget buildTab(BuildContext context, int modIndex, int rawIndex) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final isSelected = _controller.index == modIndex;

          final tab = Semantics(
            button: true,
            selected: isSelected,
            label: 'Tab ${modIndex + 1} of ${widget.contentLength}',
            hint: isSelected ? 'Currently selected' : 'Double tap to activate',
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () => _onTabTap(modIndex, rawIndex),
                child: _TabContent(
                  isTabPositionAligned: _controller.isTabPositionAligned,
                  selectedIndex: _controller.index,
                  indicatorColor: widget.indicatorColor,
                  tabPadding: widget.tabPadding,
                  modIndex: modIndex,
                  tabBuilder: widget.tabBuilder,
                  bottomBorder: effectiveBottomBorder,
                  tabWidth: widget.forceFixedTabWidth
                      ? _fixedTabWidth
                      : (_tabTextSizes.isNotEmpty
                          ? _tabTextSizes[modIndex]
                          : 0),
                  indicatorHeight: _indicatorHeight,
                  indicatorWidth:
                      _tabTextSizes.isNotEmpty ? _tabTextSizes[modIndex] : 0,
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

    if (widget.tabSeparatorBuilder != null) {
      return CycledListView.separated(
        scrollDirection: Axis.horizontal,
        controller: _controller.tabScrollController,
        contentCount: widget.contentLength,
        itemBuilder: buildTab,
        separatorBuilder: widget.tabSeparatorBuilder!,
      );
    }

    return CycledListView.builder(
      scrollDirection: Axis.horizontal,
      controller: _controller.tabScrollController,
      contentCount: widget.contentLength,
      itemBuilder: buildTab,
    );
  }

  @override
  void dispose() {
    _internalController?.dispose();
    super.dispose();
  }
}

class _TabContent extends StatelessWidget {
  const _TabContent({
    required this.isTabPositionAligned,
    required this.selectedIndex,
    required this.modIndex,
    required this.tabPadding,
    required this.indicatorColor,
    required this.tabBuilder,
    this.bottomBorder,
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
  final BorderSide? bottomBorder;
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
            border: Border(bottom: bottomBorder ?? BorderSide.none),
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
  final double size;
  final double indicatorHeight;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        height: indicatorHeight,
        width: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(indicatorHeight),
          color: indicatorColor,
        ),
      ),
    );
  }
}
