# Changelog

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
