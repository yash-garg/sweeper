import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sweeper/src/usage_scanner.dart';
import 'package:test/test.dart';

void main() {
  final fixtureRoot =
      p.normalize(p.absolute(p.join('test', 'fixtures', 'demo_app')));

  setUpAll(() {
    final result =
        Process.runSync('dart', ['pub', 'get'], workingDirectory: fixtureRoot);
    expect(result.exitCode, 0, reason: result.stderr.toString());
  });

  test('detects all resolved usages of the localizations class', () async {
    final scanner = UsageScanner(
      projectRoot: fixtureRoot,
      outputClass: 'L10n',
      excludedDir: p.join(fixtureRoot, 'lib', 'l10n'),
      outputFileStem: 'l10n',
    );
    final result = await scanner.scan();
    expect(result.usedKeys, {
      'usedDirect',
      'usedViaAlias',
      'itemCount',
      'usedViaField',
      'usedOnSubclass',
    });
    // main.dart, impostor.dart, impostor_usage.dart; lib/l10n is excluded.
    expect(result.scannedFileCount, 3);
  });

  test('scans hand-written Dart files inside the output directory', () async {
    final tmp = Directory.systemTemp.createTempSync('sweeper_arbdir_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    File(p.join(tmp.path, 'pubspec.yaml'))
        .writeAsStringSync('name: arbdirscan\nenvironment:\n  sdk: ^3.5.0\n');
    Directory(p.join(tmp.path, 'lib', 'l10n')).createSync(recursive: true);
    // Simulated generated files: must NOT count as usage.
    File(p.join(tmp.path, 'lib', 'l10n', 'l10n.dart')).writeAsStringSync('''
class L10n {
  String get fromHelper => 'used only by the helper file';
  String get fromMain => 'used only by main';
  String get selfReference => fromHelper; // generated code never counts
}
''');
    File(p.join(tmp.path, 'lib', 'l10n', 'l10n_de.dart')).writeAsStringSync('''
import 'l10n.dart';

class L10nDe extends L10n {
  @override
  String get fromMain => 'von main';
}
''');
    // Hand-written helper in the same directory: MUST count as usage.
    File(p.join(tmp.path, 'lib', 'l10n', 'extensions.dart'))
        .writeAsStringSync('''
import 'l10n.dart';

String helper(L10n l10n) => l10n.fromHelper;
''');
    File(p.join(tmp.path, 'lib', 'main.dart')).writeAsStringSync('''
import 'l10n/l10n.dart';

void main() => print(L10n().fromMain);
''');
    final pub =
        Process.runSync('dart', ['pub', 'get'], workingDirectory: tmp.path);
    expect(pub.exitCode, 0, reason: pub.stderr.toString());

    final result = await UsageScanner(
      projectRoot: tmp.path,
      outputClass: 'L10n',
      excludedDir: p.join(tmp.path, 'lib', 'l10n'),
      outputFileStem: 'l10n',
    ).scan();
    // fromHelper found via extensions.dart; selfReference (used only
    // inside the generated files) stays unused.
    expect(result.usedKeys, {'fromHelper', 'fromMain'});
    // main.dart and extensions.dart; l10n.dart and l10n_de.dart skipped.
    expect(result.scannedFileCount, 2);
  });

  test('scans tool/ scripts', () async {
    final tmp = Directory.systemTemp.createTempSync('sweeper_toolscan_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    File(p.join(tmp.path, 'pubspec.yaml'))
        .writeAsStringSync('name: toolscan\nenvironment:\n  sdk: ^3.5.0\n');
    Directory(p.join(tmp.path, 'lib', 'l10n')).createSync(recursive: true);
    Directory(p.join(tmp.path, 'tool')).createSync();
    File(p.join(tmp.path, 'lib', 'l10n', 'l10n.dart')).writeAsStringSync('''
class L10n {
  String get fromTool => 'used only by a tool script';
  String get neverUsed => 'unused';
}
''');
    File(p.join(tmp.path, 'tool', 'report.dart')).writeAsStringSync('''
import '../lib/l10n/l10n.dart';

void main() => print(L10n().fromTool);
''');
    final pub =
        Process.runSync('dart', ['pub', 'get'], workingDirectory: tmp.path);
    expect(pub.exitCode, 0, reason: pub.stderr.toString());

    final result = await UsageScanner(
      projectRoot: tmp.path,
      outputClass: 'L10n',
      excludedDir: p.join(tmp.path, 'lib', 'l10n'),
      outputFileStem: 'l10n',
    ).scan();
    expect(result.usedKeys, {'fromTool'});
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
      outputFileStem: 'l10n',
    );
    expect(
      scanner.scan,
      throwsA(
        isA<UsageScanException>()
            .having((e) => e.message, 'message', contains('pub get')),
      ),
    );
  });

  test('fails closed when a file has analysis errors', () async {
    final brokenRoot =
        p.normalize(p.absolute(p.join('test', 'fixtures', 'broken_app')));
    final pub =
        Process.runSync('dart', ['pub', 'get'], workingDirectory: brokenRoot);
    expect(pub.exitCode, 0, reason: pub.stderr.toString());

    final scanner = UsageScanner(
      projectRoot: brokenRoot,
      outputClass: 'L10n',
      excludedDir: p.join(brokenRoot, 'lib', 'l10n'),
      outputFileStem: 'l10n',
    );
    expect(
      scanner.scan,
      throwsA(
        isA<UsageScanException>()
            .having((e) => e.message, 'message', contains('main.dart')),
      ),
    );
  });
}
