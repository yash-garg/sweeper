import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'exceptions.dart';

final class SweeperConfigException(super.message) extends SweeperException;

/// gen-l10n settings sweeper needs, read from `l10n.yaml`.
final class SweeperConfig({
  /// Absolute path to the directory containing `.arb` files.
  required final String arbDir,

  /// Absolute path to the template `.arb` file (the canonical key list).
  required final String templateArbPath,

  /// Name of the generated localizations class (e.g. `AppLocalizations`).
  required final String outputClass,

  /// Absolute path to the generated-code directory (excluded from scanning).
  required final String outputDir,

  /// Basename of the generated localizations file without its extension
  /// (e.g. `app_localizations`). gen-l10n writes `<stem>.dart` plus
  /// `<stem>_<locale>.dart` per locale into [outputDir]; only those files
  /// are excluded from usage scanning.
  required final String outputFileStem,
}) {
  static SweeperConfig load(String projectRoot) {
    final file = File(p.join(projectRoot, 'l10n.yaml'));
    if (!file.existsSync()) {
      throw SweeperConfigException(
        'No l10n.yaml found in $projectRoot. sweeper requires a '
        'flutter_localizations/gen-l10n setup.',
      );
    }
    final Object? yaml;
    try {
      yaml = loadYaml(file.readAsStringSync());
    } on YamlException catch (e) {
      throw SweeperConfigException('Could not parse l10n.yaml: ${e.message}');
    }
    final map = switch (yaml) {
      YamlMap() && final YamlMap m => m,
      null => null,
      _ => throw SweeperConfigException('l10n.yaml must be a YAML map.'),
    };

    String? readString(String key) => switch (map?[key]) {
      null => null,
      final String s => s,
      _ => throw SweeperConfigException('l10n.yaml: "$key" must be a string.'),
    };

    final arbDir = p.normalize(
      p.join(projectRoot, readString('arb-dir') ?? 'lib/l10n'),
    );
    final outputDirValue = readString('output-dir');
    return SweeperConfig(
      arbDir: arbDir,
      templateArbPath: p.join(
        arbDir,
        readString('template-arb-file') ?? 'app_en.arb',
      ),
      outputClass: readString('output-class') ?? 'AppLocalizations',
      outputDir: outputDirValue == null
          ? arbDir
          : p.normalize(p.join(projectRoot, outputDirValue)),
      outputFileStem: p.basenameWithoutExtension(
        readString('output-localization-file') ?? 'app_localizations.dart',
      ),
    );
  }
}
