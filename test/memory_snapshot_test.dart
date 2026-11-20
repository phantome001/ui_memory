import 'package:flutter_test/flutter_test.dart';
import 'package:ui_memory/ui_memory.dart';

void main() {
  final savedAt = DateTime.utc(2026, 11, 20, 10, 30);

  group('encode and decode', () {
    test('round trips values, date and version', () {
      final snapshot = MemorySnapshot(
        values: const <String, Object?>{
          'feed_offset': 1240.5,
          'profile_tab': 2,
          'advanced': true,
          'filters': <Object?>['new', 7, false, null],
        },
        savedAt: savedAt,
        version: 4,
      );

      final decoded = MemorySnapshot.decode(snapshot.encode());

      expect(decoded, isNotNull);
      expect(decoded!.values, snapshot.values);
      expect(decoded.savedAt, savedAt);
      expect(decoded.version, 4);
    });

    test('returns null for missing or empty data', () {
      expect(MemorySnapshot.decode(null), isNull);
      expect(MemorySnapshot.decode(''), isNull);
    });

    test('returns null for invalid JSON instead of throwing', () {
      expect(MemorySnapshot.decode('{not json'), isNull);
      expect(MemorySnapshot.decode('"a string"'), isNull);
      expect(MemorySnapshot.decode('[1, 2, 3]'), isNull);
    });

    test('returns null when a required key is missing', () {
      expect(MemorySnapshot.decode('{"values":{}}'), isNull);
      expect(
        MemorySnapshot.decode('{"version":1,"savedAt":"2026-11-20"}'),
        isNull,
      );
    });

    test('returns null for a value that cannot be stored', () {
      const raw =
          '{"version":1,"savedAt":"2026-11-20T10:30:00Z",'
          '"values":{"nested":{"a":1}}}';
      expect(MemorySnapshot.decode(raw), isNull);
    });

    test('rejects a malformed date', () {
      const raw = '{"version":1,"savedAt":"yesterday","values":{}}';
      expect(MemorySnapshot.decode(raw), isNull);
    });

    test('is unmodifiable', () {
      final snapshot = MemorySnapshot(values: const {}, savedAt: savedAt);
      expect(() => snapshot.values['a'] = 1, throwsUnsupportedError);
    });

    test('copyWith keeps the original parts', () {
      final snapshot = MemorySnapshot(
        values: const {'a': 1},
        savedAt: savedAt,
        version: 2,
      );
      final copy = snapshot.copyWith(version: 3);
      expect(copy.values, {'a': 1});
      expect(copy.savedAt, savedAt);
      expect(copy.version, 3);
    });

    test('equality compares all parts', () {
      final a = MemorySnapshot(values: const {'a': 1}, savedAt: savedAt);
      final b = MemorySnapshot(values: const {'a': 1}, savedAt: savedAt);
      final c = MemorySnapshot(values: const {'a': 2}, savedAt: savedAt);
      expect(a, b);
      expect(a == c, isFalse);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('expiry', () {
    test('never expires without maxAge', () {
      final snapshot = MemorySnapshot(
        values: const {'a': 1},
        savedAt: DateTime.utc(2000),
      );
      expect(snapshot.isExpired(null, now: savedAt), isFalse);
    });

    test('expires after maxAge', () {
      final snapshot = MemorySnapshot(values: const {'a': 1}, savedAt: savedAt);
      expect(
        snapshot.isExpired(
          const Duration(days: 1),
          now: savedAt.add(const Duration(days: 2)),
        ),
        isTrue,
      );
      expect(
        snapshot.isExpired(
          const Duration(days: 1),
          now: savedAt.add(const Duration(hours: 1)),
        ),
        isFalse,
      );
    });
  });
}
