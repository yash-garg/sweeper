import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:sweeper/src/engine.dart';
import 'package:sweeper/src/exceptions.dart';
import 'package:sweeper/src/reporter.dart';

Future<void> main(List<String> arguments) async {
  final runner = CommandRunner<int>(
    'sweeper',
    'Finds and removes unused gen-l10n translation keys from ARB files '
        'using resolved static analysis.',
  )
    ..addCommand(_CheckCommand())
    ..addCommand(_CleanCommand());

  try {
    exitCode = await runner.run(arguments) ?? 0;
  } on UsageException catch (e) {
    stderr.writeln(e);
    exitCode = 64;
  } on SweeperException catch (e) {
    stderr.writeln('Error: ${e.message}');
    exitCode = 2;
  }
}

List<String> _keepPatterns(ArgResults results) =>
    (results['keep'] as List<String>)
        .expand((value) => value.split(','))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();

Reporter _reporter(ArgResults results) => Reporter(
      stdout,
      ansi: stdout.supportsAnsiEscapes,
      quiet: results['quiet'] as bool,
    );

class _CheckCommand extends Command<int> {
  _CheckCommand() {
    argParser
      ..addMultiOption('keep',
          abbr: 'k',
          help: 'Keys to always treat as used (comma-separated; '
              'globs like error_* allowed).')
      ..addFlag('json',
          help: 'Emit machine-readable JSON output.', negatable: false)
      ..addFlag('quiet',
          abbr: 'q',
          help: 'Print summary only, without listing keys.',
          negatable: false);
  }

  @override
  String get name => 'check';

  @override
  String get description =>
      'List unused translation keys. Exits 1 if any are found.';

  @override
  Future<int> run() async {
    final results = argResults!;
    final result = await SweepEngine(projectRoot: Directory.current.path)
        .analyze(keepPatterns: _keepPatterns(results));
    if (results['json'] as bool) {
      Reporter(stdout).checkJson(result);
    } else {
      _reporter(results).checkHuman(result);
    }
    return result.hasUnused ? 1 : 0;
  }
}

class _CleanCommand extends Command<int> {
  _CleanCommand() {
    argParser
      ..addMultiOption('keep',
          abbr: 'k',
          help: 'Keys to always treat as used (comma-separated; '
              'globs like error_* allowed).')
      ..addFlag('dry-run',
          abbr: 'n',
          help: 'Show what would be removed without writing files.',
          negatable: false)
      ..addFlag('quiet',
          abbr: 'q',
          help: 'Print summary only, without listing keys.',
          negatable: false);
  }

  @override
  String get name => 'clean';

  @override
  String get description =>
      'Delete unused translation keys (and @key metadata) from all ARB files.';

  @override
  Future<int> run() async {
    final results = argResults!;
    final dryRun = results['dry-run'] as bool;
    final result = await SweepEngine(projectRoot: Directory.current.path)
        .clean(keepPatterns: _keepPatterns(results), dryRun: dryRun);
    _reporter(results).clean(result, dryRun: dryRun);
    return result.analysis.hasUnused ? 1 : 0;
  }
}
