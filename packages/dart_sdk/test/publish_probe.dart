import 'dart:async';
import 'dart:convert';

import 'package:absmartly_dart/src/audience_matcher.dart';
import 'package:absmartly_dart/src/context.dart';
import 'package:absmartly_dart/src/context_config.dart';
import 'package:absmartly_dart/src/context_data_provider.dart';
import 'package:absmartly_dart/src/context_publisher.dart';
import 'package:absmartly_dart/src/default_audience_deserializer.dart';
import 'package:absmartly_dart/src/default_context_data_serializer.dart';
import 'package:absmartly_dart/src/default_context_event_serializer.dart';
import 'package:absmartly_dart/src/default_variable_parser.dart';
import 'package:absmartly_dart/src/java/time/clock.dart';
import 'package:absmartly_dart/src/json/context_data.dart';
import 'package:absmartly_dart/src/json/publish_event.dart';

class BytesPublisher implements ContextPublisher {
  final List<String> bodies = [];

  @override
  Completer<void> publish(Context context, PublishEvent event) {
    bodies.add(utf8.decode(DefaultContextEventSerializer().serialize(event)!));
    return Completer<void>()..complete();
  }
}

class NoDataProvider implements ContextDataProvider {
  @override
  Completer<ContextData> getContextData() => Completer<ContextData>();
}

Future<String> publishProbe(List<int> payload) async {
  final data =
      DefaultContextDataDeserializer().deserialize(payload, 0, payload.length)!;
  final publisher = BytesPublisher();
  final context = Context.create(
      Clock.fixed(1620000000000),
      ContextConfig.create()
        ..setUnit('session_id', 'e791e240fcd3df7d238cfc285f475e8152fcc0ec')
        ..setUnit('user_id', '123456789')
        ..setUnit('email', 'bleh@absmartly.com')
        ..setPublishDelay(-1)
        ..setOverride('exp_test_new', 1)
        ..setCustomAssignment('exp_test_abc', 1),
      Completer<ContextData>()..complete(data),
      NoDataProvider(),
      publisher,
      DefaultVariableParser(),
      AudienceMatcher(DefaultAudienceDeserializer()),
      null);
  await context.waitUntilReady();

  context.setAttribute('age', 30);
  for (final name in context.getExperiments()) {
    context.peekTreatment(name);
    context.getTreatment(name);
    context.getTreatment(name);
  }
  for (final key in context.getVariableKeys().keys) {
    context.peekVariableValue(key, 'default');
    context.getVariableValue(key, 'default');
  }
  context.track('goal', {'amount': 1});
  await context.publish();
  return publisher.bodies.single;
}
