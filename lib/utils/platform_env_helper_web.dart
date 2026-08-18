import 'dart:async';

bool isFlutterTestImpl() {
  return Zone.current[#flutter.test] != null;
}
