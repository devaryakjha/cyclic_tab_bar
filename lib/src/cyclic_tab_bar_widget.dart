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
    required this.tabBuilder,
    this.controller,
    this.onTabTap,
    this.tabSpacing = 0.0,
    @Deprecated(
        'Use bottomBorder instead. separator will be removed in a future version.')
    BorderSide? separator,
    BorderSide? bottomBorder,
    this.backgroundColor,
    this.indicatorColor = Colors.blueAccent,
    this.indicatorHeight,
    this.maxIndicatorWidth,
    this.tabHeight = 44.0,
    this.tabPadding = 12.0,
    this.forceFixedTabWidth = false,
    this.fixedTabWidthFraction = 0.5,
  })  : assert(tabHeight > 0, 'tabHeight must be greater than 0'),
        assert(tabPadding >= 0, 'tabPadding must be non-negative'),
        assert(
          fixedTabWidthFraction > 0 && fixedTabWidthFraction <= 1.0,
          'fixedTabWidthFraction must be between 0 and 1.0',
        ),
        assert(
          indicatorHeight == null || indicatorHeight >= 1.0,
          'indicatorHeight must be >= 1.0 when specified',
        ),
        bottomBorder = bottomBorder ?? separator;

  /// A callback for building tab contents.
  ///
  /// Can return any widget.
  /// `index` is the modulo index (0 to [contentLength] - 1).
  /// `isSelected` indicates whether this tab is currently selected.
  final SelectIndexedTabBuilder tabBuilder;

  /// The controller that coordinates this tab bar with a [CyclicTabBarView].
  ///
  /// If null, uses [DefaultCyclicTabController.of] to find a controller.
  final CyclicTabController? controller;

  /// Callback when a tab is tapped.
  final IndexedTapCallback? onTabTap;

  /// Horizontal spacing between tabs in pixels.
  ///
  /// Adds space between each tab without affecting individual tab sizes.
  /// This ensures the indicator positioning remains accurate.
  /// Defaults to 0 (no spacing).
  ///
  /// Example:
  /// ```dart
  /// CyclicTabBar(
  ///   tabSpacing: 8.0,
  ///   // ... other parameters
  /// )
  /// ```
  final double tabSpacing;

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

  /// Maximum width for the indicator in pixels.
  ///
  /// When set, the indicator width will be clamped to this value.
  /// Useful for creating compact indicators that don't span the full tab width.
  /// If null, the indicator spans the full tab text width.
  final double? maxIndicatorWidth;

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
  TextScaler _previousTextScaler = TextScaler.noScaling;
  int? _lastMeasuredContentLength;
  bool _isTabSizeCalculationScheduled = false;

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
      rethrow;
    }
  }

  double get _indicatorHeight =>
      widget.indicatorHeight ?? widget.bottomBorder?.width ?? 2.0;

  double get _fixedTabWidth {
    final size = MediaQuery.sizeOf(context);
    return size.width * widget.fixedTabWidthFraction;
  }

  double _alignmentOffset(int index) {
    if (_controller.alignment == CyclicTabAlignment.left) {
      return 0;
    }
    // Center alignment
    final size = MediaQuery.sizeOf(context);
    final tabSize =
        widget.forceFixedTabWidth ? _fixedTabWidth : _tabTextSizes[index];
    return -(size.width - tabSize) / 2;
  }

  void _calculateTabSizes() {
    _isTabSizeCalculationScheduled = false;
    final contentLength = _controller.contentLength;
    if (contentLength <= 0) return;

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

    var runningOffset = 0.0;

    _lastMeasuredContentLength = contentLength;

    // Calculate text sizes
    for (var i = 0; i < contentLength; i++) {
      final tabContent = widget.tabBuilder(i, false);
      final sizeConstraint =
          widget.forceFixedTabWidth ? _fixedTabWidth : size.width;
      final calculatedWidth = _resolveTabWidth(
        tabContent,
        defaultTextStyle: defaultTextStyle,
        textScaler: textScaler,
        textDirection: textDirection,
        locale: defaultLocale,
        sizeConstraint: sizeConstraint,
      );
      _tabTextSizes.add(calculatedWidth);
      _tabSizesFromIndex.add(runningOffset);

      final widthForOffset =
          widget.forceFixedTabWidth ? _fixedTabWidth : calculatedWidth;
      runningOffset += widthForOffset;
      if (widget.tabSpacing > 0) {
        runningOffset += widget.tabSpacing;
      }
    }
    _totalTabSize = runningOffset;

    // Calculate offset tweens
    for (var i = 0; i < contentLength; i++) {
      if (widget.forceFixedTabWidth) {
        // Account for spacing in fixed width mode
        final tabAndSpaceWidth = _fixedTabWidth + widget.tabSpacing;
        final offsetBegin = tabAndSpaceWidth * i + _alignmentOffset(i);
        final offsetEnd = tabAndSpaceWidth * (i + 1) + _alignmentOffset(i);
        _tabOffsets.add(Tween(begin: offsetBegin, end: offsetEnd));
      } else {
        final offsetBegin = _tabSizesFromIndex[i] + _alignmentOffset(i);
        final offsetEnd = i == contentLength - 1
            ? _totalTabSize + _alignmentOffset(0)
            : _tabSizesFromIndex[i + 1] + _alignmentOffset(i + 1);
        _tabOffsets.add(Tween(begin: offsetBegin, end: offsetEnd));
      }

      final sizeBegin = _tabTextSizes[i];
      final sizeEnd = _tabTextSizes[(i + 1) % contentLength];
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

  double _resolveTabWidth(
    Widget tabContent, {
    required TextStyle defaultTextStyle,
    required TextScaler textScaler,
    required TextDirection textDirection,
    required Locale locale,
    required double sizeConstraint,
  }) {
    final measuredContentWidth = _measureWidgetContentWidth(
      tabContent,
      defaultTextStyle: defaultTextStyle,
      textScaler: textScaler,
      textDirection: textDirection,
      locale: locale,
    );

    final availableContentWidth =
        math.max(0.0, sizeConstraint - widget.tabPadding * 2);
    final effectiveContentWidth = measuredContentWidth != null
        ? math.max(0.0, measuredContentWidth)
        : availableContentWidth;
    final paddedWidth =
        math.min(effectiveContentWidth + widget.tabPadding * 2, sizeConstraint);
    return paddedWidth;
  }

  double? _measureWidgetContentWidth(
    Widget widget, {
    required TextStyle defaultTextStyle,
    required TextScaler textScaler,
    required TextDirection textDirection,
    required Locale locale,
  }) {
    if (widget is Text) {
      return _measureTextWidget(
        widget,
        defaultTextStyle,
        textScaler,
        textDirection,
        locale,
      );
    }

    if (widget is SelectableText) {
      return _measureSelectableTextWidget(
        widget,
        defaultTextStyle,
        textScaler,
        textDirection,
        locale,
      );
    }

    if (widget is RichText) {
      return _measureRichTextWidget(
        widget,
        textDirection,
        locale,
      );
    }

    if (widget is Icon) {
      final iconTheme = IconTheme.of(context);
      final iconSize = widget.size ?? iconTheme.size ?? 24.0;
      return iconSize;
    }

    if (widget is IconButton) {
      final iconTheme = IconTheme.of(context);
      final iconSize = widget.iconSize ?? iconTheme.size ?? 24.0;
      final constraints = widget.constraints;
      if (constraints != null) {
        if (constraints.hasTightWidth) {
          return constraints.maxWidth;
        }
        if (constraints.minWidth > 0) {
          return constraints.minWidth;
        }
      }
      final paddingGeometry = widget.padding ?? EdgeInsets.zero;
      final padding = paddingGeometry.resolve(textDirection).horizontal;
      return iconSize + padding;
    }

    if (widget is SizedBox) {
      final width = widget.width;
      if (width != null) {
        return width;
      }
      final child = widget.child;
      if (child != null) {
        return _measureWidgetContentWidth(
          child,
          defaultTextStyle: defaultTextStyle,
          textScaler: textScaler,
          textDirection: textDirection,
          locale: locale,
        );
      }
      return 0.0;
    }

    if (widget is Padding) {
      final resolvedPadding = widget.padding.resolve(textDirection).horizontal;
      final childWidth = widget.child != null
          ? _measureWidgetContentWidth(
              widget.child!,
              defaultTextStyle: defaultTextStyle,
              textScaler: textScaler,
              textDirection: textDirection,
              locale: locale,
            )
          : 0.0;
      if (childWidth != null) {
        return childWidth + resolvedPadding;
      }
      return resolvedPadding;
    }

    if (widget is Container) {
      final resolvedPadding =
          widget.padding?.resolve(textDirection).horizontal ?? 0.0;

      final constraints = widget.constraints;
      if (constraints != null) {
        if (constraints.hasTightWidth) {
          return constraints.maxWidth;
        }
        if (constraints.minWidth > 0) {
          return constraints.minWidth;
        }
      }

      final child = widget.child;
      if (child != null) {
        final childWidth = _measureWidgetContentWidth(
          child,
          defaultTextStyle: defaultTextStyle,
          textScaler: textScaler,
          textDirection: textDirection,
          locale: locale,
        );
        if (childWidth != null) {
          return childWidth + resolvedPadding;
        }
      }

      if (resolvedPadding > 0) {
        return resolvedPadding;
      }
    }

    if (widget is ConstrainedBox) {
      final constraints = widget.constraints;
      if (constraints.hasTightWidth) {
        return constraints.maxWidth;
      }
      if (constraints.minWidth > 0) {
        return constraints.minWidth;
      }
      final child = widget.child;
      if (child != null) {
        return _measureWidgetContentWidth(
          child,
          defaultTextStyle: defaultTextStyle,
          textScaler: textScaler,
          textDirection: textDirection,
          locale: locale,
        );
      }
    }

    if (widget is Row && widget.mainAxisSize == MainAxisSize.min) {
      double totalWidth = 0.0;
      var measurementFailed = false;
      for (final child in widget.children) {
        final childWidth = _measureWidgetContentWidth(
          child,
          defaultTextStyle: defaultTextStyle,
          textScaler: textScaler,
          textDirection: textDirection,
          locale: locale,
        );
        if (childWidth == null) {
          measurementFailed = true;
          break;
        }
        totalWidth += childWidth;
      }
      if (!measurementFailed) {
        return totalWidth;
      }
    }

    if (widget is Column && widget.mainAxisSize == MainAxisSize.min) {
      double? maxWidth;
      for (final child in widget.children) {
        final childWidth = _measureWidgetContentWidth(
          child,
          defaultTextStyle: defaultTextStyle,
          textScaler: textScaler,
          textDirection: textDirection,
          locale: locale,
        );
        if (childWidth == null) {
          maxWidth = null;
          break;
        }
        maxWidth = math.max(maxWidth ?? 0.0, childWidth);
      }
      if (maxWidth != null) {
        return maxWidth;
      }
    }

    if (widget is PreferredSizeWidget) {
      final preferredWidth = widget.preferredSize.width;
      if (preferredWidth.isFinite && preferredWidth > 0) {
        return preferredWidth;
      }
    }

    if (widget is SingleChildRenderObjectWidget) {
      final child = widget.child;
      if (child != null) {
        return _measureWidgetContentWidth(
          child,
          defaultTextStyle: defaultTextStyle,
          textScaler: textScaler,
          textDirection: textDirection,
          locale: locale,
        );
      }
      return 0.0;
    }

    return null;
  }

  double _measureTextWidget(
    Text text,
    TextStyle defaultTextStyle,
    TextScaler textScaler,
    TextDirection textDirection,
    Locale locale,
  ) {
    final style = (text.style ?? defaultTextStyle).copyWith(
      fontFamily: text.style?.fontFamily ?? defaultTextStyle.fontFamily,
    );
    final span = text.textSpan ??
        TextSpan(
          text: text.data ?? '',
          style: style,
        );
    final painter = TextPainter(
      text: span,
      maxLines: text.maxLines ?? 1,
      locale: text.locale ?? locale,
      textScaler: text.textScaler ?? textScaler,
      textDirection: text.textDirection ?? textDirection,
      textAlign: text.textAlign ?? TextAlign.start,
      strutStyle: text.strutStyle,
      textWidthBasis: text.textWidthBasis ?? TextWidthBasis.parent,
      textHeightBehavior: text.textHeightBehavior,
    )..layout();
    return painter.size.width;
  }

  double _measureSelectableTextWidget(
    SelectableText text,
    TextStyle defaultTextStyle,
    TextScaler textScaler,
    TextDirection textDirection,
    Locale locale,
  ) {
    final span = text.textSpan ??
        TextSpan(
          text: text.data ?? '',
          style: (text.style ?? defaultTextStyle)
              .copyWith(fontFamily: defaultTextStyle.fontFamily),
        );
    final painter = TextPainter(
      text: span,
      maxLines: text.maxLines,
      locale: locale,
      textScaler: text.textScaler ?? TextScaler.linear(1.0),
      textDirection: text.textDirection ?? textDirection,
      textAlign: text.textAlign ?? TextAlign.start,
      strutStyle: text.strutStyle,
      textWidthBasis: text.textWidthBasis ?? TextWidthBasis.parent,
      textHeightBehavior: text.textHeightBehavior,
    )..layout();
    return painter.size.width;
  }

  double _measureRichTextWidget(
    RichText text,
    TextDirection textDirection,
    Locale locale,
  ) {
    final painter = TextPainter(
      text: text.text,
      maxLines: text.maxLines,
      locale: text.locale ?? locale,
      textScaler: text.textScaler,
      textDirection: text.textDirection ?? textDirection,
      textAlign: text.textAlign,
      strutStyle: text.strutStyle,
      textWidthBasis: text.textWidthBasis,
      textHeightBehavior: text.textHeightBehavior,
      ellipsis: text.overflow == TextOverflow.ellipsis ? '...' : null,
    )..layout();
    return painter.size.width;
  }

  @override
  void initState() {
    super.initState();

    // Calculate sizes after first frame
    _scheduleTabSizeCalculation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final textScaler = MediaQuery.textScalerOf(context);
    if (_previousTextScaler != textScaler) {
      _previousTextScaler = textScaler;
      _scheduleTabSizeCalculation();
    }
  }

  @override
  void didUpdateWidget(CyclicTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Recalculate if relevant properties changed
    if (widget.controller == null ||
        oldWidget.forceFixedTabWidth != widget.forceFixedTabWidth ||
        oldWidget.fixedTabWidthFraction != widget.fixedTabWidthFraction ||
        oldWidget.tabPadding != widget.tabPadding) {
      _scheduleTabSizeCalculation();
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
        final contentLength = _controller.contentLength;
        if (contentLength <= 0) return KeyEventResult.ignored;

        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            final newIndex = (_controller.index - 1) % contentLength;
            _controller.animateToIndex(newIndex);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            final newIndex = (_controller.index + 1) % contentLength;
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
              left: widget.tabPadding,
              right: widget.tabPadding,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => Visibility(
                  visible: _controller.isTabPositionAligned,
                  child: _CenteredIndicator(
                    indicatorColor: widget.indicatorColor,
                    size: _controller.indicatorSize - (widget.tabPadding * 2),
                    indicatorHeight: _indicatorHeight,
                    alignment: _controller.alignment,
                    maxWidth: widget.maxIndicatorWidth,
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
    final contentLength = _controller.contentLength;
    if (!_controller.isInitialized) {
      _scheduleTabSizeCalculation();
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
            label: 'Tab ${modIndex + 1} of ${_controller.contentLength}',
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
                  alignment: _controller.alignment,
                  bottomBorder: effectiveBottomBorder,
                  tabWidth: widget.forceFixedTabWidth
                      ? _fixedTabWidth
                      : (_tabTextSizes.length > modIndex
                          ? _tabTextSizes[modIndex]
                          : (_tabTextSizes.isNotEmpty
                              ? _tabTextSizes.last
                              : _fixedTabWidth)),
                  indicatorHeight: _indicatorHeight,
                  indicatorWidth: widget.forceFixedTabWidth
                      ? _fixedTabWidth
                      : (_tabTextSizes.length > modIndex
                          ? _tabTextSizes[modIndex]
                          : (_tabTextSizes.isNotEmpty
                              ? _tabTextSizes.last
                              : _fixedTabWidth)),
                  maxIndicatorWidth: widget.maxIndicatorWidth,
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

    if (_lastMeasuredContentLength != contentLength && contentLength > 0) {
      _scheduleTabSizeCalculation();
    }

    return CycledListView.builder(
      scrollDirection: Axis.horizontal,
      controller: _controller.tabScrollController,
      contentCount: contentLength,
      itemBuilder: buildTab,
      itemSpacing: widget.tabSpacing,
    );
  }

  void _scheduleTabSizeCalculation() {
    if (_isTabSizeCalculationScheduled) {
      return;
    }
    _isTabSizeCalculationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _isTabSizeCalculationScheduled = false;
        return;
      }
      _calculateTabSizes();
    });
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
    required this.alignment,
    this.bottomBorder,
    required this.indicatorHeight,
    required this.indicatorWidth,
    required this.tabWidth,
    this.maxIndicatorWidth,
  });

  final int modIndex;
  final int selectedIndex;
  final bool isTabPositionAligned;
  final double tabPadding;
  final Color indicatorColor;
  final SelectIndexedTabBuilder tabBuilder;
  final CyclicTabAlignment alignment;
  final BorderSide? bottomBorder;
  final double indicatorHeight;
  final double indicatorWidth;
  final double tabWidth;
  final double? maxIndicatorWidth;

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
            left: tabPadding,
            right: tabPadding,
            child: _CenteredIndicator(
              indicatorColor: indicatorColor,
              indicatorHeight: indicatorHeight,
              size: indicatorWidth - (tabPadding * 2),
              alignment: alignment,
              maxWidth: maxIndicatorWidth,
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
    required this.alignment,
    this.maxWidth,
  });

  final Color indicatorColor;
  final double size;
  final double indicatorHeight;
  final CyclicTabAlignment alignment;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = maxWidth != null ? math.min(size, maxWidth!) : size;

    return Align(
      alignment: alignment == CyclicTabAlignment.left
          ? Alignment.centerLeft
          : Alignment.center,
      child: SizedBox(
        width: size.normalise(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: indicatorHeight,
              width: effectiveWidth.normalise(),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(indicatorHeight),
                color: indicatorColor,
              ),
            ),
            SizedBox(width: (size - effectiveWidth).normalise()),
          ],
        ),
      ),
    );
  }
}

extension on double {
  double normalise() {
    return isNegative ? 0.0 : this;
  }
}
