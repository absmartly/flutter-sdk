import 'dart:convert';

import 'package:absmartly_sdk/absmartly_sdk.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// Serves a raw JSON context payload so the SDK's own Client and
// DefaultContextDataDeserializer parse it, exactly as on a live fetch.
class _JsonHTTPClient implements HTTPClient {
  _JsonHTTPClient(this.body);

  final String body;

  Response _ok(String content) => DefaultResponse(
        statusCode: 200,
        statusMessage: 'OK',
        contentType: 'application/json; charset=utf-8',
        content: utf8.encode(content),
      );

  @override
  Future<Response> get(String url, Map<String, String>? query,
          Map<String, String>? headers) async =>
      _ok(body);

  @override
  Future<Response> put(String url, Map<String, String>? query,
          Map<String, String>? headers, List<int>? body) async =>
      _ok('{}');

  @override
  Future<Response> post(String url, Map<String, String>? query,
          Map<String, String>? headers, List<int>? body) async =>
      _ok('{}');

  @override
  void close() {}
}

// Whole-number split weights written as JSON integers (`[0, 1]`), which any
// JSON producer may emit for a double array. `split: [0, 1]` sends every unit
// to variant 1, so a correctly parsed payload has exactly one outcome.
const _integerSplitPayload = '''
{
  "experiments": [
    {
      "id": 1,
      "name": "exp_int_split",
      "unitType": "user_id",
      "iteration": 1,
      "seedHi": 3603515,
      "seedLo": 233373850,
      "split": [0, 1],
      "trafficSeedHi": 449867249,
      "trafficSeedLo": 455443629,
      "trafficSplit": [0, 1],
      "fullOnVariant": 0,
      "applications": [{"name": "website"}],
      "variants": [
        {"name": "A", "config": null},
        {"name": "B", "config": "{\\"button.color\\":\\"red\\"}"}
      ],
      "audience": ""
    }
  ]
}
''';

void main() {
  testWidgets('integer split payload loads and renders the assigned variant',
      (tester) async {
    final client = Client.create(
      ClientConfig()
        ..setEndpoint('https://test.absmartly.io/v1')
        ..setAPIKey('test-api-key')
        ..setApplication('website')
        ..setEnvironment('test'),
      httpClient: _JsonHTTPClient(_integerSplitPayload),
    );
    final sdk = ABSmartly(ABSmartlyConfig.create()..setClient(client));
    final context =
        sdk.createContext(ContextConfig.create()..setUnit('user_id', '12345'));

    await tester.runAsync(() => context.waitUntilReady());

    expect(context.isReady(), isTrue);
    expect(context.isFailed(), isFalse);
    expect(context.readyError(), isNull);

    int? renderedVariant;
    Map<String, dynamic>? renderedVariables;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: TreatmentBuilder(
          name: 'exp_int_split',
          context: context,
          builder: (ctx, variant, variables) {
            renderedVariant = variant;
            renderedVariables = variables;
            return Text('variant: $variant');
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.text('variant: 1'), findsOneWidget);
    expect(renderedVariant, 1);
    expect(renderedVariables, {'button.color': 'red'});

    await tester.runAsync(() => context.close());
  });
}
