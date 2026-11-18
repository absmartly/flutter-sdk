// Port of java-sdk SwitchbackAttributePathTest. The fixture
// test/resources/switchback/attribute-path-cases.json is copied byte-for-byte
// from absmartly/abs 9bd2b5ca35
// collector/src/test/resources/switchback/attribute-path-cases.json (git blob
// 7b1d3fed5985), via java-sdk core-api/src/test/resources.
import 'package:absmartly_dart/src/internal/switchback_attribute_path.dart';
import 'package:test/test.dart';

import 'fixture_loader.dart';

SwitchbackAttributePath path(String p) =>
    SwitchbackAttributePath.parseSupported(p)!;

void main() {
  test('matchesEveryPathCase', () async {
    final fixture =
        await loadJsonResource('switchback/attribute-path-cases.json')
            as Map<String, dynamic>;
    final attributes = fixture['attributes'] as Map<String, dynamic>;
    final List cases = fixture['cases'] as List;
    expect(cases, hasLength(7));

    for (final c in cases) {
      final parsed =
          SwitchbackAttributePath.parseSupported(c['path'] as String);
      if (!(c['supported'] as bool)) {
        expect(parsed, isNull, reason: '$c');
        continue;
      }
      expect(parsed, isNotNull, reason: '$c');
      expect(parsed!.resolve(attributes), c['value'], reason: '$c');
    }
  });

  test('quotedSegmentsAreLiteralKeys', () {
    final attributes = {
      'geo': {'0': 'zero', 'a/b': 'slash'}
    };
    expect(path("geo/'0'").resolve(attributes), 'zero');
    expect(path('geo/"a/b"').resolve(attributes), 'slash');
  });

  // Malformed paths are unsupported, which makes the experiment unservable:
  // an unterminated quote anywhere, or a '.' anywhere, quoted or not.
  test('rejectsMalformedPaths', () {
    for (final p in [
      "geo/'0",
      "'geo",
      '"geo/city',
      'geo/"',
      'geo.city',
      'geo/a.b',
      'a./b',
      '.',
      'items/0.5/city',
      "'geo.city'",
      '"geo.city"',
      "geo/'a.b'"
    ]) {
      expect(SwitchbackAttributePath.parseSupported(p), isNull, reason: p);
    }
  });

  test('separatorsAreCollapsed', () {
    final attributes = {
      'geo': {'city': 'Porto'}
    };
    expect(path('/geo//city/').resolve(attributes), 'Porto');
    expect(path('geo').resolve(attributes), attributes['geo']);
  });

  test('rejectsUnsupportedPaths', () {
    for (final p in [
      null,
      '',
      '/',
      '//',
      '0/city',
      'items/0',
      'items/0/1/city',
      'items/-1/city',
      "'"
    ]) {
      expect(SwitchbackAttributePath.parseSupported(p), isNull, reason: '$p');
    }
  });

  test('indexSegmentsReadOnlyListsAndKeySegmentsReadOnlyMaps', () {
    final attributes = {
      'items': [
        {'city': 'Lisbon'}
      ],
      'geo': {
        '0': {'city': 'zero'}
      },
      'name': 'scalar',
    };
    expect(path('geo/0/city').resolve(attributes), isNull);
    expect(path('items/1/city').resolve(attributes), isNull);
    expect(path('name/x').resolve(attributes), isNull);
    expect(path('missing/x').resolve(attributes), isNull);
    expect(path('items/-0/city').resolve(attributes), 'Lisbon');
  });

  test('cyclicOrTooDeepValuesHaveNoKey', () {
    final p = path('geo/city');

    final Map<String, dynamic> self = {'city': 'Porto'};
    self['self'] = self;
    expect(p.resolveAttribute(self), isNull);

    final Map<String, dynamic> outer = {'city': 'Porto'};
    outer['items'] = [
      [outer]
    ];
    expect(p.resolveAttribute(outer), isNull);

    // 65 nested maps: one past the depth bound.
    Map<String, dynamic> deep = {'leaf': 'x'};
    for (int i = 0; i < 64; ++i) {
      deep = {'city': 'Porto', 'next': deep};
    }
    expect(p.resolveAttribute(deep), isNull);
    expect(p.resolveAttribute(deep['next']), 'Porto');

    // A value reached twice through siblings is not a cycle.
    final shared = {'a': 'b'};
    expect(p.resolveAttribute({'city': 'Porto', 'x': shared, 'y': shared}),
        'Porto');
  });

  // A value is read through its JSON encoding, the form it is published in.
  test('valuesAreReadThroughTheirJsonEncoding', () {
    final p = path('geo/city');
    expect(p.resolveAttribute(Object()), isNull);
    expect(
        p.resolveAttribute({
          'city': {'a': 1}.keys
        }),
        isNull);
    expect(p.resolveAttribute('scalar'), isNull);
    expect(path('city').resolveAttribute('Porto'), 'Porto');
    expect(path('city').resolveAttribute(42), 42);
  });

  test('tryParseIntFollowsGuava', () {
    expect(SwitchbackAttributePath.tryParseInt('0'), 0);
    expect(SwitchbackAttributePath.tryParseInt('-0'), 0);
    expect(SwitchbackAttributePath.tryParseInt('007'), 7);
    expect(SwitchbackAttributePath.tryParseInt('2147483647'), 2147483647);
    expect(SwitchbackAttributePath.tryParseInt('-2147483648'), -2147483648);
    for (final s in [
      '',
      '-',
      '+1',
      '1a',
      ' 1',
      '2147483648',
      '-2147483649',
      '99999999999999999999',
      '٠',
      '1.0'
    ]) {
      expect(SwitchbackAttributePath.tryParseInt(s), isNull, reason: s);
    }
  });
}
