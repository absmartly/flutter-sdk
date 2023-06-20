library ab_smartly;

import 'dart:async';

import 'package:ab_smartly/variable_parser.dart';

import 'ab_smartly_config.dart';
import 'audience_deserializer.dart';
import 'audience_matcher.dart';
import 'context.dart';
import 'context_config.dart';
import 'context_data_provider.dart';
import 'context_event_handler.dart';
import 'default_audience_deserializer.dart';
import 'default_context_data_provider.dart';
import 'default_context_event_handler.dart';
import 'default_variable_parser.dart';
import 'java/time/clock.dart';
import 'java_system_classes/closeable.dart';
import 'client.dart';
import 'json/context_data.dart';

class ABSmartly implements Closeable {
  ABSmartly(ABSmartlyConfig config) {
    contextDataProvider_ = config.getContextDataProvider();
    contextEventHandler_ = config.getContextEventHandler();
    variableParser_ = config.getVariableParser();
    audienceDeserializer_ = config.getAudienceDeserializer();
    scheduler_ = config.getScheduler();

    if ((contextDataProvider_ == null) || (contextEventHandler_ == null)) {
      client_ = config.getClient();
      if (client_ == null) {
        throw Exception("Missing Client instance");
      }

      contextDataProvider_ ??= DefaultContextDataProvider(client_!);

      contextEventHandler_ ??= DefaultContextEventHandler(client_!);
    }

    variableParser_ ??= DefaultVariableParser();

    audienceDeserializer_ ??= DefaultAudienceDeserializer();


    if (scheduler_ == null) {
      // scheduler_ = new ScheduledThreadPoolExecutor(1);
    }
  }

   Context createContext(ContextConfig config) {
    return Context.create(Clock.systemUTC(), config, scheduler_, contextDataProvider_!.getContextData(),
        contextDataProvider_!, contextEventHandler_!, variableParser_!,
        AudienceMatcher(audienceDeserializer_!));
  }

  Context createContextWith(ContextConfig config, ContextData data) {
    return Context.create(Clock.systemUTC(), config, scheduler_!, Future.value(data),
        contextDataProvider_!, contextEventHandler_!, variableParser_!,
        AudienceMatcher(audienceDeserializer_!));
  }

  Future<ContextData?> getContextData() {
    return contextDataProvider_!.getContextData();
  }

  @override
  Future<void> close() async {
    if (client_ != null) {
      client_!.close();
      client_ = null;
    }

    if (scheduler_ != null) {
      try {

        await Future.delayed(const Duration(milliseconds: 5000));
        // scheduler_.awaitTermination(5000, TimeUnit.MILLISECONDS);
      }
    catch(e) {}
    scheduler_ = null;
    }
    client_?.close();
  }

  Client? client_;
  ContextDataProvider? contextDataProvider_;
  late ContextEventHandler? contextEventHandler_;
  // late ContextEventLogger contextEventLogger_;
  late VariableParser? variableParser_;
  late AudienceDeserializer? audienceDeserializer_;

  //late ScheduledExecutorService scheduler_;

  Timer? scheduler_;

  void scheduleTask() {
    scheduler_ = Timer(const Duration(seconds: 5), () {});
  }
}
