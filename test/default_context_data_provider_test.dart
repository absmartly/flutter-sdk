import 'dart:async';

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

      final completer = Completer<ContextData>();
      completer.complete(expected);
      when(client.getContextData()).thenReturn(completer);

      final dataFuture = provider.getContextData();
      final actual = await dataFuture.future;

      expect(actual, equals(expected));
      expect(identical(expected, actual), isTrue);
    });

    test('getContextDataExceptionally', () async {
      final client = MockClient();
      final provider = DefaultContextDataProvider(client);

      final failure = Exception('FAILED');
      final completer = Completer<ContextData>();
      completer.completeError(failure);
      when(client.getContextData()).thenReturn(completer);

      final dataFuture = provider.getContextData();
      await expectLater(
          dataFuture.future, throwsA(const TypeMatcher<Exception>()));

      verify(client.getContextData()).called(1);
    });
  });
}
