import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ui_memory/ui_memory_io.dart';

void main() {
  late Directory root;
  late FileMemoryStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('ui_memory_test');
    store = FileMemoryStore(Directory('${root.path}/state'));
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test('returns null when the snapshot does not exist', () async {
    expect(await store.read('missing'), isNull);
  });

  test('creates the directory and round trips a snapshot', () async {
    await store.write('screen', '{"a":1}');
    expect(await store.read('screen'), '{"a":1}');
    expect(await store.directory.exists(), isTrue);
  });

  test('replaces a previous snapshot', () async {
    await store.write('screen', 'first');
    await store.write('screen', 'second');
    expect(await store.read('screen'), 'second');
  });

  test('deletes a snapshot', () async {
    await store.write('screen', 'value');
    await store.delete('screen');
    expect(await store.read('screen'), isNull);
  });

  test('deleting a missing snapshot is not an error', () async {
    await store.delete('missing');
  });

  test('accepts any string as an id', () async {
    final ids = <String>[
      'with/slash',
      'with space',
      'معرف عربي',
      r'../escape',
      'a' * 200,
    ];

    for (final id in ids) {
      await store.write(id, id);
    }
    for (final id in ids) {
      expect(await store.read(id), id);
    }
    for (final id in ids) {
      await store.delete(id);
      expect(await store.read(id), isNull);
    }
  });

  test('keeps files inside the store directory', () async {
    await store.write('../escape', 'value');
    final files = await store.directory
        .list()
        .where((FileSystemEntity e) => e is File)
        .toList();
    expect(files, hasLength(1));
    expect(files.single.parent.path, store.directory.path);
  });

  test('writes leave no temporary file behind', () async {
    await store.write('screen', 'value');
    final names = await store.directory
        .list()
        .map((FileSystemEntity e) => e.uri.pathSegments.last)
        .toList();
    expect(names.where((String n) => n.endsWith('.tmp')), isEmpty);
  });

  test('concurrent writes are serialized', () async {
    await Future.wait(<Future<void>>[
      for (var i = 0; i < 20; i++) store.write('screen', 'value $i'),
    ]);
    expect(await store.read('screen'), 'value 19');
  });
}
