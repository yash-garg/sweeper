# Using sweeper

sweeper is a CLI tool. Add it as a dev dependency and run it from your
project root (the directory containing `l10n.yaml`), after `pub get`.

```sh
dart pub add --dev sweeper
```

## Check for unused keys (CI-friendly)

```sh
$ dart run sweeper check
✗ 3 unused translation keys:
  oldBanner
  welcomeV1
  wizardHint
1114 keys · 3 unused · 439 files scanned
```

Exits `1` when unused keys are found, `0` when clean, `2` on environment or
config errors — so it can gate CI directly:

```yaml
# e.g. in GitHub Actions
- run: dart run sweeper check --quiet
```

Machine-readable output:

```sh
$ dart run sweeper check --json
{"unused":["oldBanner","welcomeV1","wizardHint"],"scannedFiles":439,"totalKeys":1114}
```

## Remove unused keys

Preview first, then clean. `clean` removes each unused key and its `@key`
metadata from **every** ARB file, preserving formatting and key order:

```sh
dart run sweeper clean --dry-run
dart run sweeper clean
```

## Keys accessed dynamically

Static analysis cannot see keys whose names are constructed at runtime.
Keep those explicitly (globs allowed):

```sh
dart run sweeper clean --keep 'notification_*,brandName'
```

## Library usage

The engine is also available as a library:

```dart
import 'package:sweeper/sweeper.dart';

Future<void> main() async {
  final result = await SweepEngine(projectRoot: '.').analyze();
  print(result.unusedKeys);
}
```
