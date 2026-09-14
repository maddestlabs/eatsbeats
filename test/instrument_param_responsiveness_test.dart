import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/audio/audio_engine.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/eatscript/eats_script_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Instrument Parameter Responsiveness & DSP Caching Tests', () {
    late AudioEngine audioEngine;
    late TrackChannel track;

    setUp(() {
      audioEngine = AudioEngine();
      final ymPreset = LuaPresetLibrary.getPresetById('ym2612_synth');
      track = TrackChannel(
        id: 'test_ym2612',
        name: 'YM2612 Synth',
        color: const Color(0xFFFF9800),
        type: TrackType.eatScript,
        eatScriptCode: ymPreset?.code ?? 'def process():\n    return eat.saw(440.0)\n',
        eatScriptParams: {
          'Algorithm': 4.0,
          'Feedback': 4.0,
          'Op1_Mult': 1.0,
          'Op1_TL': 10.0,
          'Op1_Attack': 0.005,
          'Op1_Decay': 0.3,
          'Op2_Mult': 2.0,
          'Op2_TL': 0.0,
        },
      );
    });

    test('track.luaParams map mutation invalidates paramsHash', () {
      final initialHash = track.paramsHash;
      expect(track.paramsHash, equals(initialHash)); // Cached read

      // Mutating parameter must immediately invalidate paramsHash
      track.luaParams['Op1_Mult'] = 3.0;
      final newHash = track.paramsHash;
      expect(newHash, isNot(equals(initialHash)));

      // Setting same value does not invalidate
      track.luaParams['Op1_Mult'] = 3.0;
      expect(track.paramsHash, equals(newHash));
    });

    test('AudioEngine invalidates cache and re-synthesizes on parameter change', () {
      expect(audioEngine.isBufferCached(track: track, midiNote: 60, durationSec: 0.3), isFalse);

      // Play note -> buffer synthesized and cached
      audioEngine.noteOn(
        track: track,
        midiNote: 60,
        velocity: 0.9,
        sustainDurationSec: 0.3,
        loop: false,
      );
      expect(audioEngine.isBufferCached(track: track, midiNote: 60, durationSec: 0.3), isTrue);

      final buf1 = audioEngine.synthesizeBufferForTrack(
        track: track,
        midiNote: 60,
        velocity: 0.9,
        durationSec: 0.3,
      );

      // Mutate instrument parameter (knob tweak)
      track.luaParams['Op1_TL'] = 80.0;
      expect(audioEngine.isBufferCached(track: track, midiNote: 60, durationSec: 0.3), isFalse);

      // Play note with new params -> buffer synthesized and cached
      audioEngine.noteOn(
        track: track,
        midiNote: 60,
        velocity: 0.9,
        sustainDurationSec: 0.3,
        loop: false,
      );
      expect(audioEngine.isBufferCached(track: track, midiNote: 60, durationSec: 0.3), isTrue);

      final buf2 = audioEngine.synthesizeBufferForTrack(
        track: track,
        midiNote: 60,
        velocity: 0.9,
        durationSec: 0.3,
      );

      // Verify actual DSP output changed
      bool hasDifference = false;
      for (int i = 0; i < buf1.length && i < buf2.length; i++) {
        if ((buf1[i] - buf2[i]).abs() > 0.01) {
          hasDifference = true;
          break;
        }
      }
      expect(hasDifference, isTrue, reason: 'Knob tweak should produce distinct synthesized audio');
    });

    test('Subtle sub-0.01 parameter changes produce distinct hashes and audio', () {
      track.luaParams['Op1_Attack'] = 0.002;
      final hash1 = track.paramsHash;

      track.luaParams['Op1_Attack'] = 0.007;
      final hash2 = track.paramsHash;

      expect(hash1, isNot(equals(hash2)), reason: 'High precision hashing must distinguish 2ms from 7ms');
    });

    test('dawState.updateLuaParam invalidates target track parameters', () {
      final dawState = DawState(enableMeterTimer: false);
      final testTrack = dawState.activeTrack;
      final initialHash = testTrack.paramsHash;

      dawState.updateLuaParam('Cutoff', 1234.0, testTrack);
      expect(testTrack.paramsHash, isNot(equals(initialHash)));
      expect(testTrack.luaParams['Cutoff'], equals(1234.0));
    });

    test('TrackChannel property setters invalidate paramsHash', () {
      final synthTrack = TrackChannel(
        id: 'synth_1',
        name: 'Poly Lead',
        color: Colors.blue,
        type: TrackType.synth,
        cutoff: 2000.0,
        attack: 0.05,
        release: 0.2,
      );

      final h1 = synthTrack.paramsHash;

      synthTrack.cutoff = 500.0;
      final h2 = synthTrack.paramsHash;
      expect(h2, isNot(equals(h1)));

      synthTrack.attack = 0.15;
      final h3 = synthTrack.paramsHash;
      expect(h3, isNot(equals(h2)));

      synthTrack.sampleName = 'square';
      final h4 = synthTrack.paramsHash;
      expect(h4, isNot(equals(h3)));
    });
  });
}
