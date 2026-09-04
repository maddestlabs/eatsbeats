import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/audio/wajuce_audio_backend.dart';
import 'package:wajuce/wajuce.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Eats Volts Sound Generation & Voice Stability Tests', () {
    test('TrackChannelStrip.safeDisposeNode guards against double disposal', () {
      expect(() => TrackChannelStrip.safeDisposeNode(null), returnsNormally);
    });

    test('Loading eats_volts.eats.lua and triggering noteOn/noteOff executes cleanly', () async {
      final dawState = DawState();
      final file = File('demos/eats_volts.eats.lua');
      expect(file.existsSync(), isTrue);

      final code = file.readAsStringSync();
      dawState.loadFromEatsLua(code);

      final voltsTrack = dawState.patterns[0].tracks.firstWhere(
        (t) => t.name.contains('Volts'),
      );
      expect(voltsTrack, isNotNull);

      // Verify piano roll noteOn preview across multiple octaves
      for (final pitch in [24, 36, 48, 60, 72, 84]) {
        dawState.audioEngine.noteOn(
          track: voltsTrack,
          midiNote: pitch,
          velocity: 0.85,
          sustainDurationSec: 0.85,
        );
        dawState.audioEngine.noteOff(
          track: voltsTrack,
          midiNote: pitch,
          releaseSec: 0.12,
        );
      }

      // Simulate rapid note glissando (16 rapid notes)
      for (int i = 0; i < 16; i++) {
        final pitch = 36 + (i % 24);
        dawState.audioEngine.noteOn(
          track: voltsTrack,
          midiNote: pitch,
          velocity: 0.85,
          sustainDurationSec: 0.85,
        );
      }

      // Releasing notes
      for (int i = 0; i < 16; i++) {
        final pitch = 36 + (i % 24);
        dawState.audioEngine.noteOff(
          track: voltsTrack,
          midiNote: pitch,
          releaseSec: 0.12,
        );
      }

      dawState.audioEngine.stopAllSound();
    });

    test('Playback toggle and pattern switching with Eats Volts runs without error', () async {
      final dawState = DawState();
      final file = File('demos/eats_volts.eats.lua');
      final code = file.readAsStringSync();
      dawState.loadFromEatsLua(code);

      // Start playback
      dawState.togglePlay();
      expect(dawState.isPlaying, isTrue);

      // Switch pattern while playing
      if (dawState.patterns.length > 1) {
        dawState.selectPattern(1);
        expect(dawState.activePatternIndex, equals(1));
        dawState.selectPattern(0);
        expect(dawState.activePatternIndex, equals(0));
      }

      // Stop playback
      dawState.stop();
      expect(dawState.isPlaying, isFalse);
    });
  });
}
