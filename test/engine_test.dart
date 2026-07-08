import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sweeper/src/arb.dart';
import 'package:sweeper/src/config.dart';
import 'package:sweeper/src/engine.dart';
import 'package:test/test.dart';

final fixtureRoot =
    p.normalize(p.absolute(p.join('test', 'fixtures', 'demo_app')));

void main() {
  setUpAll(() {
    final result =
        Process.runSync('dart', ['pub', 'get'], workingDirectory: fixtureRoot);
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

  test('keep patterns are case-sensitive on every platform', () async {
    final result = await SweepEngine(projectRoot: fixtureRoot)
        .analyze(keepPatterns: ['UNUSEDKEY', 'DynamicGreeting*']);
    // Wrong-cased patterns keep nothing.
    expect(result.unusedKeys, contains('unusedKey'));
    expect(result.unusedKeys, contains('dynamicGreetingA'));
  });

  test('accepts a relative projectRoot', () async {
    final relative = p.join('test', 'fixtures', 'demo_app');
    final result = await SweepEngine(projectRoot: relative).analyze();
    expect(result.totalKeys, 10);
  });

  test('invalid keep pattern throws KeepPatternException', () async {
    expect(
      () => SweepEngine(projectRoot: fixtureRoot)
          .analyze(keepPatterns: ['[unclosed']),
      throwsA(
        isA<KeepPatternException>()
            .having((e) => e.message, 'message', contains('[unclosed')),
      ),
    );
  });

  test('missing template ARB throws SweeperConfigException', () async {
    final tmp = Directory.systemTemp.createTempSync('sweeper_engine_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    File(p.join(tmp.path, 'l10n.yaml'))
        .writeAsStringSync('arb-dir: lib/l10n\n');
    expect(
      SweepEngine(projectRoot: tmp.path).analyze,
      throwsA(
        isA<SweeperConfigException>()
            .having((e) => e.message, 'message', contains('app_en.arb')),
      ),
    );
  });

  String copyFixtureToTemp() {
    final tmp = Directory.systemTemp.createTempSync('sweeper_clean_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    for (final entity in Directory(fixtureRoot).listSync(recursive: true)) {
      final relative = p.relative(entity.path, from: fixtureRoot);
      if (p.split(relative).contains('.dart_tool')) continue;
      final target = p.join(tmp.path, relative);
      if (entity is Directory) {
        Directory(target).createSync(recursive: true);
      } else if (entity is File) {
        File(target).createSync(recursive: true);
        entity.copySync(target);
      }
    }
    final pub =
        Process.runSync('dart', ['pub', 'get'], workingDirectory: tmp.path);
    expect(pub.exitCode, 0, reason: pub.stderr.toString());
    return tmp.path;
  }

  test('clean removes unused keys and metadata from all ARB files', () async {
    final root = copyFixtureToTemp();
    final result = await SweepEngine(projectRoot: root).clean();

    expect(result.analysis.unusedKeys, hasLength(5));
    final enPath = p.join(root, 'lib', 'l10n', 'intl_en.arb');
    final dePath = p.join(root, 'lib', 'l10n', 'intl_de.arb');
    expect(result.removedPerFile, {dePath: 2, enPath: 5});

    final en = File(enPath).readAsStringSync();
    expect(en, isNot(contains('"unusedKey"')));
    expect(en, isNot(contains('"@unusedKey"')));
    expect(en, isNot(contains('"languageName"')));
    expect(en, contains('"usedDirect"'));
    expect(en, contains('"@itemCount"'));

    final de = File(dePath).readAsStringSync();
    expect(de, isNot(contains('"unusedKey"')));
    // Keys absent from the template are left alone.
    expect(de, contains('"germanOnly"'));
    expect(de, contains('"usedDirect"'));
  });

  test('clean --dry-run reports removals but writes nothing', () async {
    final root = copyFixtureToTemp();
    final enPath = p.join(root, 'lib', 'l10n', 'intl_en.arb');
    final before = File(enPath).readAsStringSync();

    final result = await SweepEngine(projectRoot: root).clean(dryRun: true);

    expect(result.removedPerFile.values.reduce((a, b) => a + b), 7);
    expect(File(enPath).readAsStringSync(), before);
  });

  test('clean leaves files with no removals byte-identical', () async {
    final root = copyFixtureToTemp();
    final enPath = p.join(root, 'lib', 'l10n', 'intl_en.arb');
    final dePath = p.join(root, 'lib', 'l10n', 'intl_de.arb');
    // Non-standard formatting that re-serialization would normalize.
    final before = File(dePath)
        .readAsStringSync()
        .replaceFirst('"germanOnly"', '"germanOnly"  ');
    File(dePath).writeAsStringSync(before);
    final enBefore = File(enPath).readAsStringSync();

    // Keep everything: nothing is unused, so nothing may be rewritten.
    final result =
        await SweepEngine(projectRoot: root).clean(keepPatterns: ['*']);
    expect(result.analysis.hasUnused, isFalse);
    expect(File(dePath).readAsStringSync(), before);
    expect(File(enPath).readAsStringSync(), enBefore);
  });

  test('clean honors keep patterns', () async {
    final root = copyFixtureToTemp();
    await SweepEngine(projectRoot: root)
        .clean(keepPatterns: ['dynamicGreeting*']);
    final en =
        File(p.join(root, 'lib', 'l10n', 'intl_en.arb')).readAsStringSync();
    expect(en, contains('"dynamicGreetingA"'));
    expect(en, isNot(contains('"unusedKey"')));
  });

  test('scanRoots includes usage from sibling packages', () async {
    final addonRoot =
        p.normalize(p.absolute(p.join('test', 'fixtures', 'demo_addon')));
    final pub =
        Process.runSync('dart', ['pub', 'get'], workingDirectory: addonRoot);
    expect(pub.exitCode, 0, reason: pub.stderr.toString());

    final result = await SweepEngine(projectRoot: fixtureRoot)
        .analyze(scanRoots: [addonRoot]);
    // unusedPlain is used by demo_addon, so it is no longer unused.
    expect(result.unusedKeys, [
      'dynamicGreetingA',
      'dynamicGreetingB',
      'languageName',
      'unusedKey',
    ]);
  });

  test('pub workspace members are discovered and scanned automatically',
      () async {
    final wsRoot =
        p.normalize(p.absolute(p.join('test', 'fixtures', 'workspace_repo')));
    final pub =
        Process.runSync('dart', ['pub', 'get'], workingDirectory: wsRoot);
    expect(pub.exitCode, 0, reason: pub.stderr.toString());

    // Runs against the member package; usage in the sibling member and the
    // root-level package_config must both be found without any flags.
    final result =
        await SweepEngine(projectRoot: p.join(wsRoot, 'app')).analyze();
    expect(result.unusedKeys, ['neverUsed']);
  });

  test('sort orders all ARB files and reports which changed', () async {
    final root = copyFixtureToTemp();
    final dePath = p.join(root, 'lib', 'l10n', 'intl_de.arb');
    final enPath = p.join(root, 'lib', 'l10n', 'intl_en.arb');

    final result = SweepEngine(projectRoot: root).sort();
    expect(result.changedPerFile, {dePath: true, enPath: true});

    final de = File(dePath).readAsStringSync();
    final deKeys = RegExp(r'^  "([^@"][^"]*)":', multiLine: true)
        .allMatches(de)
        .map((m) => m.group(1))
        .toList();
    expect(deKeys, ['germanOnly', 'languageName', 'unusedKey', 'usedDirect']);
    // Metadata still attached to its key.
    expect(de.indexOf('"@unusedKey"'), greaterThan(de.indexOf('"unusedKey"')));

    // Second run: nothing changes.
    final again = SweepEngine(projectRoot: root).sort();
    expect(again.changedPerFile, {dePath: false, enPath: false});
  });

  test('clean aborts before writing anything if any ARB is invalid', () async {
    final root = copyFixtureToTemp();
    final enPath = p.join(root, 'lib', 'l10n', 'intl_en.arb');
    final badPath = p.join(root, 'lib', 'l10n', 'intl_fr.arb');
    File(badPath).writeAsStringSync('{ not json');
    final before = File(enPath).readAsStringSync();

    await expectLater(
      SweepEngine(projectRoot: root).clean,
      throwsA(isA<ArbParseException>()),
    );
    // The valid file was not touched: all-or-nothing.
    expect(File(enPath).readAsStringSync(), before);
  });
}
