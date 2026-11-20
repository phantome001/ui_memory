import 'dart:convert';

import 'package:flutter/foundation.dart';

/// An immutable snapshot of the UI state remembered for one screen.
///
/// The snapshot is the unit that is persisted: it carries the remembered
/// values, the save time and the schema version used to write them.
///
/// Only JSON compatible values are accepted (`bool`, `num`, `String`, `null`
/// and lists of those). A snapshot written by an older app version must never
/// be able to crash the restore path, so anything else is rejected on decode.
@immutable
class MemorySnapshot {
  /// Creates a snapshot holding [values].
  MemorySnapshot({
    required Map<String, Object?> values,
    required this.savedAt,
    this.version = 1,
  }) : values = Map<String, Object?>.unmodifiable(values);

  /// The remembered values, keyed by the memory key of each widget.
  final Map<String, Object?> values;

  /// The moment this snapshot was written.
  final DateTime savedAt;

  /// Version of the stored layout.
  ///
  /// Snapshots written with a different version than
  /// [UiMemoryController.schemaVersion] are discarded instead of being applied
  /// to a screen they were not written for.
  final int version;

  /// Whether no value was remembered.
  bool get isEmpty => values.isEmpty;

  /// Whether at least one value was remembered.
  bool get isNotEmpty => values.isNotEmpty;

  /// Returns a copy of this snapshot with the given parts replaced.
  MemorySnapshot copyWith({
    Map<String, Object?>? values,
    DateTime? savedAt,
    int? version,
  }) {
    return MemorySnapshot(
      values: values ?? this.values,
      savedAt: savedAt ?? this.savedAt,
      version: version ?? this.version,
    );
  }

  /// Whether this snapshot is older than [maxAge] at [now].
  ///
  /// A `null` [maxAge] means state never expires.
  bool isExpired(Duration? maxAge, {required DateTime now}) {
    if (maxAge == null) {
      return false;
    }
    return now.difference(savedAt) > maxAge;
  }

  /// Encodes this snapshot as a JSON string.
  String encode() {
    return jsonEncode(<String, Object?>{
      'version': version,
      'savedAt': savedAt.toUtc().toIso8601String(),
      'values': values,
    });
  }

  /// Decodes a snapshot produced by [encode].
  ///
  /// Returns `null` when [raw] is missing, malformed, or contains a value that
  /// cannot be stored. Old user data is treated as "no remembered state".
  static MemorySnapshot? decode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }

    if (decoded is! Map<String, Object?>) {
      return null;
    }

    final version = decoded['version'];
    final savedAt = decoded['savedAt'];
    final values = decoded['values'];

    if (version is! int ||
        savedAt is! String ||
        values is! Map<String, Object?>) {
      return null;
    }

    final DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(savedAt);
    } on FormatException {
      return null;
    }

    final cleanValues = <String, Object?>{};
    for (final entry in values.entries) {
      if (!_isStorable(entry.value)) {
        return null;
      }
      cleanValues[entry.key] = entry.value;
    }

    return MemorySnapshot(
      values: cleanValues,
      savedAt: parsedDate,
      version: version,
    );
  }

  static bool _isStorable(Object? value) {
    if (value == null || value is String || value is num || value is bool) {
      return true;
    }
    if (value is List) {
      return value.every(_isStorable);
    }
    return false;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is MemorySnapshot &&
        other.version == version &&
        other.savedAt == savedAt &&
        mapEquals(other.values, values);
  }

  @override
  int get hashCode => Object.hash(
    version,
    savedAt,
    Object.hashAllUnordered(
      values.entries.map(
        (MapEntry<String, Object?> e) => Object.hash(e.key, e.value),
      ),
    ),
  );

  @override
  String toString() =>
      'MemorySnapshot(version: $version, savedAt: $savedAt, '
      'values: ${values.length})';
}
