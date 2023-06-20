import 'package:ab_smartly/client.mocks.dart';
import 'package:ab_smartly/context.dart';
import 'package:ab_smartly/default_context_data_provider.dart';
import 'package:ab_smartly/json/context_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

//  all working

void main() {
  group('DefaultContextDataProvider', () {
    test('getContextData', () async {
      final client = MockClient();
      final provider = DefaultContextDataProvider(client);
      final expected = ContextData();
      when(client.getContextData())
          .thenAnswer((_) => Future.value(expected));

      final dataFuture = provider.getContextData();
      final actual = await dataFuture;

      expect(actual, equals(expected));
      expect(identical(expected, actual), isTrue);
    });

    test('getContextDataExceptionally', () async {
      final client = MockClient();
      final provider = DefaultContextDataProvider(client);

      final failure = Exception('FAILED');
      final Future<ContextData> failedFuture = Future.error(failure);
      when(client.getContextData()).thenAnswer((_) => failedFuture);

      final dataFuture = provider.getContextData();
      final actual = await expectLater(
          dataFuture, throwsA(TypeMatcher<Exception>()));

      // expect(actual.cause, equals(failure));

      verify(client.getContextData()).called(1);
    });
  });
}