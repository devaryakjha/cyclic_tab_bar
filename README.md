# cyclic_tab_bar

A Flutter package that starts from a source-level copy of Flutter's
`TabBar` and `TabBarView`, exposed as `CyclicTabBar` and
`CyclicTabBarView`.

The current baseline intentionally matches Flutter's behavior exactly.
Infinite/cyclic behavior comes in a later step.

## Getting Started

Add the package to your app:

```yaml
dependencies:
  cyclic_tab_bar:
    path: ../cyclic_tab_bar
```

## Usage

```dart
DefaultTabController(
  length: 3,
  child: Column(
    children: [
      const CyclicTabBar(
        tabs: [
          Tab(text: 'Overview'),
          Tab(text: 'Metrics'),
          Tab(text: 'Alerts'),
        ],
      ),
      const Expanded(
        child: CyclicTabBarView(
          children: [
            Center(child: Text('Overview view')),
            Center(child: Text('Metrics view')),
            Center(child: Text('Alerts view')),
          ],
        ),
      ),
    ],
  ),
)
```

## Source Sync

The vendored implementation is synced from Flutter `3.41.7`
`packages/flutter/lib/src/material/tabs.dart`, with the public widget names
renamed to `CyclicTabBar` and `CyclicTabBarView`.

The repository also includes a runnable example app in `example/`.

## Fixed Indicator Width

Use `indicatorFixedWidth` when the selected indicator should have a stable
width that is independent from the tab width:

```dart
CyclicTabBar(
  isScrollable: true,
  indicatorSize: TabBarIndicatorSize.tab,
  indicatorFixedWidth: 64,
  indicatorFixedWidthAlignment: Alignment.center,
  indicator: const UnderlineTabIndicator(),
  tabs: const [
    Tab(text: 'Overview'),
    Tab(text: 'Metrics'),
    Tab(text: 'Alerts'),
  ],
)
```

The fixed width is clamped to the available tab or label bounds after
`indicatorPadding` is applied, so narrow tabs keep the indicator inside their
available space. The same sizing logic also applies to custom `indicator`
decorations. Set `indicatorSize` to `TabBarIndicatorSize.tab` or
`TabBarIndicatorSize.label` depending on which bounds the fixed width should
use.
