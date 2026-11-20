// Flutter 3.47 moved the Material widgets to package:material_ui. This package
// also supports older SDKs, where this is still the only import available.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui_memory/ui_memory.dart';

UiMemoryController _controller(InMemoryMemoryStore store) => UiMemoryController(
  id: 'screen',
  store: store,
  debounce: const Duration(milliseconds: 10),
);

Widget _scrollApp(
  UiMemoryController memory,
  String phase,
  void Function(ScrollController) onController,
) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: 200,
        child: MemoryHost(
          key: ValueKey<String>(phase),
          controller: memory,
          builder: (BuildContext context) => RememberedScroll(
            memoryKey: 'feed',
            builder: (BuildContext context, ScrollController controller) {
              onController(controller);
              return ListView.builder(
                controller: controller,
                itemExtent: 50,
                itemCount: 100,
                itemBuilder: (_, int i) => Text('Item $i'),
              );
            },
          ),
        ),
      ),
    ),
  );
}

Widget _tabsApp(
  UiMemoryController memory,
  String phase,
  void Function(TabController) onController,
) {
  return MaterialApp(
    home: Scaffold(
      body: MemoryHost(
        key: ValueKey<String>(phase),
        controller: memory,
        builder: (BuildContext context) => RememberedTabs(
          memoryKey: 'tab',
          length: 3,
          builder: (BuildContext context, TabController controller) {
            onController(controller);
            return Column(
              children: <Widget>[
                TabBar(
                  controller: controller,
                  tabs: const <Widget>[
                    Tab(text: 'A'),
                    Tab(text: 'B'),
                    Tab(text: 'C'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: controller,
                    children: const <Widget>[
                      Center(child: Text('A page')),
                      Center(child: Text('B page')),
                      Center(child: Text('C page')),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

Widget _pagesApp(
  UiMemoryController memory,
  String phase,
  void Function(PageController) onController,
) {
  return MaterialApp(
    home: Scaffold(
      body: MemoryHost(
        key: ValueKey<String>(phase),
        controller: memory,
        builder: (BuildContext context) => RememberedPages(
          memoryKey: 'page',
          pageCount: 3,
          builder: (BuildContext context, PageController controller) {
            onController(controller);
            return PageView(
              controller: controller,
              children: const <Widget>[
                Center(child: Text('Page 0')),
                Center(child: Text('Page 1')),
                Center(child: Text('Page 2')),
              ],
            );
          },
        ),
      ),
    ),
  );
}

Widget _expansionApp(UiMemoryController memory, String phase) {
  return MaterialApp(
    home: Scaffold(
      body: MemoryHost(
        key: ValueKey<String>(phase),
        controller: memory,
        builder: (BuildContext context) => RememberedExpansion(
          memoryKey: 'advanced',
          builder: (BuildContext context, bool expanded, VoidCallback toggle) =>
              TextButton(
                onPressed: toggle,
                child: Text(expanded ? 'Expanded' : 'Collapsed'),
              ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('restores the scroll offset after a restart', (
    WidgetTester tester,
  ) async {
    final store = InMemoryMemoryStore();
    final first = _controller(store);
    ScrollController? firstController;

    await tester.pumpWidget(
      _scrollApp(first, 'first', (c) => firstController = c),
    );
    await tester.pumpAndSettle();

    firstController!.jumpTo(700);
    await tester.pumpAndSettle();
    await first.flush();

    expect(store.snapshots, isNotEmpty);

    final second = _controller(store);
    ScrollController? secondController;
    await tester.pumpWidget(
      _scrollApp(second, 'second', (c) => secondController = c),
    );
    await tester.pumpAndSettle();

    expect(secondController!.offset, greaterThan(650));
  });

  testWidgets('clamps a restored scroll offset to the new content', (
    WidgetTester tester,
  ) async {
    final store = InMemoryMemoryStore();
    final writer = _controller(store);
    writer.remember('feed', 5000.0);
    await writer.flush();

    final reader = _controller(store);
    ScrollController? controller;
    await tester.pumpWidget(_scrollApp(reader, 'short', (c) => controller = c));
    await tester.pumpAndSettle();

    // 100 items of 50 pixels in a 200 pixel viewport: max extent is 4800.
    expect(controller!.offset, inInclusiveRange(4700.0, 4800.0));
  });

  testWidgets('restores the selected tab', (WidgetTester tester) async {
    final store = InMemoryMemoryStore();
    final first = _controller(store);
    TabController? firstController;

    await tester.pumpWidget(
      _tabsApp(first, 'first', (c) => firstController = c),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('C'));
    await tester.pumpAndSettle();
    expect(firstController!.index, 2);
    await first.flush();

    final second = _controller(store);
    TabController? secondController;
    await tester.pumpWidget(
      _tabsApp(second, 'second', (c) => secondController = c),
    );
    await tester.pumpAndSettle();

    expect(secondController!.index, 2);
  });

  testWidgets('restores the current page', (WidgetTester tester) async {
    final store = InMemoryMemoryStore();
    final first = _controller(store);
    PageController? firstController;

    await tester.pumpWidget(
      _pagesApp(first, 'first', (c) => firstController = c),
    );
    await tester.pumpAndSettle();

    firstController!.jumpToPage(2);
    await tester.pumpAndSettle();
    await first.flush();

    final second = _controller(store);
    PageController? secondController;
    await tester.pumpWidget(
      _pagesApp(second, 'second', (c) => secondController = c),
    );
    await tester.pumpAndSettle();

    expect(secondController!.initialPage, 2);
  });

  testWidgets('restores an expanded section', (WidgetTester tester) async {
    final store = InMemoryMemoryStore();
    final first = _controller(store);

    await tester.pumpWidget(_expansionApp(first, 'first'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Collapsed'));
    await tester.pumpAndSettle();
    expect(find.text('Expanded'), findsOneWidget);
    await first.flush();

    final second = _controller(store);
    await tester.pumpWidget(_expansionApp(second, 'second'));
    await tester.pumpAndSettle();

    expect(find.text('Expanded'), findsOneWidget);
    expect(find.text('Collapsed'), findsNothing);
  });

  testWidgets('applies initialExpanded when nothing was remembered', (
    WidgetTester tester,
  ) async {
    final store = InMemoryMemoryStore();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MemoryHost(
            controller: _controller(store),
            builder: (BuildContext context) => RememberedExpansion(
              memoryKey: 'advanced',
              initialExpanded: true,
              builder:
                  (BuildContext context, bool expanded, VoidCallback toggle) =>
                      Text(expanded ? 'Expanded' : 'Collapsed'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Expanded'), findsOneWidget);
  });

  testWidgets('does not save anything for an untouched screen', (
    WidgetTester tester,
  ) async {
    final store = InMemoryMemoryStore();
    await tester.pumpWidget(_expansionApp(_controller(store), 'first'));
    await tester.pumpAndSettle();
    expect(store.snapshots, isEmpty);
  });

  testWidgets('flushes a pending write when the app is backgrounded', (
    WidgetTester tester,
  ) async {
    final store = InMemoryMemoryStore();
    final memory = UiMemoryController(
      id: 'screen',
      store: store,
      debounce: const Duration(minutes: 1),
    );

    await tester.pumpWidget(_expansionApp(memory, 'first'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Collapsed'));
    await tester.pumpAndSettle();

    expect(store.snapshots, isEmpty);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();

    expect(store.snapshots, isNotEmpty);
  });

  testWidgets('reports the restored snapshot exactly once', (
    WidgetTester tester,
  ) async {
    final snapshot = MemorySnapshot(
      values: const <String, Object?>{'advanced': true},
      savedAt: DateTime.utc(2026, 11, 20),
    );
    final store = InMemoryMemoryStore(<String, String>{
      'screen': snapshot.encode(),
    });
    final restored = <MemorySnapshot?>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MemoryHost(
            controller: _controller(store),
            onRestored: restored.add,
            builder: (BuildContext context) => const Text('Ready'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(restored, hasLength(1));
    expect(restored.single?.values['advanced'], isTrue);
  });

  testWidgets('shows the loading builder while restoring', (
    WidgetTester tester,
  ) async {
    final store = InMemoryMemoryStore();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MemoryHost(
            controller: _controller(store),
            loadingBuilder: (BuildContext context) =>
                const Center(child: CircularProgressIndicator()),
            builder: (BuildContext context) => const Text('Ready'),
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Ready'), findsOneWidget);
  });

  testWidgets('discard prevents the state from coming back', (
    WidgetTester tester,
  ) async {
    final store = InMemoryMemoryStore();
    final first = _controller(store);

    await tester.pumpWidget(_expansionApp(first, 'first'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Collapsed'));
    await tester.pumpAndSettle();
    await first.flush();
    await first.discard();

    final second = _controller(store);
    await tester.pumpWidget(_expansionApp(second, 'second'));
    await tester.pumpAndSettle();

    expect(find.text('Collapsed'), findsOneWidget);
  });
}
