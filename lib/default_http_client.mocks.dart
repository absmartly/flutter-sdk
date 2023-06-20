// Mocks generated by Mockito 5.3.2 from annotations
// in ab_smartly/default_http_client.dart.
// Do not manually edit this file.

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i5;

import 'package:ab_smartly/default_http_client.dart' as _i4;
import 'package:ab_smartly/helper/http/http.dart' as _i2;
import 'package:ab_smartly/http_client.dart' as _i3;
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

class _FakeClient_0 extends _i1.SmartFake implements _i2.Client {
  _FakeClient_0(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeResponse_1 extends _i1.SmartFake implements _i3.Response {
  _FakeResponse_1(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

/// A class which mocks [DefaultHTTPClient].
///
/// See the documentation for Mockito's code generation for more information.
class MockDefaultHTTPClient extends _i1.Mock implements _i4.DefaultHTTPClient {
  @override
  _i2.Client get client => (super.noSuchMethod(
        Invocation.getter(#client),
        returnValue: _FakeClient_0(
          this,
          Invocation.getter(#client),
        ),
        returnValueForMissingStub: _FakeClient_0(
          this,
          Invocation.getter(#client),
        ),
      ) as _i2.Client);
  @override
  set client(_i2.Client? _client) => super.noSuchMethod(
        Invocation.setter(
          #client,
          _client,
        ),
        returnValueForMissingStub: null,
      );
  @override
  void close() => super.noSuchMethod(
        Invocation.method(
          #close,
          [],
        ),
        returnValueForMissingStub: null,
      );
  @override
  _i5.Future<_i3.Response> get(
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
        returnValue: _i5.Future<_i3.Response>.value(_FakeResponse_1(
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
            _i5.Future<_i3.Response>.value(_FakeResponse_1(
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
      ) as _i5.Future<_i3.Response>);
  @override
  _i5.Future<_i3.Response> post(
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
        returnValue: _i5.Future<_i3.Response>.value(_FakeResponse_1(
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
            _i5.Future<_i3.Response>.value(_FakeResponse_1(
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
      ) as _i5.Future<_i3.Response>);
  @override
  _i5.Future<_i3.Response> put(
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
        returnValue: _i5.Future<_i3.Response>.value(_FakeResponse_1(
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
            _i5.Future<_i3.Response>.value(_FakeResponse_1(
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
      ) as _i5.Future<_i3.Response>);
  @override
  _i5.Future<_i3.Response> makeRequest(
    String? url,
    Map<String, String>? query,
    Map<String, String>? headers,
    List<int>? body,
    String? type,
  ) =>
      (super.noSuchMethod(
        Invocation.method(
          #makeRequest,
          [
            url,
            query,
            headers,
            body,
            type,
          ],
        ),
        returnValue: _i5.Future<_i3.Response>.value(_FakeResponse_1(
          this,
          Invocation.method(
            #makeRequest,
            [
              url,
              query,
              headers,
              body,
              type,
            ],
          ),
        )),
        returnValueForMissingStub:
            _i5.Future<_i3.Response>.value(_FakeResponse_1(
          this,
          Invocation.method(
            #makeRequest,
            [
              url,
              query,
              headers,
              body,
              type,
            ],
          ),
        )),
      ) as _i5.Future<_i3.Response>);
  @override
  _i3.Response parseHttpResponse(_i2.Response? response) => (super.noSuchMethod(
        Invocation.method(
          #parseHttpResponse,
          [response],
        ),
        returnValue: _FakeResponse_1(
          this,
          Invocation.method(
            #parseHttpResponse,
            [response],
          ),
        ),
        returnValueForMissingStub: _FakeResponse_1(
          this,
          Invocation.method(
            #parseHttpResponse,
            [response],
          ),
        ),
      ) as _i3.Response);
}