// Mocks generated by Mockito 5.3.2 from annotations
// in absmartly_sdk/http_client.dart.
// Do not manually edit this file.

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i3;

import 'package:absmartly_sdk/http_client.dart' as _i2;
import 'package:mockito/mockito.dart' as _i1;

// ignore_for_file: type=lint
// ignore_for_file: avoid_redundant_argument_values
// ignore_for_file: avoid_setters_without_getters
// ignore_for_file: comment_references
// ignore_for_file: implementation_imports
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_parenthesis
// ignore_for_file: camel_case_types
// ignore_for_file: subtype_of_sealed_class

class _FakeResponse_0 extends _i1.SmartFake implements _i2.Response {
  _FakeResponse_0(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

/// A class which mocks [HTTPClient].
///
/// See the documentation for Mockito's code generation for more information.
class MockHTTPClient extends _i1.Mock implements _i2.HTTPClient {
  @override
  _i3.Future<_i2.Response> get(
    String? url,
    Map<String, String>? query,
    Map<String, String>? headers,
  ) =>
      (super.noSuchMethod(
        Invocation.method(
          #get,
          [
            url,
            query,
            headers,
          ],
        ),
        returnValue: _i3.Future<_i2.Response>.value(_FakeResponse_0(
          this,
          Invocation.method(
            #get,
            [
              url,
              query,
              headers,
            ],
          ),
        )),
        returnValueForMissingStub:
            _i3.Future<_i2.Response>.value(_FakeResponse_0(
          this,
          Invocation.method(
            #get,
            [
              url,
              query,
              headers,
            ],
          ),
        )),
      ) as _i3.Future<_i2.Response>);
  @override
  _i3.Future<_i2.Response> put(
    String? url,
    Map<String, String>? query,
    Map<String, String>? headers,
    List<int>? body,
  ) =>
      (super.noSuchMethod(
        Invocation.method(
          #put,
          [
            url,
            query,
            headers,
            body,
          ],
        ),
        returnValue: _i3.Future<_i2.Response>.value(_FakeResponse_0(
          this,
          Invocation.method(
            #put,
            [
              url,
              query,
              headers,
              body,
            ],
          ),
        )),
        returnValueForMissingStub:
            _i3.Future<_i2.Response>.value(_FakeResponse_0(
          this,
          Invocation.method(
            #put,
            [
              url,
              query,
              headers,
              body,
            ],
          ),
        )),
      ) as _i3.Future<_i2.Response>);
  @override
  _i3.Future<_i2.Response> post(
    String? url,
    Map<String, String>? query,
    Map<String, String>? headers,
    List<int>? body,
  ) =>
      (super.noSuchMethod(
        Invocation.method(
          #post,
          [
            url,
            query,
            headers,
            body,
          ],
        ),
        returnValue: _i3.Future<_i2.Response>.value(_FakeResponse_0(
          this,
          Invocation.method(
            #post,
            [
              url,
              query,
              headers,
              body,
            ],
          ),
        )),
        returnValueForMissingStub:
            _i3.Future<_i2.Response>.value(_FakeResponse_0(
          this,
          Invocation.method(
            #post,
            [
              url,
              query,
              headers,
              body,
            ],
          ),
        )),
      ) as _i3.Future<_i2.Response>);
  @override
  void close() => super.noSuchMethod(
        Invocation.method(
          #close,
          [],
        ),
        returnValueForMissingStub: null,
      );
}

/// A class which mocks [Response].
///
/// See the documentation for Mockito's code generation for more information.
class MockResponse extends _i1.Mock implements _i2.Response {}
