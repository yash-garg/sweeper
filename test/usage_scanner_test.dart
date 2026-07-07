import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sweeper/src/usage_scanner.dart';
import 'package:test/test.dart';

void main() {
  final fixtureRoot =
      p.normalize(p.absolute(p.join('test', 'fixtures', 'demo_app')));

  setUpAll(() {
    final result = Process.runSync('dart', ['pub', 'get'],
        workingDirectory: fixtureRoot);
    expect(result.exitCode, 0, reason: result.stderr.toString());
  });

  test('detects all resolved usages of the localizations class', () async {
    final scanner = UsageScanner(
      projectRoot: fixtureRoot,
      outputClass: 'L10n',
      excludedDir: p.join(fixtureRoot, 'lib', 'l10n'),
    );
    final result = await scanner.scan();
    expect(result.usedKeys, {
      'usedDirect',
      'usedViaAlias',
      'itemCount',
      'usedViaField',
      'usedOnSubclass',
    });
    // Only main.dart is scanned; lib/l10n is excluded.
    expect(result.scannedFileCount, 1);
  });

  test('throws when pub get has not been run', () async {
    final tmp = Directory.systemTemp.createTempSync('sweeper_nopub_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    File(p.join(tmp.path, 'pubspec.yaml'))
        .writeAsStringSync('name: nopub\nenvironment:\n  sdk: ^3.5.0\n');
    final scanner = UsageScanner(
      projectRoot: tmp.path,
      outputClass: 'L10n',
      excludedDir: p.join(tmp.path, 'lib', 'l10n'),
    );
    expect(
      scanner.scan,
      throwsA(isA<UsageScanException>()
          .having((e) => e.message, 'message', contains('pub get'))),
    );
  });
}
