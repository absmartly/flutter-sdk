/// The SDK name and version sent as the X-Agent header. [version] must match
/// the version in pubspec.yaml (checked by test/sdk_version_test.dart).
class SdkVersion {
  SdkVersion._();

  static const String name = 'absmartly-dart-sdk';
  static const String version = '3.0.0';
  static const String agent = '$name/$version';
}
