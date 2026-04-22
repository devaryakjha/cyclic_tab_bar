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
- Keep behavior identical to Flutter's widgets for this first step.
- Update the example and tests to use the vendored widgets.

## Acceptance Criteria

- The package exports `CyclicTabBar` and `CyclicTabBarView`.
- The implementation is copied from Flutter source, not implemented by
  subclassing `TabBar` or `TabBarView`.
- The first package version does not add infinite/cyclic behavior yet.
- `example/` demonstrates the vendored widgets with a shared
  `DefaultTabController`.
