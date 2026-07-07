import 'dart:convert';

import 'exceptions.dart';

class ArbParseException extends SweeperException {
  ArbParseException(super.message);
}

/// An ARB file held in memory, preserving key order, indentation, and
/// trailing-newline style so a rewrite only changes what was removed.
class ArbDocument {
  ArbDocument._(this.path, this._entries, this._indent, this._trailingNewline);

  factory ArbDocument.parse(String path, String content) {
    final Object? decoded;
    try {
      decoded = jsonDecode(content);
    } on FormatException catch (e) {
      throw ArbParseException('Could not parse $path as JSON: ${e.message}');
    }
    if (decoded is! Map<String, Object?>) {
      throw ArbParseException('$path: root of an ARB file must be an object.');
    }
    return ArbDocument._(
      path,
      decoded, // jsonDecode preserves insertion order (LinkedHashMap).
      _detectIndent(content),
      content.endsWith('\n'),
    );
  }

  final String path;
  final Map<String, Object?> _entries;
  final String _indent;
  final bool _trailingNewline;

  /// Translatable keys, in file order: every entry not starting with `@`
  /// (excludes `@@locale` and `@key` metadata).
  List<String> get translationKeys =>
      _entries.keys.where((k) => !k.startsWith('@')).toList();

  /// Removes [key] and its `@key` metadata. Returns true if [key] existed.
  bool removeKey(String key) {
    final existed = _entries.remove(key) != null;
    _entries.remove('@$key');
    return existed;
  }

  /// Reorders entries: `@@`-prefixed header entries first (original order),
  /// then keys alphabetically, each immediately followed by its `@key`
  /// metadata. Returns true if the order changed.
  bool sortKeys() {
    final headers = _entries.keys.where((k) => k.startsWith('@@')).toList();
    final keys = translationKeys..sort();
    final sorted = <String, Object?>{
      for (final k in headers) k: _entries[k],
      for (final k in keys) ...{
        k: _entries[k],
        if (_entries.containsKey('@$k')) '@$k': _entries['@$k'],
      },
      // Anything left over (e.g. orphaned @key metadata) keeps its place
      // at the end rather than being dropped.
      for (final k in _entries.keys)
        if (!k.startsWith('@@') &&
            k.startsWith('@') &&
            !_entries.containsKey(k.substring(1)))
          k: _entries[k],
    };
    final changed = !_listEquals(sorted.keys.toList(), _entries.keys.toList());
    _entries
      ..clear()
      ..addAll(sorted);
    return changed;
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  String serialize() {
    final body = JsonEncoder.withIndent(_indent).convert(_entries);
    return _trailingNewline ? '$body\n' : body;
  }

  static String _detectIndent(String content) {
    final match = RegExp(r'^([ \t]+)"', multiLine: true).firstMatch(content);
    return match?.group(1) ?? '  ';
  }
}
