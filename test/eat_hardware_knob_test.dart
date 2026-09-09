import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/ui/hardware/eat_hardware_scale.dart';
import 'package:eatsbeats/ui/hardware/eat_hardware_knob_model.dart';
import 'package:eatsbeats/ui/hardware/eat_hardware_knob_painters.dart';
import 'package:eatsbeats/ui/hardware/eat_hardware_knob.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EatScript Hardware Knob Foundation Tests', () {
    test('EatScaleGraduation polar trigonometry calculates accurate angles', () {
      final scale = EatScaleGraduation.zeroToTen();
      expect(scale.tickDivisions, 10);
      expect(scale.labels.length, 11);
      expect(scale.labels.first, '0');
      expect(scale.labels.last, '10');

      final startAngle = scale.valueToAngle(0.0);
      expect(startAngle, closeTo(2.35619, 0.001));

      final endAngle = scale.valueToAngle(1.0);
      expect(endAngle, closeTo(2.35619 + 4.71239, 0.001));

      final center = const Offset(50, 50);
      final pt = scale.polarToCartesian(center, 20, 0.0);
      expect(pt.dx, closeTo(70.0, 0.01));
      expect(pt.dy, closeTo(50.0, 0.01));
    });

    test('All hardware knob presets instantiate with valid 6-zone properties', () {
      // 1. Kick/Snare Pitch
      final pitch = EatHardwareKnobStyle.creamFluted();
      expect(pitch.knurlStyle, EatKnurlStyle.fluted);
      expect(pitch.ribCount, 20);
      expect(pitch.scale.labels, ['low', 'mid', 'high']);
      expect(pitch.arcMode, EatArcMode.unipolar);

      // 2. Kick Body & Snare Wires
      final bakelite = EatHardwareKnobStyle.vintageBakelite();
      expect(pitch.skirtStyle, EatSkirtStyle.flared);
      expect(bakelite.indicatorStyle, EatIndicatorStyle.line);
      expect(bakelite.scale.labels.length, 11);

      // 3. Snare Sustain & Head
      final knurled = EatHardwareKnobStyle.anodizedKnurled(isSustain: true);
      expect(knurled.knurlStyle, EatKnurlStyle.diamond);
      expect(knurled.scale.leadLabel, 'dyn');
      expect(knurled.scale.labels, ['1', '2', '3', '4', '5', '6']);

      // 4. Kick Punch & Snare Rattle
      final stepped = EatHardwareKnobStyle.twoToneStepped();
      expect(stepped.skirtStyle, EatSkirtStyle.stepped);
      expect(stepped.capStyle, EatCapStyle.insetRim);

      // 5. Modern Encoder
      final encoder = EatHardwareKnobStyle.illuminatedEncoder();
      expect(encoder.indicatorStyle, EatIndicatorStyle.illuminatedLed);
      expect(encoder.arcMode, EatArcMode.unipolar);
    });

    test('EatStaticDialPainter and EatDynamicKnobPainter paint cleanly to Canvas', () {
      final style = EatHardwareKnobStyle.creamFluted();
      final staticPainter = EatStaticDialPainter(style: style);
      final dynamicPainter = EatDynamicKnobPainter(normalizedValue: 0.65, style: style);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(64, 64);

      expect(() => staticPainter.paint(canvas, size), returnsNormally);
      expect(() => dynamicPainter.paint(canvas, size), returnsNormally);

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    testWidgets('EatHardwareKnob renders and reacts to gestures', (tester) async {
      double knobValue = 5.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: EatHardwareKnob(
                value: knobValue,
                min: 0.0,
                max: 10.0,
                defaultValue: 5.0,
                label: 'body',
                style: EatHardwareKnobStyle.vintageBakelite(),
                onChanged: (val) => knobValue = val,
              ),
            ),
          ),
        ),
      );

      expect(find.text('BODY'), findsOneWidget);
      expect(find.byType(EatHardwareKnob), findsOneWidget);

      // Simulate dragging upwards to increase value
      final knobFinder = find.byType(GestureDetector).first;
      await tester.drag(knobFinder, const Offset(0, -50));
      await tester.pump();

      expect(knobValue, greaterThan(5.0));

      // Simulate double tap to reset
      await tester.tap(knobFinder);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(knobFinder);
      await tester.pumpAndSettle();

      expect(knobValue, equals(5.0));
    });

    test('All unified knob models (standardHardware, chromeFluted, snesConsole, minimalWhite) instantiate properly', () {
      final std = EatHardwareKnobStyle.standardHardware(accentColor: Colors.amber);
      expect(std.capColor, const Color(0xFF1E2026));
      expect(std.indicatorColor, Colors.amber);
      expect(std.scale.tickDivisions, 10);

      final chrome = EatHardwareKnobStyle.chromeFluted();
      expect(chrome.capStyle, EatCapStyle.brushedMetal);
      expect(chrome.indicatorColor, const Color(0xFF141416));
      expect(chrome.scale.labels.length, 11);

      final snes = EatHardwareKnobStyle.snesConsole();
      expect(snes.capColor, const Color(0xFFE4E1D8));
      expect(snes.indicatorColor, const Color(0xFF51388E));

      final minimal = EatHardwareKnobStyle.minimalWhite();
      expect(minimal.capColor, const Color(0xFFF6F6F7));
      expect(minimal.bezelStyle, EatBezelStyle.none);
    });

    test('TB-303 presets instantiate with authentic declined scoop and properties', () {
      final pot = EatHardwareKnobStyle.tb303Potentiometer();
      expect(pot.capStyle, EatCapStyle.declinedScoop);
      expect(pot.knurlStyle, EatKnurlStyle.fineSawtooth);
      expect(pot.ribCount, 48);
      expect(pot.scale.hasCenterDetent, true);
      expect(pot.scale.hasBlockCenterDetent, true);

      final acid = EatHardwareKnobStyle.tb303AcidHalo(accentColor: const Color(0xFF00FF88));
      expect(acid.capStyle, EatCapStyle.declinedScoop);
      expect(acid.haloColor, const Color(0xFF00FF88));
      expect(acid.knurlStyle, EatKnurlStyle.fineSawtooth);

      final selector = EatHardwareKnobStyle.tb303Selector(labels: const ['CLASSIC', 'STEP', 'WAVE', 'RAND', 'SETUP']);
      expect(selector.capStyle, EatCapStyle.diagonalBar);
      expect(selector.scale.labels, contains('CLASSIC'));
      expect(selector.scale.labels, contains('SETUP'));

      final defaultSelector = EatHardwareKnobStyle.tb303Selector();
      expect(defaultSelector.scale.labels.length, 11);
    });

    testWidgets('EatHardwareKnob allocates positive dialBoxSize for outer scale ticks and legends', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: EatHardwareKnob(
                size: 58.0,
                value: 0.5,
                defaultValue: 0.5,
                style: EatHardwareKnobStyle.creamFluted(),
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      // Sized box containing the dial should be sized widget.size + scalePad (58 + 22 = 80)
      final sizedBoxFinder = find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.width == 80.0 && widget.height == 80.0,
      );
      expect(sizedBoxFinder, findsOneWidget);
    });
  });
}
