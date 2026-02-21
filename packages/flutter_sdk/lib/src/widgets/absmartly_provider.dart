import 'package:absmartly_dart/absmartly_dart.dart';
import 'package:flutter/widgets.dart';

import '../inherited_absmartly.dart';
import '../loading_behavior.dart';

class ABSmartlyProvider extends StatefulWidget {
  /// Creates an ABSmartlyProvider with an existing SDK and context.
  /// Use this for advanced setups where you need custom SDK configuration.
  const ABSmartlyProvider({
    required this.sdk,
    required this.context,
    this.defaultLoadingBehavior = LoadingBehavior.placeholder,
    this.readyTimeout = const Duration(seconds: 3),
    required this.child,
    super.key,
  })  : _endpoint = null,
        _apiKey = null,
        _environment = null,
        _application = null,
        _units = null;

  /// Creates an ABSmartlyProvider with automatic SDK and context creation.
  /// This is the recommended way to set up ABSmartly for most apps.
  ABSmartlyProvider.create({
    required String endpoint,
    required String apiKey,
    required String environment,
    required String application,
    required Map<String, String> units,
    this.defaultLoadingBehavior = LoadingBehavior.placeholder,
    this.readyTimeout = const Duration(seconds: 3),
    required this.child,
    super.key,
  })  : sdk = null,
        context = null,
        _endpoint = endpoint,
        _apiKey = apiKey,
        _environment = environment,
        _application = application,
        _units = units;

  /// The ABSmartly SDK instance (null when using .create())
  final ABSmartly? sdk;

  /// The ABSmartly context (null when using .create())
  final Context? context;

  /// Default loading behavior for Treatment widgets
  final LoadingBehavior defaultLoadingBehavior;

  /// Timeout before falling back to control variant when using placeholder behavior
  final Duration readyTimeout;

  /// The widget tree below this provider
  final Widget child;

  // Private fields for .create() factory
  final String? _endpoint;
  final String? _apiKey;
  final String? _environment;
  final String? _application;
  final Map<String, String>? _units;

  /// Access the ABSmartlyData from the nearest provider.
  /// Set [listen] to false if you don't need to rebuild when the context changes.
  static ABSmartlyData of(BuildContext context, {bool listen = true}) {
    return InheritedABSmartly.of(context, listen: listen);
  }

  /// Access the ABSmartlyData without throwing if no provider is found.
  static ABSmartlyData? maybeOf(BuildContext context, {bool listen = true}) {
    return InheritedABSmartly.maybeOf(context, listen: listen);
  }

  @override
  State<ABSmartlyProvider> createState() => _ABSmartlyProviderState();
}

class _ABSmartlyProviderState extends State<ABSmartlyProvider> {
  late ABSmartly _sdk;
  late Context _context;
  bool _isInternallyCreated = false;

  @override
  void initState() {
    super.initState();
    _initializeSDK();
  }

  void _initializeSDK() {
    if (widget.sdk != null && widget.context != null) {
      _sdk = widget.sdk!;
      _context = widget.context!;
      _isInternallyCreated = false;
    } else {
      _isInternallyCreated = true;

      final clientConfig = ClientConfig()
        ..setEndpoint(widget._endpoint!)
        ..setAPIKey(widget._apiKey!)
        ..setEnvironment(widget._environment!)
        ..setApplication(widget._application!);

      final client = Client.create(clientConfig);

      final sdkConfig = ABSmartlyConfig.create()..setClient(client);

      _sdk = ABSmartly(sdkConfig);

      final contextConfig = ContextConfig.create()
        ..setUnits(widget._units!);

      _context = _sdk.createContext(contextConfig);
    }
  }

  Future<void> _resetContext({required Map<String, String> units}) async {
    if (_context.isClosing() || _context.isClosed()) {
      return;
    }

    await _context.close();

    final contextConfig = ContextConfig.create()..setUnits(units);

    setState(() {
      _context = _sdk.createContext(contextConfig);
    });
  }

  @override
  void dispose() {
    if (_isInternallyCreated) {
      _context.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InheritedABSmartly(
      data: ABSmartlyData(
        sdk: _sdk,
        context: _context,
        defaultLoadingBehavior: widget.defaultLoadingBehavior,
        readyTimeout: widget.readyTimeout,
        resetContext: _resetContext,
      ),
      child: widget.child,
    );
  }
}
