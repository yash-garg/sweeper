import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'exceptions.dart';

class SweeperConfigException extends SweeperException {
  SweeperConfigException(super.message);
}

/// gen-l10n settings sweeper needs, read from `l10n.yaml`.
class SweeperConfig {
  SweeperConfig({
    required this.arbDir,
    required this.templateArbPath,
    required this.outputClass,
    required this.outputDir,
  });

  /// Absolute path to the directory containing `.arb` files.
  final String arbDir;

  /// Absolute path to the template `.arb` file (the canonical key list).
  final String templateArbPath;

  /// Name of the generated localizations class (e.g. `AppLocalizations`).
  final String outputClass;

  /// Absolute path to the generated-code directory (excluded from scanning).
  final String outputDir;

  static SweeperConfig load(String projectRoot) {
    final file = File(p.join(projectRoot, 'l10n.yaml'));
    if (!file.existsSync()) {
      throw SweeperConfigException(
          'No l10n.yaml found in $projectRoot. sweeper requires a '
          'flutter_localizations/gen-l10n setup.');
    }
    final Object? yaml;
    try {
      yaml = loadYaml(file.readAsStringSync());
    } on YamlException catch (e) {
      throw SweeperConfigException('Could not parse l10n.yaml: ${e.message}');
    }
    if (yaml != null && yaml is! YamlMap) {
      throw SweeperConfigException('l10n.yaml must be a YAML map.');
    }
    final map = yaml as YamlMap?;

    String? readString(String key) {
      final value = map?[key];
      if (value == null) return null;
      if (value is! String) {
        throw SweeperConfigException('l10n.yaml: "$key" must be a string.');
      }
      return value;
    }

    final arbDir =
        p.normalize(p.join(projectRoot, readString('arb-dir') ?? 'lib/l10n'));
    final outputDirValue = readString('output-dir');
    return SweeperConfig(
      arbDir: arbDir,
      templateArbPath:
          p.join(arbDir, readString('template-arb-file') ?? 'app_en.arb'),
      outputClass: readString('output-class') ?? 'AppLocalizations',
      outputDir: outputDirValue == null
          ? arbDir
          : p.normalize(p.join(projectRoot, outputDirValue)),
    );
  }
}
