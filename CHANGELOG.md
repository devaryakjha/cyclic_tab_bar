## 1.0.4 - 2026-07-09

* Add package metadata and GitHub Actions release automation.
* Update README copy to describe cyclic tab-strip behavior accurately.
* Respect `enableFeedback: false` when cyclic edge scrolling commits.
* Give `CyclicTabBarView` the tab bar's heavy haptic when a swipe wraps
  around with `loop: true`; turn it off with its new `enableFeedback`.
* Exclude duplicated cyclic edge tabs from semantics while keeping them visible.
* Fix the edge stretch and a committed cyclic extension vanishing when the
  parent rebuilds with an equivalent `tabs` list (fresh `Tab` widgets with
  the same count). Cyclic state now only resets when the number of tabs
  changes; tab width changes keep the selected tab anchored on screen
  instead of re-centering the strip.
* Fix the cyclic extension getting stuck with its edge pulls ignored. A
  committed wrap now always comes to rest: once the user lets go and the
  strip is still, it collapses in place when the viewport already shows a
  single cycle, and otherwise eases onto the tabs the user pulled in and on
  to the strip's start or end, padding showing (or, once a paired page view
  has moved the selection, the shortest way into the copy that keeps the
  selected tab in view) and then returns to the plain single strip, edges
  included, so the next wrap takes another deliberate pull. Works under bouncing and clamping physics, with strip
  padding, in RTL, and when the viewport straddles the seam.
* Only a deliberate pull commits a wrap: a slow drag frame or a gentle
  lift past the threshold. Fast swipes and flings, including the fling
  frames after a touch drag, only stretch and spring back; trackpad
  overscroll keeps its deeper pointer threshold. The stretch is the
  finger's own travel past the edge, so a wrap takes the same pull under
  bouncing physics as under clamping physics.
* Fix the committed extension jumping the strip by a frame's worth of drag,
  and ending a drag or fling that is still in progress.
* Under bouncing physics the strip now moves with the viewport's own
  overscroll only, with the next cycle's preview filling the gap flush
  against its end, instead of running ahead of the finger; the stretch
  curve and commit thresholds are unchanged.
* Keep the strip in step with a paired `TabBarView` while a wrap is in
  flight: scroll targets use the copy of the selected tab nearest the
  viewport, and collapsing the strip mid-swipe is invisible.
* Refuse to wrap a strip whose single cycle is no wider than the viewport.
* Add opt-in page looping to `CyclicTabBarView` via `loop: true` (with
  `loopSentinelBuilder` for pages that cannot be built twice): swiping past
  the last page continues to the first and vice versa, the indicator and
  label styles follow the wrap, and a paired overflowing `CyclicTabBar`
  extends itself for it. Off by default.
* Fix a paired `CyclicTabBar` moving back and forth while a looping
  `CyclicTabBarView` swipe is held across the wrap: the extended strip now
  waits for the page to come back within the first and last tab before it
  settles, and settles as soon as a wrapping swipe lands.
* Fix a looping page swipe across the wrap leaving a padded strip's first
  or last tab a padding's width past its edge: the extended strip now aims
  where the plain strip shows the tab, padding included, and collapses in
  place there.
* Point package metadata at github.com/devaryakjha/cyclic_tab_bar.
