// An app library declaring the names that 2.2.0 added to the libraries behind
// the 2.1 deep imports. None of them may be exported by a 2.1 import path.
import 'package:absmartly_sdk/absmartly_sdk.dart';
import 'package:absmartly_sdk/client_config.dart';
import 'package:absmartly_sdk/context_config.dart';

class RuleAction {}

class CustomFieldValue {}

class GreaterThanOperator {}

class GreaterThanOrEqualOperator {}

class LessThanOperator {}

class LessThanOrEqualOperator {}

extension AssignmentRulesMatcher on String {
  bool get appHelper => true;
}

extension ContextExtensions on Context {
  bool get appHelper => true;
}

extension ClientMetadata on Client {
  bool get appHelper => true;
}

extension ABSmartlyConfigContextPublisher on ABSmartlyConfig {
  bool get appHelper => true;
}

extension ClientConfigApplicationVersion on ClientConfig {
  bool get appHelper => true;
}

extension ContextConfigUnitValues on ContextConfig {
  bool get appHelper => true;
}

extension ExperimentFields on Experiment {
  bool get appHelper => true;
}

extension ExposureRuleOverride on Exposure {
  bool get appHelper => true;
}
