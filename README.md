# sweeper

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

Zero configuration: sweeper reads `arb-dir`, `template-arb-file`, and
`output-class` from your `l10n.yaml`.

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
