import 'dart:async';

import 'package:absmartly_dart/absmartly_dart.dart';
import 'package:flutter/widgets.dart';

import '../inherited_absmartly.dart';
import '../loading_behavior.dart';
import 'absmartly_provider.dart';

typedef TreatmentWidgetBuilder = Widget Function(
  BuildContext context,
  int variant,
  Map<String, dynamic> variables,
);

class TreatmentBuilder extends StatefulWidget {
  const TreatmentBuilder({
    required this.name,
    required this.builder,
    this.loading,
    this.context,
    super.key,
  });

  /// The experiment name as configured in ABSmartly
  final String name;

  /// Builder callback that receives the variant number and experiment variables.
  ///
  /// Example:
  /// ```dart
  /// TreatmentBuilder(
  ///   name: 'price_experiment',
  ///   builder: (context, variant, variables) {
  ///     final price = variables['price'] ?? 9.99;
  ///     return PriceTag(
  ///       price: price,
  ///       highlighted: variant == 1,
  ///     );
  ///   },
  /// )
  /// ```
  final TreatmentWidgetBuilder builder;

  /// Optional widget to show while the context is loading.
  /// If not provided, uses the provider's defaultLoadingBehavior setting.
  final Widget? loading;

  /// Optional specific context to use.
  /// If not provided, uses the context from the nearest ABSmartlyProvider.
  final Context? context;

  @override
  State<TreatmentBuilder> createState() => _TreatmentBuilderState();
}

class _TreatmentBuilderState extends State<TreatmentBuilder> {
  bool _isReady = false;
  bool _timedOut = false;
  int _variant = 0;
  Map<String, dynamic> _variables = {};
  Timer? _timeoutTimer;

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
  void initState() {
    super.initState();
    _initializeTreatment();
  }

  @override
  void didUpdateWidget(TreatmentBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name || oldWidget.context != widget.context) {
      _cancelTimeout();
      setState(() {
        _isReady = false;
        _timedOut = false;
        _variant = 0;
        _variables = {};
      });
      _initializeTreatment();
    }
  }

  void _initializeTreatment() {
    final ctx = _context;

    if (ctx.isReady()) {
      _updateTreatment(ctx);
    } else {
      _startTimeoutIfNeeded();
      ctx.waitUntilReady().then((_) {
        if (mounted) {
          _cancelTimeout();
          _updateTreatment(ctx);
        }
      }).catchError((error) {
        assert(() {
          debugPrint(
              'ABSmartly: TreatmentBuilder "${widget.name}" error: $error');
          return true;
        }());
        if (mounted) {
          _cancelTimeout();
          setState(() {
            _isReady = true;
            _variant = 0;
            _variables = {};
          });
        }
      });
    }
  }

  void _updateTreatment(Context ctx) {
    if (ctx.isFailed()) {
      setState(() {
        _isReady = true;
        _variant = 0;
        _variables = {};
      });
      return;
    }

    final variant = ctx.getTreatment(widget.name);

    final variableKeys = ctx.getVariableKeys();
    final variables = <String, dynamic>{};

    for (final entry in variableKeys.entries) {
      if (entry.value.contains(widget.name)) {
        variables[entry.key] = ctx.peekVariableValue(entry.key, null);
      }
    }

    setState(() {
      _isReady = true;
      _variant = variant;
      _variables = variables;
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
      return widget.builder(context, _variant, _variables);
    }

    if (widget.loading != null) {
      return widget.loading!;
    }

    final providerData = _providerData;
    final loadingBehavior =
        providerData?.defaultLoadingBehavior ?? LoadingBehavior.control;

    if (_timedOut || loadingBehavior == LoadingBehavior.control) {
      return widget.builder(context, 0, {});
    }

    return const SizedBox.shrink();
  }
}
