import 'package:flutter/widgets.dart';

import 'memory_controller.dart';

/// Exposes a [UiMemoryController] to the remembered widgets below it.
///
/// [MemoryHost] inserts this scope. Reading it does not register a dependency:
/// each widget reads the restored values once, when it is created.
class MemoryScope extends InheritedWidget {
  /// Creates a scope providing [controller] to [child].
  const MemoryScope({
    super.key,
    required this.controller,
    required super.child,
  });

  /// The controller of the screen being built.
  final UiMemoryController controller;

  /// The closest [MemoryScope], or `null` when there is none.
  ///
  /// Safe to call from [State.initState].
  static UiMemoryController? maybeOf(BuildContext context) {
    return context.getInheritedWidgetOfExactType<MemoryScope>()?.controller;
  }

  /// The closest [MemoryScope].
  ///
  /// Throws a [FlutterError] when the widget is not inside a [MemoryHost] or a
  /// [MemoryScope].
  static UiMemoryController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(
      controller != null,
      'No MemoryScope found. Wrap the screen in a MemoryHost or a MemoryScope.',
    );
    return controller!;
  }

  @override
  bool updateShouldNotify(MemoryScope oldWidget) =>
      oldWidget.controller != controller;
}
