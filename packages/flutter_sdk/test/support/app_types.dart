// Types an app could declare with the names of SDK types that 2.1's
// absmartly_sdk.dart did not export.
export 'deep_import_app_types.dart'
    show
        CustomFieldValue,
        ContextExtensions,
        ClientMetadata,
        ABSmartlyConfigContextPublisher,
        ExperimentFields,
        ExposureRuleOverride;

class Treatment {}

enum EventType { click }

class ClientConfig {}

class ABSmartly {}

class SdkVersion {}
