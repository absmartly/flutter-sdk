import 'dart:async';

import 'package:absmartly_dart/src/audience_matcher.dart';
import 'package:absmartly_dart/src/context.dart';
import 'package:absmartly_dart/src/context_config.dart';
import 'package:absmartly_dart/src/context_data_provider.dart';
import 'package:absmartly_dart/src/context_event_handler.dart';
import 'package:absmartly_dart/src/default_audience_deserializer.dart';
import 'package:absmartly_dart/src/default_variable_parser.dart';
import 'package:absmartly_dart/src/java/time/clock.dart';
import 'package:absmartly_dart/src/json/context_data.dart';
import 'package:absmartly_dart/src/json/experiment.dart';
import 'package:absmartly_dart/src/json/experiment_variant.dart';
import 'package:absmartly_dart/src/json/publish_event.dart';
import 'package:absmartly_dart/src/variable_parser.dart';
import 'package:absmartly_sdk/absmartly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeContextDataProvider implements ContextDataProvider {
  @override
  Completer<ContextData> getContextData() {
    final completer = Completer<ContextData>();
    completer.complete(ContextData()..experiments = []);
    return completer;
  }
}

class _FakeContextEventHandler implements ContextEventHandler {
  @override
  Completer<void> publish(Context context, PublishEvent event) {
    return Completer<void>()..complete();
  }
}

void main() {
  group('Fix Verification Tests', () {
    late _FakeContextDataProvider dataProvider;
    late _FakeContextEventHandler eventHandler;
    late VariableParser variableParser;
    late AudienceMatcher audienceMatcher;
    late Clock clock;

    setUp(() {
      dataProvider = _FakeContextDataProvider();
      eventHandler = _FakeContextEventHandler();
      variableParser = DefaultVariableParser();
      audienceMatcher = AudienceMatcher(DefaultAudienceDeserializer());
      clock = Clock.fixed(1620000000000);
    });

    Context createReadyContextWithExperiments(List<Experiment> experiments) {
      final data = ContextData();
      data.experiments = experiments;

      final config = ContextConfig.create(
        units: {'user_id': 'test123'},
        publishDelay: 0,
      );
      final completer = Completer<ContextData>()..complete(data);

      return Context.create(clock, config, completer, dataProvider,
          eventHandler, variableParser, audienceMatcher, null);
    }

    group('Fix #2: TreatmentBuilder scopes variables to experiment', () {
      testWidgets('only returns variables belonging to named experiment',
          (tester) async {
        final exp1 = Experiment(
          id: 1,
          name: 'exp_button',
          unitType: 'user_id',
          iteration: 1,
          seedHi: 1,
          seedLo: 1,
          split: [0.5, 0.5],
          trafficSeedHi: 1,
          trafficSeedLo: 1,
          trafficSplit: [0.0, 1.0],
          fullOnVariant: 0,
          audienceStrict: false,
          audience: null,
          applications: [],
          variants: [
            ExperimentVariant(name: 'control', config: null),
            ExperimentVariant(
                name: 'treatment', config: '{"button_color":"red"}'),
          ],
        );

        final exp2 = Experiment(
          id: 2,
          name: 'exp_header',
          unitType: 'user_id',
          iteration: 1,
          seedHi: 2,
          seedLo: 2,
          split: [0.5, 0.5],
          trafficSeedHi: 2,
          trafficSeedLo: 2,
          trafficSplit: [0.0, 1.0],
          fullOnVariant: 0,
          audienceStrict: false,
          audience: null,
          applications: [],
          variants: [
            ExperimentVariant(name: 'control', config: null),
            ExperimentVariant(
                name: 'treatment', config: '{"header_size":"large"}'),
          ],
        );

        final ctx = createReadyContextWithExperiments([exp1, exp2]);
        await ctx.waitUntilReady();

        Map<String, dynamic>? capturedVariables;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: TreatmentBuilder(
              name: 'exp_button',
              context: ctx,
              builder: (context, variant, variables) {
                capturedVariables = variables;
                return Text('variant: $variant');
              },
            ),
          ),
        );

        await tester.pump();

        expect(capturedVariables, isNotNull);
        expect(capturedVariables!.containsKey('header_size'), isFalse);

        await ctx.close();
      });
    });

    group('Fix #6: TreatmentVariant.variant type is Object', () {
      test('accepts int variant', () {
        const tv = TreatmentVariant(variant: 1, child: SizedBox());
        expect(tv.variantIndex, equals(1));
      });

      test('accepts String letter variant', () {
        const tv = TreatmentVariant(variant: 'B', child: SizedBox());
        expect(tv.variantIndex, equals(1));
      });

      test('accepts String number variant', () {
        const tv = TreatmentVariant(variant: '3', child: SizedBox());
        expect(tv.variantIndex, equals(3));
      });

      test('returns 0 for unknown string', () {
        const tv = TreatmentVariant(variant: 'unknown', child: SizedBox());
        expect(tv.variantIndex, equals(0));
      });
    });

    group('Fix CR3: Context.getUnits returns actual units', () {
      test('returns actual units not empty map', () async {
        final config = ContextConfig.create(
          units: {'user_id': 'test123', 'session_id': 'sess456'},
        );

        final data = ContextData()..experiments = [];
        final completer = Completer<ContextData>()..complete(data);

        final ctx = Context.create(clock, config, completer, dataProvider,
            eventHandler, variableParser, audienceMatcher, null);
        addTearDown(() => ctx.close());

        await ctx.waitUntilReady();

        final units = ctx.getUnits();
        expect(units['user_id'], equals('test123'));
        expect(units['session_id'], equals('sess456'));
        expect(units.length, equals(2));
      });

      test('returned map is unmodifiable', () async {
        final config = ContextConfig.create(units: {'user_id': 'test123'});
        final data = ContextData()..experiments = [];
        final completer = Completer<ContextData>()..complete(data);

        final ctx = Context.create(clock, config, completer, dataProvider,
            eventHandler, variableParser, audienceMatcher, null);
        addTearDown(() => ctx.close());

        await ctx.waitUntilReady();

        final units = ctx.getUnits();
        expect(() => units['new_key'] = 'value', throwsUnsupportedError);
      });
    });

    group('Fix 7: ContextConfig field typo corrected', () {
      test('customAssignments field works correctly after rename', () {
        final config = ContextConfig.create()
          ..setCustomAssignment('exp_test', 2)
          ..setCustomAssignment('exp_test_2', 1);

        expect(config.getCustomAssignment('exp_test'), equals(2));
        expect(config.getCustomAssignment('exp_test_2'), equals(1));
        expect(config.getCustomAssignments(),
            equals({'exp_test': 2, 'exp_test_2': 1}));
      });
    });

    group('Fix Q3: ClientConfig fields without late', () {
      test('ClientConfig fields are null by default without late init error',
          () {
        final config = ClientConfig();
        expect(config.getAPIKey(), isNull);
        expect(config.getEnvironment(), isNull);
        expect(config.getApplication(), isNull);
        expect(config.getEndpoint(), isNull);
      });
    });
  });
}
