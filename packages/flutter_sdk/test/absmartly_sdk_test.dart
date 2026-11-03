import 'package:flutter_test/flutter_test.dart';
import 'package:absmartly_sdk/absmartly_sdk.dart';

void main() {
  group('ABSmartly SDK Exports', () {
    test('can access ABSmartly class', () {
      expect(ABSmartly, isNotNull);
    });

    test('can access ABSmartlyConfig class', () {
      expect(ABSmartlyConfig, isNotNull);
    });

    test('can access Client class', () {
      expect(Client, isNotNull);
    });

    test('can access ClientConfig class', () {
      expect(ClientConfig, isNotNull);
    });

    test('can access Context class', () {
      expect(Context, isNotNull);
    });

    test('can access ContextConfig class', () {
      expect(ContextConfig, isNotNull);
    });

    test('can access ContextData class', () {
      expect(ContextData, isNotNull);
    });

    test('can access Attribute class', () {
      expect(Attribute, isNotNull);
    });

    test('can access Experiment class', () {
      expect(Experiment, isNotNull);
    });

    test('can access Exposure class', () {
      expect(Exposure, isNotNull);
    });

    test('can access GoalAchievement class', () {
      expect(GoalAchievement, isNotNull);
    });
  });

  group('ClientConfig', () {
    test('can create and configure ClientConfig', () {
      final config = ClientConfig()
        ..setEndpoint('https://test.absmartly.io/v1')
        ..setAPIKey('test-api-key')
        ..setApplication('test-app')
        ..setEnvironment('development');

      expect(config.getEndpoint(), equals('https://test.absmartly.io/v1'));
      expect(config.getAPIKey(), equals('test-api-key'));
      expect(config.getApplication(), equals('test-app'));
      expect(config.getEnvironment(), equals('development'));
    });

    test('can create using factory method', () {
      final config = ClientConfig.create();
      expect(config, isNotNull);
    });

    test('can set deserializer and serializer', () {
      final config = ClientConfig()
        ..setContextDataDeserializer(DefaultContextDataDeserializer())
        ..setContextEventSerializer(DefaultContextEventSerializer());

      expect(config.getContextDataDeserializer(), isNotNull);
      expect(config.getContextEventSerializer(), isNotNull);
    });

    test('getContextDataDeserializer returns default if not set', () {
      final config = ClientConfig();
      expect(config.getContextDataDeserializer(),
          isA<DefaultContextDataDeserializer>());
    });

    test('getContextEventSerializer returns default if not set', () {
      final config = ClientConfig();
      expect(config.getContextEventSerializer(),
          isA<DefaultContextEventSerializer>());
    });
  });

  group('ABSmartlyConfig', () {
    test('can create config using factory', () {
      final config = ABSmartlyConfig.create();
      expect(config, isNotNull);
    });

    test('can set client', () {
      final clientConfig = ClientConfig()
        ..setEndpoint('https://test.absmartly.io/v1')
        ..setAPIKey('test-api-key')
        ..setApplication('test-app')
        ..setEnvironment('development');

      final client = Client.create(clientConfig);
      final sdkConfig = ABSmartlyConfig.create().setClient(client);

      expect(sdkConfig, isNotNull);
    });
  });

  group('ContextConfig', () {
    test('can create context config', () {
      final config = ContextConfig.create();
      expect(config, isNotNull);
    });

    test('can set units', () {
      final config = ContextConfig.create()
        ..setUnit('user_id', '12345')
        ..setUnit('session_id', 'abc123');

      expect(config, isNotNull);
    });

    test('can set multiple units via setUnits', () {
      final config = ContextConfig.create()
        ..setUnits({'user_id': '12345', 'device_id': 'device-abc'});

      expect(config, isNotNull);
    });

    test('can set publish delay', () {
      final config = ContextConfig.create()..setPublishDelay(1000);

      expect(config, isNotNull);
    });

    test('can set refresh interval', () {
      final config = ContextConfig.create()..setRefreshInterval(3600000);

      expect(config, isNotNull);
    });
  });

  group('Attribute', () {
    test('can create Attribute', () {
      final attr = Attribute(
        name: 'country',
        value: 'US',
        setAt: 1234567890,
      );

      expect(attr.name, equals('country'));
      expect(attr.value, equals('US'));
      expect(attr.setAt, equals(1234567890));
    });

    test('Attribute toMap works', () {
      final attr = Attribute(
        name: 'country',
        value: 'US',
        setAt: 1234567890,
      );

      final map = attr.toMap();
      expect(map['name'], equals('country'));
      expect(map['value'], equals('US'));
      expect(map['setAt'], equals(1234567890));
    });

    test('Attribute equality works', () {
      final attr1 = Attribute(name: 'country', value: 'US', setAt: 1234567890);
      final attr2 = Attribute(name: 'country', value: 'US', setAt: 1234567890);
      final attr3 = Attribute(name: 'country', value: 'UK', setAt: 1234567890);

      expect(attr1, equals(attr2));
      expect(attr1, isNot(equals(attr3)));
    });
  });

  group('Exposure', () {
    test('can create Exposure', () {
      final exposure = Exposure(
        id: 1,
        name: 'test_experiment',
        unit: 'user_id',
        variant: 1,
        exposedAt: 1234567890,
        assigned: true,
        eligible: true,
        overridden: false,
        fullOn: false,
        custom: false,
        audienceMismatch: false,
      );

      expect(exposure.name, equals('test_experiment'));
      expect(exposure.variant, equals(1));
      expect(exposure.assigned, isTrue);
      expect(exposure.eligible, isTrue);
      expect(exposure.overridden, isFalse);
    });

    test('Exposure toMap works', () {
      final exposure = Exposure(
        id: 1,
        name: 'test_experiment',
        unit: 'user_id',
        variant: 1,
        exposedAt: 1234567890,
        assigned: true,
        eligible: true,
        overridden: false,
        fullOn: false,
        custom: false,
        audienceMismatch: false,
      );

      final map = exposure.toMap();
      expect(map['name'], equals('test_experiment'));
      expect(map['variant'], equals(1));
    });
  });

  group('GoalAchievement', () {
    test('can create GoalAchievement', () {
      final goal = GoalAchievement(
        name: 'purchase',
        achievedAt: 1234567890,
        properties: {'amount': 99.99},
      );

      expect(goal.name, equals('purchase'));
      expect(goal.achievedAt, equals(1234567890));
      expect(goal.properties?['amount'], equals(99.99));
    });

    test('GoalAchievement toMap works', () {
      final goal = GoalAchievement(
        name: 'signup',
        achievedAt: 1234567890,
        properties: null,
      );

      final map = goal.toMap();
      expect(map['name'], equals('signup'));
      expect(map['achievedAt'], equals(1234567890));
    });

    test('GoalAchievement equality works', () {
      final goal1 =
          GoalAchievement(name: 'signup', achievedAt: 123, properties: null);
      final goal2 =
          GoalAchievement(name: 'signup', achievedAt: 123, properties: null);
      final goal3 =
          GoalAchievement(name: 'purchase', achievedAt: 123, properties: null);

      expect(goal1, equals(goal2));
      expect(goal1, isNot(equals(goal3)));
    });
  });

  group('Unit', () {
    test('can create Unit', () {
      final unit = Unit(type: 'user_id', uid: '12345');

      expect(unit.type, equals('user_id'));
      expect(unit.uid, equals('12345'));
    });

    test('Unit toMap works', () {
      final unit = Unit(type: 'session_id', uid: 'abc123');
      final map = unit.toMap();

      expect(map['type'], equals('session_id'));
      expect(map['uid'], equals('abc123'));
    });

    test('Unit equality works', () {
      final unit1 = Unit(type: 'user_id', uid: '12345');
      final unit2 = Unit(type: 'user_id', uid: '12345');
      final unit3 = Unit(type: 'user_id', uid: '67890');

      expect(unit1, equals(unit2));
      expect(unit1, isNot(equals(unit3)));
    });
  });

  group('ExperimentVariant', () {
    test('can create ExperimentVariant', () {
      final variant = ExperimentVariant(
        name: 'control',
        config: '{"color": "blue"}',
      );

      expect(variant.name, equals('control'));
      expect(variant.config, equals('{"color": "blue"}'));
    });
  });

  group('PublishEvent', () {
    test('can create PublishEvent', () {
      final event = PublishEvent(
        hashed: true,
        units: [Unit(type: 'user_id', uid: '12345')],
        publishedAt: 1234567890,
        exposures: [],
        goals: [],
        attributes: [],
      );

      expect(event.hashed, isTrue);
      expect(event.units.length, equals(1));
      expect(event.publishedAt, equals(1234567890));
    });
  });

  group('DefaultContextDataDeserializer', () {
    test('can create deserializer', () {
      final deserializer = DefaultContextDataDeserializer();
      expect(deserializer, isNotNull);
    });
  });

  group('DefaultContextEventSerializer', () {
    test('can create serializer', () {
      final serializer = DefaultContextEventSerializer();
      expect(serializer, isNotNull);
    });
  });
}
