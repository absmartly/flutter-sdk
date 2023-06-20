import 'package:ab_smartly/client.mocks.dart';
import 'package:ab_smartly/context.mocks.dart';
import 'package:ab_smartly/default_context_event_handler.dart';
import 'package:ab_smartly/java/time/clock.dart';
import 'package:ab_smartly/json/publish_event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

// all working

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
      when(client.publish(event)).thenAnswer((_) => Future.value(null));

      final dataFuture = eventHandler.publish(context, event);
      final actual = await dataFuture;

      // expect(actual, isNull);
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
      final failedFuture = Future<void>.error(failure) ;
      when(client.publish(event)).thenAnswer((_){
       return failedFuture;
      });

      final publishFuture = eventHandler.publish(context, event);
      final actual = await expectLater(
          publishFuture, throwsA(TypeMatcher<Exception>()));
      // expect(actual.cause, equals(failure));

      verify(client.publish(event)).called(1);
    });
  });
}
