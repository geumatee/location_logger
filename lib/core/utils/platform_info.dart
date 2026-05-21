import 'dart:io';

/// Small abstraction over `dart:io` platform checks for easier testing.
abstract class PlatformInfo {
  /// Whether the current platform is Android.
  bool get isAndroid;

  /// Whether the current platform is iOS.
  bool get isIos;
}

/// Default `PlatformInfo` backed by `dart:io`.
class DefaultPlatformInfo implements PlatformInfo {
  @override
  bool get isAndroid => Platform.isAndroid;

  @override
  bool get isIos => Platform.isIOS;
}
