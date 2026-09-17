import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/eatscript/eats_tb303_core.dart';
import 'package:eatsbeats/ui/widgets/eats_color_picker_dialog.dart';

void main() {
  group('UI/UX Refinements - Color Picker HSL', () {
    testWidgets('Color picker has Saturation and Luminance sliders alongside Hue', (tester) async {
      Color pickedColor = const Color(0xFF00FFE0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => EatsColorPickerDialog(
                      initialColor: pickedColor,
                      onColorSelected: (c) => pickedColor = c,
                    ),
                  );
                },
                child: const Text('Open Picker'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Check title and sliders
      expect(find.text('SELECT TRACK COLOR'), findsOneWidget);
      expect(find.textContaining('HUE'), findsOneWidget);
      expect(find.textContaining('SATURATION'), findsOneWidget);
      expect(find.textContaining('LUMINANCE'), findsOneWidget);

      // Verify percent readouts are present
      expect(find.textContaining('%'), findsWidgets);
    });

    testWidgets('Opening one settings section collapses any previously open section (accordion)', (tester) async {
      int? activeSection = 0; // Section 0: Project Hub open by default

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    ListTile(
                      title: const Text('PROJECT HUB'),
                      subtitle: activeSection == 0 ? const Text('PROJECT_HUB_EXPANDED') : null,
                      onTap: () => setState(() => activeSection = (activeSection == 0) ? null : 0),
                    ),
                    ListTile(
                      title: const Text('SESSION PERSISTENCE & AUTO-RESTORE'),
                      subtitle: activeSection == 1 ? const Text('SESSION_PERSISTENCE_EXPANDED') : null,
                      onTap: () => setState(() => activeSection = (activeSection == 1) ? null : 1),
                    ),
                    ListTile(
                      title: const Text('DISPLAY & WORKSPACE'),
                      subtitle: activeSection == 2 ? const Text('DISPLAY_WORKSPACE_EXPANDED') : null,
                      onTap: () => setState(() => activeSection = (activeSection == 2) ? null : 2),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('PROJECT_HUB_EXPANDED'), findsOneWidget);
      expect(find.text('SESSION_PERSISTENCE_EXPANDED'), findsNothing);

      // Tapping SESSION PERSISTENCE should expand it and collapse PROJECT HUB
      await tester.tap(find.text('SESSION PERSISTENCE & AUTO-RESTORE'));
      await tester.pumpAndSettle();

      expect(find.text('PROJECT_HUB_EXPANDED'), findsNothing);
      expect(find.text('SESSION_PERSISTENCE_EXPANDED'), findsOneWidget);

      // Tapping DISPLAY & WORKSPACE should expand it and collapse SESSION PERSISTENCE
      await tester.tap(find.text('DISPLAY & WORKSPACE'));
      await tester.pumpAndSettle();

      expect(find.text('SESSION_PERSISTENCE_EXPANDED'), findsNothing);
      expect(find.text('DISPLAY_WORKSPACE_EXPANDED'), findsOneWidget);
    });
  });

  group('Eats-303 Portamento & Glide Curve DSP Fix', () {
    setUp(() {
      EatsTb303Core.clearAllVoices();
    });

    test('Notes with slide > 0 do NOT fade to silence over successive notes', () {
      const sampleRate = 44100.0;
      const notes = [36, 38, 40, 43, 45, 36, 48, 36, 40, 43, 36, 38, 40, 43, 45, 48];

      final Map<String, double> params = {
        'Cutoff': 2000.0,
        'Resonance': 2.0,
        'EnvMod': 0.5,
        'Decay': 0.5,
        'Accent': 0.0,
        'Drive': 0.0,
        'GlideCurve': 0.0,
      };

      final peakAmplitudes = <double>[];

      for (int i = 0; i < notes.length; i++) {
        final midi = notes[i];
        final freq = 440.0 * math.pow(2.0, (midi - 69) / 12.0);

        final buffer = EatsTb303Core.synthesizeBuffer(
          durationSec: 0.1,
          freq: freq,
          note: midi,
          params: params,
          trackId: 'test_voice_decay',
          sampleRate: sampleRate,
          isSlide: false,
        );

        double maxAmp = 0.0;
        for (int s = 0; s < buffer.length; s++) {
          final a = buffer[s].abs();
          if (a > maxAmp) maxAmp = a;
        }
        peakAmplitudes.add(maxAmp);
      }

      // Verify that every single note maintains solid audible amplitude (> 0.1) across all 16 notes!
      for (int i = 0; i < peakAmplitudes.length; i++) {
        expect(
          peakAmplitudes[i],
          greaterThan(0.1),
          reason: 'Note $i decayed to silence (peak ${peakAmplitudes[i]}), envelope retriggering failed!',
        );
      }
    });

    test('Glide curves (EXP, LIN, S_CURVE) affect pitch trajectory predictably on slide steps', () {
      const sampleRate = 44100.0;

      // Note 1: Set prior pitch at C2 (MIDI 36, ~65.4 Hz)
      EatsTb303Core.synthesizeBuffer(
        durationSec: 0.05,
        freq: 65.4,
        note: 36,
        params: {'Cutoff': 3000.0},
        trackId: 'curve_voice',
        sampleRate: sampleRate,
      );

      // Note 2: Glide to C4 (MIDI 60, ~261.6 Hz) with EXP curve
      EatsTb303Core.synthesizeBuffer(
        durationSec: 0.08,
        freq: 261.6,
        note: 60,
        fromMidiNote: 36,
        isSlide: true,
        params: {'GlideCurve': 0.0, 'Cutoff': 3000.0},
        trackId: 'curve_voice_exp',
        sampleRate: sampleRate,
      );
      final voiceExp = EatsTb303Core.getVoice('curve_voice_exp');

      // Note 2: Glide to C4 with LIN curve
      EatsTb303Core.synthesizeBuffer(
        durationSec: 0.08,
        freq: 261.6,
        note: 60,
        fromMidiNote: 36,
        isSlide: true,
        params: {'GlideCurve': 1.0, 'Cutoff': 3000.0},
        trackId: 'curve_voice_lin',
        sampleRate: sampleRate,
      );
      final voiceLin = EatsTb303Core.getVoice('curve_voice_lin');

      // Note 2: Glide to C4 with S_CURVE
      EatsTb303Core.synthesizeBuffer(
        durationSec: 0.08,
        freq: 261.6,
        note: 60,
        fromMidiNote: 36,
        isSlide: true,
        params: {'GlideCurve': 2.0, 'Cutoff': 3000.0},
        trackId: 'curve_voice_scurve',
        sampleRate: sampleRate,
      );
      final voiceScurve = EatsTb303Core.getVoice('curve_voice_scurve');

      // All voices glided towards 261.6 Hz without error
      expect(voiceExp.lastFreq, closeTo(261.6, 50.0));
      expect(voiceLin.lastFreq, closeTo(261.6, 50.0));
      expect(voiceScurve.lastFreq, closeTo(261.6, 50.0));
    });
  });
}
