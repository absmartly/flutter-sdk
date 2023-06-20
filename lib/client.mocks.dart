// Mocks generated by Mockito 5.3.2 from annotations
// in ab_smartly/client.dart.
// Do not manually edit this file.

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i6;

import 'package:ab_smartly/client.dart' as _i3;
import 'package:ab_smartly/context_data_deserializer.dart' as _i4;
import 'package:ab_smartly/context_event_serializer.dart' as _i5;
import 'package:ab_smartly/http_client.dart' as _i2;
import 'package:ab_smartly/json/context_data.dart' as _i7;
import 'package:ab_smartly/json/publish_event.dart' as _i8;
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

class _FakeHTTPClient_0 extends _i1.SmartFake implements _i2.HTTPClient {
  _FakeHTTPClient_0(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

/// A class which mocks [Client].
///
/// See the documentation for Mockito's code generation for more information.
class MockClient extends _i1.Mock implements _i3.Client {
  @override
  String get url_ => (super.noSuchMethod(
        Invocation.getter(#url_),
        returnValue: '',
        returnValueForMissingStub: '',
      ) as String);
  @override
  set url_(String? _url_) => super.noSuchMethod(
        Invocation.setter(
          #url_,
          _url_,
        ),
        returnValueForMissingStub: null,
      );
  @override
  Map<String, String> get query_ => (super.noSuchMethod(
        Invocation.getter(#query_),
        returnValue: <String, String>{},
        returnValueForMissingStub: <String, String>{},
      ) as Map<String, String>);
  @override
  set query_(Map<String, String>? _query_) => super.noSuchMethod(
        Invocation.setter(
          #query_,
          _query_,
        ),
        returnValueForMissingStub: null,
      );
  @override
  Map<String, String> get headers_ => (super.noSuchMethod(
        Invocation.getter(#headers_),
        returnValue: <String, String>{},
        returnValueForMissingStub: <String, String>{},
      ) as Map<String, String>);
  @override
  set headers_(Map<String, String>? _headers_) => super.noSuchMethod(
        Invocation.setter(
          #headers_,
          _headers_,
        ),
        returnValueForMissingStub: null,
      );
  @override
  _i2.HTTPClient get httpClient_ => (super.noSuchMethod(
        Invocation.getter(#httpClient_),
        returnValue: _FakeHTTPClient_0(
          this,
          Invocation.getter(#httpClient_),
        ),
        returnValueForMissingStub: _FakeHTTPClient_0(
          this,
          Invocation.getter(#httpClient_),
        ),
      ) as _i2.HTTPClient);
  @override
  set httpClient_(_i2.HTTPClient? _httpClient_) => super.noSuchMethod(
        Invocation.setter(
          #httpClient_,
          _httpClient_,
        ),
        returnValueForMissingStub: null,
      );
  @override
  set deserializer_(_i4.ContextDataDeserializer? _deserializer_) =>
      super.noSuchMethod(
        Invocation.setter(
          #deserializer_,
          _deserializer_,
        ),
        returnValueForMissingStub: null,
      );
  @override
  set serializer_(_i5.ContextEventSerializer? _serializer_) =>
      super.noSuchMethod(
        Invocation.setter(
          #serializer_,
          _serializer_,
        ),
        returnValueForMissingStub: null,
      );
  @override
  _i6.Future<_i7.ContextData?> getContextData() => (super.noSuchMethod(
        Invocation.method(
          #getContextData,
          [],
        ),
        returnValue: _i6.Future<_i7.ContextData?>.value(),
        returnValueForMissingStub: _i6.Future<_i7.ContextData?>.value(),
      ) as _i6.Future<_i7.ContextData?>);
  @override
  _i6.Future<void> publish(_i8.PublishEvent? event) => (super.noSuchMethod(
        Invocation.method(
          #publish,
          [event],
        ),
        returnValue: _i6.Future<void>.value(),
        returnValueForMissingStub: _i6.Future<void>.value(),
      ) as _i6.Future<void>);
  @override
  void close() => super.noSuchMethod(
        Invocation.method(
          #close,
          [],
        ),
        returnValueForMissingStub: null,
      );
}