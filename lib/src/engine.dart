import 'dart:io';

import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

import 'arb.dart';
import 'config.dart';
import 'exceptions.dart';
import 'usage_scanner.dart';
import 'workspace.dart';

/// Thrown when a `--keep` pattern is not a valid glob.
final class KeepPatternException(super.message) extends SweeperException;

/// The outcome of analyzing a project for unused translation keys.
final class SweepResult({
  /// Unused translation keys from the template ARB, sorted.
  required final List<String> unusedKeys,

  /// Total translatable keys in the template ARB.
  required final int totalKeys,

  /// Number of Dart files that were resolved and scanned.
  required final int scannedFileCount,
}) {
  /// Whether any unused keys were found.
  bool get hasUnused => unusedKeys.isNotEmpty;
}

/// The outcome of a [SweepEngine.clean] run.
final class CleanResult({
  /// The analysis the removals were based on.
  required final SweepResult analysis,

  /// ARB file path → number of keys removed from it (sorted by path).
  required final Map<String, int> removedPerFile,
});

/// The outcome of a [SweepEngine.sort] run.
final class SortResult({required final Map<String, bool> changedPerFile}) {
  /// Number of files whose order changed.
  int get changedCount => changedPerFile.values.where((c) => c).length;
}

/// Orchestrates config loading, scanning, and the unused-key computation:
/// unused = templateKeys − usedKeys − keepGlobs.
final class SweepEngine({required String projectRoot}) {
  /// Absolute, normalized path to the project being swept.
  ///
  /// A relative [projectRoot] (the directory containing `l10n.yaml` and
  /// `pubspec.yaml`) is resolved against the current working directory.
  final String projectRoot = p.normalize(p.absolute(projectRoot));

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
        // Keys are not paths: force posix syntax and case-sensitivity so
        // patterns behave identically on every platform (the default
        // platform context is case-insensitive on Windows).
        return Glob(pattern, context: p.posix, caseSensitive: true);
      } on FormatException catch (e) {
        throw KeepPatternException(
          'Invalid keep pattern "$pattern": ${e.message}',
        );
      }
    }

    final keepGlobs = keepPatterns.map(parseGlob).toList();
    bool isKept(String key) => keepGlobs.any((g) => g.matches(key));

    final unused =
        templateKeys
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
    final analysis = await analyze(
      keepPatterns: keepPatterns,
      scanRoots: scanRoots,
    );

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
    final arbPaths =
        arbDir
            .listSync()
            .whereType<File>()
            .map((f) => f.path)
            .where((path) => path.endsWith('.arb'))
            .toList()
          ..sort();
    return [for (final path in arbPaths) _parseArb(path)];
  }

  void _writeAtomic(String path, String content) {
    // Pid-suffixed so concurrent sweeper runs never share a tmp file.
    final tmp = File('$path.$pid.sweeper.tmp');
    try {
      tmp.writeAsStringSync(content, flush: true);
      tmp.renameSync(path);
    } catch (_) {
      if (tmp.existsSync()) tmp.deleteSync();
      rethrow;
    }
  }

  ArbDocument _parseArb(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw SweeperConfigException('ARB file not found: $path');
    }
    return ArbDocument.parse(path, file.readAsStringSync());
  }
}
