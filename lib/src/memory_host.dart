import 'dart:async';

import 'package:flutter/widgets.dart';

import 'memory_controller.dart';
import 'memory_scope.dart';
import 'memory_snapshot.dart';

/// Restores remembered UI state before building a screen and keeps it saved.
///
/// Widgets such as [RememberedScroll] and [RememberedTabs] read their initial
/// values from the nearest [MemoryScope]. [MemoryHost] waits for
/// [UiMemoryController.restore] before building [builder], so those widgets are
/// created with the right state from the start and do not jump after the first
/// frame.
///
/// A pending write is flushed when the app goes to the background, which is
/// the moment the operating system may kill it.
///
/// ```dart
/// MemoryHost(
///   controller: memory,
///   builder: (context) => RememberedScroll(
///     memoryKey: 'feed',
///     builder: (context, controller) => ListView.builder(
///       controller: controller,
///       itemCount: 100,
///       itemBuilder: (_, i) => ListTile(title: Text('Item $i')),
///     ),
///   ),
/// )
/// ```
class MemoryHost extends StatefulWidget {
  /// Creates a host backed by [controller].
  const MemoryHost({
    super.key,
    required this.controller,
    required this.builder,
    this.restoreOnStart = true,
    this.onRestored,
    this.loadingBuilder,
  });

  /// The controller holding the remembered state of this screen.
  final UiMemoryController controller;

  /// Builds the screen after the restore completed.
  final WidgetBuilder builder;

  /// Whether to restore before the first build.
  ///
  /// Set it to `false` when [UiMemoryController.restore] was already called by
  /// the app, or when the user must decide whether to restore.
  final bool restoreOnStart;

  /// Called once the restore attempt completed.
  ///
  /// [snapshot] is `null` when there was nothing to restore.
  final ValueChanged<MemorySnapshot?>? onRestored;

  /// Shown while the snapshot is being read from the store.
  ///
  /// Defaults to an empty box, so the layout does not flash before the screen.
  final WidgetBuilder? loadingBuilder;

  @override
  State<MemoryHost> createState() => _MemoryHostState();
}

class _MemoryHostState extends State<MemoryHost> with WidgetsBindingObserver {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_prepare());
  }

  Future<void> _prepare() async {
    MemorySnapshot? restored;
    try {
      if (widget.restoreOnStart) {
        restored = await widget.controller.restore();
      }
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'ui_memory',
          context: ErrorDescription('while restoring remembered UI state'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _ready = true);
        widget.onRestored?.call(restored);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        unawaited(widget.controller.flush());
      case AppLifecycleState.resumed:
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return widget.loadingBuilder?.call(context) ?? const SizedBox.shrink();
    }
    return MemoryScope(
      controller: widget.controller,
      child: Builder(builder: widget.builder),
    );
  }
}
