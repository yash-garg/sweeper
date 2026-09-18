import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:path/path.dart' as p;

import 'exceptions.dart';
import 'workspace.dart';

final class UsageScanException(super.message) extends SweeperException;

final class UsageScanResult({
  required final Set<String> usedKeys,
  required final int scannedFileCount,
});

/// Finds translation keys that are used, by fully resolving the project and
/// collecting every reference whose element is a getter or method declared
/// on the class named [outputClass] (or a subclass of it).
///
/// Fail-closed: any file that cannot be resolved cleanly aborts the scan.
final class UsageScanner({
  required final String projectRoot,
  required final String outputClass,

  /// Generated-code directory (gen-l10n `output-dir`); generated files in
  /// it are skipped so the generated class's own code never counts as
  /// usage.
  required final String excludedDir,

  /// Basename (without extension) of the generated localizations file
  /// (gen-l10n `output-localization-file`). Only `<stem>.dart` and
  /// `<stem>_<locale>.dart` inside [excludedDir] are skipped, so
  /// hand-written Dart files living in the same directory still count
  /// as usage.
  required final String outputFileStem,

  /// Additional package roots (e.g. monorepo siblings) whose sources are
  /// also scanned for usage.
  final List<String> extraRoots = const [],
}) {
  static const _scanRoots = ['lib', 'bin', 'test', 'integration_test', 'tool'];

  Future<UsageScanResult> scan() async {
    if (findPackageConfig(projectRoot) == null) {
      throw UsageScanException(
        'No .dart_tool/package_config.json found for $projectRoot. '
        'Run `dart pub get` (or `flutter pub get`) first.',
      );
    }

    for (final root in extraRoots) {
      if (!Directory(root).existsSync()) {
        throw UsageScanException('Scan root not found: $root');
      }
    }

    final includedPaths = [
      for (final root in [projectRoot, ...extraRoots])
        for (final dir in _scanRoots.map((d) => p.join(root, d)))
          if (Directory(dir).existsSync()) dir,
    ];
    if (includedPaths.isEmpty) {
      throw UsageScanException(
        'No Dart source directories found to scan '
        '(looked for ${_scanRoots.join(', ')} in $projectRoot).',
      );
    }

    final collection = AnalysisContextCollection(includedPaths: includedPaths);
    final usedKeys = <String>{};
    var scannedFileCount = 0;

    for (final context in collection.contexts) {
      for (final path in context.contextRoot.analyzedFiles()) {
        if (!path.endsWith('.dart')) continue;
        if (_isGeneratedFile(path)) continue;
        final result = await context.currentSession.getResolvedUnit(path);
        if (result is! ResolvedUnitResult) {
          throw UsageScanException(
            'Could not resolve $path '
            '(${result.runtimeType}). Aborting: results would be '
            'unreliable.',
          );
        }
        final firstError = result.diagnostics
            .where((d) => d.severity == Severity.error)
            .firstOrNull;
        if (firstError != null) {
          throw UsageScanException(
            'Analysis error in $path: ${firstError.message}\n'
            'sweeper fails closed: fix analysis errors and rerun.',
          );
        }
        scannedFileCount++;
        result.unit.accept(_UsageVisitor(outputClass, excludedDir, usedKeys));
      }
    }
    return UsageScanResult(
      usedKeys: usedKeys,
      scannedFileCount: scannedFileCount,
    );
  }

  /// True for gen-l10n output files: `<stem>.dart` or `<stem>_*.dart`
  /// inside the output directory. Anything else in that directory is
  /// hand-written and must be scanned like any other source.
  bool _isGeneratedFile(String path) {
    if (!p.isWithin(excludedDir, path)) return false;
    final base = p.basename(path);
    return base == '$outputFileStem.dart' ||
        (base.startsWith('${outputFileStem}_') && base.endsWith('.dart'));
  }
}

final class _UsageVisitor(
  final String outputClass,

  /// Directory the generated localizations code lives in (`output-dir`).
  final String generatedDir,
  final Set<String> usedKeys,
) extends RecursiveAstVisitor<void> {
  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    // Covers PropertyAccess.propertyName, PrefixedIdentifier.identifier,
    // MethodInvocation.methodName, and tear-offs: all reference sites end
    // in a SimpleIdentifier whose `element` is the resolved declaration.
    // Static members (e.g. the generated `of` factory) are never
    // translation keys — only instance getters/methods are.
    if (node.element case final ExecutableElement element
        when !element.isStatic) {
      if (element.enclosingElement case final InterfaceElement enclosing
          when _isLocalizationsClass(enclosing)) {
        usedKeys.add(element.displayName);
      }
    }
    super.visitSimpleIdentifier(node);
  }

  bool _isLocalizationsClass(InterfaceElement cls) =>
      _isGeneratedRoot(cls) ||
      cls.allSupertypes.any((type) => _isGeneratedRoot(type.element));

  /// True only for the real gen-l10n class: right name AND declared where
  /// gen-l10n generates code (`output-dir`, or the legacy synthetic
  /// `package:flutter_gen` package). An identically-named class declared
  /// anywhere else never matches.
  bool _isGeneratedRoot(InterfaceElement cls) {
    if (cls.name != outputClass) return false;
    final library = cls.library;
    final uri = library.uri;
    if (uri.scheme == 'package' && uri.path.startsWith('flutter_gen/')) {
      return true;
    }
    final path = library.firstFragment.source.fullName;
    return p.isWithin(generatedDir, path);
  }
}
