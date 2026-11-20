/// Where [UiMemoryController] keeps the serialized UI state.
///
/// The package ships with [InMemoryMemoryStore] for tests and previews, and
/// with `FileMemoryStore` (see `package:ui_memory/io.dart`) for real apps on
/// `dart:io` platforms. Implement this interface to use `shared_preferences`,
/// a database, or any other backend.
///
/// Implementations should be safe to call concurrently.
abstract class MemoryStore {
  /// Reads the raw snapshot stored under [id], or `null` when there is none.
  Future<String?> read(String id);

  /// Writes [value] as the snapshot stored under [id], replacing any old value.
  Future<void> write(String id, String value);

  /// Deletes the snapshot stored under [id].
  ///
  /// Deleting a missing snapshot is not an error.
  Future<void> delete(String id);
}

/// A [MemoryStore] that keeps snapshots in memory.
///
/// State lives only as long as this instance, which makes it the right choice
/// for tests and previews. It cannot survive the app being killed.
class InMemoryMemoryStore implements MemoryStore {
  /// Creates a store, optionally pre-filled with raw [snapshots].
  InMemoryMemoryStore([Map<String, String>? snapshots])
    : _snapshots = <String, String>{...?snapshots};

  final Map<String, String> _snapshots;

  /// The raw snapshots currently held by this store, for test assertions.
  Map<String, String> get snapshots =>
      Map<String, String>.unmodifiable(_snapshots);

  @override
  Future<String?> read(String id) async => _snapshots[id];

  @override
  Future<void> write(String id, String value) async {
    _snapshots[id] = value;
  }

  @override
  Future<void> delete(String id) async {
    _snapshots.remove(id);
  }
}
