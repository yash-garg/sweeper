import 'dart:io';

import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

import 'arb.dart';
import 'config.dart';
import 'exceptions.dart';
import 'usage_scanner.dart';
import 'workspace.dart';

/// Thrown when a `--keep` pattern is not a valid glob.
class KeepPatternException extends SweeperException {
  KeepPatternException(super.message);
}

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

/// The outcome of a [SweepEngine.sort] run.
class SortResult {
  /// Creates a result; see the field docs for the meaning of each value.
  SortResult({required this.changedPerFile});

  /// ARB file path → whether sorting changed its key order.
  final Map<String, bool> changedPerFile;

  /// Number of files whose order changed.
  int get changedCount => changedPerFile.values.where((c) => c).length;
}

/// Orchestrates config loading, scanning, and the unused-key computation:
/// unused = templateKeys − usedKeys − keepGlobs.
class SweepEngine {
  /// Creates an engine for the package at [projectRoot] (the directory
  /// containing `l10n.yaml` and `pubspec.yaml`). A relative path is
  /// resolved against the current working directory.
  SweepEngine({required String projectRoot})
      : projectRoot = p.normalize(p.absolute(projectRoot));

  /// Absolute, normalized path to the project being swept.
  final String projectRoot;

  /// Finds unused translation keys without modifying anything.
  ///
  /// Keys matching any glob in [keepPatterns] are treated as used. Sources
  /// in [scanRoots] (additional package roots, e.g. monorepo siblings) are
  /// scanned for usage alongside the project's own.
  Future<SweepResult> analyze({
    List<String> keepPatterns = const [],
    List<String> scanRoots = const [],
  }) async {
    final config = SweeperConfig.load(projectRoot);
    final template = _parseArb(config.templateArbPath);
    final templateKeys = template.translationKeys;

    final scan = await UsageScanner(
      projectRoot: projectRoot,
      outputClass: config.outputClass,
      excludedDir: config.outputDir,
      outputFileStem: config.outputFileStem,
      extraRoots: {
        ...scanRoots,
        // Pub workspace members share the translations' resolution; their
        // usage counts automatically.
        ...discoverWorkspaceMembers(projectRoot),
      }.toList(),
    ).scan();

    Glob parseGlob(String pattern) {
      try {
        return Glob(pattern);
      } on FormatException catch (e) {
        throw KeepPatternException(
            'Invalid keep pattern "$pattern": ${e.message}');
      }
    }

    final keepGlobs = keepPatterns.map(parseGlob).toList();
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
    List<String> scanRoots = const [],
    bool dryRun = false,
  }) async {
    final config = SweeperConfig.load(projectRoot);
    final analysis =
        await analyze(keepPatterns: keepPatterns, scanRoots: scanRoots);

    final documents = _arbDocuments(config);

    final removedPerFile = <String, int>{};
    for (final doc in documents) {
      var removed = 0;
      for (final key in analysis.unusedKeys) {
        if (doc.removeKey(key)) removed++;
      }
      removedPerFile[doc.path] = removed;
      // Only rewrite files something was removed from: serialization
      // normalizes formatting, so untouched files must stay byte-identical.
      if (!dryRun && removed > 0) {
        _writeAtomic(doc.path, doc.serialize());
      }
    }
    return CleanResult(analysis: analysis, removedPerFile: removedPerFile);
  }

  /// Alphabetizes the keys of every ARB file in the configured ARB
  /// directory, keeping `@@` header entries first and `@key` metadata
  /// attached to its key. Files already in order are not rewritten.
  SortResult sort() {
    final config = SweeperConfig.load(projectRoot);
    final changedPerFile = <String, bool>{};
    for (final doc in _arbDocuments(config)) {
      final changed = doc.sortKeys();
      changedPerFile[doc.path] = changed;
      if (changed) {
        _writeAtomic(doc.path, doc.serialize());
      }
    }
    return SortResult(changedPerFile: changedPerFile);
  }

  /// Parses every `.arb` file in the ARB directory (sorted by path) BEFORE
  /// anything is written: all-or-nothing.
  List<ArbDocument> _arbDocuments(SweeperConfig config) {
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
    return [for (final path in arbPaths) _parseArb(path)];
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
