import 'package:sweeper/src/arb.dart';
import 'package:test/test.dart';

const source = '''
{
  "@@locale": "en",
  "greeting": "Hello",
  "@greeting": {
    "description": "A greeting"
  },
  "farewell": "Bye",
  "itemCount": "{count} items",
  "@itemCount": {
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  }
}
''';

void main() {
  test('translationKeys excludes @-prefixed entries, preserves order', () {
    final doc = ArbDocument.parse('a.arb', source);
    expect(doc.translationKeys, ['greeting', 'farewell', 'itemCount']);
  });

  test('serialize round-trips unchanged content exactly', () {
    final doc = ArbDocument.parse('a.arb', source);
    expect(doc.serialize(), source);
  });

  test('removeKey removes key and its @key metadata', () {
    final doc = ArbDocument.parse('a.arb', source);
    expect(doc.removeKey('greeting'), isTrue);
    expect(doc.serialize(), isNot(contains('"greeting"')));
    expect(doc.serialize(), isNot(contains('"@greeting"')));
    expect(doc.translationKeys, ['farewell', 'itemCount']);
  });

  test('removeKey returns false for absent key', () {
    final doc = ArbDocument.parse('a.arb', source);
    expect(doc.removeKey('nope'), isFalse);
  });

  test('preserves 4-space indentation', () {
    const wide = '{\n    "a": "x",\n    "b": "y"\n}\n';
    final doc = ArbDocument.parse('a.arb', wide);
    doc.removeKey('b');
    expect(doc.serialize(), '{\n    "a": "x"\n}\n');
  });

  test('preserves absence of trailing newline', () {
    const compact = '{\n  "a": "x"\n}';
    expect(ArbDocument.parse('a.arb', compact).serialize(), compact);
  });

  test('sortKeys orders keys alphabetically, header first, metadata attached',
      () {
    const unsorted = '''
{
  "@@locale": "en",
  "zebra": "Z",
  "@zebra": {
    "description": "z"
  },
  "apple": "A",
  "mango": "M"
}
''';
    final doc = ArbDocument.parse('a.arb', unsorted);
    expect(doc.sortKeys(), isTrue);
    expect(doc.serialize(), '''
{
  "@@locale": "en",
  "apple": "A",
  "mango": "M",
  "zebra": "Z",
  "@zebra": {
    "description": "z"
  }
}
''');
  });

  test('sortKeys returns false when already sorted', () {
    const sorted = '{\n  "@@locale": "en",\n  "a": "x",\n  "b": "y"\n}\n';
    final doc = ArbDocument.parse('a.arb', sorted);
    expect(doc.sortKeys(), isFalse);
    expect(doc.serialize(), sorted);
  });

  test('throws ArbParseException on invalid JSON, naming the file', () {
    expect(
      () => ArbDocument.parse('bad.arb', '{ not json'),
      throwsA(isA<ArbParseException>()
          .having((e) => e.message, 'message', contains('bad.arb'))),
    );
  });

  test('throws ArbParseException when root is not an object', () {
    expect(() => ArbDocument.parse('bad.arb', '[1, 2]'),
        throwsA(isA<ArbParseException>()));
  });
}
