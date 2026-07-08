import 'dart:io';

import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Finds the `.dart_tool/package_config.json` governing [projectRoot] by
/// walking up parent directories, mirroring the analyzer's own lookup.
/// Returns null when none exists (pub get has not been run).
String? findPackageConfig(String projectRoot) {
  var dir = p.normalize(p.absolute(projectRoot));
  while (true) {
    final candidate = p.join(dir, '.dart_tool', 'package_config.json');
    if (File(candidate).existsSync()) return candidate;
    final parent = p.dirname(dir);
    if (parent == dir) return null;
    dir = parent;
  }
}

/// Discovers pub workspace members sharing a workspace with [projectRoot].
///
/// If [projectRoot]'s pubspec declares `resolution: workspace`, walks up to
/// the workspace root pubspec (the one with a `workspace:` list), expands
/// its entries (glob patterns supported), and returns the absolute roots of
/// all members except [projectRoot] itself. Returns an empty list when the
/// project is not a workspace member.
List<String> discoverWorkspaceMembers(String projectRoot) {
  final root = p.normalize(p.absolute(projectRoot));
  if (_pubspecOf(root)?['resolution'] != 'workspace') return const [];

  var dir = p.dirname(root);
  while (true) {
    final pubspec = _pubspecOf(dir);
    final workspace = pubspec?['workspace'];
    if (workspace is YamlList) {
      return _expandMembers(dir, workspace).where((m) => m != root).toList();
    }
    final parent = p.dirname(dir);
    if (parent == dir) return const [];
    dir = parent;
  }
}

List<String> _expandMembers(String workspaceRoot, YamlList entries) {
  final members = <String>[];
  for (final entry in entries) {
    if (entry is! String) continue;
    if (Glob.quote(entry) == entry) {
      // Plain path, no glob characters.
      members.add(p.normalize(p.join(workspaceRoot, entry)));
      continue;
    }
    final matches = Glob(entry).listSync(root: workspaceRoot);
    members.addAll(matches
        .whereType<Directory>()
        .map((d) => p.normalize(p.absolute(d.path))),);
  }
  return [
    for (final m in members)
      if (File(p.join(m, 'pubspec.yaml')).existsSync()) m,
  ];
}

Map<Object?, Object?>? _pubspecOf(String dir) {
  final file = File(p.join(dir, 'pubspec.yaml'));
  if (!file.existsSync()) return null;
  try {
    final yaml = loadYaml(file.readAsStringSync());
    return yaml is YamlMap ? yaml : null;
  } on YamlException {
    return null;
  }
}
