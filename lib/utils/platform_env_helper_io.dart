import 'dart:async';
import 'dart:io' as io;

bool isFlutterTestImpl() {
  try {
    return io.Platform.environment.containsKey('FLUTTER_TEST') ||
        io.Platform.environment['FLUTTER_TEST'] == '1' ||
        Zone.current[#flutter.test] != null;
  } catch (_) {
    return Zone.current[#flutter.test] != null;
  }
}
