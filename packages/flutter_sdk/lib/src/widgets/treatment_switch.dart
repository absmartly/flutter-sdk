import 'dart:async';

import 'package:absmartly_dart/absmartly_dart.dart';
import 'package:flutter/widgets.dart';

import '../inherited_absmartly.dart';
import '../loading_behavior.dart';
import 'absmartly_provider.dart';

class TreatmentVariant extends StatelessWidget {
  const TreatmentVariant({
    required this.variant,
    required this.child,
    super.key,
  });

  /// The variant identifier.
  /// Can be an int (0, 1, 2, ...) or a String letter ('A', 'B', 'C', ...).
  /// - 0 or 'A' = control
  /// - 1 or 'B' = first variant
  /// - etc.
  final dynamic variant;

  /// The widget to display for this variant.
  final Widget child;

  int get variantIndex {
    if (variant is int) {
      return variant as int;
    }
    if (variant is String) {
      final letter = (variant as String).toUpperCase();
      if (letter.length == 1) {
        final code = letter.codeUnitAt(0);
        if (code >= 65 && code <= 90) {
          return code - 65;
        }
      }
      final parsed = int.tryParse(variant as String);
      if (parsed != null) {
        return parsed;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

class TreatmentSwitch extends StatefulWidget {
  const TreatmentSwitch({
    required this.name,
    required this.children,
    this.loading,
    this.context,
    super.key,
  });

  /// The experiment name as configured in ABSmartly
  final String name;

  /// List of TreatmentVariant widgets.
  /// The first variant matching the assigned treatment will be displayed.
  ///
  /// Example:
  /// ```dart
  /// TreatmentSwitch(
  ///   name: 'hero_experiment',
  ///   children: [
  ///     TreatmentVariant(variant: 0, child: ClassicHero()),
  ///     TreatmentVariant(variant: 1, child: ModernHero()),
  ///     TreatmentVariant(variant: 'C', child: MinimalHero()),
  ///   ],
  /// )
  /// ```
  final List<TreatmentVariant> children;

  /// Optional widget to show while the context is loading.
  /// If not provided, uses the provider's defaultLoadingBehavior setting.
  final Widget? loading;

  /// Optional specific context to use.
  /// If not provided, uses the context from the nearest ABSmartlyProvider.
  final Context? context;

  @override
  State<TreatmentSwitch> createState() => _TreatmentSwitchState();
}

class _TreatmentSwitchState extends State<TreatmentSwitch> {
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
  void didUpdateWidget(TreatmentSwitch oldWidget) {
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
      }).catchError((_) {
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

  Widget? _findVariantChild(int variantIndex) {
    for (final child in widget.children) {
      if (child.variantIndex == variantIndex) {
        return child.child;
      }
    }
    return null;
  }

  Widget _getControlChild() {
    return _findVariantChild(0) ??
        (widget.children.isNotEmpty ? widget.children.first.child : const SizedBox.shrink());
  }

  @override
  Widget build(BuildContext context) {
    if (_isReady) {
      return _findVariantChild(_variant) ?? _getControlChild();
    }

    if (widget.loading != null) {
      return widget.loading!;
    }

    final providerData = _providerData;
    final loadingBehavior = providerData?.defaultLoadingBehavior ?? LoadingBehavior.control;

    if (_timedOut || loadingBehavior == LoadingBehavior.control) {
      return _getControlChild();
    }

    return const SizedBox.shrink();
  }
}
