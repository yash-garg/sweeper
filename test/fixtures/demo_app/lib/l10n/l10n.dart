class L10n {
  String get languageName => 'English';
  String get usedDirect => 'Used directly';
  String get usedViaField => 'Used via a field';
  String get usedViaAlias => 'Used via an aliased variable';
  String get usedOnSubclass => 'Used through a locale subclass';
  String itemCount(int count) => '$count items';
  String get unusedKey => 'Never referenced';
  String get unusedPlain => 'Never referenced, no metadata';
  String get dynamicGreetingA => 'Accessed dynamically at runtime';
  String get dynamicGreetingB => 'Accessed dynamically at runtime';

  static L10n of(Object context) => L10n();
}

class L10nDe extends L10n {
  @override
  String get usedDirect => 'Direkt benutzt';
}
