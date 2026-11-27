/// The full absmartly_sdk API: the absmartly_dart core and the Flutter
/// widgets. New code should import this library.
library absmartly;

// Response stays out of this barrel, as in 2.1: package:http exports a class
// of the same name, so exporting it would make apps that import both fail to
// compile. Import it from package:absmartly_sdk/http_client.dart.
export 'package:absmartly_dart/absmartly_dart.dart' hide Response;

export 'src/loading_behavior.dart';
export 'src/inherited_absmartly.dart';
export 'src/widgets/absmartly_provider.dart';
export 'src/widgets/treatment.dart';
export 'src/widgets/treatment_builder.dart';
export 'src/widgets/treatment_switch.dart';
export 'src/widgets/variable_value.dart';
