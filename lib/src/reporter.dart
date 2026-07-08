import 'dart:convert';

import 'engine.dart';

/// The single place sweeper produces output. Writes to an injected sink so
/// tests never capture stdout.
class Reporter {
  Reporter(this._out, {this.ansi = false, this.quiet = false});

  final StringSink _out;

  /// Whether to color output with ANSI escapes (auto-detected by the CLI).
  final bool ansi;

  /// When true, print summaries only — no key or per-file listings.
  final bool quiet;

  void checkHuman(SweepResult result) {
    if (!result.hasUnused) {
      _out.writeln(_green('✓ No unused translation keys.'));
      _writeStats(result);
      return;
    }
    _out.writeln(_red('✗ ${result.unusedKeys.length} unused translation '
        '${_keyWord(result.unusedKeys.length)}${quiet ? '' : ':'}'),);
    if (!quiet) {
      for (final key in result.unusedKeys) {
        _out.writeln('  ${_dim(key)}');
      }
    }
    _writeStats(result);
  }

  void checkJson(SweepResult result) {
    _out.writeln(jsonEncode({
      'unused': result.unusedKeys,
      'scannedFiles': result.scannedFileCount,
      'totalKeys': result.totalKeys,
    }),);
  }

  void clean(CleanResult result, {required bool dryRun}) {
    final analysis = result.analysis;
    if (!analysis.hasUnused) {
      _out.writeln(_green('✓ No unused translation keys. Nothing to clean.'));
      _writeStats(analysis);
      return;
    }
    final count = analysis.unusedKeys.length;
    final headline = dryRun
        ? _yellow('Would remove (dry run) $count unused ${_keyWord(count)}')
        : _green('Removed $count unused ${_keyWord(count)}');
    _out.writeln('$headline${quiet ? '' : ':'}');
    if (!quiet) {
      for (final key in analysis.unusedKeys) {
        _out.writeln('  ${_dim(key)}');
      }
      _out.writeln('Per file:');
      for (final entry in result.removedPerFile.entries) {
        _out.writeln('  ${entry.key}: ${_bold('${entry.value}')}');
      }
    }
    _writeStats(analysis);
  }

  void sort(SortResult result) {
    final changed = result.changedCount;
    final total = result.changedPerFile.length;
    if (changed == 0) {
      _out.writeln(_green('✓ All $total ARB files already sorted.'));
      return;
    }
    _out.writeln(_green('Sorted $changed of $total ARB files.'));
    if (!quiet) {
      for (final entry in result.changedPerFile.entries) {
        if (entry.value) _out.writeln('  ${_dim(entry.key)}');
      }
    }
  }

  void _writeStats(SweepResult result) {
    _out.writeln(_dim('${result.totalKeys} keys · '
        '${result.unusedKeys.length} unused · '
        '${result.scannedFileCount} files scanned'),);
  }

  static String _keyWord(int count) => count == 1 ? 'key' : 'keys';

  String _paint(String text, String code) =>
      ansi ? '\x1B[${code}m$text\x1B[0m' : text;

  String _green(String text) => _paint(text, '32');
  String _red(String text) => _paint(text, '31');
  String _yellow(String text) => _paint(text, '33');
  String _bold(String text) => _paint(text, '1');
  String _dim(String text) => _paint(text, '2');
}
