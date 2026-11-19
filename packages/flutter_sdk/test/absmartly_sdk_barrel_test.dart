import 'package:absmartly_sdk/absmartly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_types.dart';

// absmartly_sdk.dart exports only the names it exported in 2.1. This file
// stops compiling (ambiguous imports) if it exports any name declared in
// support/app_types.dart.
void main() {
  test('absmartly_sdk.dart keeps the 2.1 export list', () {
    expect(Treatment(), isA<Treatment>());
    expect(EventType.click.name, 'click');
    expect(ClientConfig(), isA<ClientConfig>());
    expect(ABSmartly(), isA<ABSmartly>());
    expect(SdkVersion(), isA<SdkVersion>());

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
