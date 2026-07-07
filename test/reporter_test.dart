import 'dart:convert';

import 'package:sweeper/src/engine.dart';
import 'package:sweeper/src/reporter.dart';
import 'package:test/test.dart';

void main() {
  SweepResult sweep(List<String> unused) =>
      SweepResult(unusedKeys: unused, totalKeys: 10, scannedFileCount: 3);

  test('checkJson emits the documented shape', () {
    final buffer = StringBuffer();
    Reporter(buffer).checkJson(sweep(['a', 'b']));
    expect(jsonDecode(buffer.toString()), {
      'unused': ['a', 'b'],
      'scannedFiles': 3,
      'totalKeys': 10,
    });
  });

  test('checkHuman lists keys and counts', () {
    final buffer = StringBuffer();
    Reporter(buffer).checkHuman(sweep(['a', 'b']));
    final out = buffer.toString();
    expect(out, contains('2 unused'));
    expect(out, contains('  a\n'));
    expect(out, contains('  b\n'));
  });

  test('checkHuman reports success when nothing is unused', () {
    final buffer = StringBuffer();
    Reporter(buffer).checkHuman(sweep([]));
    expect(buffer.toString(), contains('No unused translation keys'));
  });

  test('clean reports per-file removals and dry-run marker', () {
    final buffer = StringBuffer();
    Reporter(buffer).clean(
      CleanResult(
        analysis: sweep(['a']),
        removedPerFile: {'lib/l10n/intl_en.arb': 1},
      ),
      dryRun: true,
    );
    final out = buffer.toString();
    expect(out, contains('dry run'));
    expect(out, contains('lib/l10n/intl_en.arb: 1'));
  });
}
