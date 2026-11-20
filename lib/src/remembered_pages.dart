import 'package:flutter/widgets.dart';

import 'memory_scope.dart';

/// A [PageController] whose page is remembered.
///
/// The page is saved only once a swipe/animation settles on a whole page, so a
/// partially dragged page is never persisted. The restored page is clamped to
/// [pageCount].
///
/// ```dart
/// RememberedPages(
///   memoryKey: 'onboarding',
///   pageCount: 3,
///   builder: (context, controller) => PageView(
///     controller: controller,
///     children: const [Page1(), Page2(), Page3()],
///   ),
/// )
/// ```
class RememberedPages extends StatefulWidget {
  /// Creates a remembered page controller for [pageCount] pages.
  const RememberedPages({
    super.key,
    required this.memoryKey,
    required this.pageCount,
    required this.builder,
  }) : assert(memoryKey != '', 'A memory key cannot be empty'),
       assert(pageCount > 0, 'There must be at least one page');

  /// Key under which the page index is saved.
  final String memoryKey;

  /// Total number of pages.
  final int pageCount;

  /// Builds the page view with the managed [PageController].
  final Widget Function(BuildContext context, PageController controller)
  builder;

  @override
  State<RememberedPages> createState() => _RememberedPagesState();
}

class _RememberedPagesState extends State<RememberedPages> {
  late PageController _controller;

  @override
  void initState() {
    super.initState();
    final stored =
        MemoryScope.maybeOf(context)?.read<int>(widget.memoryKey) ?? 0;
    final initial = stored < 0 || stored >= widget.pageCount ? 0 : stored;
    _controller = PageController(initialPage: initial);
    _controller.addListener(_handleChange);
  }

  void _handleChange() {
    final page = _controller.page;
    if (page == null || !mounted) {
      return;
    }
    final rounded = page.round();
    if ((page - rounded).abs() < 0.01 &&
        rounded >= 0 &&
        rounded < widget.pageCount) {
      MemoryScope.maybeOf(context)?.remember(widget.memoryKey, rounded);
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
