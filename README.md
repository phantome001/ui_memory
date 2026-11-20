# ui_memory

**Put the user back where they were.** `ui_memory` remembers Flutter UI state —
scroll offset, selected tab, current page and expanded sections — and restores
it when the screen opens again, even after the operating system killed the app.

[![pub package](https://img.shields.io/pub/v/ui_memory.svg)](https://pub.dev/packages/ui_memory)

## The problem

A user scrolls halfway down a list, opens a detail page, comes back — and the
list is at the top again. Rotate the phone, switch apps, or let Android kill a
background process, and the same thing happens. Restoring all of that by hand
means wiring controllers, `RestorableProperty`, storage and lifecycle checks
into every screen, so most apps simply don't do it.

`ui_memory` does it once, with small widgets that wrap the controllers you
already use.

## What it does

- Remembers scroll offsets and clamps them when the content becomes shorter.
- Remembers the selected tab and current page, with safe bounds checks.
- Remembers whether a section was expanded.
- Restores state **before the screen is built**, so there is no visible jump.
- Flushes pending state when the app goes to the background.
- Expires old state, and discards state written for an older layout.
- Has no platform channel and no plugin dependency: every test runs on any
  machine with Flutter, no emulator required.

## Install

```yaml
dependencies:
  ui_memory: ^0.1.0
```

## Quick start

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ui_memory/ui_memory.dart';
import 'package:ui_memory/ui_memory_io.dart';

final memory = UiMemoryController(
  id: 'feed',                         // stable, unique per screen
  store: FileMemoryStore(directory),
  maxAge: const Duration(days: 7),
);

MemoryHost(
  controller: memory,
  builder: (context) => RememberedScroll(
    memoryKey: 'feed_list',
    builder: (context, controller) => ListView.builder(
      controller: controller,
      itemCount: messages.length,
      itemBuilder: (_, i) => ListTile(title: Text(messages[i].title)),
    ),
  ),
)
```

That is all. The offset is saved as the user scrolls and restored the next time
the page opens.

### Remembering a tab

```dart
RememberedTabs(
  memoryKey: 'profile_tab',
  length: 3,
  builder: (context, controller) => Column(
    children: [
      TabBar(controller: controller, tabs: const [
        Tab(text: 'Posts'),
        Tab(text: 'Photos'),
        Tab(text: 'About'),
      ]),
      Expanded(
        child: TabBarView(
          controller: controller,
          children: const [PostsPage(), PhotosPage(), AboutPage()],
        ),
      ),
    ],
  ),
)
```

### Remembering a page

```dart
RememberedPages(
  memoryKey: 'onboarding',
  pageCount: 3,
  builder: (context, controller) => PageView(
    controller: controller,
    children: const [StepOne(), StepTwo(), StepThree()],
  ),
)
```

### Remembering an expanded section

```dart
RememberedExpansion(
  memoryKey: 'advanced_filters',
  initialExpanded: false,
  builder: (context, expanded, toggle) => ExpansionTile(
    title: const Text('Advanced filters'),
    initiallyExpanded: expanded,
    onExpansionChanged: (_) => toggle(),
    children: const [FilterControls()],
  ),
)
```

## Where to store state

`FileMemoryStore` writes one JSON file per screen and creates its directory on
first use. On a real device, get a durable directory with `path_provider`:

```dart
final support = await getApplicationSupportDirectory();
final store = FileMemoryStore(Directory('${support.path}/ui_state'));
```

The core package is platform independent. Implement `MemoryStore` to use
`shared_preferences`, a database, or any other backend:

```dart
class PreferencesMemoryStore implements MemoryStore {
  // read / write / delete, each returns a Future
}
```

`InMemoryMemoryStore` is included for tests and previews.

## API

| Widget / class | Purpose |
| --- | --- |
| `UiMemoryController` | Owns one screen's state: values, restore, debounced writes, expiry. |
| `MemoryHost` | Restores before building and flushes on background. |
| `RememberedScroll` | A scrollable with a remembered offset. |
| `RememberedTabs` | A `TabController` with a remembered index. |
| `RememberedPages` | A `PageController` with a remembered page. |
| `RememberedExpansion` | A remembered boolean flag for expandable UI. |
| `MemorySnapshot` | The persisted data; can be encoded and decoded on its own. |
| `MemoryStore` | Storage interface. |
| `FileMemoryStore` | File based store for `dart:io` platforms. |
| `InMemoryMemoryStore` | Volatile store for tests. |

### Controller options

| Option | Default | Meaning |
| --- | --- | --- |
| `id` | required | Stable identifier of the screen. |
| `debounce` | 500 ms | Delay after the last change before writing. |
| `maxAge` | `null` | States older than this are deleted on restore. |
| `schemaVersion` | `1` | Bump it when stored keys change incompatibly. |

### Resetting a screen

Delete remembered state when it no longer applies — for example after logout or
when a user chooses "start over":

```dart
await controller.discard();
```

### Restoring with the user's permission

Set `restoreOnStart: false`, call `await controller.restore()` yourself, and
decide from the returned `MemorySnapshot?`:

```dart
final snapshot = await controller.restore();
if (snapshot != null && await _askUser('Resume where you left off?')) {
  // Build the screen with the restored controller.
}
```

## Privacy

State is stored as **plain JSON**. It is convenience data, not a secret store.
Do not use a memory key for sensitive values; use a secure storage backend if
your app needs one.

## Compatibility

The package supports Flutter 3.24 and newer and has no plugin dependency. It
imports `package:flutter/material.dart` for `TabController`, which Flutter 3.47
deprecated in favour of `package:material_ui`; the import is kept so that
existing apps on older SDKs can use the package.

## Example

See [`example/lib/main.dart`](example/lib/main.dart) for a complete demo with a
restore banner, a remembered list, tabs, pages and an expandable section.

```bash
cd example
flutter run
```

## Contributing

Issues and pull requests are welcome at
https://github.com/phantome001/ui_memory.

```bash
flutter pub get
flutter analyze
flutter test
```

## License

MIT — see [LICENSE](LICENSE).
