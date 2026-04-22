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
