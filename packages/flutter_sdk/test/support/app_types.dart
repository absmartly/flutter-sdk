// Types an app could declare with the names of SDK types that 2.1's
// absmartly_sdk.dart did not export.
import 'package:absmartly_sdk/absmartly_sdk.dart';

class Treatment {}

enum EventType { click }

class ClientConfig {}

class ABSmartly {}

class SdkVersion {}

class CustomFieldValue {}

extension ContextExtensions on Context {
  bool get appHelper => true;
}

extension ClientMetadata on Client {
  bool get appHelper => true;
}

extension ABSmartlyConfigContextPublisher on ABSmartlyConfig {
  bool get appHelper => true;
}

extension ExperimentFields on Experiment {
  bool get appHelper => true;
}

extension ExposureRuleOverride on Exposure {
  bool get appHelper => true;
}
