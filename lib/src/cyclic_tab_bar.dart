import 'package:flutter/material.dart';

/// A type of callback to build [Widget] on specified index.
typedef SelectIndexedWidgetBuilder = Widget Function(
    BuildContext context, int index, bool isSelected);

/// A type of callback to build [Text] Widget on specified index.
typedef SelectIndexedTextBuilder = Text Function(int index, bool isSelected);

/// A type of callback to execute processing on tapped tab.
typedef IndexedTapCallback = void Function(int index);
