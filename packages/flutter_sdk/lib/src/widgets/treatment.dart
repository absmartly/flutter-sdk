import 'dart:async';

import 'package:absmartly_dart/absmartly_dart.dart';
import 'package:flutter/widgets.dart';

import '../inherited_absmartly.dart';
import '../loading_behavior.dart';
import 'absmartly_provider.dart';

class Treatment extends StatefulWidget {
  const Treatment({
    required this.name,
    required this.variants,
    this.loading,
    this.context,
    super.key,
  });

  /// The experiment name as configured in ABSmartly
  final String name;

  /// Map of variant index to widget.
  /// Key 0 = control, 1+ = treatment variants.
  ///
  /// Example:
  /// ```dart
  /// Treatment(
  ///   name: 'checkout_experiment',
  ///   variants: {
  ///     0: OldCheckoutButton(),
  ///     1: NewCheckoutButton(),
  ///   },
  /// )
  /// ```
  final Map<int, Widget> variants;

  /// Optional widget to show while the context is loading.
  /// If not provided, uses the provider's defaultLoadingBehavior setting.
  final Widget? loading;

  /// Optional specific context to use.
  /// If not provided, uses the context from the nearest ABSmartlyProvider.
  final Context? context;

  @override
  State<Treatment> createState() => _TreatmentState();
}

class _TreatmentState extends State<Treatment> {
  bool _isReady = false;
  bool _timedOut = false;
  int _variant = 0;
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
  void didUpdateWidget(Treatment oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name || oldWidget.context != widget.context) {
      _cancelTimeout();
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
          debugPrint('ABSmartly: Treatment "${widget.name}" error: $error');
          return true;
        }());
        if (mounted) {
          _cancelTimeout();
          setState(() {
            _isReady = true;
            _variant = 0;
          });
        }
      });
    }
  }

  void _updateTreatment(Context ctx) {
    setState(() {
      _isReady = true;
      _variant = ctx.isFailed() ? 0 : ctx.getTreatment(widget.name);
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
      return widget.variants[_variant] ?? widget.variants[0] ?? const SizedBox.shrink();
    }

    if (widget.loading != null) {
      return widget.loading!;
    }

    final providerData = _providerData;
    final loadingBehavior = providerData?.defaultLoadingBehavior ?? LoadingBehavior.control;

    if (_timedOut || loadingBehavior == LoadingBehavior.control) {
      return widget.variants[0] ?? const SizedBox.shrink();
    }

    return const SizedBox.shrink();
  }
}
