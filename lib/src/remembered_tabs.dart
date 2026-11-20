// TabController lives in the Material library. Import just that symbol; the
// library import is ignored because Flutter 3.47 moved Material widgets out of
// package:flutter while older SDKs still need this import.
// ignore: deprecated_member_use
import 'package:flutter/material.dart' show TabController;
import 'package:flutter/widgets.dart';

import 'memory_scope.dart';

/// A [TabController] whose selected index is remembered.
///
/// Build the `TabBar` and `TabBarView` with the controller given to [builder].
/// The remembered index is clamped to the current number of tabs, so adding or
/// removing a tab cannot crash the restore.
///
/// ```dart
/// RememberedTabs(
///   memoryKey: 'profile_tab',
///   length: 3,
///   builder: (context, controller) => Column(
///     children: [
///       TabBar(controller: controller, tabs: [...]),
///       Expanded(
///         child: TabBarView(controller: controller, children: [...]),
///       ),
///     ],
///   ),
/// )
/// ```
class RememberedTabs extends StatefulWidget {
  /// Creates a remembered tab controller with [length] tabs.
  const RememberedTabs({
    super.key,
    required this.memoryKey,
    required this.length,
    required this.builder,
  }) : assert(memoryKey != '', 'A memory key cannot be empty'),
       assert(length > 0, 'There must be at least one tab');

  /// Key under which the index is saved.
  final String memoryKey;

  /// Number of tabs.
  final int length;

  /// Builds the tab bar and view with the managed [TabController].
  final Widget Function(BuildContext context, TabController controller) builder;

  @override
  State<RememberedTabs> createState() => _RememberedTabsState();
}

class _RememberedTabsState extends State<RememberedTabs>
    with SingleTickerProviderStateMixin {
  late TabController _controller;

  int _initialIndex() {
    final stored =
        MemoryScope.maybeOf(context)?.read<int>(widget.memoryKey) ?? 0;
    if (stored < 0 || stored >= widget.length) {
      return 0;
    }
    return stored;
  }

  @override
  void initState() {
    super.initState();
    _controller = TabController(
      length: widget.length,
      initialIndex: _initialIndex(),
      vsync: this,
    );
    _controller.addListener(_handleChange);
  }

  void _handleChange() {
    if (_controller.indexIsChanging || !mounted) {
      return;
    }
    MemoryScope.maybeOf(context)?.remember(widget.memoryKey, _controller.index);
  }

  @override
  void didUpdateWidget(RememberedTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.length != widget.length) {
      _controller
        ..removeListener(_handleChange)
        ..dispose();
      _controller = TabController(
        length: widget.length,
        initialIndex: _initialIndex().clamp(0, widget.length - 1),
        vsync: this,
      );
      _controller.addListener(_handleChange);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleChange);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _controller);
  }
}
