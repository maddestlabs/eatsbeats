import 'package:flutter/services.dart';

bool isFullscreenState = false;

Future<void> toggleFullscreenImpl() async {
  isFullscreenState = !isFullscreenState;
  try {
    if (isFullscreenState) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  } catch (_) {}
}

Future<void> setFullscreenImpl(bool enable) async {
  isFullscreenState = enable;
  try {
    if (enable) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  } catch (_) {}
}

bool getIsFullscreenImpl() => isFullscreenState;
