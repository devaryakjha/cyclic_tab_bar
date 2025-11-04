# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter package that provides a cyclic tab bar component with infinite scrolling. The package is published on pub.dev as `cyclic_tab_bar`.

**Key Architecture Change (Latest)**: The package now uses a separated component architecture similar to Flutter's official TabBar API, with `CyclicTabBar`, `CyclicTabBarView`, and `CyclicTabController` as independent components.

## Key Commands

### Running Tests
```bash
flutter test
```

Run a specific test file:
```bash
flutter test test/infinite_scroll_tab_view_test.dart
```

### Linting
```bash
flutter analyze
```

The project uses `flutter_lints` for code analysis.

### Running the Example App
```bash
cd example
flutter run
```

### Package Management
```bash
flutter pub get          # Install dependencies
flutter pub upgrade      # Upgrade dependencies
```

## Architecture

### Core Components (New API)

**CyclicTabController** (`lib/src/cyclic_tab_controller.dart`)
- Central state manager that coordinates tabs and pages
- Extends `ChangeNotifier` for reactive updates
- Manages two `CycledScrollController` instances (one for tabs, one for pages)
- Holds tab size calculations, offset mapping, and animation state
- Provides public API: `index`, `animateToIndex()`, `jumpToIndex()`, listeners
- Internal API for components: `updateTabSizes()`, `onPageScroll()`, `onTabScroll()`

**CyclicTabBar** (`lib/src/new_cyclic_tab_bar.dart`)
- Renders only the tab bar UI component
- Can accept optional `controller` parameter or uses `DefaultCyclicTabController.of(context)`
- Calculates tab sizes using `TextPainter` and provides data to controller via `updateTabSizes()`
- Listens to controller for updates and rebuilds when state changes
- Handles keyboard navigation (arrow keys)
- Returns Stack with tabs and animated indicator
- **Key benefit**: Can be wrapped in Container/DecoratedBox for custom backgrounds

**CyclicTabBarView** (`lib/src/cyclic_tab_bar_view.dart`)
- Renders only the page view UI component
- Accepts optional `controller` parameter or uses `DefaultCyclicTabController.of(context)`
- Reports scroll events to controller via `onPageScroll()`
- Listens to controller for index changes
- Uses `CycledListView` with infinite scroll bounds

**DefaultCyclicTabController** (`lib/src/default_cyclic_tab_controller.dart`)
- Convenience widget that creates and manages a `CyclicTabController`
- Provides controller to descendants via `InheritedWidget` pattern
- Similar to Flutter's `DefaultTabController`
- Automatically disposes controller when widget is disposed

**CycledListView** (`lib/src/cycled_list_view.dart`)
- Custom ListView with infinite scroll bounds (`double.negativeInfinity` to `double.infinity`)
- Uses custom `CycledScrollController` and `_InfiniteScrollPosition`
- Renders items in both positive and negative directions from center
- Modulo arithmetic maps infinite index space to finite content: `index % contentCount`
- Supports `itemSpacing` parameter to add space between items without affecting individual item sizes

### Legacy Components

**InnerCyclicTabBar** (`lib/src/inner_cyclic_tab_bar.dart`)
- Old combined implementation (kept for reference, not exported)
- Contains the original tight coupling logic
- Shows how synchronization worked before separation

**Old CyclicTabBar** (`lib/src/cyclic_tab_bar.dart`)
- Now only exports type definitions: `SelectIndexedWidgetBuilder`, `SelectIndexedTextBuilder`, `IndexedTapCallback`
- No longer contains widget implementation

### Scroll Synchronization Strategy

The controller maintains synchronization between tab and page scrolling through:

1. **Tab Size Pre-calculation**: Tab sizes are calculated by `CyclicTabBar` using `TextPainter` and stored in controller's internal arrays (`_tabTextSizes`, `_tabSizesFromIndex`)

2. **Offset Mapping**: `_tabOffsets` Tweens in controller map page scroll progress to corresponding tab scroll positions

3. **Page-to-Tab Updates**: When pages scroll, `CyclicTabBarView` calls `controller.onPageScroll()` which:
   - Calculates current page index and decimal position
   - Updates tab scroll position using pre-calculated Tweens
   - Updates indicator size with smooth transitions
   - Notifies listeners when index changes

4. **Tab-to-Page Updates**: When tabs are tapped, `CyclicTabBar` calls `controller.animateToIndex()` which:
   - Sets `_isContentChangingByTab` flag to prevent feedback loops
   - Animates both tab and page controllers simultaneously
   - Uses `calculateMoveIndexDistance` to determine shortest wraparound path

5. **State Synchronization**: Controller uses flags to prevent feedback loops:
   - `_isContentChangingByTab`: Prevents page listener from interfering during tab-initiated navigation
   - `_isTabForceScrolling`: Prevents tab listener from interfering during programmatic scrolling
   - `_isTabPositionAligned`: Controls indicator visibility during manual scrolling

### Index Management

- **Raw Index**: Actual index in the infinite scroll range (can be negative or very large)
- **Mod Index**: `rawIndex % contentLength` - maps to actual content array
- Both indices available to builder callbacks for flexibility

## Testing Notes

Tests verify:
- Component separation and independent operation
- Custom decoration wrapping of tab bar
- Controller-based coordination between components
- `calculateMoveIndexDistance` correctly handles wrapping in both directions
- Programmatic navigation via controller
- Tab and page synchronization
- Spacing functionality in both tabs and pages
- Backward compatibility with deprecated `separator` parameter (now `bottomBorder`)

When testing widgets:
```dart
// Find controller from context
final controller = DefaultCyclicTabController.of(context);

// Or create explicit controller
final controller = CyclicTabController(contentLength: 10);
```

## Development Guidelines

- The package uses null safety (SDK: ">=2.12.0 <3.0.0")
- Uses modern Flutter APIs: `TextScaler` instead of deprecated `textScaleFactor`, `MediaQuery.sizeOf()` instead of `MediaQuery.of().size`
- Tab builders must return `Text` widgets (enforced by `SelectIndexedTextBuilder` type)
- Page builders can return any widget (uses `SelectIndexedWidgetBuilder`)
- When adding new features, consider whether they belong in the controller, tab bar, or page view
- The separated architecture allows users to create custom tab bars or page views that work with the same controller

## API Usage Patterns

### Basic Usage (DefaultCyclicTabController)
```dart
DefaultCyclicTabController(
  contentLength: 10,
  child: Column(
    children: [
      CyclicTabBar(...),
      Expanded(child: CyclicTabBarView(...)),
    ],
  ),
)
```

### Explicit Controller (Advanced)
```dart
class MyWidget extends StatefulWidget {
  @override
  State createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> with SingleTickerProviderStateMixin {
  late CyclicTabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CyclicTabController(
      contentLength: 10,
      vsync: this,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CyclicTabBar(controller: _controller, ...),
        Expanded(child: CyclicTabBarView(controller: _controller, ...)),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

### Custom Tab Bar Decoration
```dart
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(...),
    boxShadow: [...],
  ),
  child: CyclicTabBar(...),
)
```

### Tab Spacing
```dart
CyclicTabBar(
  contentLength: 10,
  tabBuilder: (index, _) => Text('Tab $index'),
  tabSpacing: 8.0,  // 8 pixels between tabs
)
```

### Page Spacing
```dart
CyclicTabBarView(
  contentLength: 10,
  pageBuilder: (context, index, _) => Center(child: Text('Page $index')),
  pageSpacing: 16.0,  // 16 pixels between pages
)
```

### Bottom Border
```dart
CyclicTabBar(
  contentLength: 10,
  tabBuilder: (index, _) => Text('Tab $index'),
  bottomBorder: BorderSide(color: Colors.grey, width: 2),
)
```

## Package Exports

The main export file (`lib/cyclic_tab_bar.dart`) exports:
- `CyclicTabController` - Controller class
- `DefaultCyclicTabController` - Convenience wrapper
- `CyclicTabBar` - Tab bar widget
- `CyclicTabBarView` - Page view widget
- Type definitions: `SelectIndexedWidgetBuilder`, `SelectIndexedTextBuilder`, `IndexedTapCallback`, `ModuloIndexedWidgetBuilder`
- Utilities: `CycledScrollController`, `calculateMoveIndexDistance`, `CycledListView`

## Spacing Feature Details

### Overview
The package supports spacing between tabs and pages through simple spacing parameters.

### Implementation Details

**Item Spacing:**
- Uses `SizedBox` widgets inserted between items
- Child count becomes `2 * itemCount - 1` when spacing > 0
- Works in both positive and negative scroll directions
- Spacing appears at wrap-around boundaries (between last and first item)
- Does NOT affect individual item sizes - spacing is added between items
- This ensures indicator positioning and size calculations remain accurate

**Tab Spacing (`CyclicTabBar.tabSpacing`):**
- Horizontal spacing between tabs in pixels
- Added as separate `SizedBox` widgets between tabs
- Tab size calculations automatically account for spacing
- Useful for creating visual separation without affecting tab dimensions

**Page Spacing (`CyclicTabBarView.pageSpacing`):**
- Horizontal spacing between pages in pixels
- Useful for creating "peek" effects where adjacent pages are partially visible
- Does not affect page swipe physics

### Benefits of Spacing Approach
- Simple API - just provide a number
- No need to specify separator width separately
- Tab/page sizes remain unchanged
- Indicator positioning works correctly
- Scroll synchronization automatically accounts for spacing

### Deprecation Notice
The `separator` parameter in `CyclicTabBar` has been deprecated in favor of `bottomBorder` to avoid confusion:
- Old: `separator: BorderSide(...)` - applies bottom border to tab bar
- New: `bottomBorder: BorderSide(...)` - clearer naming
- The old parameter still works but will be removed in a future version
