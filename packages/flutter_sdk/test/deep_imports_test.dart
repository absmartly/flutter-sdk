// ignore_for_file: unused_import, unnecessary_import
import 'package:absmartly_sdk/ab_smartly.dart';
import 'package:absmartly_sdk/absmartly_sdk.dart';
import 'package:absmartly_sdk/absmartly_sdk_config.dart';
import 'package:absmartly_sdk/audience_deserializer.dart';
import 'package:absmartly_sdk/audience_matcher.dart';
import 'package:absmartly_sdk/client.dart';
import 'package:absmartly_sdk/client_config.dart';
import 'package:absmartly_sdk/context.dart';
import 'package:absmartly_sdk/context_config.dart';
import 'package:absmartly_sdk/context_data_deserializer.dart';
import 'package:absmartly_sdk/context_data_provider.dart';
import 'package:absmartly_sdk/context_event_handler.dart';
import 'package:absmartly_sdk/context_event_logger.dart';
import 'package:absmartly_sdk/context_event_serializer.dart';
import 'package:absmartly_sdk/default_audience_deserializer.dart';
import 'package:absmartly_sdk/default_context_data_provider.dart';
import 'package:absmartly_sdk/default_context_data_serializer.dart';
import 'package:absmartly_sdk/default_context_event_handler.dart';
import 'package:absmartly_sdk/default_context_event_serializer.dart';
import 'package:absmartly_sdk/default_http_client.dart';
import 'package:absmartly_sdk/default_http_client_config.dart';
import 'package:absmartly_sdk/default_variable_parser.dart';
import 'package:absmartly_sdk/executor.dart';
import 'package:absmartly_sdk/generated/assets.dart';
import 'package:absmartly_sdk/http_client.dart';
import 'package:absmartly_sdk/http_version_policy.dart';
import 'package:absmartly_sdk/internal/algorithm.dart';
import 'package:absmartly_sdk/internal/buffers.dart';
import 'package:absmartly_sdk/internal/hashing/hashing.dart';
import 'package:absmartly_sdk/internal/hashing/md5.dart';
import 'package:absmartly_sdk/internal/hashing/murmur3_32.dart';
import 'package:absmartly_sdk/internal/variant_assigner.dart';
import 'package:absmartly_sdk/java/time/clock.dart';
import 'package:absmartly_sdk/java/time/internal/fixed_clock.dart';
import 'package:absmartly_sdk/java/time/internal/system_clock_utc.dart';
import 'package:absmartly_sdk/java/util/objects.dart';
import 'package:absmartly_sdk/json/attribute.dart';
import 'package:absmartly_sdk/json/context_data.dart';
import 'package:absmartly_sdk/json/experiment.dart';
import 'package:absmartly_sdk/json/experiment_application.dart';
import 'package:absmartly_sdk/json/experiment_variant.dart';
import 'package:absmartly_sdk/json/exposure.dart';
import 'package:absmartly_sdk/json/goal_achievement.dart';
import 'package:absmartly_sdk/json/publish_event.dart';
import 'package:absmartly_sdk/json/unit.dart';
import 'package:absmartly_sdk/jsonexpr/evaluator.dart';
import 'package:absmartly_sdk/jsonexpr/expr_evaluator.dart';
import 'package:absmartly_sdk/jsonexpr/json_expr.dart';
import 'package:absmartly_sdk/jsonexpr/operator.dart';
import 'package:absmartly_sdk/jsonexpr/operators/and_combinator.dart';
import 'package:absmartly_sdk/jsonexpr/operators/binary_operator.dart';
import 'package:absmartly_sdk/jsonexpr/operators/boolean_combinator.dart';
import 'package:absmartly_sdk/jsonexpr/operators/equals_operator.dart';
import 'package:absmartly_sdk/jsonexpr/operators/greater_then_operator.dart';
import 'package:absmartly_sdk/jsonexpr/operators/greater_then_or_equal_operator.dart';
import 'package:absmartly_sdk/jsonexpr/operators/in_operator.dart';
import 'package:absmartly_sdk/jsonexpr/operators/less_then_operator.dart';
import 'package:absmartly_sdk/jsonexpr/operators/less_then_or_eqal_operator.dart';
import 'package:absmartly_sdk/jsonexpr/operators/match_operator.dart';
import 'package:absmartly_sdk/jsonexpr/operators/not_operator.dart';
import 'package:absmartly_sdk/jsonexpr/operators/null_operator.dart';
import 'package:absmartly_sdk/jsonexpr/operators/or_combinator.dart';
import 'package:absmartly_sdk/jsonexpr/operators/unary_operator.dart';
import 'package:absmartly_sdk/jsonexpr/operators/value_operator.dart';
import 'package:absmartly_sdk/jsonexpr/operators/var_operator.dart';
import 'package:absmartly_sdk/variable_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/deep_import_app_types.dart';

// Every 2.1 import path of absmartly_sdk (ab_smartly_config.dart declares a
// second ABSmartlyConfig, as in 2.1, so it is left out) exports only its 2.1
// names. Referencing each app name below is an ambiguous-import error if one
// of those paths exports it too.
// ignore: unused_element
List<Object> _appNames(
        Context context,
        Client client,
        ABSmartlyConfig config,
        ClientConfig clientConfig,
        ContextConfig contextConfig,
        Experiment experiment,
        Exposure exposure) =>
    [
      RuleAction(),
      CustomFieldValue(),
      GreaterThanOperator(),
      GreaterThanOrEqualOperator(),
      LessThanOperator(),
      LessThanOrEqualOperator(),
      AssignmentRulesMatcher('').appHelper,
      ContextExtensions(context).appHelper,
      ClientMetadata(client).appHelper,
      ABSmartlyConfigContextPublisher(config).appHelper,
      ClientConfigApplicationVersion(clientConfig).appHelper,
      ContextConfigUnitValues(contextConfig).appHelper,
      ExperimentFields(experiment).appHelper,
      ExposureRuleOverride(exposure).appHelper,
    ];

void main() {
  test('2.1 deep imports leave newer names to the app', () {
    expect(RuleAction(), isA<RuleAction>());
    expect(CustomFieldValue(), isA<CustomFieldValue>());
    expect(GreaterThenOperator, isNotNull);
  });
}
