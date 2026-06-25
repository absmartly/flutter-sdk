import 'package:absmartly_dart/src/audience_matcher.dart';
import 'package:absmartly_dart/src/default_audience_deserializer.dart';
import 'package:test/test.dart';

void main() {
  final audienceMatcher = AudienceMatcher(DefaultAudienceDeserializer());

  group('AudienceMatcherTest', () {
    test('evaluateReturnsNullOnEmptyAudience', () {
      expect(audienceMatcher.evaluate('', null), isNull);
      expect(audienceMatcher.evaluate('{}', null), isNull);
      expect(audienceMatcher.evaluate('null', null), isNull);
    });

    test('evaluateReturnsNullIfFilterNotMapOrList', () {
      expect(audienceMatcher.evaluate('{"filter":null}', null), isNull);
      expect(audienceMatcher.evaluate('{"filter":false}', null), isNull);
      expect(audienceMatcher.evaluate('{"filter":5}', null), isNull);
      expect(audienceMatcher.evaluate('{"filter":"a"}', null), isNull);
    });

    test('evaluateReturnsBooleanForValueExpressions', () {
      // Test with truthy values
      expect(audienceMatcher.evaluate('{"filter":[{"value":5}]}', null)?.get(),
          isTrue);
      expect(
          audienceMatcher.evaluate('{"filter":[{"value":true}]}', null)?.get(),
          isTrue);
      expect(audienceMatcher.evaluate('{"filter":[{"value":1}]}', null)?.get(),
          isTrue);

      // Test with falsy values
      expect(
          audienceMatcher.evaluate('{"filter":[{"value":null}]}', null)?.get(),
          isFalse);
      expect(audienceMatcher.evaluate('{"filter":[{"value":0}]}', null)?.get(),
          isFalse);
      expect(
          audienceMatcher.evaluate('{"filter":[{"value":false}]}', null)?.get(),
          isFalse);
    });

    test('evaluateReturnsBooleanForVarExpressions', () {
      // Test not operator with var
      expect(
          audienceMatcher.evaluate('{"filter":[{"not":{"var":"returning"}}]}',
              {'returning': true})?.get(),
          isFalse);
      expect(
          audienceMatcher.evaluate('{"filter":[{"not":{"var":"returning"}}]}',
              {'returning': false})?.get(),
          isTrue);
    });

    test('evaluateWithMapFilter', () {
      // Filter as map (single expression)
      expect(audienceMatcher.evaluate('{"filter":{"value":true}}', null)?.get(),
          isTrue);
      expect(
          audienceMatcher.evaluate('{"filter":{"value":false}}', null)?.get(),
          isFalse);
    });

    test('evaluateWithComplexExpressions', () {
      final attributes = {'age': 25, 'country': 'US', 'returning': true};

      // Test equality check
      expect(
          audienceMatcher
              .evaluate(
                  '{"filter":[{"eq":[{"var":"country"},{"value":"US"}]}]}',
                  attributes)
              ?.get(),
          isTrue);

      expect(
          audienceMatcher
              .evaluate(
                  '{"filter":[{"eq":[{"var":"country"},{"value":"UK"}]}]}',
                  attributes)
              ?.get(),
          isFalse);
    });

    test('evaluateWithComparisonOperators', () {
      final attributes = {'age': 25};

      // Greater than or equal
      expect(
          audienceMatcher
              .evaluate('{"filter":[{"gte":[{"var":"age"},{"value":18}]}]}',
                  attributes)
              ?.get(),
          isTrue);

      expect(
          audienceMatcher
              .evaluate('{"filter":[{"gte":[{"var":"age"},{"value":30}]}]}',
                  attributes)
              ?.get(),
          isFalse);

      // Less than
      expect(
          audienceMatcher
              .evaluate('{"filter":[{"lt":[{"var":"age"},{"value":30}]}]}',
                  attributes)
              ?.get(),
          isTrue);
    });

    test('evaluateWithAndConditions', () {
      final attributes = {'age': 25, 'country': 'US'};

      // Both conditions true (implicit AND with list)
      expect(
          audienceMatcher
              .evaluate(
                  '{"filter":[{"eq":[{"var":"country"},{"value":"US"}]},{"gte":[{"var":"age"},{"value":18}]}]}',
                  attributes)
              ?.get(),
          isTrue);

      // One condition false
      expect(
          audienceMatcher
              .evaluate(
                  '{"filter":[{"eq":[{"var":"country"},{"value":"UK"}]},{"gte":[{"var":"age"},{"value":18}]}]}',
                  attributes)
              ?.get(),
          isFalse);
    });

    test('evaluateWithOrConditions', () {
      final attributes = {'age': 25, 'country': 'US'};

      // OR condition - one true
      expect(
          audienceMatcher
              .evaluate(
                  '{"filter":[{"or":[[{"eq":[{"var":"country"},{"value":"UK"}]}],[{"eq":[{"var":"country"},{"value":"US"}]}]]}]}',
                  attributes)
              ?.get(),
          isTrue);

      // OR condition - both false
      expect(
          audienceMatcher
              .evaluate(
                  '{"filter":[{"or":[[{"eq":[{"var":"country"},{"value":"UK"}]}],[{"eq":[{"var":"country"},{"value":"DE"}]}]]}]}',
                  attributes)
              ?.get(),
          isFalse);
    });

    test('evaluateReturnsNullOnInvalidJson', () {
      expect(audienceMatcher.evaluate('invalid json', null), isNull);
      expect(audienceMatcher.evaluate('{invalid}', null), isNull);
    });

    test('evaluateWithNullAttributes', () {
      // Should work with null attributes when not accessing vars
      expect(
          audienceMatcher.evaluate('{"filter":[{"value":true}]}', null)?.get(),
          isTrue);
    });

    test('evaluateWithMissingAttribute', () {
      final attributes = {'name': 'John'};

      // Accessing non-existent attribute
      expect(
          audienceMatcher
              .evaluate('{"filter":[{"var":"age"}]}', attributes)
              ?.get(),
          isFalse);
    });

    test('evaluateWithStringContains', () {
      final attributes = {'name': 'John Doe'};

      // in operator with string: haystack-first (haystack, needle) - checks if haystack contains needle
      expect(
          audienceMatcher
              .evaluate('{"filter":[{"in":[{"var":"name"},{"value":"John"}]}]}',
                  attributes)
              ?.get(),
          isTrue);

      expect(
          audienceMatcher
              .evaluate('{"filter":[{"in":[{"var":"name"},{"value":"Jane"}]}]}',
                  attributes)
              ?.get(),
          isFalse);
    });

    test('evaluateWithMatchOperator', () {
      final attributes = {'email': 'test@example.com'};

      expect(
          audienceMatcher
              .evaluate(
                  '{"filter":[{"match":[{"var":"email"},{"value":".*@example\\\\.com"}]}]}',
                  attributes)
              ?.get(),
          isTrue);

      expect(
          audienceMatcher
              .evaluate(
                  '{"filter":[{"match":[{"var":"email"},{"value":".*@other\\\\.com"}]}]}',
                  attributes)
              ?.get(),
          isFalse);
    });

    test('evaluateWithNullOperator', () {
      final attributesWithNull = {'value': null};
      final attributesWithValue = {'value': 'test'};

      expect(
          audienceMatcher
              .evaluate(
                  '{"filter":[{"null":{"var":"value"}}]}', attributesWithNull)
              ?.get(),
          isTrue);

      expect(
          audienceMatcher
              .evaluate(
                  '{"filter":[{"null":{"var":"value"}}]}', attributesWithValue)
              ?.get(),
          isFalse);
    });
  });
}
