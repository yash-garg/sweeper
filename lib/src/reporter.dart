import 'dart:convert';

import 'engine.dart';

/// The single place sweeper produces output. Writes to an injected sink so
/// tests never capture stdout.
class Reporter {
  Reporter(this._out);

  final StringSink _out;

  void checkHuman(SweepResult result) {
    _out.writeln('Scanned ${result.scannedFileCount} Dart files, '
        '${result.totalKeys} translation keys.');
    if (!result.hasUnused) {
      _out.writeln('No unused translation keys. ✅');
      return;
    }
    _out.writeln('${result.unusedKeys.length} unused translation keys:');
    for (final key in result.unusedKeys) {
      _out.writeln('  $key');
    }
  }

  void checkJson(SweepResult result) {
    _out.writeln(jsonEncode({
      'unused': result.unusedKeys,
      'scannedFiles': result.scannedFileCount,
      'totalKeys': result.totalKeys,
    }));
  }

  void clean(CleanResult result, {required bool dryRun}) {
    final analysis = result.analysis;
    if (!analysis.hasUnused) {
      _out.writeln('No unused translation keys. Nothing to clean. ✅');
      return;
    }
    final verb = dryRun ? 'Would remove (dry run)' : 'Removed';
    _out.writeln('$verb ${analysis.unusedKeys.length} unused keys:');
    for (final key in analysis.unusedKeys) {
      _out.writeln('  $key');
    }
    _out.writeln('Per file:');
    for (final entry in result.removedPerFile.entries) {
      _out.writeln('  ${entry.key}: ${entry.value}');
    }
  }
}
