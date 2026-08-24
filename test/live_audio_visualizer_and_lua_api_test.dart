import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_wren_daw/audio/audio_engine.dart';
import 'package:mobile_wren_daw/lua/lua_preset_library.dart';
import 'package:mobile_wren_daw/models/daw_state.dart';
import 'package:mobile_wren_daw/models/track_model.dart';
import 'package:mobile_wren_daw/ui/widgets/dynamic_instrument_gui_widget.dart';
import 'package:mobile_wren_daw/ui/widgets/interactive_game_canvas_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioEngine Waveform & Spectrum Analysis Tests', () {
    test('AudioEngine returns valid normalized waveform samples', () {
      final engine = AudioEngine();
      final masterWaveform = engine.getWaveformSamples(count: 64, gain: 1.5, timebase: 1.0);

      expect(masterWaveform.length, 64);
      for (final sample in masterWaveform) {
        expect(sample, inInclusiveRange(-1.0, 1.0));
      }
    });

    test('AudioEngine returns multi-band spectrum energies', () {
      final engine = AudioEngine();
      final bands16 = engine.getSpectrumBands(bands: 16, gain: 1.0);
      expect(bands16.length, 16);
      for (final b in bands16) {
        expect(b, inInclusiveRange(0.0, 1.0));
      }

      final bands8 = engine.getSpectrumBands(bands: 8, gain: 1.2);
      expect(bands8.length, 8);
      for (final b in bands8) {
        expect(b, inInclusiveRange(0.0, 1.0));
      }
    });

    test('AudioEngine modulates waveform and spectrum when note is played', () {
      final engine = AudioEngine();
      final track = TrackChannel(
        id: 'test_synth_1',
        name: 'Lead Synth',
        type: TrackType.luaScript,
        color: const Color(0xFF21F4E8),
        luaScriptCode: '-- synth',
      );

      // Play note to trigger audio activity
      engine.playNoteOrSample(
        track: track,
        midiNote: 60,
        velocity: 0.9,
        durationSec: 0.5,
      );

      final trackWaveform = engine.getWaveformSamples(trackId: track.id, count: 64);
      expect(trackWaveform.length, 64);
      final hasNonZero = trackWaveform.any((s) => s.abs() > 0.001);
      expect(hasNonZero, isTrue);

      final trackSpectrum = engine.getSpectrumBands(trackId: track.id, bands: 16);
      expect(trackSpectrum.length, 16);
      final hasEnergy = trackSpectrum.any((b) => b > 0.001);
      expect(hasEnergy, isTrue);

      final (left, right) = engine.getPeakLevels(trackId: track.id);
      expect(left, greaterThan(0.0));
      expect(right, greaterThan(0.0));
    });
  });

  group('Live Audio Visualizer Widget Tests', () {
    testWidgets('Eats-Scope renders live vector oscilloscope from audio stream', (tester) async {
      final dawState = DawState();
      final track = dawState.activeTrack;
      final scopePreset = LuaPresetLibrary.getPresetById('eats_scope')!;

      dawState.addAudioFXFromPreset(track, scopePreset);
      final fx = track.fxRack.last;

      final fxTrack = TrackChannel(
        id: fx.id,
        name: fx.name,
        type: TrackType.luaScript,
        color: const Color(0xFF00FF9D),
        luaScriptCode: fx.luaScriptCode ?? '',
        luaParams: fx.luaParams,
      );

      // Play note so audio waveform has activity
      dawState.audioEngine.playNoteOrSample(
        track: track,
        midiNote: 64,
        velocity: 0.8,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DynamicInstrumentGuiWidget(
                dawState: dawState,
                track: fxTrack,
                hideHeader: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(InteractiveGameCanvasWidget), findsOneWidget);
      expect(find.text('TIMEBASE'), findsOneWidget);
      expect(find.text('GAIN'), findsOneWidget);
      expect(find.text('BEAM COLOR'), findsOneWidget);
    });

    testWidgets('Eats-Spectrum renders real-time 16-band spectrum analyzer with live audio', (tester) async {
      final dawState = DawState();
      final track = dawState.activeTrack;
      final spectrumPreset = LuaPresetLibrary.getPresetById('eats_spectrum')!;

      dawState.addAudioFXFromPreset(track, spectrumPreset);
      final fx = track.fxRack.last;

      final fxTrack = TrackChannel(
        id: fx.id,
        name: fx.name,
        type: TrackType.luaScript,
        color: const Color(0xFF00E5FF),
        luaScriptCode: fx.luaScriptCode ?? '',
        luaParams: fx.luaParams,
      );

      // Play note to trigger spectrum frequency bars
      dawState.audioEngine.playNoteOrSample(
        track: track,
        midiNote: 48,
        velocity: 0.9,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DynamicInstrumentGuiWidget(
                dawState: dawState,
                track: fxTrack,
                hideHeader: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(InteractiveGameCanvasWidget), findsOneWidget);
      expect(find.text('GAIN'), findsOneWidget);
      expect(find.text('DECAY'), findsOneWidget);
    });
  });
}
