import 'package:flutter_test/flutter_test.dart';
import 'package:ui_memory/ui_memory.dart';

class _CountingStore extends InMemoryMemoryStore {
  int writes = 0;

  @override
  Future<void> write(String id, String value) {
    writes++;
    return super.write(id, value);
  }
}

void main() {
  late InMemoryMemoryStore store;
  late DateTime now;

  UiMemoryController controller({
    String id = 'screen',
    Duration debounce = Duration.zero,
    Duration? maxAge,
    int schemaVersion = 1,
  }) {
    return UiMemoryController(
      id: id,
      store: store,
      debounce: debounce,
      maxAge: maxAge,
      schemaVersion: schemaVersion,
      clock: () => now,
    );
  }

  setUp(() {
    store = InMemoryMemoryStore();
    now = DateTime.utc(2026, 11, 20, 12);
  });

  group('remember and flush', () {
    test('saves values and gives them back on restore', () async {
      final first = controller();
      first
        ..remember('feed', 1240.5)
        ..remember('tab', 2);
      await first.flush();

      final second = controller();
      final restored = await second.restore();

      expect(restored, isNotNull);
      expect(second.read<double>('feed'), 1240.5);
      expect(second.read<int>('tab'), 2);
      expect(second.hasState, isTrue);
      expect(second.savedAt, now);
    });

    test('read returns null for a missing key', () async {
      final c = controller();
      await c.restore();
      expect(c.read<int>('missing'), isNull);
    });

    test('read returns null when the stored type differs', () async {
      final writer = controller();
      writer.remember('tab', 'not an int');
      await writer.flush();

      final reader = controller();
      await reader.restore();

      expect(reader.read<int>('tab'), isNull);
      expect(reader.values['tab'], 'not an int');
    });

    test('forget removes one value', () async {
      final c = controller();
      c
        ..remember('a', 1)
        ..remember('b', 2);
      await c.flush();
      c.forget('a');
      await c.flush();

      expect(c.values, {'b': 2});
    });

    test('clearing every value deletes the snapshot', () async {
      final c = controller();
      c.remember('a', 1);
      await c.flush();
      expect(store.snapshots, isNotEmpty);

      c.forget('a');
      await c.flush();

      expect(store.snapshots, isEmpty);
      expect(c.hasState, isFalse);
    });

    test('persist false does not write', () async {
      final counting = _CountingStore();
      final c = UiMemoryController(
        id: 'screen',
        store: counting,
        debounce: Duration.zero,
        clock: () => now,
      );

      c.remember('a', 1, persist: false);
      await Future<void>.delayed(Duration.zero);

      expect(counting.writes, 0);
      expect(c.values, {'a': 1});
    });

    test('debounce groups the writes', () async {
      final counting = _CountingStore();
      final c = UiMemoryController(
        id: 'screen',
        store: counting,
        debounce: const Duration(milliseconds: 30),
        clock: () => now,
      );

      c.remember('a', 1);
      c.remember('b', 2);
      c.remember('c', 3);
      expect(counting.writes, 0);

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(counting.writes, 1);
      expect(counting.snapshots, hasLength(1));
    });

    test('an unchanged value does not schedule a write', () async {
      final counting = _CountingStore();
      final c = UiMemoryController(
        id: 'screen',
        store: counting,
        clock: () => now,
      );

      c.remember('a', 1);
      await c.flush();
      final before = counting.writes;

      c.remember('a', 1);
      await Future<void>.delayed(Duration.zero);

      expect(counting.writes, before);
    });
  });

  group('restore', () {
    test('returns null when the store is empty', () async {
      final c = controller();
      expect(await c.restore(), isNull);
      expect(c.isRestored, isTrue);
      expect(c.values, isEmpty);
    });

    test('deletes an expired snapshot', () async {
      final writer = controller();
      writer.remember('a', 1);
      await writer.flush();

      now = now.add(const Duration(days: 30));
      final reader = controller(maxAge: const Duration(days: 7));

      expect(await reader.restore(), isNull);
      expect(reader.values, isEmpty);
      expect(store.snapshots, isEmpty);
    });

    test('keeps a snapshot that did not expire', () async {
      final writer = controller();
      writer.remember('a', 1);
      await writer.flush();

      now = now.add(const Duration(days: 2));
      final reader = controller(maxAge: const Duration(days: 7));

      expect(await reader.restore(), isNotNull);
      expect(reader.values, {'a': 1});
    });

    test('deletes a snapshot written with another schema version', () async {
      final writer = controller(schemaVersion: 1);
      writer.remember('a', 1);
      await writer.flush();

      final reader = controller(schemaVersion: 2);

      expect(await reader.restore(), isNull);
      expect(store.snapshots, isEmpty);
    });

    test('ignores a corrupt snapshot', () async {
      final c = UiMemoryController(
        id: 'screen',
        store: InMemoryMemoryStore(<String, String>{'screen': 'not json'}),
        clock: () => now,
      );

      expect(await c.restore(), isNull);
      expect(c.values, isEmpty);
    });

    test('a second restore clears values from the first call', () async {
      final writer = controller();
      writer.remember('a', 1);
      await writer.flush();

      final reader = controller();
      await reader.restore();
      expect(reader.values, {'a': 1});

      await reader.discard();
      expect(await reader.restore(), isNull);
    });
  });

  group('discard', () {
    test('removes the snapshot and cancels a pending write', () async {
      final counting = _CountingStore();
      final c = UiMemoryController(
        id: 'screen',
        store: counting,
        debounce: const Duration(milliseconds: 20),
        clock: () => now,
      );

      c.remember('a', 1);
      await c.discard();
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(counting.writes, 0);
      expect(counting.snapshots, isEmpty);
      expect(c.values, isEmpty);
    });
  });

  group('notifications and dispose', () {
    test('notifies on every change', () async {
      final c = controller();
      var notifications = 0;
      c.addListener(() => notifications++);

      c.remember('a', 1);
      c.remember('a', 2);
      await c.flush();

      expect(notifications, greaterThanOrEqualTo(2));
    });

    test('dispose cancels the pending write', () async {
      final counting = _CountingStore();
      final c = UiMemoryController(
        id: 'screen',
        store: counting,
        debounce: const Duration(milliseconds: 10),
        clock: () => now,
      );

      c.remember('a', 1);
      c.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(counting.writes, 0);
    });
  });
}
