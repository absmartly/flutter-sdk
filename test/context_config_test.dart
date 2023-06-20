
import 'package:ab_smartly/context_config.dart';
import 'package:flutter_test/flutter_test.dart';


// all working
void main() {
  group('ContextConfig', () {
    test('setUnit', () {
      final config = ContextConfig.create().setUnit('session_id', '0ab1e23f4eee');
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
}
