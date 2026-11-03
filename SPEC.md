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
- For scrollable tab bars, pulling past either edge extends the tab strip
  cyclically without requiring a long stretch.
- The stretch of a touch drag is the finger's own travel past the edge, up
  to 128 px, on both physics, so a wrap takes the same pull everywhere
  (about 80 px beyond the touch slop). Only a deliberate pull commits it: a
  drag frame past the threshold whose finger moves no faster than 500 px/s,
  or a lift (not a cancelled drag) no faster than 500 px/s with the stretch
  past the threshold. A trackpad overscroll commits through the pointer
  thresholds (steeper curve, 84 px, visible on a previous frame). Fling
  frames after a touch drag, and fast swipes, only stretch and spring back;
  after the finger leaves under bouncing physics the stretch retreats in
  step with the bounce. Under bouncing physics the strip moves with the
  viewport's own overscroll only; the preview fills that gap, flush against
  the strip's end.
- A commit lays out two copies of the tabs for the duration of one wrap
  (the original cycle followed by the next, or the previous followed by the
  original) and moves the scroll position so the picture does not change.
  Edge pulls are not interpreted while two copies are shown. Every idle
  transition of the strip's scroll position settles the wrap: if the
  viewport already shows what the normal strip can show (it lies inside one
  copy's tabs, or in the padding beyond the strip's ends), the strip
  collapses to the single strip in place, invisibly. Otherwise it first
  eases (`kTabScrollDuration`, `Curves.ease`): after a pull whose selection
  has not changed since, onto the wrapped-to copy with its edge tab flush
  against the viewport edge (the tabs the user pulled in), and once
  collapsed there eases on (150 ms) to the strip's start or end, so the
  pulled-in tabs sit where they do when the screen opens, padding showing;
  after the page view changed the selection, or drove the wrap itself, to
  the nearest such position inside the copy that holds the copy of the
  selected tab nearest the viewport, so the selected tab stays in view. A
  wrap committed during a drag eases to rest the same way on any release
  instead of coasting. The collapse follows when the animation ends.
  A change in the number of tabs during that animation stops it in place.
  The strip therefore always returns to a single strip with real edges, and
  the next wrap takes another deliberate pull.
- A strip whose single cycle is no wider than the viewport never wraps.
- Rebuilding `CyclicTabBar` with a `tabs` list of the same length never
  resets cyclic state or moves the strip. A change in the number of tabs
  resets it. A change in tab widths keeps the selected tab anchored on
  screen when it was visible and the strip is at rest.
- Scroll targets (controller sync, tab taps, initial offset) use the rendered
  copy of a tab nearest the viewport; a tap on a specific copy scrolls to
  that copy.
- `CyclicTabBarView` optionally loops pages when `loop` is true, by scrolling
  through a sentinel copy of the first or last page and jumping to the real
  page once the scroll settles. The shared `TabController` keeps its normal
  `0..length - 1` index range; its animation value may briefly pass outside
  that range during the wrap, and the strip's indicator and label styles
  follow it off the end toward the wrapped-to tab. A paired scrollable
  `CyclicTabBar` that overflows its viewport extends itself for a swiped
  wrap and settles like a pulled one. Pages that cannot be built twice
  supply `loopSentinelBuilder`.
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
- Pulling roughly half of the maximum cyclic stretch past either edge commits
  the cyclic extension.
