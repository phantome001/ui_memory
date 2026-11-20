import 'package:flutter/widgets.dart';

import 'memory_scope.dart';

/// A scrollable whose offset is remembered across rebuilds and restarts.
///
/// The controller is created with the remembered offset and the value is
/// clamped once the content is laid out, so a shorter list cannot restore an
/// impossible position. Every scroll updates the [MemoryScope] controller,
/// which writes the value after its debounce.
///
/// ```dart
/// RememberedScroll(
///   memoryKey: 'feed',
///   builder: (context, controller) => ListView.builder(
///     controller: controller,
///     itemCount: messages.length,
///     itemBuilder: (_, i) => ListTile(title: Text(messages[i].title)),
///   ),
/// )
/// ```
class RememberedScroll extends StatefulWidget {
  /// Creates a remembered scrollable stored under [memoryKey].
  const RememberedScroll({
    super.key,
    required this.memoryKey,
    required this.builder,
  }) : assert(memoryKey != '', 'A memory key cannot be empty');

  /// Key under which the offset is saved. Must be stable across versions.
  final String memoryKey;

  /// Builds the scrollable with the managed [ScrollController].
  final Widget Function(BuildContext context, ScrollController controller)
  builder;

  @override
  State<RememberedScroll> createState() => _RememberedScrollState();
}

class _RememberedScrollState extends State<RememberedScroll> {
  late ScrollController _controller;
  double? _offset;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    _offset = MemoryScope.maybeOf(context)?.read<double>(widget.memoryKey);
    _controller = ScrollController(initialScrollOffset: _offset ?? 0);
    _controller.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreOffset());
  }

  void _handleScroll() {
    if (_restoring || !mounted) {
      return;
    }
    final offset = _controller.offset;
    _offset = offset;
    MemoryScope.maybeOf(context)?.remember(widget.memoryKey, offset);
  }

  void _restoreOffset() {
    final offset = _offset;
    if (offset == null || !_controller.hasClients) {
      return;
    }
    _restoring = true;
    final max = _controller.position.maxScrollExtent;
    final target = offset.clamp(0.0, max).toDouble();
    if ((_controller.offset - target).abs() > 1) {
      _controller.jumpTo(target);
    }
    _restoring = false;
  }

  @override
  void didUpdateWidget(RememberedScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.memoryKey != widget.memoryKey) {
      _offset = MemoryScope.maybeOf(context)?.read<double>(widget.memoryKey);
      WidgetsBinding.instance.addPostFrameCallback((_) => _restoreOffset());
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleScroll);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _controller);
  }
}
