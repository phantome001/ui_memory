import 'dart:convert';
import 'dart:io';

import 'memory_store.dart';

/// A [MemoryStore] that keeps each snapshot in its own JSON file.
///
/// Import it from `package:ui_memory/io.dart`, so that builds targeting the
/// web never reach this library. It is available on Android, iOS, desktop and
/// anywhere else `dart:io` exists.
///
/// Writes go through a temporary file and are renamed into place, so a snapshot
/// is never left half written if the app is killed during a save. Operations
/// are serialized: the last write always wins.
class FileMemoryStore implements MemoryStore {
  /// Creates a store writing snapshots inside [directory].
  ///
  /// The directory is created when the first snapshot is written.
  FileMemoryStore(this.directory, {this.suffix = '.memory.json'})
    : assert(suffix.isNotEmpty, 'The suffix cannot be empty');

  /// Directory holding the snapshot files.
  final Directory directory;

  /// File name suffix of the snapshots.
  final String suffix;

  Future<void> _queue = Future<void>.value();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  /// Path of the snapshot file for [id].
  ///
  /// The id is base64url encoded, so any string works as an id. Very long ids
  /// are shortened and suffixed with a stable hash to stay under file name
  /// limits.
  File fileFor(String id) {
    return File('${directory.path}${Platform.pathSeparator}${_fileName(id)}');
  }

  String _fileName(String id) {
    final encoded = base64Url.encode(utf8.encode(id)).replaceAll('=', '');
    if (encoded.length <= 100) {
      return '$encoded$suffix';
    }
    return '${encoded.substring(0, 80)}-${_hash(id)}$suffix';
  }

  static String _hash(String value) {
    var hash = 0xcbf29ce484222325;
    for (final byte in utf8.encode(value)) {
      hash ^= byte;
      hash *= 0x100000001b3;
    }
    return hash.toUnsigned(64).toRadixString(16);
  }

  @override
  Future<String?> read(String id) {
    return _serialized(() async {
      final file = fileFor(id);
      if (!await file.exists()) {
        return null;
      }
      try {
        return await file.readAsString();
      } on FileSystemException {
        return null;
      }
    });
  }

  @override
  Future<void> write(String id, String value) {
    return _serialized(() async {
      await directory.create(recursive: true);
      final file = fileFor(id);
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(value, flush: true);
      if (await file.exists()) {
        await file.delete();
      }
      await temp.rename(file.path);
    });
  }

  @override
  Future<void> delete(String id) {
    return _serialized(() async {
      final file = fileFor(id);
      if (await file.exists()) {
        await file.delete();
      }
    });
  }
}
