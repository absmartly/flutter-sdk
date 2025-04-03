import 'dart:async';

import 'package:absmartly_sdk/audience_matcher.dart';
import 'package:absmartly_sdk/context.dart';
import 'package:absmartly_sdk/context_config.dart';
import 'package:absmartly_sdk/context_data_provider.dart';
import 'package:absmartly_sdk/context_data_provider.mocks.dart';
import 'package:absmartly_sdk/context_event_handler.dart';
import 'package:absmartly_sdk/context_event_handler.mocks.dart';
import 'package:absmartly_sdk/default_audience_deserializer.dart';
import 'package:absmartly_sdk/default_context_data_serializer.dart';
import 'package:absmartly_sdk/default_variable_parser.dart';
import 'package:absmartly_sdk/java/time/clock.dart';
import 'package:absmartly_sdk/json/context_data.dart';
import 'package:absmartly_sdk/json/exposure.dart';
import 'package:absmartly_sdk/json/goal_achievement.dart';
import 'package:absmartly_sdk/json/publish_event.dart';
import 'package:absmartly_sdk/json/unit.dart';
import 'package:absmartly_sdk/variable_parser.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'test_utils.dart';

// not working

void main() {
  group("context", () {
    final Map<String, String> units = {
      "session_id": "e791e240fcd3df7d238cfc285f475e8152fcc0ec",
      "user_id": "123456789",
      "email": "bleh@absmartly.com",
    };

    final Map<String, dynamic> attributes = {
      "attr1": "value1",
      "attr2": "value2",
      "attr3": 5,
    };

    final Map<String, int> expectedVariants = {
      "exp_test_ab": 1,
      "exp_test_abc": 2,
      "exp_test_not_eligible": 0,
      "exp_test_fullon": 2,
      "exp_test_new": 1,
    };

    final Map<String, dynamic> expectedVariables = {
      "banner.border": 1,
      "banner.size": "large",
      "button.color": "red",
      "submit.color": "blue",
      "submit.shape": "rect",
      "show-modal": true,
    };

    final Map<String, List<String>> variableExperiments = {
      "banner.border": ["exp_test_ab"],
      "banner.size": ["exp_test_ab"],
      "button.color": ["exp_test_abc"],
      "card.width": ["exp_test_not_eligible"],
      "submit.color": ["exp_test_fullon"],
      "submit.shape": ["exp_test_fullon"],
      "show-modal": ["exp_test_new"],
    };

    final List<Unit> publishUnits = [
      Unit(type: "user_id", uid: "JfnnlDI7RTiF9RgfG2JNCw"),
      Unit(type: "session_id", uid: "pAE3a1i5Drs5mKRNq56adA"),
      Unit(type: "email", uid: "IuqYkNRfEx5yClel4j3NbA"),
    ];

    late ContextData data;
    late ContextData refreshData;
    late ContextData audienceData;
    late ContextData audienceStrictData;
    late Future<ContextData> dataFutureReady;
    late Future<ContextData> dataFutureFailed;
    late Completer<ContextData> dataFuture;
    late Future<ContextData> refreshDataFutureReady;
    late Completer<ContextData> refreshDataFuture;
    late Future<ContextData> audienceDataFutureReady;
    late Future<ContextData> audienceStrictDataFutureReady;
    late ContextDataProvider dataProvider;
    late ContextEventHandler eventHandler;
    late VariableParser variableParser;
    late AudienceMatcher audienceMatcher;
    late Timer scheduler;
    late DefaultContextDataDeserializer deser =
        DefaultContextDataDeserializer();
    late Clock clock =
        Clock.fixed(DateTime(2021, 5, 14).millisecondsSinceEpoch);

    setUp(() async {
      WidgetsFlutterBinding.ensureInitialized();
      List<int> bytes = await getResourceBytes("context.json");
      data = deser.deserialize(bytes, 0, bytes.length)!;

      List<int> refreshBytes = await getResourceBytes("refreshed.json");
      refreshData = deser.deserialize(refreshBytes, 0, refreshBytes.length)!;

      List<int> audienceBytes = await getResourceBytes("audience_context.json");
      audienceData = deser.deserialize(audienceBytes, 0, audienceBytes.length)!;

      List<int> audienceStrictBytes =
          await getResourceBytes("audience_strict_context.json");

      audienceStrictData = deser.deserialize(
          audienceStrictBytes, 0, audienceStrictBytes.length)!;
      Completer d = Completer();

      dataFutureReady = Future<ContextData>.value(data);
      // dataFutureFailed = Future.error(Exception("FAILED"));
      dataFuture = Completer<ContextData>();
      refreshDataFutureReady = Future<ContextData>.value(refreshData);
      refreshDataFuture = Completer<ContextData>();
      audienceDataFutureReady = Future<ContextData>.value(audienceData);
      audienceStrictDataFutureReady =
          Future<ContextData>.value(audienceStrictData);
      dataProvider = MockContextDataProvider();
      eventHandler = MockContextEventHandler();
      variableParser = DefaultVariableParser();
      audienceMatcher = AudienceMatcher(DefaultAudienceDeserializer());
      scheduler = Timer(const Duration(seconds: 5), () {});
    });
    Context createContext(
        ContextConfig? config, Future<ContextData> dataFuture) {
      if (config == null) {
        final ContextConfig config = ContextConfig.create().setUnits(units);
        return Context.create(clock, config, scheduler, dataFuture,
            dataProvider, eventHandler, variableParser, audienceMatcher);
      }
      return Context.create(clock, config, scheduler, dataFuture, dataProvider,
          eventHandler, variableParser, audienceMatcher);
    }

    Context createReadyContext(ContextData? data) {
      final ContextConfig config = ContextConfig.create().setUnits(units);
      if (data == null) {
        return Context.create(clock, config, scheduler, dataFutureReady,
            dataProvider, eventHandler, variableParser, audienceMatcher);
      }
      return Context.create(clock, config, scheduler, Future.value(data),
          dataProvider, eventHandler, variableParser, audienceMatcher);
    }

    test('becomesReadyWithCompletedFuture', () async {
      final context = createReadyContext(null);

      await context.waitUntilReady();
      expect(context.isReady(), true);
      expect(context.getData(), equals(data));
    });

    test('becomesReadyAndFailedWithException', () async {
      final context = createContext(null, dataFuture.future);
      expect(context.isReady(), isFalse);
      expect(context.isFailed(), isFalse);

      context.setDataFailed(Exception("FAILED"));
      await context.waitUntilReady();

      expect(context.isReady(), isTrue);
      expect(context.isFailed(), isTrue);
    });

    test('waitUntilReady', () async {
      final context = createContext(null, dataFuture.future);
      expect(context.isReady(), isFalse);

      final completer = dataFuture.complete(data);
      await context.waitUntilReady();

      expect(context.isReady(), isTrue);
      expect(context.getData(), same(data));
    });
    //
    test('waitUntilReadyWithCompletedFuture', () async {
      final context = createReadyContext(null);
      expect(context.isReady(), isFalse);

      await context.waitUntilReady();
      expect(context.getData(), same(data));
    });
    //
    test('waitUntilReadyAsync', () async {
      final context = createContext(null, dataFuture.future);
      expect(context.isReady(), isFalse);

      final readyFuture = context.waitUntilReadyAsync();
      expect(context.isReady(), isFalse);

      final completer = dataFuture.complete(data);
      await readyFuture;

      expect(context.isReady(), isTrue);
      expect(await readyFuture, same(context));
      expect(context.getData(), same(data));
    });
    //
    test('waitUntilReadyAsyncWithCompletedFuture', () async {
      final context = createReadyContext(null);
      await context.waitUntilReady();
      expect(context.isReady(), isTrue);

      final readyFuture = context.waitUntilReadyAsync();
      await readyFuture;

      expect(context.isReady(), isTrue);
      expect(await readyFuture, same(context));
      expect(context.getData(), same(data));
    });
    //
    test("testGetExperiments", () async {
      final context = createReadyContext(null);

      await context.waitUntilReady();
      final experiments = data.experiments.map((e) => e.name).toList();
      expect(await context.getExperiments(), experiments);
    });
    test("testStartsRefreshTimerWhenReady", () async {
      final config = ContextConfig()
        ..units_ = units
        ..refreshInterval = 5000;

      final context = createContext(config, dataFuture.future);
      expect(context.isReady(), isFalse);
      expect(context.isFailed(), isFalse);

      dataFuture.complete(data);
      context.waitUntilReady();

      when(dataProvider.getContextData())
          .thenAnswer((_) => refreshDataFutureReady);
    });

    test("setUnits", () {
      final Context context =
          createContext(ContextConfig.create(), dataFuture.future);
      context.waitUntilReady();
      context.setUnits(units);

      units.forEach((key, value) {
        expect(value, context.getUnit(key));
      });
    });
    test("setUnitEmpty", () {
      final Context context = createContext(null, dataFutureReady);

      expect(() {
        context.setUnit("db_user_id", "");
      }, throwsException);
    });
    //
    test("setUnitThrowsOnAlreadySet", () {
      final Context context = createContext(null, dataFutureReady);

      expect(() {
        context.setUnit('session_id', 'new_uid');
      }, throwsException);
    });

    test("setAttributes", () {
      final Context context = createContext(null, dataFuture.future);
      context.setAttribute("attr1", "value1");
      context.setAttributes({"attr2": "value2", "attr3": 15});
      expect("value1", context.getAttribute("attr1"));
      expect({"attr1": "value1", "attr2": "value2", "attr3": 15},
          context.getAttributes());
    });

    test("setAttributesBeforeReady", () {
      final Context context = createContext(null, dataFuture.future);
      expect(false, context.isReady());

      context.setAttribute("attr1", "value1");
      context.setAttributes({"attr2": "value2"});

      expect("value1", context.getAttribute("attr1"));
      expect({"attr1": "value1", "attr2": "value2"}, context.getAttributes());

      dataFuture.complete(data);

      context.waitUntilReady();
    });

    test("setOverride", () {
      final Context context = createReadyContext(null);

      context.setOverride("exp_test", 2);

      expect(2, context.getOverride("exp_test"));

      context.setOverride("exp_test", 3);
      expect(3, context.getOverride("exp_test"));

      context.setOverride("exp_test_2", 1);
      expect(1, context.getOverride("exp_test_2"));

      final Map<String, int> overrides = {
        "exp_test_new": 3,
        "exp_test_new_2": 5
      };

      context.setOverrides(overrides);

      expect(3, context.getOverride("exp_test"));
      expect(1, context.getOverride("exp_test_2"));
      overrides.forEach((experimentName, variant) =>
          expect(variant, context.getOverride(experimentName)));
    });

    // test("setOverrideClearsAssignmentCache", () {
    //   final Context context = createReadyContext(null);
    //
    //   final Map<String, int> overrides = {
    //     "exp_test_new": 3,
    //     "exp_test_new_2": 5
    //   };
    //
    //   context.setOverrides(overrides);
    //
    //   overrides.forEach((experimentName, variant) =>
    //       expect(variant, context.getTreatment(experimentName)));
    //   expect(overrides.length, context.getPendingCount());
    //
    //   // overriding again with the same variant shouldn't clear assignment cache
    //   overrides.forEach((experimentName, variant) {
    //     context.setOverride(experimentName, variant);
    //     expect(variant, context.getTreatment(experimentName));
    //   });
    //   expect(overrides.length, context.getPendingCount());
    //
    //   // overriding with the different variant should clear assignment cache
    //   overrides.forEach((experimentName, variant) {
    //     context.setOverride(experimentName, variant + 11);
    //     expect(variant + 11, context.getTreatment(experimentName));
    //   });
    //
    //   expect(overrides.length * 2, context.getPendingCount());
    //
    //   // overriding a computed assignment should clear assignment cache
    //   expect(
    //       expectedVariants["exp_test_ab"], context.getTreatment("exp_test_ab"));
    //   expect(1 + overrides.length * 2, context.getPendingCount());
    //
    //   context.setOverride("exp_test_ab", 9);
    //   expect(9, context.getTreatment("exp_test_ab"));
    //   expect(2 + overrides.length * 2, context.getPendingCount());
    // });

    test("setOverridesBeforeReady", () {
      final Context context = createContext(null, dataFuture.future);
      expect(false, context.isReady());

      context.setOverride("exp_test", 2);
      context.setOverrides({"exp_test_new": 3, "exp_test_new_2": 5});

      dataFuture.complete(data);

      context.waitUntilReady();

      expect(2, context.getOverride("exp_test"));
      expect(3, context.getOverride("exp_test_new"));
      expect(5, context.getOverride("exp_test_new_2"));
    });

    test("setCustomAssignment", () {
      final Context context = createReadyContext(null);
      context.setCustomAssignment("exp_test", 2);

      expect(2, context.getCustomAssignment("exp_test"));

      context.setCustomAssignment("exp_test", 3);
      expect(3, context.getCustomAssignment("exp_test"));

      context.setCustomAssignment("exp_test_2", 1);
      expect(1, context.getCustomAssignment("exp_test_2"));

      final Map<String, int> cassignments = {
        "exp_test_new": 3,
        "exp_test_new_2": 5
      };

      context.setCustomAssignments(cassignments);

      expect(3, context.getCustomAssignment("exp_test"));
      expect(1, context.getCustomAssignment("exp_test_2"));
      cassignments.forEach((experimentName, variant) =>
          expect(variant, context.getCustomAssignment(experimentName)));
    });
    //
    test("setCustomAssignmentDoesNotOverrideFullOnOrNotEligibleAssignments",
        () async {
      final Context context = createReadyContext(null);

      await context.waitUntilReady();
      context.setCustomAssignment("exp_test_not_eligible", 3);
      context.setCustomAssignment("exp_test_fullon", 3);

      expect(0, await context.getTreatment("exp_test_not_eligible"));
      expect(2, await context.getTreatment("exp_test_fullon"));
    });

    test("setCustomAssignmentsBeforeReady", () {
      final Context context = createContext(null, dataFuture.future);
      expect(false, context.isReady());

      context.setCustomAssignment("exp_test", 2);
      context.setCustomAssignments({"exp_test_new": 3, "exp_test_new_2": 5});

      dataFuture.complete(data);

      context.waitUntilReady();

      expect(2, context.getCustomAssignment("exp_test"));
      expect(3, context.getCustomAssignment("exp_test_new"));
      expect(5, context.getCustomAssignment("exp_test_new_2"));
    });

    test("getVariableValue", () async {
      final Context context = createReadyContext(null);

      await context.waitUntilReady();
      final Set<String> experiments =
          Set.from(data.experiments.map((x) => x.name));

      for (var entry in variableExperiments.entries) {
        var variable = entry.key;
        var experimentNames = entry.value;

        final String experimentName = experimentNames[0];
        final dynamic actual = await context.getVariableValue(variable, 17);
        final bool eligible = experimentName != "exp_test_not_eligible";

        // if (eligible && experiments.contains(experimentName)) {
        //   expect(expectedVariables[variable], actual);
        // } else {
        //   expect(17, actual);
        // }
      }

      expect(experiments.length, 4);
    });

    test(
        "getTreatmentQueuesExposureWithAudienceMismatchTrueAndControlVariantOnAudienceMismatchInStrictMode",
        () async {
      final Context context =
          createContext(null, audienceStrictDataFutureReady);

      await context.waitUntilReady();

      expect(0, await context.getTreatment("exp_test_ab"));

      expect(1, context.getPendingCount());

      context.publish();

      // return;
      final PublishEvent expected = PublishEvent(
          hashed: true,
          units: publishUnits,
          publishedAt: clock.millis(),
          exposures: [
            Exposure(
                id: 1,
                name: "exp_test_ab",
                unit: "session_id",
                variant: 0,
                exposedAt: clock.millis(),
                assigned: false,
                eligible: true,
                overridden: false,
                fullOn: false,
                custom: false,
                audienceMismatch: true)
          ],
          goals: [],
          attributes: []);

      context.publish();
    });

    test("getVariableKeys", () async {
      final Context context = createContext(null, refreshDataFutureReady);
      await context.waitUntilReady();
      expect(variableExperiments, context.getVariableKeys());
    });

    test("track", () {
      final Context context = createReadyContext(null);
      context.track("goal1", {"amount": 125, "hours": 245});
      context.track("goal2", {"tries": 7});

      expect(2, context.getPendingCount());

      context.track("goal2", {"tests": 12});
      context.track("goal3", null);

      expect(4, context.getPendingCount());

      final PublishEvent expected = PublishEvent(
          hashed: true,
          units: publishUnits,
          publishedAt: clock.millis(),
          exposures: [],
          goals: [],
          attributes: []);

      expected.goals = [
        GoalAchievement(
            name: "goal1",
            achievedAt: clock.millis(),
            properties: {"amount": 125, "hours": 245}),
        GoalAchievement(name: "goal2", achievedAt: clock.millis(), properties: {
          "tries": 7,
        }),
        GoalAchievement(
            name: "goal2",
            achievedAt: clock.millis(),
            properties: {"tests": 12}),
        GoalAchievement(
            name: "goal3", achievedAt: clock.millis(), properties: null),
      ];
      context.publish();
      context.close();
    });

    test("peekVariableValue", () async {
      final Context context = createReadyContext(null);
      await context.waitUntilReady();
      final Set<String> experiments =
          data.experiments.map((x) => x.name).toSet();

      for (var entry in variableExperiments.entries) {
        var variable = entry.key;
        var experimentNames = entry.value;

        final String experimentName = experimentNames[0];

        final actual = await context.peekVariableValue(variable, 17);
        final eligible = experimentName != "exp_test_not_eligible";

        if (!(eligible && experiments.contains(experimentName))) {
          expect(actual, equals(17));
        }
      }

      expect(context.getPendingCount(), equals(0));
    });

    test("refreshAsync", () async {
      final Context context = createReadyContext(null);
      await context.waitUntilReady();
      when(dataProvider.getContextData())
          .thenAnswer((_) => refreshDataFuture.future);

      final refreshFuture = context.refreshAsync();
      final refreshFutureNext = context.refreshAsync();

      expect(refreshFuture, same(refreshFutureNext));

      verify(dataProvider.getContextData()).called(1);

      final experiments = refreshData.experiments.map((x) => x.name).toList()
        ..remove("exp_test_new");
      expect(await context.getExperiments(), equals(experiments));
    });
  });
}
