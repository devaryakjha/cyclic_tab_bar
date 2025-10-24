# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter package that provides an infinitely scrollable tab view component. The package is published on pub.dev as `infinite_scroll_tab_view`.

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

### Core Components

**InfiniteScrollTabView** (`lib/src/infinite_scroll_tab_view.dart`)
- Public-facing widget that developers use
- Wraps MediaQuery context data and passes it to InnerInfiniteScrollTabView
- Main configuration point with properties for tab/page builders, styling, callbacks

**InnerInfiniteScrollTabView** (`lib/src/inner_infinite_scroll_tab_view.dart`)
- Stateful implementation handling scroll synchronization
- Manages two `CycledScrollController` instances (one for tabs, one for pages)
- Calculates tab sizes dynamically using `TextPainter` to measure text dimensions
- Implements bidirectional scroll synchronization between tabs and pages
- Uses `Tween` objects to map page scroll positions to tab positions
- Handles animated indicator that follows selected tab
- Key function: `calculateMoveIndexDistance` determines shortest path when wrapping around content bounds

**CycledListView** (`lib/src/cycled_list_view.dart`)
- Custom ListView with infinite scroll bounds (`double.negativeInfinity` to `double.infinity`)
- Uses custom `CycledScrollController` and `_InfiniteScrollPosition`
- Renders items in both positive and negative directions from center
- Modulo arithmetic maps infinite index space to finite content: `index % contentCount`

### Scroll Synchronization Strategy

The widget maintains synchronization between tab and page scrolling through:
1. Tab sizes are pre-calculated on initialization and stored in arrays (`_tabTextSizes`, `_tabSizesFromIndex`)
2. `_tabOffsets` Tweens map page scroll progress to corresponding tab scroll positions
3. Page controller listener updates tab position in real-time during page swipes
4. Tab tap triggers animated scrolling of both controllers with state flags to prevent feedback loops
5. `_isContentChangingByTab` flag prevents page listener from interfering during tab-initiated navigation

### Index Management

- **Raw Index**: Actual index in the infinite scroll range (can be negative or very large)
- **Mod Index**: `rawIndex % contentLength` - maps to actual content array
- Both indices passed to builder callbacks for flexibility

## Testing Notes

Tests verify:
- `calculateMoveIndexDistance` correctly handles wrapping in both directions
- Tab sizing calculations work correctly on initialization
- Dynamic recalculation when `TextScaler` changes

When testing, access internal state via:
```dart
final InnerInfiniteScrollTabViewState state =
    tester.state(find.byType(InnerInfiniteScrollTabView));
```

## Development Guidelines

- The package uses null safety (SDK: ">=2.12.0 <3.0.0")
- Uses modern Flutter APIs: `TextScaler` instead of deprecated `textScaleFactor`, `MediaQuery.sizeOf()` instead of `MediaQuery.of().size`
- Annotate internal widgets/classes with `@visibleForTesting` when needed for unit tests
- Tab builders must return `Text` widgets (enforced by `SelectIndexedTextBuilder` type)
- Page builders can return any widget (uses `SelectIndexedWidgetBuilder`)
