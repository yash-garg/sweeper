import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sweeper/src/config.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('sweeper_config_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  void writeL10nYaml(String content) =>
      File(p.join(tmp.path, 'l10n.yaml')).writeAsStringSync(content);

  test('loads explicit values from l10n.yaml', () {
    writeL10nYaml('''
arb-dir: lib/l10n
template-arb-file: intl_en.arb
output-class: L10n
output-dir: lib/generated
output-localization-file: l10n.dart
''');
    final config = SweeperConfig.load(tmp.path);
    expect(config.arbDir, p.join(tmp.path, 'lib/l10n'));
    expect(config.templateArbPath, p.join(tmp.path, 'lib/l10n/intl_en.arb'));
    expect(config.outputClass, 'L10n');
    expect(config.outputDir, p.join(tmp.path, 'lib/generated'));
    expect(config.outputFileStem, 'l10n');
  });

  test('applies gen-l10n defaults for missing keys', () {
    writeL10nYaml('arb-dir: lib/l10n\n');
    final config = SweeperConfig.load(tmp.path);
    expect(config.templateArbPath, p.join(tmp.path, 'lib/l10n/app_en.arb'));
    expect(config.outputClass, 'AppLocalizations');
    expect(config.outputDir, config.arbDir);
    expect(config.outputFileStem, 'app_localizations');
  });

  test('empty l10n.yaml falls back to all defaults', () {
    writeL10nYaml('');
    final config = SweeperConfig.load(tmp.path);
    expect(config.arbDir, p.join(tmp.path, 'lib/l10n'));
  });

  test('throws SweeperConfigException when l10n.yaml is missing', () {
    expect(
      () => SweeperConfig.load(tmp.path),
      throwsA(isA<SweeperConfigException>()
          .having((e) => e.message, 'message', contains('l10n.yaml'))),
    );
  });

  test('throws SweeperConfigException on malformed yaml', () {
    writeL10nYaml('arb-dir: [unclosed\n');
    expect(() => SweeperConfig.load(tmp.path),
        throwsA(isA<SweeperConfigException>()));
  });
}
