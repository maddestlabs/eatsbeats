import 'platform_env_helper_stub.dart'
    if (dart.library.io) 'platform_env_helper_io.dart'
    if (dart.library.js_interop) 'platform_env_helper_web.dart'
    if (dart.library.html) 'platform_env_helper_web.dart';

class PlatformEnvHelper {
  /// Returns true if currently running in a headless Flutter / Dart test environment.
  static bool get isFlutterTest => isFlutterTestImpl();
}
