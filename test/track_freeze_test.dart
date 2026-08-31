import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/audio/track_freeze_engine.dart';
import 'package:eatsbeats/audio/audio_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Track Freeze Engine & Hash Tests', () {
    test('computeTrackHash returns deterministic hash and changes on code/note modifications', () {
      final track = TrackChannel(
        id: 'trk_test_1',
        name: 'Acid Lead',
        color: const Color(0xFF00E5FF),
        type: TrackType.luaScript,
        luaScriptCode: 'function process(sampleRate) return 0.5 end',
        notes: [
          Note(id: 'n1', pitch: 60, startStep: 0, durationSteps: 2),
        ],
      );

      final hash1 = TrackFreezeEngine.computeTrackHash(track, bpm: 120.0, timelineBars: 4);
      final hash2 = TrackFreezeEngine.computeTrackHash(track, bpm: 120.0, timelineBars: 4);

      expect(hash1, equals(hash2));
      expect(hash1.length, equals(16));

      // Change Lua Code
      final trackModifiedCode = track.copyWith(
        luaScriptCode: 'function process(sampleRate) return 0.8 end',
      );
      final hashModifiedCode = TrackFreezeEngine.computeTrackHash(trackModifiedCode, bpm: 120.0, timelineBars: 4);
      expect(hashModifiedCode, isNot(equals(hash1)));

      // Change Note
      final trackModifiedNote = track.copyWith(
        notes: [
          Note(id: 'n1', pitch: 64, startStep: 0, durationSteps: 2),
        ],
      );
      final hashModifiedNote = TrackFreezeEngine.computeTrackHash(trackModifiedNote, bpm: 120.0, timelineBars: 4);
      expect(hashModifiedNote, isNot(equals(hash1)));
    });

    test('renderTrackOffline generates non-empty PCM buffer for notes', () async {
      final audioEngine = AudioEngine();
      final track = TrackChannel(
        id: 'trk_synth_1',
        name: 'Saw Lead',
        color: const Color(0xFF00E5FF),
        type: TrackType.synth,
        synthWaveform: 'sawtooth',
        notes: [
          Note(id: 'n1', pitch: 60, startStep: 0.0, durationSteps: 4.0),
          Note(id: 'n2', pitch: 67, startStep: 4.0, durationSteps: 4.0),
        ],
      );

      double reportedProgress = 0.0;
      String reportedStatus = '';

      final buffer = await TrackFreezeEngine.renderTrackOffline(
        track: track,
        audioEngine: audioEngine,
        bpm: 120.0,
        totalTimelineBars: 2,
        onProgress: (p, s) {
          reportedProgress = p;
          reportedStatus = s;
        },
      );

      expect(buffer.isNotEmpty, isTrue);
      // 2 bars at 120 BPM = 4 seconds = 4 * 44100 = 176400 samples
      expect(buffer.length, equals(176400));
      expect(reportedProgress, equals(1.0));
      expect(reportedStatus, contains('Bake complete'));

      // Verify that rendered buffer has non-zero amplitude
      final hasAudio = buffer.any((s) => s.abs() > 0.001);
      expect(hasAudio, isTrue);
    });
  });

  group('DawState Freeze Workflow Tests', () {
    late DawState dawState;

    setUp(() {
      dawState = DawState();
    });

    test('freezeTrack bakes audio and sets hasValidBake to true', () async {
      final track = dawState.activeTrack;
      track.notes = [
        Note(id: 'n1', pitch: 60, startStep: 0, durationSteps: 2),
        Note(id: 'n2', pitch: 64, startStep: 4, durationSteps: 2),
      ];

      expect(track.isFrozen, isFalse);
      expect(track.hasValidBake, isFalse);

      await dawState.freezeTrack(track);

      expect(track.isFrozen, isTrue);
      expect(track.isBaking, isFalse);
      expect(track.frozenAudioBuffer, isNotNull);
      expect(track.frozenAudioBuffer!.isNotEmpty, isTrue);
      expect(track.hasValidBake, isTrue);
      expect(track.frozenDurationSec, greaterThan(0));
      expect(track.frozenContentHash, isNotNull);

      // Unfreeze
      dawState.unfreezeTrack(track);

      expect(track.isFrozen, isFalse);
      expect(track.frozenAudioBuffer, isNull);
      expect(track.hasValidBake, isFalse);
    });

    test('toggleFreezeTrack alternates between frozen and unbaked state', () async {
      final track = dawState.activeTrack;
      track.notes = [
        Note(id: 'n1', pitch: 60, startStep: 0, durationSteps: 2),
      ];

      expect(track.isFrozen, isFalse);

      await dawState.toggleFreezeTrack(track);
      expect(track.isFrozen, isTrue);
      expect(track.hasValidBake, isTrue);

      await dawState.toggleFreezeTrack(track);
      expect(track.isFrozen, isFalse);
      expect(track.hasValidBake, isFalse);
    });

    test('TrackChannel serialization preserves isFrozen and frozenContentHash', () {
      final track = TrackChannel(
        id: 'trk_test_freeze',
        name: 'Freeze Test',
        color: const Color(0xFFFF0055),
        type: TrackType.synth,
        isFrozen: true,
        frozenContentHash: 'a1b2c3d4e5f60718',
      );

      final json = track.toJson();
      expect(json['isFrozen'], isTrue);
      expect(json['frozenContentHash'], equals('a1b2c3d4e5f60718'));

      final restored = TrackChannel.fromJson(json);
      expect(restored.isFrozen, isTrue);
      expect(restored.frozenContentHash, equals('a1b2c3d4e5f60718'));
    });
  });
}
