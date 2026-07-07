/// A class that happens to share the generated localizations class name but
/// is NOT the gen-l10n output (it lives outside `output-dir`). Member access
/// on it must never count as translation-key usage.
class L10n {
  String get dynamicGreetingA => 'not a translation';
}
