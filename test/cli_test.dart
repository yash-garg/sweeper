import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final sweeperBin = p.absolute(p.join('bin', 'sweeper.dart'));
final demoRoot = p.absolute(p.join('test', 'fixtures', 'demo_app'));
final brokenRoot = p.absolute(p.join('test', 'fixtures', 'broken_app'));

ProcessResult runCli(List<String> args, {required String cwd}) =>
    Process.runSync('dart', [sweeperBin, ...args], workingDirectory: cwd);

void main() {
  setUpAll(() {
    for (final root in [demoRoot, brokenRoot]) {
      final result =
          Process.runSync('dart', ['pub', 'get'], workingDirectory: root);
      expect(result.exitCode, 0, reason: result.stderr.toString());
    }
  });

  test('check exits 1 and lists unused keys', () {
    final result = runCli(['check'], cwd: demoRoot);
    expect(result.exitCode, 1, reason: result.stderr.toString());
    expect(result.stdout, contains('unusedKey'));
    expect(result.stdout, contains('5 unused'));
  });

  test('check --json emits machine-readable output', () {
    final result = runCli(['check', '--json'], cwd: demoRoot);
    expect(result.exitCode, 1);
    final decoded = jsonDecode(result.stdout as String);
    expect(decoded['unused'], contains('unusedPlain'));
    expect(decoded['totalKeys'], 10);
  });

  test('check --keep with globs exits 0 when everything is covered', () {
    final result = runCli(
      ['check', '--keep', 'dynamicGreeting*,languageName,unused*'],
      cwd: demoRoot,
    );
    expect(result.exitCode, 0, reason: result.stdout.toString());
  });

  test('check exits 2 with a clear error outside a gen-l10n project', () {
    final tmp = Directory.systemTemp.createTempSync('sweeper_cli_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final result = runCli(['check'], cwd: tmp.path);
    expect(result.exitCode, 2);
    expect(result.stderr, contains('l10n.yaml'));
  });

  test('check exits 2 on unresolvable project (fail-closed)', () {
    final result = runCli(['check'], cwd: brokenRoot);
    expect(result.exitCode, 2);
    expect(result.stderr, contains('main.dart'));
  });

  test('clean --dry-run exits 1 and modifies nothing', () {
    final enPath = p.join(demoRoot, 'lib', 'l10n', 'intl_en.arb');
    final before = File(enPath).readAsStringSync();
    final result = runCli(['clean', '--dry-run'], cwd: demoRoot);
    expect(result.exitCode, 1);
    expect(result.stdout, contains('dry run'));
    expect(File(enPath).readAsStringSync(), before);
  });

  test('check --quiet omits the key list but keeps summary and exit 1', () {
    final result = runCli(['check', '--quiet'], cwd: demoRoot);
    expect(result.exitCode, 1);
    expect(result.stdout, contains('5 unused'));
    expect(result.stdout, isNot(contains('unusedPlain')));
  });

  test('piped output has no ANSI escapes', () {
    final result = runCli(['check'], cwd: demoRoot);
    expect(result.stdout, isNot(contains('\x1B[')));
  });

  test('unknown command exits nonzero with usage', () {
    final result = runCli(['bogus'], cwd: demoRoot);
    expect(result.exitCode, isNot(0));
  });
}
