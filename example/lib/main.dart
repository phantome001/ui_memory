import 'dart:io';

// Flutter 3.47 moved the Material widgets to package:material_ui. This example
// also runs on older SDKs, where this is still the only import available.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:ui_memory/ui_memory.dart';
import 'package:ui_memory/ui_memory_io.dart';

void main() {
  runApp(const ExampleApp());
}

/// Shows how a screen comes back exactly where the user left it.
///
/// State is stored in a temporary directory to keep the example free of
/// plugins. In a real app, use `path_provider`:
///
/// ```dart
/// final directory = await getApplicationSupportDirectory();
/// final store = FileMemoryStore(Directory('${directory.path}/ui_state'));
/// ```
class ExampleApp extends StatelessWidget {
  /// Creates the example application.
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ui_memory example',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const DemoPage(),
    );
  }
}

/// A playground with a remembered list, tabs, pages and expansion.
class DemoPage extends StatefulWidget {
  /// Creates the demo page.
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  late final UiMemoryController _memory;
  bool _restored = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    final store = FileMemoryStore(
      Directory('${Directory.systemTemp.path}/ui_memory_example'),
    );
    _memory = UiMemoryController(
      id: 'playground',
      store: store,
      maxAge: const Duration(days: 7),
    );
  }

  @override
  void dispose() {
    _memory.dispose();
    super.dispose();
  }

  Future<void> _discard() async {
    await _memory.discard();
    if (!mounted) {
      return;
    }
    setState(() {
      _restored = false;
      _generation++;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Remembered state cleared')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ui_memory'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Clear remembered state',
            onPressed: _discard,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: MemoryHost(
          key: ValueKey<int>(_generation),
          controller: _memory,
          loadingBuilder: (BuildContext context) =>
              const Center(child: CircularProgressIndicator()),
          onRestored: (MemorySnapshot? snapshot) {
            if (snapshot != null && mounted) {
              setState(() => _restored = true);
            }
          },
          builder: (BuildContext context) => Column(
            children: <Widget>[
              if (_restored)
                Card(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.restore),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your place was restored. Scroll, switch tabs or '
                            'toggle a section, then close and reopen the app.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: RememberedTabs(
                  memoryKey: 'section',
                  length: 3,
                  builder: (BuildContext context, TabController controller) =>
                      Column(
                        children: <Widget>[
                          TabBar(
                            controller: controller,
                            tabs: const <Widget>[
                              Tab(text: 'List'),
                              Tab(text: 'Pages'),
                              Tab(text: 'Details'),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              controller: controller,
                              children: const <Widget>[
                                FeedPage(),
                                PagesPage(),
                                DetailsPage(),
                              ],
                            ),
                          ),
                        ],
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A long list whose scroll position is remembered.
class FeedPage extends StatelessWidget {
  /// Creates the feed page.
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return RememberedScroll(
      memoryKey: 'feed_offset',
      builder: (BuildContext context, ScrollController controller) =>
          ListView.builder(
            controller: controller,
            itemCount: 200,
            itemExtent: 64,
            itemBuilder: (BuildContext context, int index) => ListTile(
              leading: CircleAvatar(child: Text('${index + 1}')),
              title: Text('Item ${index + 1}'),
              subtitle: const Text('Scroll away and come back'),
            ),
          ),
    );
  }
}

/// A page view whose current page is remembered.
class PagesPage extends StatelessWidget {
  /// Creates the pages demo.
  const PagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return RememberedPages(
      memoryKey: 'story_page',
      pageCount: 3,
      builder: (BuildContext context, PageController controller) => PageView(
        controller: controller,
        children: <Widget>[
          _StoryPage(color: Colors.indigo.shade100, label: 'Page 1'),
          _StoryPage(color: Colors.teal.shade100, label: 'Page 2'),
          _StoryPage(color: Colors.orange.shade100, label: 'Page 3'),
        ],
      ),
    );
  }
}

/// A settings page with an expandable section.
class DetailsPage extends StatelessWidget {
  /// Creates the details page.
  const DetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('State is local'),
          subtitle: Text('Nothing is sent anywhere.'),
        ),
        const Divider(),
        RememberedExpansion(
          memoryKey: 'advanced_details',
          initialExpanded: false,
          builder: (BuildContext context, bool expanded, VoidCallback toggle) =>
              ExpansionTile(
                title: const Text('Advanced details'),
                initiallyExpanded: expanded,
                onExpansionChanged: (_) => toggle(),
                children: const <Widget>[
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'This section stays open or closed across rebuilds and app '
                      'restarts, just like the scroll position and selected tab.',
                    ),
                  ),
                ],
              ),
        ),
      ],
    );
  }
}

class _StoryPage extends StatelessWidget {
  const _StoryPage({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      alignment: Alignment.center,
      child: Text(label, style: Theme.of(context).textTheme.headlineMedium),
    );
  }
}
