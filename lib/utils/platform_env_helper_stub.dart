import 'dart:async';

bool isFlutterTestImpl() {
  return const bool.fromEnvironment('FLUTTER_TEST') || Zone.current[#flutter.test] != null;
}
