# ui_memory example

A small Flutter app that shows the state of one screen coming back exactly
where the user left it.

![ui_memory example](https://img.shields.io/badge/Flutter-example-blue)

## Run it

From this directory:

```bash
flutter pub get
flutter run
```

The example depends on `ui_memory` through a path dependency (`../`), so it
always runs the local source of the package.

## What to try

1. Open the app and scroll the **List** tab down a few dozen items.
2. Switch to **Pages** and move to page 2 or 3.
3. Open **Details** and expand **Advanced details**.
4. Close the app completely and open it again.

A banner confirms that the screen was restored, then the list, the page and
the expanded section are all back where you left them. The bin icon in the app
bar clears the remembered state so you can start over.

## How it works

`DemoPage` creates a `UiMemoryController` with the id `playground` and wraps
the screen in `MemoryHost`. The three tabs use `RememberedTabs`,
`RememberedScroll`, `RememberedPages` and `RememberedExpansion`, each with a
stable `memoryKey`. State is restored before the screen is built, so there is
no visible jump when the app opens.

## Storage

The demo writes snapshots to a temporary directory so it needs no plugins and
runs on every platform:

```dart
FileMemoryStore(Directory('${Directory.systemTemp.path}/ui_memory_example'));
```

In a real app, use a durable directory from `path_provider`:

```dart
final support = await getApplicationSupportDirectory();
final store = FileMemoryStore(Directory('${support.path}/ui_state'));
```

State is plain JSON and is meant for convenience, not for secrets.
