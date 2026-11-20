import 'package:flutter/widgets.dart';

import 'memory_scope.dart';

/// A boolean flag that remembers whether a section was expanded.
///
/// Useful for expansion tiles, accordions, collapsible filters and any other
/// piece of UI that the user expects to stay the same when they come back.
///
/// ```dart
/// RememberedExpansion(
///   memoryKey: 'advanced_filters',
///   initialExpanded: false,
///   builder: (context, expanded, toggle) => ExpansionTile(
///     title: const Text('Advanced'),
///     initiallyExpanded: expanded,
///     onExpansionChanged: (_) => toggle(),
///   ),
/// )
/// ```
class RememberedExpansion extends StatefulWidget {
  /// Creates a remembered expansion flag.
  const RememberedExpansion({
    super.key,
    required this.memoryKey,
    this.initialExpanded = false,
    required this.builder,
  }) : assert(memoryKey != '', 'A memory key cannot be empty');

  /// Key under which the flag is saved.
  final String memoryKey;

  /// Value used when nothing was remembered.
  final bool initialExpanded;

  /// Builds the section with the current value and a toggle callback.
  final Widget Function(
    BuildContext context,
    bool expanded,
    VoidCallback toggle,
  )
  builder;

  @override
  State<RememberedExpansion> createState() => _RememberedExpansionState();
}

class _RememberedExpansionState extends State<RememberedExpansion> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded =
        MemoryScope.maybeOf(context)?.read<bool>(widget.memoryKey) ??
        widget.initialExpanded;
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    MemoryScope.maybeOf(context)?.remember(widget.memoryKey, _expanded);
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _expanded, _toggle);
  }
}
