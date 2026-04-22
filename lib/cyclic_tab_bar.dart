import 'package:flutter/material.dart';

/// Normalizes [index] into the valid range for a cyclic collection.
int normalizeCyclicIndex(int index, int length) {
  if (length <= 0) {
    throw ArgumentError.value(length, 'length', 'Must be greater than 0.');
  }

  final normalized = index % length;
  return normalized < 0 ? normalized + length : normalized;
}

/// A lightweight tab bar with previous and next controls that wrap indexes.
class CyclicTabBar extends StatelessWidget {
  const CyclicTabBar({
    super.key,
    required this.labels,
    required this.currentIndex,
    required this.onIndexChanged,
    this.height = 52,
    this.padding = const EdgeInsets.all(4),
  }) : assert(labels.length > 1, 'Provide at least two tabs.');

  final List<String> labels;
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;
  final double height;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = normalizeCyclicIndex(currentIndex, labels.length);
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        _CycleButton(
          icon: Icons.chevron_left_rounded,
          colorScheme: colorScheme,
          onPressed: () => onIndexChanged(
            normalizeCyclicIndex(selectedIndex - 1, labels.length),
          ),
        ),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: padding,
              child: SizedBox(
                height: height,
                child: Row(
                  children: List.generate(labels.length, (index) {
                    final isSelected = index == selectedIndex;
                    return Expanded(
                      child: _TabSegment(
                        label: labels[index],
                        isSelected: isSelected,
                        onTap: () => onIndexChanged(index),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
        _CycleButton(
          icon: Icons.chevron_right_rounded,
          colorScheme: colorScheme,
          onPressed: () => onIndexChanged(
            normalizeCyclicIndex(selectedIndex + 1, labels.length),
          ),
        ),
      ],
    );
  }
}

class _CycleButton extends StatelessWidget {
  const _CycleButton({
    required this.icon,
    required this.colorScheme,
    required this.onPressed,
  });

  final IconData icon;
  final ColorScheme colorScheme;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colorScheme.secondaryContainer,
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onPressed,
        color: colorScheme.onSecondaryContainer,
        icon: Icon(icon),
      ),
    );
  }
}

class _TabSegment extends StatelessWidget {
  const _TabSegment({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = isSelected
        ? colorScheme.primary
        : Colors.transparent;
    final foregroundColor = isSelected
        ? colorScheme.onPrimary
        : colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: Theme.of(context).textTheme.labelLarge!.copyWith(
                color: foregroundColor,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}
