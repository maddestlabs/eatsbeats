import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/audio/audio_engine.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:flutter/material.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Mixer Audio Meter Continuous Level Tests', () {
    test('Track and Master meters maintain continuous levels across sustained note playback', () async {
      final engine = AudioEngine();
      engine.ensureContextRunning();

      final track = TrackChannel(
        id: 'snes_pad',
        name: 'SNES Pad',
        type: TrackType.synth,
        color: Colors.purple,
      );
      track.volume = 1.0;

      // Play a 1.0 second note
      engine.playNoteOrSample(
        track: track,
        midiNote: 60,
        velocity: 0.85,
        durationSec: 1.0,
      );

      // Immediately after triggering note
      engine.updateMeters();
      final initialTrackPeak = engine.getTrackLeftPeak(track.id);
      final initialMasterPeak = engine.leftPeak;
      expect(initialTrackPeak, greaterThan(0.15), reason: 'Track peak must be non-zero on note attack');
      expect(initialMasterPeak, greaterThan(0.15), reason: 'Master peak must be non-zero on note attack');

      // 100ms into sustain (previously this would have decayed to near-zero!)
      await Future<void>.delayed(const Duration(milliseconds: 100));
      engine.updateMeters();
      final peakAt100 = engine.getTrackLeftPeak(track.id);
      expect(peakAt100, greaterThan(0.15),
          reason: 'Track meter must maintain continuous level during sustain, was $peakAt100');
      expect(engine.leftPeak, greaterThan(0.15));

      // 300ms into sustain
      await Future<void>.delayed(const Duration(milliseconds: 200));
      engine.updateMeters();
      final peakAt300 = engine.getTrackLeftPeak(track.id);
      expect(peakAt300, greaterThan(0.15),
          reason: 'Track meter must maintain continuous level at 300ms, was $peakAt300');
      expect(engine.leftPeak, greaterThan(0.15));

      // 600ms into sustain
      await Future<void>.delayed(const Duration(milliseconds: 300));
      engine.updateMeters();
      final peakAt600 = engine.getTrackLeftPeak(track.id);
      expect(peakAt600, greaterThan(0.15),
          reason: 'Track meter must maintain continuous level at 600ms, was $peakAt600');
      expect(engine.leftPeak, greaterThan(0.15));

      // Muting the track should immediately zero out the track meter
      track.isMuted = true;
      engine.updateMeters();
      expect(engine.getTrackLeftPeak(track.id), equals(0.0), reason: 'Muted track meter must drop to 0.0');
      track.isMuted = false;

      // Stop all sound immediately clears meters and active voices
      engine.stopAllSound();
      expect(engine.getTrackLeftPeak(track.id), equals(0.0));
      expect(engine.leftPeak, equals(0.0));
      expect(engine.hasActiveMeterActivity, isFalse);
    });

    test('Polyphonic chord on track combines loudness and respects track volume fader', () async {
      final engine = AudioEngine();
      engine.ensureContextRunning();

      final track = TrackChannel(
        id: 'chord_track',
        name: 'Chord Synth',
        type: TrackType.synth,
        color: Colors.teal,
      );
      track.volume = 1.0;

      // Play 4 notes simultaneously (a chord) for 0.8 seconds
      for (final pitch in [60, 64, 67, 71]) {
        engine.playNoteOrSample(
          track: track,
          midiNote: pitch,
          velocity: 0.8,
          durationSec: 0.8,
        );
      }

      await Future<void>.delayed(const Duration(milliseconds: 100));
      engine.updateMeters();
      final chordLevel = engine.getTrackLeftPeak(track.id);
      expect(chordLevel, greaterThan(0.25), reason: 'Polyphonic chord should show substantial energy');

      // Adjust volume fader down
      track.volume = 0.2;
      engine.updateMeters();
      final lowerVolLevel = engine.getTrackLeftPeak(track.id);
      expect(lowerVolLevel, lessThan(chordLevel), reason: 'Track meter must react to volume fader reduction');

      engine.stopAllSound();
    });
  });
}
