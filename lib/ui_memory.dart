/// Remember Flutter UI state across rebuilds and app restarts.
///
/// Wrap a screen in a [MemoryHost] and replace plain controllers with the
/// remembered variants:
///
/// ```dart
/// MemoryHost(
///   controller: UiMemoryController(id: 'feed', store: store),
///   builder: (context) => RememberedScroll(
///     memoryKey: 'feed_list',
///     builder: (context, controller) => ListView.builder(
///       controller: controller,
///       itemCount: 100,
///       itemBuilder: (_, i) => ListTile(title: Text('Item $i')),
///     ),
///   ),
/// )
/// ```
///
/// See `package:ui_memory/io.dart` for the file based store.
library;

export 'src/memory_controller.dart';
export 'src/memory_host.dart';
export 'src/memory_scope.dart';
export 'src/memory_snapshot.dart';
export 'src/memory_store.dart';
export 'src/remembered_expansion.dart';
export 'src/remembered_pages.dart';
export 'src/remembered_scroll.dart';
export 'src/remembered_tabs.dart';
