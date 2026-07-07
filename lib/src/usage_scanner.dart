import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:path/path.dart' as p;

import 'exceptions.dart';

class UsageScanException extends SweeperException {
  UsageScanException(super.message);
}

class UsageScanResult {
  UsageScanResult({required this.usedKeys, required this.scannedFileCount});

  final Set<String> usedKeys;
  final int scannedFileCount;
}

/// Finds translation keys that are used, by fully resolving the project and
/// collecting every reference whose element is a getter or method declared
/// on the class named [outputClass] (or a subclass of it).
///
/// Fail-closed: any file that cannot be resolved cleanly aborts the scan.
class UsageScanner {
  UsageScanner({
    required this.projectRoot,
    required this.outputClass,
    required this.excludedDir,
  });

  final String projectRoot;
  final String outputClass;

  /// Generated-code directory (gen-l10n `output-dir`); skipped so the
  /// generated class's own code never counts as usage.
  final String excludedDir;

  static const _scanRoots = ['lib', 'bin', 'test', 'integration_test'];

  Future<UsageScanResult> scan() async {
    final packageConfig =
        File(p.join(projectRoot, '.dart_tool', 'package_config.json'));
    if (!packageConfig.existsSync()) {
      throw UsageScanException(
          'No .dart_tool/package_config.json in $projectRoot. '
          'Run `dart pub get` (or `flutter pub get`) first.');
    }

    final includedPaths = _scanRoots
        .map((dir) => p.join(projectRoot, dir))
        .where((dir) => Directory(dir).existsSync())
        .toList();
    if (includedPaths.isEmpty) {
      throw UsageScanException('No Dart source directories found to scan '
          '(looked for ${_scanRoots.join(', ')} in $projectRoot).');
    }

    final collection = AnalysisContextCollection(includedPaths: includedPaths);
    final usedKeys = <String>{};
    var scannedFileCount = 0;

    for (final context in collection.contexts) {
      for (final path in context.contextRoot.analyzedFiles()) {
        if (!path.endsWith('.dart')) continue;
        if (p.isWithin(excludedDir, path) || p.equals(excludedDir, path)) {
          continue;
        }
        final result = await context.currentSession.getResolvedUnit(path);
        if (result is! ResolvedUnitResult) {
          throw UsageScanException('Could not resolve $path '
              '(${result.runtimeType}). Aborting: results would be '
              'unreliable.');
        }
        final firstError = result.diagnostics
            .where((d) => d.severity == Severity.error)
            .firstOrNull;
        if (firstError != null) {
          throw UsageScanException(
              'Analysis error in $path: ${firstError.message}\n'
              'sweeper fails closed: fix analysis errors and rerun.');
        }
        scannedFileCount++;
        result.unit.accept(_UsageVisitor(outputClass, usedKeys));
      }
    }
    return UsageScanResult(
        usedKeys: usedKeys, scannedFileCount: scannedFileCount);
  }
}

class _UsageVisitor extends RecursiveAstVisitor<void> {
  _UsageVisitor(this.outputClass, this.usedKeys);

  final String outputClass;
  final Set<String> usedKeys;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    // Covers PropertyAccess.propertyName, PrefixedIdentifier.identifier,
    // MethodInvocation.methodName, and tear-offs: all reference sites end
    // in a SimpleIdentifier whose `element` is the resolved declaration.
    final element = node.element;
    // Static members (e.g. the generated `of` factory) are never
    // translation keys — only instance getters/methods are.
    if (element is ExecutableElement && !element.isStatic) {
      final enclosing = element.enclosingElement;
      if (enclosing is InterfaceElement && _isLocalizationsClass(enclosing)) {
        usedKeys.add(element.displayName);
      }
    }
    super.visitSimpleIdentifier(node);
  }

  bool _isLocalizationsClass(InterfaceElement cls) =>
      cls.name == outputClass ||
      cls.allSupertypes.any((type) => type.element.name == outputClass);
}
