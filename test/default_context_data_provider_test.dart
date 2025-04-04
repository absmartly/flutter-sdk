import 'package:absmartly_sdk/client.dart';
import 'package:absmartly_sdk/default_context_data_provider.dart';
import 'package:absmartly_sdk/json/context_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'default_context_data_provider_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<Client>(),
])
void main() {
  group('DefaultContextDataProvider', () {
    test('getContextData', () async {
      final client = MockClient();
      final provider = DefaultContextDataProvider(client);
      final expected = ContextData();
      when(client.getContextData()).thenAnswer((_) => Future.value(expected));

      final dataFuture = provider.getContextData();
      final actual = dataFuture;

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
          dataFuture, throwsA(const TypeMatcher<Exception>()));

      // expect(actual.cause, equals(failure));

      verify(client.getContextData()).called(1);
    });
  });
}
