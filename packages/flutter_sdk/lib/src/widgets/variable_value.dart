import 'dart:async';

import 'package:absmartly_dart/absmartly_dart.dart';
import 'package:flutter/widgets.dart';

import '../inherited_absmartly.dart';
import '../loading_behavior.dart';
import 'absmartly_provider.dart';

class VariableValue<T> extends StatefulWidget {
  const VariableValue({
    required this.name,
    required this.defaultValue,
    required this.builder,
    this.loading,
    this.context,
    super.key,
  });

  /// The variable name as configured in ABSmartly experiment variants.
  final String name;

  /// The default value to use if the variable is not found or context fails.
  final T defaultValue;

  /// Builder function that receives the variable value and returns a widget.
  ///
  /// Example:
  /// ```dart
  /// VariableValue<String>(
  ///   name: 'button_text',
  ///   defaultValue: 'Click me',
  ///   builder: (value) => ElevatedButton(
  ///     onPressed: () {},
  ///     child: Text(value),
  ///   ),
  /// )
  /// ```
  final Widget Function(T value) builder;

  /// Optional widget to show while the context is loading.
  /// If not provided, uses the provider's defaultLoadingBehavior setting.
  final Widget? loading;

  /// Optional specific context to use.
  /// If not provided, uses the context from the nearest ABSmartlyProvider.
  final Context? context;

  @override
  State<VariableValue<T>> createState() => _VariableValueState<T>();
}

class _VariableValueState<T> extends State<VariableValue<T>> {
  bool _isReady = false;
  bool _timedOut = false;
  late T _value;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _value = widget.defaultValue;
    _initializeValue();
  }

  Context get _context {
    if (widget.context != null) {
      return widget.context!;
    }
    return ABSmartlyProvider.of(context, listen: false).context;
  }

  ABSmartlyData? get _providerData {
    return ABSmartlyProvider.maybeOf(context, listen: false);
  }

  @override
  void didUpdateWidget(VariableValue<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name ||
        oldWidget.context != widget.context ||
        oldWidget.defaultValue != widget.defaultValue) {
      _cancelTimeout();
      _initializeValue();
    }
  }

  void _initializeValue() {
    final ctx = _context;

    if (ctx.isReady()) {
      _updateValue(ctx);
    } else {
      _startTimeoutIfNeeded();
      ctx.waitUntilReady().then((_) {
        if (mounted) {
          _cancelTimeout();
          _updateValue(ctx);
        }
      }).catchError((error) {
        assert(() {
          debugPrint('ABSmartly: VariableValue "${widget.name}" error: $error');
          return true;
        }());
        if (mounted) {
          _cancelTimeout();
          setState(() {
            _isReady = true;
            _value = widget.defaultValue;
          });
        }
      });
    }
  }

  void _updateValue(Context ctx) {
    setState(() {
      _isReady = true;
      if (ctx.isFailed()) {
        _value = widget.defaultValue;
      } else {
        final result = ctx.getVariableValue(widget.name, widget.defaultValue);
        _value = result is T ? result : widget.defaultValue;
      }
    });
  }

  void _startTimeoutIfNeeded() {
    if (widget.loading != null) {
      return;
    }

    final providerData = _providerData;
    if (providerData == null) {
      return;
    }

    if (providerData.defaultLoadingBehavior == LoadingBehavior.placeholder) {
      _timeoutTimer = Timer(providerData.readyTimeout, () {
        if (mounted && !_isReady) {
          setState(() {
            _timedOut = true;
          });
        }
      });
    }
  }

  void _cancelTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  @override
  void dispose() {
    _cancelTimeout();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isReady) {
      return widget.builder(_value);
    }

    if (widget.loading != null) {
      return widget.loading!;
    }

    final providerData = _providerData;
    final loadingBehavior =
        providerData?.defaultLoadingBehavior ?? LoadingBehavior.control;

    if (_timedOut || loadingBehavior == LoadingBehavior.control) {
      return widget.builder(widget.defaultValue);
    }

    return const SizedBox.shrink();
  }
}
