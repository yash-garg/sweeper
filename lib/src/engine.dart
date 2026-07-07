import 'dart:io';

import 'package:glob/glob.dart';

import 'arb.dart';
import 'config.dart';
import 'usage_scanner.dart';

class SweepResult {
  SweepResult({
    required this.unusedKeys,
    required this.totalKeys,
    required this.scannedFileCount,
  });

  /// Unused translation keys from the template ARB, sorted.
  final List<String> unusedKeys;

  /// Total translatable keys in the template ARB.
  final int totalKeys;

  final int scannedFileCount;

  bool get hasUnused => unusedKeys.isNotEmpty;
}

/// Orchestrates config loading, scanning, and the unused-key computation:
/// unused = templateKeys − usedKeys − keepGlobs.
class SweepEngine {
  SweepEngine({required this.projectRoot});

  final String projectRoot;

  Future<SweepResult> analyze({List<String> keepPatterns = const []}) async {
    final config = SweeperConfig.load(projectRoot);
    final template = _parseArb(config.templateArbPath);
    final templateKeys = template.translationKeys;

    final scan = await UsageScanner(
      projectRoot: projectRoot,
      outputClass: config.outputClass,
      excludedDir: config.outputDir,
    ).scan();

    final keepGlobs = keepPatterns.map(Glob.new).toList();
    bool isKept(String key) => keepGlobs.any((g) => g.matches(key));

    final unused = templateKeys
        .where((key) => !scan.usedKeys.contains(key) && !isKept(key))
        .toList()
      ..sort();

    return SweepResult(
      unusedKeys: unused,
      totalKeys: templateKeys.length,
      scannedFileCount: scan.scannedFileCount,
    );
  }

  ArbDocument _parseArb(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw SweeperConfigException('ARB file not found: $path');
    }
    return ArbDocument.parse(path, file.readAsStringSync());
  }
}
