import 'package:flutter/material.dart';

/// A type of callback to build [Widget] on specified index.
typedef SelectIndexedWidgetBuilder = Widget Function(
    BuildContext context, int index, bool isSelected);

/// A type of callback to build tab widgets for a specified index.
typedef SelectIndexedTabBuilder = Widget Function(int index, bool isSelected);

/// A type of callback to execute processing on tapped tab.
typedef IndexedTapCallback = void Function(int index);
