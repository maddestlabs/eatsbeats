import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/ui/vector/svg_path_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SvgPathParser Tests', () {
    test('parses simple triangle path M, L, Z', () {
      final path = SvgPathParser.parse('M 0 0 L 10 20 L -10 20 Z');
      expect(path, isNotNull);
      final bounds = path.getBounds();
      expect(bounds.left, -10.0);
      expect(bounds.right, 10.0);
      expect(bounds.top, 0.0);
      expect(bounds.bottom, 20.0);
    });

    test('parses relative commands m, l, z', () {
      final path = SvgPathParser.parse('m 10 10 l 5 5 l -5 5 z');
      expect(path, isNotNull);
      final bounds = path.getBounds();
      expect(bounds.left, 10.0);
      expect(bounds.right, 15.0);
      expect(bounds.top, 10.0);
      expect(bounds.bottom, 20.0);
    });

    test('parses horizontal and vertical lines H, h, V, v', () {
      final path = SvgPathParser.parse('M 0 0 H 50 V 30 h -50 v -30 Z');
      expect(path, isNotNull);
      final bounds = path.getBounds();
      expect(bounds.left, 0.0);
      expect(bounds.right, 50.0);
      expect(bounds.top, 0.0);
      expect(bounds.bottom, 30.0);
    });

    test('parses cubic and quadratic beziers C, c, Q, q', () {
      final path = SvgPathParser.parse('M 0 0 C 10 10 20 10 30 0 Q 40 20 50 0 Z');
      expect(path, isNotNull);
      final bounds = path.getBounds();
      expect(bounds.width, greaterThan(0));
      expect(bounds.height, greaterThan(0));
    });

    test('caches identical SVG strings to avoid re-parsing', () {
      final p1 = SvgPathParser.parse('M -1.5 0 L 0 -19 L 1.5 0 Z');
      final p2 = SvgPathParser.parse('M -1.5 0 L 0 -19 L 1.5 0 Z');
      expect(identical(p1, p2), isTrue);
    });

    test('handles empty or whitespace strings gracefully', () {
      final path = SvgPathParser.parse('   ');
      expect(path, isNotNull);
      expect(path.getBounds().isEmpty, isTrue);
    });
  });
}
