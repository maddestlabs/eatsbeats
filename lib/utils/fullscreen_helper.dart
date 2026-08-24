import 'package:flutter/foundation.dart';
import 'fullscreen_helper_stub.dart'
    if (dart.library.io) 'fullscreen_helper_io.dart'
    if (dart.library.js_interop) 'fullscreen_helper_web.dart'
    if (dart.library.html) 'fullscreen_helper_web.dart';

class FullscreenHelper {
  static final ValueNotifier<bool> isFullscreenNotifier = ValueNotifier<bool>(false);

  static bool get isFullscreen => getIsFullscreenImpl();

  static Future<void> toggleFullscreen() async {
    await toggleFullscreenImpl();
    isFullscreenNotifier.value = isFullscreen;
  }

  static Future<void> setFullscreen(bool enable) async {
    await setFullscreenImpl(enable);
    isFullscreenNotifier.value = isFullscreen;
  }
}
