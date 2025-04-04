library absmartly_sdk;

import 'dart:async';

import 'package:absmartly_sdk/context_event_logger.dart';
import 'package:absmartly_sdk/variable_parser.dart';

import 'absmartly_sdk_config.dart';
import 'audience_deserializer.dart';
import 'audience_matcher.dart';
import 'context.dart';
import 'context_config.dart';
import 'context_data_provider.dart';
import 'context_event_handler.dart';
import 'java/time/clock.dart';
import 'client.dart';
import 'json/context_data.dart';

class ABSmartly {
  ABSmartly(ABSmartlyConfig config) {
    contextDataProvider_ = config.getContextDataProvider();
    contextEventHandler_ = config.getContextEventHandler();
    contextEventLogger_ = config.getContextEventLogger();
    variableParser_ = config.getVariableParser();
    audienceDeserializer_ = config.getAudienceDeserializer();
    client_ = config.getClient();

    if (client_ == null) {
      throw Exception("Missing Client instance");
    }
  }

  Context createContext(ContextConfig config) {
    return Context.create(
        Clock.systemUTC(),
        config,
        contextDataProvider_!.getContextData(),
        contextDataProvider_!,
        contextEventHandler_!,
        variableParser_!,
        AudienceMatcher(audienceDeserializer_!),
        contextEventLogger_);
  }

  Context createContextWith(ContextConfig config, ContextData data) {
    return Context.create(
        Clock.systemUTC(),
        config,
        Completer<ContextData>()..complete(data),
        contextDataProvider_!,
        contextEventHandler_!,
        variableParser_!,
        AudienceMatcher(audienceDeserializer_!),
        contextEventLogger_);
  }

  Completer<ContextData> getContextData() {
    return contextDataProvider_!.getContextData();
  }

  Client? client_;
  late ContextDataProvider? contextDataProvider_;
  late ContextEventHandler? contextEventHandler_;
  late ContextEventLogger? contextEventLogger_;
  late VariableParser? variableParser_;
  late AudienceDeserializer? audienceDeserializer_;
}
