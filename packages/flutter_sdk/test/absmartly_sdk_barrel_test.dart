import 'package:absmartly_sdk/absmartly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_types.dart';

// absmartly_sdk.dart exports only the names it exported in 2.1. This file
// stops compiling (ambiguous imports) if it exports any name declared in
// support/app_types.dart.
// Never called: referencing each app extension by name is enough to make an
// SDK export of the same name an ambiguous import.
// ignore: unused_element
List<bool> _appExtensions(Context context, Client client,
        ABSmartlyConfig config, Experiment experiment, Exposure exposure) =>
    [
      ContextExtensions(context).appHelper,
      ClientMetadata(client).appHelper,
      ABSmartlyConfigContextPublisher(config).appHelper,
      ExperimentFields(experiment).appHelper,
      ExposureRuleOverride(exposure).appHelper,
    ];

void main() {
  test('absmartly_sdk.dart keeps the 2.1 export list', () {
    expect(Treatment(), isA<Treatment>());
    expect(EventType.click.name, 'click');
    expect(ClientConfig(), isA<ClientConfig>());
    expect(ABSmartly(), isA<ABSmartly>());
    expect(SdkVersion(), isA<SdkVersion>());
    expect(CustomFieldValue(), isA<CustomFieldValue>());

    expect(ABSmartlyConfig.create(), isA<ABSmartlyConfig>());
    expect(<Type>[
      Context,
      Client,
      ContextData,
      ContextEventHandler,
      ContextDataProvider,
      DefaultContextDataProvider,
      DefaultContextEventHandler,
      Attribute,
      Experiment,
      ExperimentVariant,
      Exposure,
      GoalAchievement,
      PublishEvent,
      Unit,
    ], hasLength(14));
  });
}
