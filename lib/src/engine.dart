import 'dart:io';

import 'package:glob/glob.dart';

import 'arb.dart';
import 'config.dart';
import 'usage_scanner.dart';

/// The outcome of analyzing a project for unused translation keys.
class SweepResult {
  /// Creates a result; see the field docs for the meaning of each value.
  SweepResult({
    required this.unusedKeys,
    required this.totalKeys,
    required this.scannedFileCount,
  });

  /// Unused translation keys from the template ARB, sorted.
  final List<String> unusedKeys;

  /// Total translatable keys in the template ARB.
  final int totalKeys;

  /// Number of Dart files that were resolved and scanned.
  final int scannedFileCount;

  /// Whether any unused keys were found.
  bool get hasUnused => unusedKeys.isNotEmpty;
}

/// The outcome of a [SweepEngine.clean] run.
class CleanResult {
  /// Creates a result; see the field docs for the meaning of each value.
  CleanResult({required this.analysis, required this.removedPerFile});

  /// The analysis the removals were based on.
  final SweepResult analysis;

  /// ARB file path → number of keys removed from it (sorted by path).
  final Map<String, int> removedPerFile;
}

/// Orchestrates config loading, scanning, and the unused-key computation:
/// unused = templateKeys − usedKeys − keepGlobs.
class SweepEngine {
  /// Creates an engine for the package at [projectRoot] (the directory
  /// containing `l10n.yaml` and `pubspec.yaml`).
  SweepEngine({required this.projectRoot});

  /// Absolute path to the project being swept.
  final String projectRoot;

  /// Finds unused translation keys without modifying anything.
  ///
  /// Keys matching any glob in [keepPatterns] are treated as used.
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

  /// Removes unused translation keys (and their `@key` metadata) from every
  /// ARB file in the configured ARB directory.
  ///
  /// All files are parsed before any is written (all-or-nothing), and writes
  /// are atomic. With [dryRun], nothing is written and the returned
  /// [CleanResult] describes what would have been removed.
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
