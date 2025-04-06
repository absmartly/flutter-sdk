import 'dart:async';

import 'package:absmartly_sdk/context.dart';
import 'package:absmartly_sdk/client.dart';
import 'package:absmartly_sdk/default_context_event_handler.dart';
import 'package:absmartly_sdk/java/time/clock.dart';
import 'package:absmartly_sdk/json/publish_event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'default_context_event_handler_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<Context>(),
  MockSpec<Client>(),
])
void main() {
  group('DefaultContextEventHandler', () {
    test('publish', () async {
      final context = MockContext();
      final client = MockClient();
      final eventHandler = DefaultContextEventHandler(client);

      final event = PublishEvent(
        hashed: true,
        units: [],
        publishedAt: Clock.systemUTC().millis(),
        exposures: [],
        goals: [],
        attributes: [],
      );

      final completer = Completer<void>();
      completer.complete();
      when(client.publish(event)).thenReturn(completer);

      final dataFuture = eventHandler.publish(context, event);
      await dataFuture.future;

      verify(client.publish(event)).called(1);
    });

    test('publishExceptionally', () async {
      final context = MockContext();
      final client = MockClient();
      final eventHandler = DefaultContextEventHandler(client);
      final event = PublishEvent(
        hashed: true,
        units: [],
        publishedAt: Clock.systemUTC().millis(),
        exposures: [],
        goals: [],
        attributes: [],
      );

      final failure = Exception('FAILED');
      final completer = Completer<void>();
      completer.completeError(failure);
      when(client.publish(event)).thenReturn(completer);

      final publishFuture = eventHandler.publish(context, event);
      await expectLater(
          publishFuture.future, throwsA(const TypeMatcher<Exception>()));

      verify(client.publish(event)).called(1);
    });
  });
}
