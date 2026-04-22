# cyclic_tab_bar

A lightweight Flutter package for building tab bars with previous and next
controls that wrap around cyclically.

## Getting Started

Add the package to your app:

```yaml
dependencies:
  cyclic_tab_bar:
    path: ../cyclic_tab_bar
```

## Usage

```dart
CyclicTabBar(
  labels: const ['Overview', 'Metrics', 'Alerts'],
  currentIndex: currentIndex,
  onIndexChanged: (index) {
    setState(() {
      currentIndex = index;
    });
  },
)
```

The repository also includes a runnable example app in `example/`.
