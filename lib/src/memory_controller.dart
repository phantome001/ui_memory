import 'dart:async';

import 'package:flutter/foundation.dart';

import 'memory_snapshot.dart';
import 'memory_store.dart';

/// Saves and restores the UI state of one screen.
///
/// A controller is identified by [id], which must be unique per screen in the
/// [store]. Recreating a controller with the same id and the same store is what
/// lets a screen come back with the same scroll position, tab and page after
/// the operating system killed the app.
///
/// ```dart
/// final memory = UiMemoryController(
///   id: 'feed',
///   store: FileMemoryStore(directory),
/// );
/// await memory.restore();
/// ```
class UiMemoryController extends ChangeNotifier {
  /// Creates a controller for the screen identified by [id].
  ///
  /// [debounce] is the delay after the last change before writing to [store].
  /// Passing [Duration.zero] writes on every change.
  ///
  /// When [maxAge] is set, older snapshots are deleted instead of restored.
  ///
  /// Bump [schemaVersion] when the set of remembered widgets changes in a way
  /// that makes old state invalid.
  ///
  /// [clock] is only meant for tests.
  UiMemoryController({
    required this.id,
    required this.store,
    this.debounce = const Duration(milliseconds: 500),
    this.maxAge,
    this.schemaVersion = 1,
    DateTime Function()? clock,
  }) : assert(id.isNotEmpty, 'A memory id cannot be empty'),
       _clock = clock ?? DateTime.now;

  /// Identifier of the screen, unique inside [store].
  final String id;

  /// Where the snapshot is persisted.
  final MemoryStore store;

  /// Delay between the last change and the write to [store].
  final Duration debounce;

  /// Maximum age of a snapshot that can be restored.
  final Duration? maxAge;

  /// Version of the stored layout; see the constructor.
  final int schemaVersion;

  final DateTime Function() _clock;
  final Map<String, Object?> _values = <String, Object?>{};
  Timer? _timer;
  MemorySnapshot? _snapshot;
  bool _restored = false;
  bool _dirty = false;
  bool _disposed = false;

  /// The values currently held by the controller, read-only.
  Map<String, Object?> get values => Map<String, Object?>.unmodifiable(_values);

  /// The last snapshot read from or written to [store].
  MemorySnapshot? get snapshot => _snapshot;

  /// Whether remembered state exists and was not discarded.
  bool get hasState => _snapshot != null && _snapshot!.isNotEmpty;

  /// The moment the current snapshot was saved, or `null` when there is none.
  DateTime? get savedAt => _snapshot?.savedAt;

  /// Whether [restore] completed.
  bool get isRestored => _restored;

  /// Whether values changed since the last successful write.
  bool get isDirty => _dirty;

  /// Reads the value remembered under [key], when it has type [T].
  ///
  /// Returns `null` when the key is missing or the stored value has a different
  /// type, so a stale snapshot can never cause a cast error in a widget.
  T? read<T>(String key) {
    final value = _values[key];
    return value is T ? value : null;
  }

  /// Reads the snapshot from [store] into [values].
  ///
  /// Expired snapshots, snapshots written with another [schemaVersion] and
  /// unreadable snapshots are deleted. Returns the restored snapshot, or `null`
  /// when there is nothing to restore.
  ///
  /// Call this before creating the widgets that restore their state.
  Future<MemorySnapshot?> restore() async {
    _assertNotDisposed();
    final snapshot = MemorySnapshot.decode(await store.read(id));

    if (snapshot == null ||
        snapshot.version != schemaVersion ||
        snapshot.isExpired(maxAge, now: _clock())) {
      if (snapshot != null) {
        await store.delete(id);
      }
      _snapshot = null;
      _values.clear();
      _restored = true;
      _notify();
      return null;
    }

    _snapshot = snapshot;
    _values
      ..clear()
      ..addAll(snapshot.values);
    _restored = true;
    _dirty = false;
    _notify();
    return snapshot;
  }

  /// Remembers [value] under [key] and schedules a write.
  ///
  /// Pass `persist: false` to change [values] without writing, and call [flush]
  /// yourself later. Unchanged values do not schedule a write.
  void remember(String key, Object? value, {bool persist = true}) {
    _assertNotDisposed();

    if (value == null) {
      if (_values.remove(key) == null) {
        return;
      }
    } else {
      if (_values[key] == value) {
        return;
      }
      _values[key] = value;
    }

    _dirty = true;
    _notify();

    if (persist) {
      _scheduleWrite();
    }
  }

  /// Forgets a single value and schedules a write.
  void forget(String key) {
    remember(key, null);
  }

  /// Writes the current values to [store] immediately.
  ///
  /// Cancels a pending debounced write. When no value is remembered, the
  /// snapshot is deleted instead of being stored.
  Future<void> flush() async {
    _assertNotDisposed();
    _timer?.cancel();
    _timer = null;

    if (_values.isEmpty) {
      if (_snapshot == null) {
        _dirty = false;
        return;
      }
      await store.delete(id);
      _snapshot = null;
      _dirty = false;
      _notify();
      return;
    }

    final snapshot = MemorySnapshot(
      values: _values,
      savedAt: _clock(),
      version: schemaVersion,
    );
    await store.write(id, snapshot.encode());
    _snapshot = snapshot;
    _dirty = false;
    _notify();
  }

  /// Deletes the remembered state and clears [values].
  Future<void> discard() async {
    _assertNotDisposed();
    _timer?.cancel();
    _timer = null;
    _values.clear();
    _snapshot = null;
    _dirty = false;
    await store.delete(id);
    _notify();
  }

  void _scheduleWrite() {
    _timer?.cancel();
    _timer = Timer(debounce, () {
      _timer = null;
      unawaited(flush());
    });
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  void _assertNotDisposed() {
    assert(!_disposed, 'A disposed UiMemoryController cannot be used anymore');
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  @override
  String toString() =>
      'UiMemoryController(id: $id, values: ${_values.length}, '
      'savedAt: $savedAt)';
}
