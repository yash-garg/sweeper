# Changelog

## 0.4.1

- `clean` no longer rewrites ARB files it removed nothing from: untouched
  files stay byte-identical instead of being reformatted by re-serialization.
- Hand-written Dart files inside the gen-l10n output directory (e.g.
  `lib/l10n/l10n.dart` helpers) are now scanned for key usage; only the
  generated `<output-localization-file>` and its `_<locale>` variants are
  excluded. Previously, keys used only in such files were wrongly deleted.
- `tool/` scripts are now scanned for key usage.
- Invalid `--keep` globs report a clean error (exit 2) instead of crashing
  with a stack trace.
- `--keep` globs are case-sensitive on every platform; previously they were
  case-insensitive on Windows only.
- `SweepEngine` accepts a relative `projectRoot` instead of throwing a raw
  `ArgumentError`.
- Removing an ARB key with an explicit `null` value is now counted in the
  per-file removal totals.
- Atomic writes use a pid-suffixed temp file (safe under concurrent runs)
  and clean up the temp file on failure.

## 0.4.0

- New `--scan`/`-s` flag on `check` and `clean`: include additional package
  roots (monorepo siblings) when scanning for key usage.
- Pub workspaces are detected automatically: all workspace members are
  scanned for key usage, and the shared root `package_config.json` is found
  by walking up parent directories.

## 0.3.0

- New `sort` command: alphabetizes keys in all ARB files, keeping `@@`
  headers first and `@key` metadata attached to its key.

## 0.2.2

- Widened `analyzer` constraint to `>=10.0.0 <15.0.0` so sweeper can coexist
  with packages pinned to older analyzer majors (e.g. dart_code_linter).
  Full test suite verified against analyzer 10.0.0 and 14.0.0.

## 0.2.1

- README: full commands & flags reference (including `--quiet`).

## 0.2.0

- Hardened detection: the localizations class must be declared in the
  gen-l10n output location (`output-dir` or the legacy `package:flutter_gen`
  synthetic package), so identically-named classes elsewhere never count.
- Colored terminal output (ANSI auto-detected, plain when piped).
- New `--quiet`/`-q` flag on `check` and `clean` to print summaries only.
- Dartdoc for the full public API and a pub.dev example.

## 0.1.0

- Initial release: `check` and `clean` commands with resolved-AST unused-key
  detection, `--keep` globs, `--json`, `--dry-run`, and fail-closed behavior.
