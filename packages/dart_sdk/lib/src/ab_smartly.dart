import 'dart:async';

import 'context_event_logger.dart';
import 'variable_parser.dart';

import 'absmartly_sdk_config.dart';
import 'audience_deserializer.dart';
import 'audience_matcher.dart';
import 'context.dart';
import 'context_config.dart';
import 'context_data_provider.dart';
import 'context_publisher.dart';
import 'java/time/clock.dart';
import 'client.dart';
import 'json/context_data.dart';

class ABSmartly {
  ABSmartly(ABSmartlyConfig config)
      : client_ = config.getClient(),
        contextDataProvider_ = config.getContextDataProvider(),
        contextEventHandler_ = config.getContextEventHandler(),
        contextEventLogger_ = config.getContextEventLogger(),
        variableParser_ = config.getVariableParser(),
        audienceDeserializer_ = config.getAudienceDeserializer();

  Context createContext(ContextConfig config) {
    return Context.create(
        Clock.systemUTC(),
        config,
        contextDataProvider_.getContextData(),
        contextDataProvider_,
        contextEventHandler_,
        variableParser_,
        AudienceMatcher(audienceDeserializer_),
        contextEventLogger_);
  }

  Context createContextWith(ContextConfig config, ContextData data) {
    return Context.create(
        Clock.systemUTC(),
        config,
        Completer<ContextData>()..complete(data),
        contextDataProvider_,
        contextEventHandler_,
        variableParser_,
        AudienceMatcher(audienceDeserializer_),
        contextEventLogger_);
  }

  Future<ContextData> getContextData() {
    return contextDataProvider_.getContextData().future;
  }

  Client client_;
  ContextDataProvider contextDataProvider_;
  ContextPublisher contextEventHandler_;
  ContextEventLogger? contextEventLogger_;
  VariableParser variableParser_;
  AudienceDeserializer audienceDeserializer_;
}
