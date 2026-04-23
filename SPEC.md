# cyclic_tab_bar Spec

## Goal

Create `CyclicTabBar` and `CyclicTabBarView` by copying Flutter's upstream
`TabBar` and `TabBarView` source into this package rather than extending the
framework widgets.

## Scope

- Vendor the relevant implementation from Flutter `3.41.7`
  (`packages/flutter/lib/src/material/tabs.dart`).
- Rename only the two public widgets to `CyclicTabBar` and
  `CyclicTabBarView`.
- Keep Flutter behavior unless a package-specific extension is documented here.
- Add optional fixed-width indicator sizing with configurable horizontal
  alignment for `CyclicTabBar`.
- Clamp fixed-width indicators to the available tab or label width after
  `indicatorPadding` is applied so narrow tabs do not overflow.
- Apply the fixed-width indicator behavior to both the default underline
  indicator and custom `Decoration` indicators.
- Update the example and tests to use the vendored widgets.

## Acceptance Criteria

- The package exports `CyclicTabBar` and `CyclicTabBarView`.
- The implementation is copied from Flutter source, not implemented by
  subclassing `TabBar` or `TabBarView`.
- `example/` demonstrates the vendored widgets with a shared
  `DefaultTabController`.
- `CyclicTabBar` exposes `indicatorFixedWidth` and
  `indicatorFixedWidthAlignment`.
- When `indicatorFixedWidth` is set, the painted indicator width is
  `min(indicatorFixedWidth, availableIndicatorWidth)` and the remaining space
  is distributed according to `indicatorFixedWidthAlignment`.
