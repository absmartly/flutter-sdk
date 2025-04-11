// Mocks generated by Mockito 5.4.4 from annotations
// in absmartly_sdk/test/ab_smartly_test.dart.
// Do not manually edit this file.

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i3;
import 'dart:typed_data' as _i19;

import 'package:absmartly_sdk/audience_deserializer.dart' as _i24;
import 'package:absmartly_sdk/audience_matcher.dart' as _i9;
import 'package:absmartly_sdk/client.dart' as _i4;
import 'package:absmartly_sdk/context.dart' as _i10;
import 'package:absmartly_sdk/context_data_deserializer.dart' as _i14;
import 'package:absmartly_sdk/context_data_provider.dart' as _i7;
import 'package:absmartly_sdk/context_event_handler.dart' as _i6;
import 'package:absmartly_sdk/context_event_logger.dart' as _i18;
import 'package:absmartly_sdk/context_event_serializer.dart' as _i15;
import 'package:absmartly_sdk/default_context_data_provider.dart' as _i17;
import 'package:absmartly_sdk/http_client.dart' as _i2;
import 'package:absmartly_sdk/internal/variant_assigner.dart' as _i12;
import 'package:absmartly_sdk/java/time/clock.dart' as _i5;
import 'package:absmartly_sdk/json/attribute.dart' as _i22;
import 'package:absmartly_sdk/json/context_data.dart' as _i11;
import 'package:absmartly_sdk/json/experiment.dart' as _i23;
import 'package:absmartly_sdk/json/exposure.dart' as _i20;
import 'package:absmartly_sdk/json/goal_achievement.dart' as _i21;
import 'package:absmartly_sdk/json/publish_event.dart' as _i16;
import 'package:absmartly_sdk/variable_parser.dart' as _i8;
import 'package:mockito/mockito.dart' as _i1;
import 'package:mockito/src/dummies.dart' as _i13;

// ignore_for_file: type=lint
// ignore_for_file: avoid_redundant_argument_values
// ignore_for_file: avoid_setters_without_getters
// ignore_for_file: comment_references
// ignore_for_file: deprecated_member_use
// ignore_for_file: deprecated_member_use_from_same_package
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

class _FakeCompleter_1<T> extends _i1.SmartFake implements _i3.Completer<T> {
  _FakeCompleter_1(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeClient_2 extends _i1.SmartFake implements _i4.Client {
  _FakeClient_2(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeClock_3 extends _i1.SmartFake implements _i5.Clock {
  _FakeClock_3(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeContextEventHandler_4 extends _i1.SmartFake
    implements _i6.ContextEventHandler {
  _FakeContextEventHandler_4(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeContextDataProvider_5 extends _i1.SmartFake
    implements _i7.ContextDataProvider {
  _FakeContextDataProvider_5(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeVariableParser_6 extends _i1.SmartFake
    implements _i8.VariableParser {
  _FakeVariableParser_6(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeAudienceMatcher_7 extends _i1.SmartFake
    implements _i9.AudienceMatcher {
  _FakeAudienceMatcher_7(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeContext_8 extends _i1.SmartFake implements _i10.Context {
  _FakeContext_8(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeContextData_9 extends _i1.SmartFake implements _i11.ContextData {
  _FakeContextData_9(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeAssignment_10 extends _i1.SmartFake implements _i10.Assignment {
  _FakeAssignment_10(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeVariantAssigner_11 extends _i1.SmartFake
    implements _i12.VariantAssigner {
  _FakeVariantAssigner_11(
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
class MockClient extends _i1.Mock implements _i4.Client {
  @override
  String get url_ => (super.noSuchMethod(
        Invocation.getter(#url_),
        returnValue: _i13.dummyValue<String>(
          this,
          Invocation.getter(#url_),
        ),
        returnValueForMissingStub: _i13.dummyValue<String>(
          this,
          Invocation.getter(#url_),
        ),
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
  set deserializer_(_i14.ContextDataDeserializer? _deserializer_) =>
      super.noSuchMethod(
        Invocation.setter(
          #deserializer_,
          _deserializer_,
        ),
        returnValueForMissingStub: null,
      );

  @override
  set serializer_(_i15.ContextEventSerializer? _serializer_) =>
      super.noSuchMethod(
        Invocation.setter(
          #serializer_,
          _serializer_,
        ),
        returnValueForMissingStub: null,
      );

  @override
  _i3.Completer<_i11.ContextData> getContextData() => (super.noSuchMethod(
        Invocation.method(
          #getContextData,
          [],
        ),
        returnValue: _FakeCompleter_1<_i11.ContextData>(
          this,
          Invocation.method(
            #getContextData,
            [],
          ),
        ),
        returnValueForMissingStub: _FakeCompleter_1<_i11.ContextData>(
          this,
          Invocation.method(
            #getContextData,
            [],
          ),
        ),
      ) as _i3.Completer<_i11.ContextData>);

  @override
  _i3.Completer<void> publish(_i16.PublishEvent? event) => (super.noSuchMethod(
        Invocation.method(
          #publish,
          [event],
        ),
        returnValue: _FakeCompleter_1<void>(
          this,
          Invocation.method(
            #publish,
            [event],
          ),
        ),
        returnValueForMissingStub: _FakeCompleter_1<void>(
          this,
          Invocation.method(
            #publish,
            [event],
          ),
        ),
      ) as _i3.Completer<void>);
}

/// A class which mocks [DefaultContextDataProvider].
///
/// See the documentation for Mockito's code generation for more information.
class MockDefaultContextDataProvider extends _i1.Mock
    implements _i17.DefaultContextDataProvider {
  @override
  _i4.Client get client_ => (super.noSuchMethod(
        Invocation.getter(#client_),
        returnValue: _FakeClient_2(
          this,
          Invocation.getter(#client_),
        ),
        returnValueForMissingStub: _FakeClient_2(
          this,
          Invocation.getter(#client_),
        ),
      ) as _i4.Client);

  @override
  _i3.Completer<_i11.ContextData> getContextData() => (super.noSuchMethod(
        Invocation.method(
          #getContextData,
          [],
        ),
        returnValue: _FakeCompleter_1<_i11.ContextData>(
          this,
          Invocation.method(
            #getContextData,
            [],
          ),
        ),
        returnValueForMissingStub: _FakeCompleter_1<_i11.ContextData>(
          this,
          Invocation.method(
            #getContextData,
            [],
          ),
        ),
      ) as _i3.Completer<_i11.ContextData>);
}

/// A class which mocks [Context].
///
/// See the documentation for Mockito's code generation for more information.
class MockContext extends _i1.Mock implements _i10.Context {
  @override
  _i5.Clock get clock_ => (super.noSuchMethod(
        Invocation.getter(#clock_),
        returnValue: _FakeClock_3(
          this,
          Invocation.getter(#clock_),
        ),
        returnValueForMissingStub: _FakeClock_3(
          this,
          Invocation.getter(#clock_),
        ),
      ) as _i5.Clock);

  @override
  set clock_(_i5.Clock? _clock_) => super.noSuchMethod(
        Invocation.setter(
          #clock_,
          _clock_,
        ),
        returnValueForMissingStub: null,
      );

  @override
  int get publishDelay_ => (super.noSuchMethod(
        Invocation.getter(#publishDelay_),
        returnValue: 0,
        returnValueForMissingStub: 0,
      ) as int);

  @override
  set publishDelay_(int? _publishDelay_) => super.noSuchMethod(
        Invocation.setter(
          #publishDelay_,
          _publishDelay_,
        ),
        returnValueForMissingStub: null,
      );

  @override
  int get refreshInterval_ => (super.noSuchMethod(
        Invocation.getter(#refreshInterval_),
        returnValue: 0,
        returnValueForMissingStub: 0,
      ) as int);

  @override
  set refreshInterval_(int? _refreshInterval_) => super.noSuchMethod(
        Invocation.setter(
          #refreshInterval_,
          _refreshInterval_,
        ),
        returnValueForMissingStub: null,
      );

  @override
  _i6.ContextEventHandler get eventHandler_ => (super.noSuchMethod(
        Invocation.getter(#eventHandler_),
        returnValue: _FakeContextEventHandler_4(
          this,
          Invocation.getter(#eventHandler_),
        ),
        returnValueForMissingStub: _FakeContextEventHandler_4(
          this,
          Invocation.getter(#eventHandler_),
        ),
      ) as _i6.ContextEventHandler);

  @override
  set eventHandler_(_i6.ContextEventHandler? _eventHandler_) =>
      super.noSuchMethod(
        Invocation.setter(
          #eventHandler_,
          _eventHandler_,
        ),
        returnValueForMissingStub: null,
      );

  @override
  _i7.ContextDataProvider get dataProvider_ => (super.noSuchMethod(
        Invocation.getter(#dataProvider_),
        returnValue: _FakeContextDataProvider_5(
          this,
          Invocation.getter(#dataProvider_),
        ),
        returnValueForMissingStub: _FakeContextDataProvider_5(
          this,
          Invocation.getter(#dataProvider_),
        ),
      ) as _i7.ContextDataProvider);

  @override
  set dataProvider_(_i7.ContextDataProvider? _dataProvider_) =>
      super.noSuchMethod(
        Invocation.setter(
          #dataProvider_,
          _dataProvider_,
        ),
        returnValueForMissingStub: null,
      );

  @override
  _i8.VariableParser get variableParser_ => (super.noSuchMethod(
        Invocation.getter(#variableParser_),
        returnValue: _FakeVariableParser_6(
          this,
          Invocation.getter(#variableParser_),
        ),
        returnValueForMissingStub: _FakeVariableParser_6(
          this,
          Invocation.getter(#variableParser_),
        ),
      ) as _i8.VariableParser);

  @override
  set variableParser_(_i8.VariableParser? _variableParser_) =>
      super.noSuchMethod(
        Invocation.setter(
          #variableParser_,
          _variableParser_,
        ),
        returnValueForMissingStub: null,
      );

  @override
  _i9.AudienceMatcher get audienceMatcher_ => (super.noSuchMethod(
        Invocation.getter(#audienceMatcher_),
        returnValue: _FakeAudienceMatcher_7(
          this,
          Invocation.getter(#audienceMatcher_),
        ),
        returnValueForMissingStub: _FakeAudienceMatcher_7(
          this,
          Invocation.getter(#audienceMatcher_),
        ),
      ) as _i9.AudienceMatcher);

  @override
  set audienceMatcher_(_i9.AudienceMatcher? _audienceMatcher_) =>
      super.noSuchMethod(
        Invocation.setter(
          #audienceMatcher_,
          _audienceMatcher_,
        ),
        returnValueForMissingStub: null,
      );

  @override
  set eventLogger_(_i18.ContextEventLogger? _eventLogger_) =>
      super.noSuchMethod(
        Invocation.setter(
          #eventLogger_,
          _eventLogger_,
        ),
        returnValueForMissingStub: null,
      );

  @override
  Map<String, String> get units_ => (super.noSuchMethod(
        Invocation.getter(#units_),
        returnValue: <String, String>{},
        returnValueForMissingStub: <String, String>{},
      ) as Map<String, String>);

  @override
  bool get failed_ => (super.noSuchMethod(
        Invocation.getter(#failed_),
        returnValue: false,
        returnValueForMissingStub: false,
      ) as bool);

  @override
  set failed_(bool? _failed_) => super.noSuchMethod(
        Invocation.setter(
          #failed_,
          _failed_,
        ),
        returnValueForMissingStub: null,
      );

  @override
  set data_(_i11.ContextData? _data_) => super.noSuchMethod(
        Invocation.setter(
          #data_,
          _data_,
        ),
        returnValueForMissingStub: null,
      );

  @override
  Map<String, _i10.ExperimentVariables> get index_ => (super.noSuchMethod(
        Invocation.getter(#index_),
        returnValue: <String, _i10.ExperimentVariables>{},
        returnValueForMissingStub: <String, _i10.ExperimentVariables>{},
      ) as Map<String, _i10.ExperimentVariables>);

  @override
  set index_(Map<String, _i10.ExperimentVariables>? _index_) =>
      super.noSuchMethod(
        Invocation.setter(
          #index_,
          _index_,
        ),
        returnValueForMissingStub: null,
      );

  @override
  Map<String, List<_i10.ExperimentVariables>> get indexVariables_ =>
      (super.noSuchMethod(
        Invocation.getter(#indexVariables_),
        returnValue: <String, List<_i10.ExperimentVariables>>{},
        returnValueForMissingStub: <String, List<_i10.ExperimentVariables>>{},
      ) as Map<String, List<_i10.ExperimentVariables>>);

  @override
  set indexVariables_(
          Map<String, List<_i10.ExperimentVariables>>? _indexVariables_) =>
      super.noSuchMethod(
        Invocation.setter(
          #indexVariables_,
          _indexVariables_,
        ),
        returnValueForMissingStub: null,
      );

  @override
  Map<String, _i19.Uint8List> get hashedUnits_ => (super.noSuchMethod(
        Invocation.getter(#hashedUnits_),
        returnValue: <String, _i19.Uint8List>{},
        returnValueForMissingStub: <String, _i19.Uint8List>{},
      ) as Map<String, _i19.Uint8List>);

  @override
  Map<String, _i12.VariantAssigner> get assigners_ => (super.noSuchMethod(
        Invocation.getter(#assigners_),
        returnValue: <String, _i12.VariantAssigner>{},
        returnValueForMissingStub: <String, _i12.VariantAssigner>{},
      ) as Map<String, _i12.VariantAssigner>);

  @override
  Map<String, _i10.Assignment> get assignmentCache_ => (super.noSuchMethod(
        Invocation.getter(#assignmentCache_),
        returnValue: <String, _i10.Assignment>{},
        returnValueForMissingStub: <String, _i10.Assignment>{},
      ) as Map<String, _i10.Assignment>);

  @override
  List<_i20.Exposure> get exposures_ => (super.noSuchMethod(
        Invocation.getter(#exposures_),
        returnValue: <_i20.Exposure>[],
        returnValueForMissingStub: <_i20.Exposure>[],
      ) as List<_i20.Exposure>);

  @override
  List<_i21.GoalAchievement> get achievements_ => (super.noSuchMethod(
        Invocation.getter(#achievements_),
        returnValue: <_i21.GoalAchievement>[],
        returnValueForMissingStub: <_i21.GoalAchievement>[],
      ) as List<_i21.GoalAchievement>);

  @override
  List<_i22.Attribute> get attributes_ => (super.noSuchMethod(
        Invocation.getter(#attributes_),
        returnValue: <_i22.Attribute>[],
        returnValueForMissingStub: <_i22.Attribute>[],
      ) as List<_i22.Attribute>);

  @override
  Map<String, int> get overrides_ => (super.noSuchMethod(
        Invocation.getter(#overrides_),
        returnValue: <String, int>{},
        returnValueForMissingStub: <String, int>{},
      ) as Map<String, int>);

  @override
  Map<String, int> get cassignments_ => (super.noSuchMethod(
        Invocation.getter(#cassignments_),
        returnValue: <String, int>{},
        returnValueForMissingStub: <String, int>{},
      ) as Map<String, int>);

  @override
  int get pendingCount_ => (super.noSuchMethod(
        Invocation.getter(#pendingCount_),
        returnValue: 0,
        returnValueForMissingStub: 0,
      ) as int);

  @override
  set pendingCount_(int? _pendingCount_) => super.noSuchMethod(
        Invocation.setter(
          #pendingCount_,
          _pendingCount_,
        ),
        returnValueForMissingStub: null,
      );

  @override
  bool get closing_ => (super.noSuchMethod(
        Invocation.getter(#closing_),
        returnValue: false,
        returnValueForMissingStub: false,
      ) as bool);

  @override
  set closing_(bool? _closing_) => super.noSuchMethod(
        Invocation.setter(
          #closing_,
          _closing_,
        ),
        returnValueForMissingStub: null,
      );

  @override
  bool get closed_ => (super.noSuchMethod(
        Invocation.getter(#closed_),
        returnValue: false,
        returnValueForMissingStub: false,
      ) as bool);

  @override
  set closed_(bool? _closed_) => super.noSuchMethod(
        Invocation.setter(
          #closed_,
          _closed_,
        ),
        returnValueForMissingStub: null,
      );

  @override
  bool get refreshing_ => (super.noSuchMethod(
        Invocation.getter(#refreshing_),
        returnValue: false,
        returnValueForMissingStub: false,
      ) as bool);

  @override
  set refreshing_(bool? _refreshing_) => super.noSuchMethod(
        Invocation.setter(
          #refreshing_,
          _refreshing_,
        ),
        returnValueForMissingStub: null,
      );

  @override
  set readyFuture_(_i3.Completer<void>? _readyFuture_) => super.noSuchMethod(
        Invocation.setter(
          #readyFuture_,
          _readyFuture_,
        ),
        returnValueForMissingStub: null,
      );

  @override
  set closingFuture_(_i3.Completer<void>? _closingFuture_) =>
      super.noSuchMethod(
        Invocation.setter(
          #closingFuture_,
          _closingFuture_,
        ),
        returnValueForMissingStub: null,
      );

  @override
  set refreshFuture_(_i3.Completer<void>? _refreshFuture_) =>
      super.noSuchMethod(
        Invocation.setter(
          #refreshFuture_,
          _refreshFuture_,
        ),
        returnValueForMissingStub: null,
      );

  @override
  set timeout_(_i3.Timer? _timeout_) => super.noSuchMethod(
        Invocation.setter(
          #timeout_,
          _timeout_,
        ),
        returnValueForMissingStub: null,
      );

  @override
  set refreshTimer_(_i3.Timer? _refreshTimer_) => super.noSuchMethod(
        Invocation.setter(
          #refreshTimer_,
          _refreshTimer_,
        ),
        returnValueForMissingStub: null,
      );

  @override
  bool isReady() => (super.noSuchMethod(
        Invocation.method(
          #isReady,
          [],
        ),
        returnValue: false,
        returnValueForMissingStub: false,
      ) as bool);

  @override
  bool isFailed() => (super.noSuchMethod(
        Invocation.method(
          #isFailed,
          [],
        ),
        returnValue: false,
        returnValueForMissingStub: false,
      ) as bool);

  @override
  bool isClosed() => (super.noSuchMethod(
        Invocation.method(
          #isClosed,
          [],
        ),
        returnValue: false,
        returnValueForMissingStub: false,
      ) as bool);

  @override
  bool isClosing() => (super.noSuchMethod(
        Invocation.method(
          #isClosing,
          [],
        ),
        returnValue: false,
        returnValueForMissingStub: false,
      ) as bool);

  @override
  _i3.Future<_i10.Context> waitUntilReady() => (super.noSuchMethod(
        Invocation.method(
          #waitUntilReady,
          [],
        ),
        returnValue: _i3.Future<_i10.Context>.value(_FakeContext_8(
          this,
          Invocation.method(
            #waitUntilReady,
            [],
          ),
        )),
        returnValueForMissingStub:
            _i3.Future<_i10.Context>.value(_FakeContext_8(
          this,
          Invocation.method(
            #waitUntilReady,
            [],
          ),
        )),
      ) as _i3.Future<_i10.Context>);

  @override
  List<String> getExperiments() => (super.noSuchMethod(
        Invocation.method(
          #getExperiments,
          [],
        ),
        returnValue: <String>[],
        returnValueForMissingStub: <String>[],
      ) as List<String>);

  @override
  _i11.ContextData getData() => (super.noSuchMethod(
        Invocation.method(
          #getData,
          [],
        ),
        returnValue: _FakeContextData_9(
          this,
          Invocation.method(
            #getData,
            [],
          ),
        ),
        returnValueForMissingStub: _FakeContextData_9(
          this,
          Invocation.method(
            #getData,
            [],
          ),
        ),
      ) as _i11.ContextData);

  @override
  void setOverride(
    String? experimentName,
    int? variant,
  ) =>
      super.noSuchMethod(
        Invocation.method(
          #setOverride,
          [
            experimentName,
            variant,
          ],
        ),
        returnValueForMissingStub: null,
      );

  @override
  int? getOverride(String? experimentName) => (super.noSuchMethod(
        Invocation.method(
          #getOverride,
          [experimentName],
        ),
        returnValueForMissingStub: null,
      ) as int?);

  @override
  void setOverrides(Map<String, int>? overrides) => super.noSuchMethod(
        Invocation.method(
          #setOverrides,
          [overrides],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void setCustomAssignment(
    String? experimentName,
    int? variant,
  ) =>
      super.noSuchMethod(
        Invocation.method(
          #setCustomAssignment,
          [
            experimentName,
            variant,
          ],
        ),
        returnValueForMissingStub: null,
      );

  @override
  int? getCustomAssignment(String? experimentName) => (super.noSuchMethod(
        Invocation.method(
          #getCustomAssignment,
          [experimentName],
        ),
        returnValueForMissingStub: null,
      ) as int?);

  @override
  void setCustomAssignments(Map<String, int>? customAssignments) =>
      super.noSuchMethod(
        Invocation.method(
          #setCustomAssignments,
          [customAssignments],
        ),
        returnValueForMissingStub: null,
      );

  @override
  String? getUnit(String? unitType) => (super.noSuchMethod(
        Invocation.method(
          #getUnit,
          [unitType],
        ),
        returnValueForMissingStub: null,
      ) as String?);

  @override
  void setUnit(
    String? unitType,
    String? uid,
  ) =>
      super.noSuchMethod(
        Invocation.method(
          #setUnit,
          [
            unitType,
            uid,
          ],
        ),
        returnValueForMissingStub: null,
      );

  @override
  Map<String, String> getUnits() => (super.noSuchMethod(
        Invocation.method(
          #getUnits,
          [],
        ),
        returnValue: <String, String>{},
        returnValueForMissingStub: <String, String>{},
      ) as Map<String, String>);

  @override
  void setUnits(Map<String, String>? units) => super.noSuchMethod(
        Invocation.method(
          #setUnits,
          [units],
        ),
        returnValueForMissingStub: null,
      );

  @override
  dynamic getAttribute(String? name) => super.noSuchMethod(
        Invocation.method(
          #getAttribute,
          [name],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void setAttribute(
    String? name,
    dynamic value,
  ) =>
      super.noSuchMethod(
        Invocation.method(
          #setAttribute,
          [
            name,
            value,
          ],
        ),
        returnValueForMissingStub: null,
      );

  @override
  Map<String, dynamic> getAttributes() => (super.noSuchMethod(
        Invocation.method(
          #getAttributes,
          [],
        ),
        returnValue: <String, dynamic>{},
        returnValueForMissingStub: <String, dynamic>{},
      ) as Map<String, dynamic>);

  @override
  void setAttributes(Map<String, dynamic>? attributes) => super.noSuchMethod(
        Invocation.method(
          #setAttributes,
          [attributes],
        ),
        returnValueForMissingStub: null,
      );

  @override
  int getTreatment(String? experimentName) => (super.noSuchMethod(
        Invocation.method(
          #getTreatment,
          [experimentName],
        ),
        returnValue: 0,
        returnValueForMissingStub: 0,
      ) as int);

  @override
  void queueExposure(_i10.Assignment? assignment) => super.noSuchMethod(
        Invocation.method(
          #queueExposure,
          [assignment],
        ),
        returnValueForMissingStub: null,
      );

  @override
  int peekTreatment(String? experimentName) => (super.noSuchMethod(
        Invocation.method(
          #peekTreatment,
          [experimentName],
        ),
        returnValue: 0,
        returnValueForMissingStub: 0,
      ) as int);

  @override
  Map<String, List<String>> getVariableKeys() => (super.noSuchMethod(
        Invocation.method(
          #getVariableKeys,
          [],
        ),
        returnValue: <String, List<String>>{},
        returnValueForMissingStub: <String, List<String>>{},
      ) as Map<String, List<String>>);

  @override
  dynamic getVariableValue(
    String? key,
    dynamic defaultValue,
  ) =>
      super.noSuchMethod(
        Invocation.method(
          #getVariableValue,
          [
            key,
            defaultValue,
          ],
        ),
        returnValueForMissingStub: null,
      );

  @override
  dynamic peekVariableValue(
    String? key,
    dynamic defaultValue,
  ) =>
      super.noSuchMethod(
        Invocation.method(
          #peekVariableValue,
          [
            key,
            defaultValue,
          ],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void track(
    String? goalName,
    Map<String, dynamic>? properties,
  ) =>
      super.noSuchMethod(
        Invocation.method(
          #track,
          [
            goalName,
            properties,
          ],
        ),
        returnValueForMissingStub: null,
      );

  @override
  _i3.Future<void> publish() => (super.noSuchMethod(
        Invocation.method(
          #publish,
          [],
        ),
        returnValue: _i3.Future<void>.value(),
        returnValueForMissingStub: _i3.Future<void>.value(),
      ) as _i3.Future<void>);

  @override
  int getPendingCount() => (super.noSuchMethod(
        Invocation.method(
          #getPendingCount,
          [],
        ),
        returnValue: 0,
        returnValueForMissingStub: 0,
      ) as int);

  @override
  _i3.Future<void> refresh() => (super.noSuchMethod(
        Invocation.method(
          #refresh,
          [],
        ),
        returnValue: _i3.Future<void>.value(),
        returnValueForMissingStub: _i3.Future<void>.value(),
      ) as _i3.Future<void>);

  @override
  _i3.Future<void> close() => (super.noSuchMethod(
        Invocation.method(
          #close,
          [],
        ),
        returnValue: _i3.Future<void>.value(),
        returnValueForMissingStub: _i3.Future<void>.value(),
      ) as _i3.Future<void>);

  @override
  _i3.Future<void> flush() => (super.noSuchMethod(
        Invocation.method(
          #flush,
          [],
        ),
        returnValue: _i3.Future<void>.value(),
        returnValueForMissingStub: _i3.Future<void>.value(),
      ) as _i3.Future<void>);

  @override
  void checkNotClosed() => super.noSuchMethod(
        Invocation.method(
          #checkNotClosed,
          [],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void checkReady(bool? expectNotClosed) => super.noSuchMethod(
        Invocation.method(
          #checkReady,
          [expectNotClosed],
        ),
        returnValueForMissingStub: null,
      );

  @override
  bool experimentMatches(
    _i23.Experiment? experiment,
    _i10.Assignment? assignment,
  ) =>
      (super.noSuchMethod(
        Invocation.method(
          #experimentMatches,
          [
            experiment,
            assignment,
          ],
        ),
        returnValue: false,
        returnValueForMissingStub: false,
      ) as bool);

  @override
  _i10.Assignment getAssignment(String? experimentName) => (super.noSuchMethod(
        Invocation.method(
          #getAssignment,
          [experimentName],
        ),
        returnValue: _FakeAssignment_10(
          this,
          Invocation.method(
            #getAssignment,
            [experimentName],
          ),
        ),
        returnValueForMissingStub: _FakeAssignment_10(
          this,
          Invocation.method(
            #getAssignment,
            [experimentName],
          ),
        ),
      ) as _i10.Assignment);

  @override
  _i10.Assignment? getVariableAssignment(String? key) => (super.noSuchMethod(
        Invocation.method(
          #getVariableAssignment,
          [key],
        ),
        returnValueForMissingStub: null,
      ) as _i10.Assignment?);

  @override
  _i10.ExperimentVariables? getExperiment(String? experimentName) =>
      (super.noSuchMethod(
        Invocation.method(
          #getExperiment,
          [experimentName],
        ),
        returnValueForMissingStub: null,
      ) as _i10.ExperimentVariables?);

  @override
  List<_i10.ExperimentVariables>? getVariableExperiments(String? key) =>
      (super.noSuchMethod(
        Invocation.method(
          #getVariableExperiments,
          [key],
        ),
        returnValueForMissingStub: null,
      ) as List<_i10.ExperimentVariables>?);

  @override
  _i19.Uint8List getUnitHash(
    String? unitType,
    String? unitUID,
  ) =>
      (super.noSuchMethod(
        Invocation.method(
          #getUnitHash,
          [
            unitType,
            unitUID,
          ],
        ),
        returnValue: _i19.Uint8List(0),
        returnValueForMissingStub: _i19.Uint8List(0),
      ) as _i19.Uint8List);

  @override
  _i12.VariantAssigner getVariantAssigner(
    String? unitType,
    _i19.Uint8List? unitHash,
  ) =>
      (super.noSuchMethod(
        Invocation.method(
          #getVariantAssigner,
          [
            unitType,
            unitHash,
          ],
        ),
        returnValue: _FakeVariantAssigner_11(
          this,
          Invocation.method(
            #getVariantAssigner,
            [
              unitType,
              unitHash,
            ],
          ),
        ),
        returnValueForMissingStub: _FakeVariantAssigner_11(
          this,
          Invocation.method(
            #getVariantAssigner,
            [
              unitType,
              unitHash,
            ],
          ),
        ),
      ) as _i12.VariantAssigner);

  @override
  void setTimeout() => super.noSuchMethod(
        Invocation.method(
          #setTimeout,
          [],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void clearTimeout() => super.noSuchMethod(
        Invocation.method(
          #clearTimeout,
          [],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void setRefreshTimer() => super.noSuchMethod(
        Invocation.method(
          #setRefreshTimer,
          [],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void clearRefreshTimer() => super.noSuchMethod(
        Invocation.method(
          #clearRefreshTimer,
          [],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void setData(_i11.ContextData? data) => super.noSuchMethod(
        Invocation.method(
          #setData,
          [data],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void setDataFailed(dynamic exception) => super.noSuchMethod(
        Invocation.method(
          #setDataFailed,
          [exception],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void logEvent(
    _i18.EventType? event,
    dynamic data,
  ) =>
      super.noSuchMethod(
        Invocation.method(
          #logEvent,
          [
            event,
            data,
          ],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void logError(dynamic error) => super.noSuchMethod(
        Invocation.method(
          #logError,
          [error],
        ),
        returnValueForMissingStub: null,
      );
}

/// A class which mocks [ContextDataProvider].
///
/// See the documentation for Mockito's code generation for more information.
class MockContextDataProvider extends _i1.Mock
    implements _i7.ContextDataProvider {
  @override
  _i3.Completer<_i11.ContextData> getContextData() => (super.noSuchMethod(
        Invocation.method(
          #getContextData,
          [],
        ),
        returnValue: _FakeCompleter_1<_i11.ContextData>(
          this,
          Invocation.method(
            #getContextData,
            [],
          ),
        ),
        returnValueForMissingStub: _FakeCompleter_1<_i11.ContextData>(
          this,
          Invocation.method(
            #getContextData,
            [],
          ),
        ),
      ) as _i3.Completer<_i11.ContextData>);
}

/// A class which mocks [ContextEventHandler].
///
/// See the documentation for Mockito's code generation for more information.
class MockContextEventHandler extends _i1.Mock
    implements _i6.ContextEventHandler {
  @override
  _i3.Completer<void> publish(
    _i10.Context? context,
    _i16.PublishEvent? event,
  ) =>
      (super.noSuchMethod(
        Invocation.method(
          #publish,
          [
            context,
            event,
          ],
        ),
        returnValue: _FakeCompleter_1<void>(
          this,
          Invocation.method(
            #publish,
            [
              context,
              event,
            ],
          ),
        ),
        returnValueForMissingStub: _FakeCompleter_1<void>(
          this,
          Invocation.method(
            #publish,
            [
              context,
              event,
            ],
          ),
        ),
      ) as _i3.Completer<void>);
}

/// A class which mocks [ContextEventLogger].
///
/// See the documentation for Mockito's code generation for more information.
class MockContextEventLogger extends _i1.Mock
    implements _i18.ContextEventLogger {
  @override
  void handleEvent(
    _i10.Context? context,
    _i18.EventType? type,
    dynamic data,
  ) =>
      super.noSuchMethod(
        Invocation.method(
          #handleEvent,
          [
            context,
            type,
            data,
          ],
        ),
        returnValueForMissingStub: null,
      );
}

/// A class which mocks [VariableParser].
///
/// See the documentation for Mockito's code generation for more information.
class MockVariableParser extends _i1.Mock implements _i8.VariableParser {
  @override
  Map<String, dynamic>? parse(
    _i10.Context? context,
    String? experimentName,
    String? variantName,
    String? variableValue,
  ) =>
      (super.noSuchMethod(
        Invocation.method(
          #parse,
          [
            context,
            experimentName,
            variantName,
            variableValue,
          ],
        ),
        returnValueForMissingStub: null,
      ) as Map<String, dynamic>?);
}

/// A class which mocks [AudienceDeserializer].
///
/// See the documentation for Mockito's code generation for more information.
class MockAudienceDeserializer extends _i1.Mock
    implements _i24.AudienceDeserializer {
  @override
  Map<String, dynamic>? deserialize(
    List<int>? bytes,
    int? offset,
    int? length,
  ) =>
      (super.noSuchMethod(
        Invocation.method(
          #deserialize,
          [
            bytes,
            offset,
            length,
          ],
        ),
        returnValueForMissingStub: null,
      ) as Map<String, dynamic>?);
}
