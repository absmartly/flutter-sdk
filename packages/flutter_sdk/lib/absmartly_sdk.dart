// The names this library exported in 2.1, and no others: an app that defines
// a class of the same name as a newer SDK type and imports this library must
// keep compiling. Each shim below shows only its 2.1 names. The full API is in
// package:absmartly_sdk/absmartly.dart.
export 'absmartly_sdk_config.dart';
export 'context.dart';
export 'client.dart';
export 'json/context_data.dart';
export 'context_event_handler.dart';
export 'context_data_provider.dart';
export 'default_context_data_provider.dart';
export 'default_context_event_handler.dart';
export 'json/attribute.dart';
export 'json/experiment.dart';
export 'json/experiment_variant.dart';
export 'json/exposure.dart';
export 'json/goal_achievement.dart';
export 'json/publish_event.dart';
export 'json/unit.dart';
