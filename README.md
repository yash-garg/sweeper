# sweeper

[![pub package](https://img.shields.io/pub/v/sweeper.svg)](https://pub.dev/packages/sweeper)
[![CI](https://github.com/yash-garg/sweeper/actions/workflows/ci.yaml/badge.svg)](https://github.com/yash-garg/sweeper/actions/workflows/ci.yaml)

Finds and removes unused gen-l10n translation keys from ARB files — using
**resolved static analysis**, not name heuristics, so a key is only reported
unused when no real reference to its generated getter/method exists.

## Install

```sh
dart pub add --dev sweeper
```

## Usage

Run from your project root (where `l10n.yaml` lives), after `pub get`:

```sh
# List unused keys. Exits 1 if any are found (CI-friendly), 0 otherwise.
dart run sweeper check
dart run sweeper check --json

# Delete unused keys (and their @key metadata) from every ARB file.
dart run sweeper clean
dart run sweeper clean --dry-run   # preview without writing

# Keys accessed dynamically at runtime can't be seen statically — keep them:
dart run sweeper check --keep 'dynamicGreeting*,languageName'
```

Zero configuration: sweeper reads `arb-dir`, `template-arb-file`,
`output-class`, and `output-dir` from your `l10n.yaml`.

## Commands & flags

### `sweeper check`

Lists unused translation keys. Exits `1` if any are found.

| Flag | | Description |
| --- | --- | --- |
| `--keep` | `-k` | Keys to always treat as used. Comma-separated; globs allowed (e.g. `error_*`). Repeatable. |
| `--json` | | Machine-readable JSON output: `{"unused": [...], "scannedFiles": N, "totalKeys": N}`. |
| `--quiet` | `-q` | Print the summary only, without listing keys. |

### `sweeper clean`

Deletes unused keys — and their `@key` metadata — from **every** ARB file in
`arb-dir`, preserving key order and formatting. All files are parsed before
any is written (all-or-nothing), and writes are atomic.

| Flag | | Description |
| --- | --- | --- |
| `--keep` | `-k` | Keys to always treat as used. Comma-separated; globs allowed. Repeatable. |
| `--dry-run` | `-n` | Show what would be removed without writing files. |
| `--quiet` | `-q` | Print the summary only, without listing keys or per-file counts. |

### `sweeper sort`

Sorts the keys of every ARB file alphabetically. `@@locale`-style header
entries stay first, and `@key` metadata stays attached to its key. Files
already in order are left untouched. Always exits `0` (or `2` on error).

| Flag | | Description |
| --- | --- | --- |
| `--quiet` | `-q` | Print summary only, without listing changed files. |

Output is colored when attached to a terminal and plain when piped or in CI.

## How it works

sweeper resolves your project with the Dart analyzer and counts a key as
used only when a reference's resolved element belongs to your generated
localizations class (or a locale subclass). This catches
`AppLocalizations.of(context).key`, `widget.l10n.key`, aliased variables,
and tear-offs — and never miscounts identically-named members on unrelated
classes.

**Fail-closed:** if any file can't be resolved (analysis errors, missing
`pub get`), sweeper aborts with exit code 2 instead of guessing.

## Exit codes

| Code | Meaning                     |
| ---- | --------------------------- |
| 0    | No unused keys              |
| 1    | Unused keys found           |
| 2    | Environment or config error |

## Scope

ARB + `flutter_localizations`/gen-l10n only.
