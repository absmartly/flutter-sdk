import 'package:absmartly_dart/src/audience_matcher.dart';
import 'package:absmartly_dart/src/default_audience_deserializer.dart';
import 'package:test/test.dart';

// Runs on the VM and compiled to JavaScript (CI: dart test -p node), where
// every number is a double and Infinity or -0 also pass `is int`.
void main() {
  final matcher = AudienceMatcher(DefaultAudienceDeserializer());

  String rules(String variant) => '{"rules":['
      '{"type":"assign","variant":$variant,"environments":[],'
      '"conditions":{"value":true}},'
      '{"type":"assign","variant":2,"environments":[],'
      '"conditions":{"value":true}}]}';

  test('an infinite assign variant is skipped for the next rule', () {
    expect(matcher.evaluateRules(rules('1e400'), 'production', {}),
        RuleAction.assign(2));
    expect(matcher.evaluateRules(rules('-1e400'), 'production', {}),
        RuleAction.assign(2));
  });

  test('a -0 assign variant is variant 0', () {
    final action = matcher.evaluateRules(rules('-0'), 'production', {})!;
    expect(action.variant, 0);
    expect(action.variant.toString(), '0');
    expect(matcher.evaluateRules(rules('-0.0'), 'production', {})!.variant, 0);
  });

  test('whole and fractional assign variants', () {
    expect(matcher.evaluateRules(rules('1'), 'production', {}),
        RuleAction.assign(1));
    expect(matcher.evaluateRules(rules('1.0'), 'production', {}),
        RuleAction.assign(1));
    expect(matcher.evaluateRules(rules('1.5'), 'production', {}),
        RuleAction.assign(2));
  });
}
