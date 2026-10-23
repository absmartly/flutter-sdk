import 'package:absmartly_dart/absmartly_dart.dart';
import 'package:flutter/widgets.dart';

import 'loading_behavior.dart';

class ABSmartlyData {
  ABSmartlyData({
    required this.sdk,
    required this.context,
    required this.defaultLoadingBehavior,
    required this.readyTimeout,
    required this.resetContext,
  });

  final ABSmartly sdk;
  final Context context;
  final LoadingBehavior defaultLoadingBehavior;
  final Duration readyTimeout;
  final Future<void> Function({required Map<String, String> units})
      resetContext;

  bool get isReady => context.isReady();
  bool get isFailed => context.isFailed();
}

class InheritedABSmartly extends InheritedWidget {
  const InheritedABSmartly({
    required this.data,
    required super.child,
    super.key,
  });

  final ABSmartlyData data;

  static ABSmartlyData of(BuildContext context, {bool listen = true}) {
    final inherited = listen
        ? context.dependOnInheritedWidgetOfExactType<InheritedABSmartly>()
        : context.getInheritedWidgetOfExactType<InheritedABSmartly>();

    if (inherited == null) {
      throw FlutterError.fromParts([
        ErrorSummary('ABSmartlyProvider not found in widget tree.'),
        ErrorDescription(
          'No ABSmartlyProvider ancestor could be found starting from the '
          'context that was passed to ABSmartlyProvider.of(). This can happen '
          'if the context you used comes from a widget above the ABSmartlyProvider.',
        ),
        ErrorHint(
          'Ensure that ABSmartlyProvider is an ancestor of the widget that '
          'calls ABSmartlyProvider.of(). For example:\n'
          '\n'
          '  ABSmartlyProvider.create(\n'
          '    endpoint: "https://...",\n'
          '    apiKey: "...",\n'
          '    environment: "production",\n'
          '    application: "my-app",\n'
          '    units: {"user_id": "12345"},\n'
          '    child: MyApp(),\n'
          '  )',
        ),
      ]);
    }

    return inherited.data;
  }

  static ABSmartlyData? maybeOf(BuildContext context, {bool listen = true}) {
    final inherited = listen
        ? context.dependOnInheritedWidgetOfExactType<InheritedABSmartly>()
        : context.getInheritedWidgetOfExactType<InheritedABSmartly>();
    return inherited?.data;
  }

  @override
  bool updateShouldNotify(InheritedABSmartly oldWidget) {
    return data.context != oldWidget.data.context ||
        data.sdk != oldWidget.data.sdk ||
        data.defaultLoadingBehavior != oldWidget.data.defaultLoadingBehavior ||
        data.readyTimeout != oldWidget.data.readyTimeout;
  }
}
