import 'package:absmartly_sdk/audience_matcher.dart';
import 'package:absmartly_sdk/default_audience_deserializer.dart';
import 'package:flutter_test/flutter_test.dart';

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

    // test('evaluateReturnsBoolean', () {
    //   expect(matcher.evaluate('{"filter":{"value":5}}', null), isTrue);
    //   // expect(matcher.evaluate('{"filter":[{"value":true}]}', null), isTrue);
    //   // expect(matcher.evaluate('{"filter":[{"value":1}]}', null), isTrue);
    //   // expect(matcher.evaluate('{"filter":[{"value":null}]}', null), isFalse);
    //   // expect(matcher.evaluate('{"filter":[{"value":0}]}', null), isFalse);
    //
    //   // expect(
    //   //     matcher.evaluate('{"filter":[{"not":{"var":"returning"}}]}', {'returning': true}),
    //   //     isFalse);
    //   // expect(
    //   //     matcher.evaluate('{"filter":[{"not":{"var":"returning"}}]}', {'returning': false}),
    //   //     isTrue);
    // });

    test('evaluate returns null when audience is an empty string', () {
      final result = audienceMatcher.evaluate('', {});
      expect(result, isNull);
    });

    test('evaluate returns null when deserializer returns null', () {
      final result = audienceMatcher.evaluate('invalid', {});
      expect(result, isNull);
    });

    test('evaluate returns null when filter is not a Map or a List', () {
      final result = audienceMatcher.evaluate('{"filter": "invalid"}', {});
      expect(result, isNull);
    });

    // not working

    // test('evaluate returns false when filter is an empty Map', () {
    //   final result = audienceMatcher.evaluate('{}', {});
    //   expect(result?.get(), isFalse);
    // });
    //
    // test('evaluate returns true when filter matches a single attribute in attributes', () {
    //
    //   final result = audienceMatcher.evaluate('{"filter": {"attribute1": "value1"}}', {});
    //   expect(result?.get(), isTrue);
    // });
    //
  });
}
