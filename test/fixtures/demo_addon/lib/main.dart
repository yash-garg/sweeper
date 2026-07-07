import 'package:demo_app/l10n/l10n.dart';

/// Uses a key that demo_app itself never references. Only visible to
/// sweeper when this package is included via --scan.
String addonText() => L10n().unusedPlain;
