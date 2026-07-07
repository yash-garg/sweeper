import 'l10n/l10n.dart';

/// Simulates a widget holding a localizations instance in a field.
class Holder {
  Holder(this.l10n);

  final L10n l10n;

  String title() => l10n.usedViaField;
}

/// Unrelated class with members named like translation keys.
/// Resolved detection must NOT count these as usage.
class Unrelated {
  String get unusedKey => 'not a translation';
  String get languageName => 'not a translation';
  String unusedPlain() => 'not a translation';
}

void main() {
  final context = Object();
  // Direct access through the static factory.
  print(L10n.of(context).usedDirect);
  // Access through an arbitrarily-named local variable.
  final texts = L10n.of(context);
  print(texts.usedViaAlias);
  // Placeholder message = method invocation.
  print(texts.itemCount(3));
  // Access through a field on another object.
  print(Holder(L10n()).title());
  // Access through a variable statically typed as a locale subclass.
  final L10nDe de = L10nDe();
  print(de.usedOnSubclass);
  // Same-named members on an unrelated class: must not mark keys used.
  final other = Unrelated();
  print(other.unusedKey);
  print(other.languageName);
  print(other.unusedPlain());
}
