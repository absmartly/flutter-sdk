import 'package:absmartly_dart/src/context_config.dart';
import 'package:test/test.dart';

void main() {
  group('ContextConfig', () {
    test('setUnit', () {
      final config =
          ContextConfig.create().setUnit('session_id', '0ab1e23f4eee');
      expect(config.getUnit('session_id'), equals('0ab1e23f4eee'));
    });

    test('setAttribute', () {
      final config = ContextConfig.create()
          .setAttribute('user_agent', 'Chrome')
          .setAttribute('age', 9);
      expect(config.getAttribute('user_agent'), equals('Chrome'));
      expect(config.getAttribute('age'), equals(9));
    });

    test('setAttributes', () {
      final attributes = {'user_agent': 'Chrome', 'age': 9};
      final config = ContextConfig.create().setAttributes(attributes);
      expect(config.getAttribute('user_agent'), equals('Chrome'));
      expect(config.getAttribute('age'), equals(9));
      expect(config.getAttributes(), equals(attributes));
    });

    test('setOverride', () {
      final config = ContextConfig.create().setOverride('exp_test', 2);
      expect(config.getOverride('exp_test'), equals(2));
    });

    test('setOverrides', () {
      final overrides = {'exp_test': 2, 'exp_test_new': 1};
      final config = ContextConfig.create().setOverrides(overrides);
      expect(config.getOverride('exp_test'), equals(2));
      expect(config.getOverride('exp_test_new'), equals(1));
      expect(config.getOverrides(), equals(overrides));
    });

    test('setCustomAssignment', () {
      final config = ContextConfig.create().setCustomAssignment('exp_test', 2);
      expect(config.getCustomAssignment('exp_test'), equals(2));
    });

    test('setCustomAssignments', () {
      final cassignments = {'exp_test': 2, 'exp_test_new': 1};
      final config = ContextConfig.create().setCustomAssignments(cassignments);
      expect(config.getCustomAssignment('exp_test'), equals(2));
      expect(config.getCustomAssignment('exp_test_new'), equals(1));
      expect(config.getCustomAssignments(), equals(cassignments));
    });

    test('setPublishDelay', () {
      final config = ContextConfig.create().setPublishDelay(999);
      expect(config.getPublishDelay(), equals(999));
    });

    test('setRefreshInterval', () {
      final config = ContextConfig.create().setRefreshInterval(999);
      expect(config.getRefreshInterval(), equals(999));
    });
  });

  group('ContextConfig.create with named parameters', () {
    test('create with all parameters', () {
      final units = {'session_id': '0ab1e23f4eee'};
      final attributes = {'user_agent': 'Chrome', 'age': 9};
      final overrides = {'exp_test': 2};
      final customAssignments = {'exp_test_new': 1};

      final config = ContextConfig.create(
        units: units,
        attributes: attributes,
        overrides: overrides,
        customAssignments: customAssignments,
        publishDelay: 500,
        refreshInterval: 1000,
      );

      expect(config.getUnit('session_id'), equals('0ab1e23f4eee'));
      expect(config.getUnits(), equals(units));
      expect(config.getAttribute('user_agent'), equals('Chrome'));
      expect(config.getAttribute('age'), equals(9));
      expect(config.getOverride('exp_test'), equals(2));
      expect(config.getCustomAssignment('exp_test_new'), equals(1));
      expect(config.getPublishDelay(), equals(500));
      expect(config.getRefreshInterval(), equals(1000));
    });

    test('create with units only', () {
      final config = ContextConfig.create(
        units: {'session_id': '0ab1e23f4eee'},
      );

      expect(config.getUnit('session_id'), equals('0ab1e23f4eee'));
      expect(config.getPublishDelay(), equals(100));
      expect(config.getRefreshInterval(), equals(0));
    });

    test('create with no parameters is backward compatible', () {
      final config = ContextConfig.create();
      expect(config.getUnits(), isEmpty);
      expect(config.getAttributes(), isEmpty);
      expect(config.getOverrides(), isEmpty);
      expect(config.getCustomAssignments(), isEmpty);
      expect(config.getPublishDelay(), equals(100));
      expect(config.getRefreshInterval(), equals(0));
    });
  });
}
