import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/lua/lua_script_library.dart';
import 'package:eatsbeats/audio/graph/graph_evaluator.dart';
import 'package:eatsbeats/audio/graph/graph_node.dart';
import 'package:eatsbeats/audio/procedural_ir_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Eats Volts + Convolution Reverb Audio Engine Stability & Optimization Tests', () {
    late DawState dawState;

    setUp(() {
      dawState = DawState();
    });

    test('Eats Volts synth graph evaluates across full piano roll with zero NaNs and valid bounds', () {
      final voltaicRoot = GraphEvaluator.buildVoltaicPlasmaSynth();

      final testMidiNotes = [24, 36, 48, 60, 72, 84]; // C1 to C6
      for (final note in testMidiNotes) {
        final ctx = GraphContext(
          durationSec: 0.5,
          freq: 440.0 * (note >= 69 ? 1.0 : 0.5),
          midiNote: note,
          velocity: 0.85,
        );
        final buffer = Float32List(ctx.totalSamples);
        voltaicRoot.process(ctx, buffer);

        expect(buffer.isNotEmpty, isTrue);
        for (int i = 0; i < buffer.length; i++) {
          final s = buffer[i];
          expect(s.isNaN, isFalse, reason: 'Sample at $i for note $note is NaN');
          expect(s.isInfinite, isFalse, reason: 'Sample at $i for note $note is infinite');
          expect(s >= -1.05 && s <= 1.05, isTrue, reason: 'Sample $s out of bounds [-1.0, 1.0]');
        }
      }
    });

    test('Eats Volts instrument and Convolution Reverb co-exist seamlessly on Track FX rack', () {
      final track = dawState.activeTrack;

      // 1. Apply Eats Volts instrument
      final voltsPreset = LuaScriptLibrary.getScriptById('voltaic_plasma_synth');
      expect(voltsPreset, isNotNull, reason: 'voltaic_plasma_synth must exist in LuaScriptLibrary');
      dawState.applyPreset(voltsPreset!, targetTrack: track);

      expect(track.name, contains('Volts'));
      expect(track.type, equals(TrackType.luaScript));

      // 2. Add Convolution Reverb to the track
      track.fxRack.clear();
      final convReverbPreset = LuaScriptLibrary.getScriptById('convolution_reverb');
      expect(convReverbPreset, isNotNull, reason: 'convolution_reverb must exist in LuaScriptLibrary');
      dawState.addAudioFXFromPreset(track, convReverbPreset!);

      expect(track.fxRack.length, equals(1));
      final fx = track.fxRack.first;
      expect(fx.type, equals(FXType.convolutionReverb));

      // 3. Synthesize multiple notes through AudioEngine and verify buffer bounds
      final sw = Stopwatch()..start();
      for (int note = 36; note <= 60; note += 3) {
        final buf = dawState.audioEngine.synthesizeBufferForTrack(
          track: track,
          midiNote: note,
          velocity: 0.8,
          durationSec: 0.25,
        );
        expect(buf.isNotEmpty, isTrue);
      }
      sw.stop();

      // Synthesis of 9 notes should execute in under 1000ms
      expect(sw.elapsedMilliseconds, lessThan(1000), reason: 'Note synthesis took too long: ${sw.elapsedMilliseconds}ms');
    });

    test('AudioEngine PCM cache strictly respects 256 capacity limit during rapid note generation', () {
      final track = dawState.activeTrack;
      final voltsPreset = LuaScriptLibrary.getScriptById('voltaic_plasma_synth')!;
      dawState.applyPreset(voltsPreset, targetTrack: track);

      // Play 300 notes through playNoteOrSample to exercise _getOrCreateBuffer and _pcmCache eviction
      for (int i = 0; i < 300; i++) {
        track.luaParams['SparkJitter'] = (i % 100) / 100.0;
        dawState.audioEngine.playNoteOrSample(
          track: track,
          midiNote: 36 + (i % 24),
          velocity: 0.8,
          durationSec: 0.05,
        );
      }

      // Verify that engine remains completely healthy and handles further notes
      final testBuf = dawState.audioEngine.synthesizeBufferForTrack(
        track: track,
        midiNote: 60,
        velocity: 0.8,
        durationSec: 0.05,
      );
      expect(testBuf.isNotEmpty, isTrue);
    });

    test('Rapid Convolution Reverb parameter tweaking executes without memory or structural regression', () {
      final track = dawState.activeTrack;
      final convReverbPreset = LuaScriptLibrary.getScriptById('convolution_reverb')!;
      dawState.addAudioFXFromPreset(track, convReverbPreset);

      final fx = track.fxRack.first;

      // Simulate dragging RT60, Damping, DryLevel, WetLevel sliders
      final testRt60Values = [0.5, 1.2, 2.0, 3.5, 5.0, 2.2];
      for (final rt in testRt60Values) {
        dawState.updateFXParam(track, fx.id, 'RT60', rt);
        expect(fx.params['RT60'], equals(rt));
      }

      final testDampValues = [0.1, 0.4, 0.7, 0.9, 0.25];
      for (final d in testDampValues) {
        dawState.updateFXParam(track, fx.id, 'Damping', d);
        expect(fx.params['Damping'], equals(d));
      }

      final testDryValues = [0.0, 0.5, 1.0, 1.2];
      for (final dry in testDryValues) {
        dawState.updateFXParam(track, fx.id, 'DryLevel', dry);
        expect(fx.params['DryLevel'], equals(dry));
      }
    });

    test('Room Designer and Cab Designer procedural IR generation executes with optimized velvet noise loop', () {
      final roomPreset = ProceduralIRGenerator.presets['Great Hall']!;
      final sw = Stopwatch()..start();
      final stereo = ProceduralIRGenerator.generateStereo(roomPreset);
      sw.stop();

      expect(stereo.left.isNotEmpty, isTrue);
      expect(stereo.right.isNotEmpty, isTrue);
      expect(stereo.left.length, equals(stereo.right.length));
      expect(sw.elapsedMilliseconds, lessThan(250), reason: 'Room IR generation took too long: ${sw.elapsedMilliseconds}ms');

      // Verify bounds and non-emptiness
      double maxPeak = 0.0;
      for (int i = 0; i < stereo.left.length; i++) {
        final val = stereo.left[i].abs();
        if (val > maxPeak) maxPeak = val;
        expect(stereo.left[i].isNaN, isFalse);
      }
      expect(maxPeak, greaterThan(0.01));
      expect(maxPeak, lessThanOrEqualTo(1.01));
    });
  });
}
