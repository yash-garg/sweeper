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
    expect(out, contains('lib/l10n/intl_en.arb'));
  });

  test('output contains no ANSI codes by default', () {
    final buffer = StringBuffer();
    Reporter(buffer).checkHuman(sweep(['a']));
    expect(buffer.toString(), isNot(contains('\x1B[')));
  });

  test('ansi mode colors the output', () {
    final buffer = StringBuffer();
    Reporter(buffer, ansi: true).checkHuman(sweep(['a']));
    expect(buffer.toString(), contains('\x1B['));
  });

  test('quiet checkHuman prints summary only, no key list', () {
    final buffer = StringBuffer();
    Reporter(buffer, quiet: true).checkHuman(sweep(['a', 'b']));
    final out = buffer.toString();
    expect(out, contains('2 unused'));
    expect(out, isNot(contains('  a\n')));
  });

  test('quiet clean prints totals only, no keys or per-file list', () {
    final buffer = StringBuffer();
    Reporter(buffer, quiet: true).clean(
      CleanResult(
        analysis: sweep(['a']),
        removedPerFile: {'lib/l10n/intl_en.arb': 1},
      ),
      dryRun: false,
    );
    final out = buffer.toString();
    expect(out, contains('Removed 1 unused key'));
    expect(out, isNot(contains('  a\n')));
    expect(out, isNot(contains('intl_en.arb')));
  });
}
