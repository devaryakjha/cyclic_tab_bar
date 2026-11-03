# cyclic_tab_bar

A source-synced Flutter Material tab bar with cyclic edge scrolling and
fixed-width indicator support.

`CyclicTabBar` starts from Flutter's `TabBar` implementation, so it keeps the
normal Material tab API while adding package-owned behavior where Flutter does
not expose an extension point.

## Features

- `CyclicTabBar` extends a scrollable tab strip past either edge so users can
  pull the next cycle into view.
- `indicatorFixedWidth` keeps the selected indicator at a stable width without
  overflowing narrow tabs.
- `CyclicTabBarView` mirrors Flutter's `TabBarView` API for pairing tab labels
  with pages.

A deliberate pull past either edge wraps the strip once: the next cycle's
tabs are pulled into view, and when you let go the strip settles onto them
at its start (or end) and becomes a plain strip with edges again. Flings
and fast swipes only stretch and spring back. Rebuilding with an equivalent `tabs`
list (new `Tab` widgets, same count) never resets or moves the strip, so
labels can update freely; a width change keeps the selected tab in place.

`CyclicTabBarView` does not loop content pages by default. Pass `loop: true`
to let a swipe past the last page continue to the first and vice versa; a
paired `CyclicTabBar` follows the wrap. Pages that cannot be built twice
(a `GlobalKey`, a single-instance controller) need `loopSentinelBuilder`.

## Install

```yaml
dependencies:
  cyclic_tab_bar: ^1.0.4
```

## Usage

```dart
DefaultTabController(
  length: 4,
  child: Column(
    children: [
      const CyclicTabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorFixedWidth: 64,
        tabs: [
          Tab(text: 'Overview'),
          Tab(text: 'Metrics'),
          Tab(text: 'Alerts'),
          Tab(text: 'Profile'),
        ],
      ),
      const Expanded(
        child: CyclicTabBarView(
          children: [
            Center(child: Text('Overview view')),
            Center(child: Text('Metrics view')),
            Center(child: Text('Alerts view')),
            Center(child: Text('Profile view')),
          ],
        ),
      ),
    ],
  ),
)
```

## Fixed Indicator Width

Use `indicatorFixedWidth` when the selected indicator should have a stable
width independent from the tab width:

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
`indicatorPadding` is applied. Set `indicatorSize` to
`TabBarIndicatorSize.tab` or `TabBarIndicatorSize.label` depending on which
bounds the fixed width should use.

## Source Sync

The vendored implementation is synced from Flutter `3.41.7`
`packages/flutter/lib/src/material/tabs.dart`, with the public widget names
renamed to `CyclicTabBar` and `CyclicTabBarView`.

Run checks before publishing:

```sh
flutter analyze
flutter test
flutter pub publish --dry-run
```
