import 'dart:convert';

import 'package:absmartly_sdk/context.dart';
import 'package:absmartly_sdk/default_variable_parser.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'test_utils.dart';

import 'default_variable_parser_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<Context>(),
])
main() {
  test("parse", () async {
    WidgetsFlutterBinding.ensureInitialized();
    final Context context = MockContext();
    final configValue = utf8.decode(await getResourceBytes('variables.json'));

    final variableParser = DefaultVariableParser();
    final variables =
        variableParser.parse(context, 'test_exp', 'B', configValue);

    expect(variables, {
      'a': 1,
      'b': 'test',
      'c': {
        'test': 2,
        'double': 19.123,
        'list': ['x', 'y', 'z'],
        'point': {
          'x': -1.0,
          'y': 0.0,
          'z': 1.0,
        },
      },
      'd': true,
      'f': [9234567890, 'a', true, false],
      'g': 9.123,
    });
  });
}
