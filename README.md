# 📜 cyclic_tab_bar

[![pub package](https://img.shields.io/pub/v/cyclic_tab_bar.svg)](https://pub.dev/packages/cyclic_tab_bar)

A Flutter package for a cyclic tab bar with infinite scrolling, providing separated tab bar and tab bar view components similar to Flutter's official TabBar API.

<p align="center">
    <image src="https://raw.githubusercontent.com/wiki/cb-cloud/flutter_infinite_scroll_tab_view/assets/doc/top.gif"/>
</p>

## ✨ Features

- **Separated Components**: Use `CyclicTabBar` and `CyclicTabBarView` independently for flexible layouts
- **Custom Decorations**: Wrap the tab bar with any decoration (gradients, shadows, etc.)
- **Infinite Scrolling**: Seamlessly scroll through tabs and pages with wraparound support
- **Controller-based**: Coordinate multiple components with `CyclicTabController`
- **Programmatic Control**: Navigate to any tab index programmatically
- **Customizable**: Extensive styling options for tabs, indicators, and animations

## ✍️ Usage

### Basic Example

```dart
import 'package:cyclic_tab_bar/cyclic_tab_bar.dart';

DefaultCyclicTabController(
  contentLength: 10,
  child: Column(
    children: [
      CyclicTabBar(
        contentLength: 10,
        tabBuilder: (index, isSelected) => Text(
          'Tab $index',
          style: TextStyle(
            color: isSelected ? Colors.pink : Colors.black54,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      Expanded(
        child: CyclicTabBarView(
          contentLength: 10,
          pageBuilder: (context, index, isSelected) => Center(
            child: Text('Page $index'),
          ),
        ),
      ),
    ],
  ),
)
```

### Custom Tab Bar Decoration

One of the key benefits of the separated architecture is the ability to wrap the tab bar with custom decorations:

```dart
DefaultCyclicTabController(
  contentLength: 10,
  child: Column(
    children: [
      // Wrap tab bar with custom decoration
      Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade100, Colors.purple.shade100],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: CyclicTabBar(
          contentLength: 10,
          tabBuilder: (index, isSelected) => Text('Tab $index'),
          indicatorColor: Colors.pink,
          separator: BorderSide(color: Colors.black12, width: 2.0),
        ),
      ),
      Expanded(
        child: CyclicTabBarView(
          contentLength: 10,
          pageBuilder: (context, index, isSelected) => Center(
            child: Text('Page $index'),
          ),
          onPageChanged: (index) => print('Page changed to $index'),
        ),
      ),
    ],
  ),
)
```

### Using Explicit Controller

For more control, create your own `CyclicTabController`:

```dart
class MyWidget extends StatefulWidget {
  @override
  _MyWidgetState createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> with SingleTickerProviderStateMixin {
  late CyclicTabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CyclicTabController(
      contentLength: 10,
      initialIndex: 5,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CyclicTabBar(
          contentLength: 10,
          controller: _controller,
          tabBuilder: (index, isSelected) => Text('Tab $index'),
        ),
        Expanded(
          child: CyclicTabBarView(
            contentLength: 10,
            controller: _controller,
            pageBuilder: (context, index, isSelected) => Center(
              child: Text('Page $index'),
            ),
          ),
        ),
        // Programmatic control
        ElevatedButton(
          onPressed: () => _controller.animateToIndex(7),
          child: Text('Go to Tab 7'),
        ),
      ],
    );
  }
}
```

### Customization Options

#### CyclicTabBar

- `contentLength`: Number of tabs
- `tabBuilder`: Builder function for tab widgets (must return `Text`)
- `controller`: Optional `CyclicTabController`
- `onTabTap`: Callback when a tab is tapped
- `indicatorColor`: Color of the selection indicator
- `indicatorHeight`: Height of the indicator
- `tabHeight`: Height of the tab bar
- `tabPadding`: Horizontal padding for each tab
- `forceFixedTabWidth`: Whether to use fixed width tabs
- `fixedTabWidthFraction`: Fraction of screen width for fixed tabs
- `separator`: Border separator between tabs and content
- `backgroundColor`: Background color of the tab bar

#### CyclicTabBarView

- `contentLength`: Number of pages (must match tab bar)
- `pageBuilder`: Builder function for page widgets
- `controller`: Optional `CyclicTabController`
- `onPageChanged`: Callback when the page changes
- `scrollPhysics`: Scroll physics for the page view

#### DefaultCyclicTabController

- `contentLength`: Number of tabs/pages
- `initialIndex`: Initial selected index (default: 0)
- `animationDuration`: Duration of tab switching animations
- `child`: The widget tree that will use the controller

## 🔧 Migration from Old API

If you were using the old combined `CyclicTabBar` widget (which included both tabs and pages), you can easily migrate:

**Old API:**
```dart
CyclicTabBar(
  contentLength: 10,
  tabBuilder: (index, isSelected) => Text('Tab $index'),
  pageBuilder: (context, index, isSelected) => Text('Page $index'),
)
```

**New API:**
```dart
DefaultCyclicTabController(
  contentLength: 10,
  child: Column(
    children: [
      CyclicTabBar(
        contentLength: 10,
        tabBuilder: (index, isSelected) => Text('Tab $index'),
      ),
      Expanded(
        child: CyclicTabBarView(
          contentLength: 10,
          pageBuilder: (context, index, isSelected) => Text('Page $index'),
        ),
      ),
    ],
  ),
)
```

## 💭 Have a question?

If you have a question or found an issue, feel free to [create an issue](https://github.com/cb-cloud/flutter_infinite_scroll_tab_view/issues/new).
