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

  String serialize() {
    final body = JsonEncoder.withIndent(_indent).convert(_entries);
    return _trailingNewline ? '$body\n' : body;
  }

  static String _detectIndent(String content) {
    final match = RegExp(r'^([ \t]+)"', multiLine: true).firstMatch(content);
    return match?.group(1) ?? '  ';
  }
}
