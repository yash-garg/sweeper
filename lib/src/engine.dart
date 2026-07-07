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

class CleanResult {
  CleanResult({required this.analysis, required this.removedPerFile});

  final SweepResult analysis;

  /// ARB file path → number of keys removed from it (sorted by path).
  final Map<String, int> removedPerFile;
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

  Future<CleanResult> clean({
    List<String> keepPatterns = const [],
    bool dryRun = false,
  }) async {
    final config = SweeperConfig.load(projectRoot);
    final analysis = await analyze(keepPatterns: keepPatterns);

    final arbDir = Directory(config.arbDir);
    if (!arbDir.existsSync()) {
      throw SweeperConfigException('ARB directory not found: ${config.arbDir}');
    }
    final arbPaths = arbDir
        .listSync()
        .whereType<File>()
        .map((f) => f.path)
        .where((path) => path.endsWith('.arb'))
        .toList()
      ..sort();

    // Parse every file BEFORE writing anything: all-or-nothing.
    final documents = [
      for (final path in arbPaths) _parseArb(path),
    ];

    final removedPerFile = <String, int>{};
    for (final doc in documents) {
      var removed = 0;
      for (final key in analysis.unusedKeys) {
        if (doc.removeKey(key)) removed++;
      }
      removedPerFile[doc.path] = removed;
      if (!dryRun) {
        _writeAtomic(doc.path, doc.serialize());
      }
    }
    return CleanResult(analysis: analysis, removedPerFile: removedPerFile);
  }

  void _writeAtomic(String path, String content) {
    final tmp = File('$path.sweeper.tmp');
    tmp.writeAsStringSync(content, flush: true);
    tmp.renameSync(path);
  }

  ArbDocument _parseArb(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw SweeperConfigException('ARB file not found: $path');
    }
    return ArbDocument.parse(path, file.readAsStringSync());
  }
}
