import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_wren_daw/models/daw_state.dart';
import 'package:mobile_wren_daw/models/track_model.dart';
import 'package:mobile_wren_daw/theme/eats_theme.dart';
import 'package:mobile_wren_daw/ui/arranger_view.dart';
import 'package:mobile_wren_daw/ui/edit_view.dart';
import 'package:mobile_wren_daw/ui/piano_roll_view.dart';
import 'package:mobile_wren_daw/ui/widgets/arranger_context_inspector.dart';
import 'package:mobile_wren_daw/ui/widgets/glowing_nixie_display.dart';
import 'package:mobile_wren_daw/ui/widgets/lcd_display_widget.dart';
import 'package:mobile_wren_daw/ui/widgets/midi_fx_rack_widget.dart';
import 'package:mobile_wren_daw/ui/widgets/modular_fx_rack_widget.dart';
import 'package:mobile_wren_daw/ui/widgets/skeuomorphic_hardware_switch.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Theme Color Tokens & Display Tests', () {
    test('EatsTheme provides customized colors for tempo, clip, chord track, and LCD across all presets', () {
      for (final preset in EatsThemePreset.values) {
        EatsTheme.currentPreset = preset;
        expect(EatsTheme.tempoTextColor, isNotNull);
        expect(EatsTheme.tempoGlowColor, isNotNull);
        expect(EatsTheme.clipTextColor, isNotNull);
        expect(EatsTheme.chordTrackTextColor, isNotNull);
        expect(EatsTheme.highlightColor, isNotNull);
        expect(EatsTheme.lcdBackground, isNotNull);
        expect(EatsTheme.lcdBorder, isNotNull);
        expect(EatsTheme.lcdTextColor, isNotNull);
        expect(EatsTheme.lcdDotColor, isNotNull);
        expect(EatsTheme.lcdGlowColor, isNotNull);
      }
      EatsTheme.currentPreset = EatsThemePreset.ateTrack;
    });

    testWidgets('GlowingNixieDisplay uses theme tempoTextColor and tempoGlowColor', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: GlowingNixieDisplay(
                label: 'TEMPO',
                valueText: '120',
                unit: 'BPM',
              ),
            ),
          ),
        ),
      );

      expect(find.text('120 BPM'), findsNWidgets(2)); // Glow + foreground
    });

    testWidgets('LcdDisplayWidget renders across all theme presets with dynamic LCD colors', (tester) async {
      for (final preset in EatsThemePreset.values) {
        EatsTheme.currentPreset = preset;
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: LcdDisplayWidget(
                  title: '1  SYNTH LEAD',
                  leftText: 'center',
                  rightText: '85%',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('1  SYNTH LEAD'), findsOneWidget);
        expect(find.text('center'), findsOneWidget);
        expect(find.text('85%'), findsOneWidget);
      }
      EatsTheme.currentPreset = EatsThemePreset.ateTrack;
    });
  });

  group('FX Rack Button Text Tests', () {
    testWidgets('ModularFxRackWidget renders single "+ ADD FX" button without duplicate plus icon', (tester) async {
      final dawState = DawState(enableMeterTimer: false);
      final track = dawState.activeTrack;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModularFxRackWidget(dawState: dawState, track: track),
          ),
        ),
      );

      expect(find.text('+ ADD FX'), findsOneWidget);
      // No duplicate plus icon inside the button
      final addIcons = find.descendant(
        of: find.widgetWithText(PopupMenuButton<FXType>, '+ ADD FX'),
        matching: find.byIcon(Icons.add),
      );
      expect(addIcons, findsNothing);

      dawState.dispose();
    });

    testWidgets('MidiFxRackWidget renders single "+ ADD MIDI FX" button without duplicate plus icon', (tester) async {
      final dawState = DawState(enableMeterTimer: false);
      final track = dawState.activeTrack;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MidiFxRackWidget(dawState: dawState, track: track),
          ),
        ),
      );

      expect(find.text('+ ADD MIDI FX'), findsOneWidget);
      final addIcons = find.descendant(
        of: find.widgetWithText(PopupMenuButton<String>, '+ ADD MIDI FX'),
        matching: find.byIcon(Icons.add),
      );
      expect(addIcons, findsNothing);

      dawState.dispose();
    });
  });

  group('SkeuomorphicHardwareSwitch Proportions Test', () {
    testWidgets('Renders toggle switch in ON state cleanly with jewel LED', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SkeuomorphicHardwareSwitch(
                value: true,
                showLed: true,
                onChanged: (v) {},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(SkeuomorphicHardwareSwitch), findsOneWidget);
    });
  });

  group('Arranger Properties Tab & Clip Right-Click Tests', () {
    testWidgets('ArrangerView renders right sidebar Properties icon tab and opens inspector', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dawState = DawState(enableMeterTimer: false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArrangerView(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify INFO button is NOT present in tracks header
      expect(find.widgetWithText(Row, 'INFO'), findsNothing);

      // Verify Properties tab button is present on right sidebar
      final propBtn = find.byTooltip('Open Properties Panel');
      expect(propBtn, findsOneWidget);

      // Tap to open inspector
      await tester.tap(propBtn);
      await tester.pumpAndSettle();

      expect(find.byType(ArrangerContextInspector), findsOneWidget);

      dawState.dispose();
    });
  });

  group('Piano Roll Top Toolbar Cleanup Tests', () {
    testWidgets('PianoRollView has removed CLIP BARS and NOTES steppers from top toolbar', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dawState = DawState(enableMeterTimer: false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PianoRollView(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify CLIP: and NOTES: steppers are not present in top bar
      expect(find.text('CLIP:'), findsNothing);
      expect(find.text('NOTES:'), findsNothing);
      expect(find.byTooltip('Select Previous Note'), findsNothing);
      expect(find.byTooltip('Select Next Note'), findsNothing);
      expect(find.byTooltip('Shorten Clip Loop Length'), findsNothing);
      expect(find.byTooltip('Extend Clip Loop Length'), findsNothing);

      dawState.dispose();
    });
  });
}
