import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sweeper/src/config.dart';
import 'package:sweeper/src/engine.dart';
import 'package:test/test.dart';

final fixtureRoot =
    p.normalize(p.absolute(p.join('test', 'fixtures', 'demo_app')));

void main() {
  setUpAll(() {
    final result = Process.runSync('dart', ['pub', 'get'],
        workingDirectory: fixtureRoot);
    expect(result.exitCode, 0, reason: result.stderr.toString());
  });

  test('analyze reports exactly the unused template keys, sorted', () async {
    final result = await SweepEngine(projectRoot: fixtureRoot).analyze();
    expect(result.unusedKeys, [
      'dynamicGreetingA',
      'dynamicGreetingB',
      'languageName',
      'unusedKey',
      'unusedPlain',
    ]);
    expect(result.totalKeys, 10);
    expect(result.hasUnused, isTrue);
  });

  test('keep patterns support exact names and globs', () async {
    final result = await SweepEngine(projectRoot: fixtureRoot)
        .analyze(keepPatterns: ['dynamicGreeting*', 'languageName']);
    expect(result.unusedKeys, ['unusedKey', 'unusedPlain']);
  });

  test('missing template ARB throws SweeperConfigException', () async {
    final tmp = Directory.systemTemp.createTempSync('sweeper_engine_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    File(p.join(tmp.path, 'l10n.yaml'))
        .writeAsStringSync('arb-dir: lib/l10n\n');
    expect(
      SweepEngine(projectRoot: tmp.path).analyze,
      throwsA(isA<SweeperConfigException>()
          .having((e) => e.message, 'message', contains('app_en.arb'))),
    );
  });
}
