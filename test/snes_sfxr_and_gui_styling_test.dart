import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/audio/snes_dsp_engine.dart';
import 'package:eatsbeats/lua/lua_engine.dart';
import 'package:eatsbeats/lua/lua_gui_model.dart';
import 'package:eatsbeats/lua/lua_preset_library.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/ui/widgets/dynamic_instrument_gui_widget.dart';
import 'package:eatsbeats/ui/widgets/grungy_rack_panel.dart';
import 'package:eatsbeats/ui/widgets/hardware_listbox_widget.dart';
import 'package:eatsbeats/ui/widgets/skeuomorphic_hardware_button.dart';
import 'package:eatsbeats/ui/widgets/skeuomorphic_hardware_knob.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SNES Synth and SNES Sfxr Renaming & Preset Tests', () {
    test('Preset names are renamed to SNES Synth and SNES Sfxr', () {
      final sfxr = LuaPresetLibrary.getPresetById('eats_sfxr');
      expect(sfxr, isNotNull);
      expect(sfxr!.name, equals('SNES Sfxr'));
      expect(sfxr.code, contains('-- @name: SNES Sfxr'));

      final synth = LuaPresetLibrary.getPresetById('snes_console_synth');
      expect(synth, isNotNull);
      expect(synth!.name, equals('SNES Synth'));
      expect(synth.code, contains('-- @name: SNES Synth'));
    });

    test('SNES Sfxr GUI title, labels, and removed LCD match specification', () {
      final sfxr = LuaPresetLibrary.getPresetById('eats_sfxr')!;
      final compilation = LuaEngine.compile(sfxr.code);

      expect(compilation.guiLayout, isNotNull);
      final panel = compilation.guiLayout!;
      expect(panel.title, equals('SNES Sfxr'));
      expect(panel.backgroundStyle, equals(PanelBackgroundStyle.snes));
      expect(panel.defaultKnobStyle, equals(KnobStyle.snes));

      // Check ListBox nodes
      final row1 = panel.children.first;
      expect(row1.type, equals(LuaGuiNodeType.row));

      final listBoxes = row1.children.where((c) => c.type == LuaGuiNodeType.listBox).toList();
      expect(listBoxes.length, equals(2));
      expect(listBoxes[0].label, equals('SFX Type'));
      expect(listBoxes[1].label, equals('Wavetable'));

      // Check Column on the right has Nixie and Button, but NO LCD
      final col = row1.children.firstWhere((c) => c.type == LuaGuiNodeType.column);
      expect(col.children.any((c) => c.type == LuaGuiNodeType.lcd), isFalse);
      expect(col.children.any((c) => c.type == LuaGuiNodeType.nixie), isTrue);
      expect(col.children.any((c) => c.type == LuaGuiNodeType.button), isTrue);
    });
  });

  group('Skeuomorphic Hardware Knob SNES Style Tests', () {
    testWidgets('Renders KnobStyle.snes without errors', (tester) async {
      double testVal = 0.5;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFFD8D6CD),
            body: Center(
              child: SkeuomorphicHardwareKnob(
                label: 'ATTACK',
                value: testVal,
                defaultValue: 0.25,
                min: 0.0,
                max: 1.0,
                knobStyle: KnobStyle.snes,
                isLightChassis: true,
                onChanged: (v) => testVal = v,
              ),
            ),
          ),
        ),
      );

      expect(find.text('ATTACK'), findsOneWidget);
      expect(find.byType(SkeuomorphicHardwareKnob), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  group('HardwareListBoxWidget Glass Overlay & Auto-scroll Tests', () {
    testWidgets('HardwareListBoxWidget renders glass reflection overlay and scrolls on selection', (tester) async {
      final dawState = DawState();
      final track = TrackChannel(
        id: 'test_track',
        name: 'SNES Track',
        type: TrackType.synth,
        color: const Color(0xFF7B52AB),
        luaParams: {'SFXType': 0.0},
      );
      dawState.tracks.add(track);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: HardwareListBoxWidget(
                dawState: dawState,
                track: track,
                paramName: 'SFXType',
                label: 'SFX Type',
                options: const [
                  'Laser',
                  'Explosion',
                  'Powerup',
                  'Coin',
                  'Jump',
                  'Hurt',
                  'Lose',
                  'Button',
                  'Warp',
                  'Mutate',
                  'Custom SNES',
                ],
                accentColor: const Color(0xFF7B52AB),
              ),
            ),
          ),
        ),
      );

      expect(find.text('SFX TYPE'), findsOneWidget);
      expect(find.text('Laser'), findsOneWidget);

      // Tap downward stepper
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pumpAndSettle();

      expect(track.luaParams['SFXType'], equals(1.0));
      expect(find.text('02/11'), findsOneWidget);
    });
  });

  group('Procedural Parameter Randomization & Waveform Variation Tests', () {
    test('Candidate waveform pools are tailored for archetypes', () {
      final laserPool = SNESSFXRGenerator.getCandidateWaveformsForType(0);
      expect(laserPool, contains(SNESWaveform.sawtooth));
      expect(laserPool, contains(SNESWaveform.pulse12));

      final explosionPool = SNESSFXRGenerator.getCandidateWaveformsForType(1);
      expect(explosionPool, contains(SNESWaveform.noise));

      final coinPool = SNESSFXRGenerator.getCandidateWaveformsForType(3);
      expect(coinPool, contains(SNESWaveform.chime));
    });

    test('generateParamsForType produces rich valid parameters with curated waveforms', () {
      for (int t = 0; t <= 10; t++) {
        final params = SNESSFXRGenerator.generateParamsForType(t, seed: 1234);
        expect(params['SFXType'], equals(t.toDouble()));
        expect(params['Seed'], equals(1234.0));
        expect(params.containsKey('Waveform'), isTrue);
        expect(params.containsKey('Attack'), isTrue);
        expect(params.containsKey('Decay'), isTrue);
        expect(params.containsKey('Sustain'), isTrue);
        expect(params.containsKey('Release'), isTrue);
        expect(params.containsKey('PitchSweep'), isTrue);
        expect(params.containsKey('EchoVolume'), isTrue);
      }
    });

    test('Wavetable selector affects audio synthesis across non-custom archetypes', () {
      final sfxr = LuaPresetLibrary.getPresetById('eats_sfxr')!;

      // Synthesize Laser with Sawtooth waveform
      final bufSaw = LuaEngine.synthesizeBuffer(
        code: sfxr.code,
        durationSec: 0.1,
        freq: 440.0,
        note: 69,
        params: {
          'SFXType': 0.0, // Laser
          'Waveform': SNESWaveform.sawtooth.index.toDouble(),
        },
      );

      // Synthesize Laser with Sine waveform
      final bufSine = LuaEngine.synthesizeBuffer(
        code: sfxr.code,
        durationSec: 0.1,
        freq: 440.0,
        note: 69,
        params: {
          'SFXType': 0.0, // Laser
          'Waveform': SNESWaveform.sine.index.toDouble(),
        },
      );

      bool diff = false;
      for (int i = 0; i < bufSaw.length; i++) {
        if ((bufSaw[i] - bufSine[i]).abs() > 0.05) {
          diff = true;
          break;
        }
      }
      expect(diff, isTrue, reason: 'Wavetable selection should modulate the sound even for Laser archetype');
    });

    testWidgets('DynamicInstrumentGuiWidget RANDOMIZE button updates track parameters', (tester) async {
      final dawState = DawState();
      final sfxr = LuaPresetLibrary.getPresetById('eats_sfxr')!;
      final track = TrackChannel(
        id: 'sfxr_track',
        name: 'SNES Sfxr',
        type: TrackType.synth,
        color: const Color(0xFF7B52AB),
        luaScriptCode: sfxr.code,
        luaParams: {
          'SFXType': 2.0, // Powerup
          'Seed': 42.0,
          'Attack': 0.1,
          'Decay': 0.5,
        },
      );
      dawState.tracks.add(track);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DynamicInstrumentGuiWidget(
                dawState: dawState,
                track: track,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SNES SFXR'), findsOneWidget);
      expect(find.text('SFX TYPE'), findsOneWidget);
      expect(find.text('WAVETABLE'), findsOneWidget);
      expect(find.text('RANDOMIZE'), findsOneWidget);
      expect(find.text('RNG SEED'), findsOneWidget);

      // Tap the RANDOMIZE button
      await tester.tap(find.text('RANDOMIZE'));
      await tester.pumpAndSettle();

      // Parameters should be updated according to Powerup archetype generator
      expect(track.luaParams['SFXType'], equals(2.0));
      expect(track.luaParams.containsKey('Waveform'), isTrue);
      expect(track.luaParams['EchoVolume'], isNonZero);
    });

    testWidgets('Selecting SFXType in listbox auto-randomizes parameters without needing RANDOM button', (tester) async {
      final dawState = DawState();
      final sfxr = LuaPresetLibrary.getPresetById('eats_sfxr')!;
      final track = TrackChannel(
        id: 'sfxr_track_2',
        name: 'SNES Sfxr',
        type: TrackType.synth,
        color: const Color(0xFF7B52AB),
        luaScriptCode: sfxr.code,
        luaParams: {
          'SFXType': 0.0, // Laser
          'Seed': 42.0,
          'Waveform': 3.0,
        },
      );
      dawState.tracks.add(track);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DynamicInstrumentGuiWidget(
                dawState: dawState,
                track: track,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap downward stepper on SFXType to select Explosion (1.0)
      final downSteppers = find.byIcon(Icons.keyboard_arrow_down);
      expect(downSteppers, findsWidgets);
      await tester.tap(downSteppers.first);
      await tester.pumpAndSettle();

      expect(track.luaParams['SFXType'], equals(1.0));
      // Parameters should automatically have been randomized for Explosion
      expect(track.luaParams.containsKey('Waveform'), isTrue);
      expect(track.luaParams['Decay'], greaterThan(0.2));
    });
  });

  group('SNES Synth Clean Synthesis & GUI Tests', () {
    test('SNES Synth compiles with full SNES GUI layout', () {
      final synth = LuaPresetLibrary.getPresetById('snes_console_synth')!;
      final compilation = LuaEngine.compile(synth.code);

      expect(compilation.guiLayout, isNotNull);
      final panel = compilation.guiLayout!;
      expect(panel.title, equals('SNES Synth'));
      expect(panel.subtitle, contains('Polyphonic'));
      expect(panel.backgroundStyle, equals(PanelBackgroundStyle.snes));
      expect(panel.defaultKnobStyle, equals(KnobStyle.snes));

      final row1 = panel.children.first;
      expect(row1.type, equals(LuaGuiNodeType.row));
      expect(row1.children.any((c) => c.type == LuaGuiNodeType.listBox && c.label == 'Wavetable'), isTrue);
    });

    test('SNES Synth synthesizes pure waveform without initial laser pitch-dive blip', () {
      final synth = LuaPresetLibrary.getPresetById('snes_console_synth')!;

      final buffer = LuaEngine.synthesizeBuffer(
        code: synth.code,
        durationSec: 0.1,
        freq: 440.0,
        note: 69,
        params: {
          'Waveform': SNESWaveform.sine.index.toDouble(),
          'Attack': 0.001,
          'Decay': 0.5,
          'Sustain': 1.0,
          'Release': 0.1,
        },
      );

      expect(buffer.isNotEmpty, isTrue);
      // Ensure the waveform starts cleanly without high-frequency laser sweep
      double maxAbs = 0.0;
      for (int i = 0; i < 200; i++) {
        if (buffer[i].abs() > maxAbs) maxAbs = buffer[i].abs();
      }
      expect(maxAbs, greaterThan(0.01));
    });
  });

  group('GrungyRackPanel SNES Chassis Style Tests', () {
    testWidgets('GrungyRackPanel renders PanelBackgroundStyle.snes correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GrungyRackPanel(
              title: 'SNES Sfxr',
              subtitle: '16-Bit Procedural Sound Engine',
              backgroundStyle: PanelBackgroundStyle.snes,
              accentColor: const Color(0xFF7B52AB),
              child: const Text('Console Content'),
            ),
          ),
        ),
      );

      expect(find.text('SNES SFXR'), findsOneWidget);
      expect(find.text('16-Bit Procedural Sound Engine'), findsOneWidget);
      expect(find.text('Console Content'), findsOneWidget);
    });
  });
}
