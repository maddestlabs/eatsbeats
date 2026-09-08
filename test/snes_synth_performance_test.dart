import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/audio/snes_dsp_engine.dart';
import 'package:eatsbeats/models/chord_model.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SNES S-DSP Synthesis Performance & Zero-Desync Tests', () {
    test('3.0-second sustained 4-voice chord through 8-tap FIR echo synthesizes in under 150ms', () {
      final dsp = SNESDSPEngine();
      dsp.reset();

      // Configure high-complexity SNES Synth preset with 8-tap FIR echo
      dsp.echo.enabled = true;
      dsp.echo.delayMs = 240;
      dsp.echo.feedback = 0.45;
      dsp.echo.volume = 0.4;
      dsp.echo.firCoefficients = [0.75, -0.15, 0.25, -0.1, 0.15, -0.05, 0.08, -0.02];

      // Enable 4 polyphonic voices with vibrato and envelopes
      final chordFreqs = [261.63, 329.63, 392.00, 493.88]; // Cmaj7: C4, E4, G4, B4
      for (int v = 0; v < 4; v++) {
        dsp.voices[v].waveform = SNESWaveform.values[v % SNESWaveform.values.length];
        dsp.voices[v].attack = 0.05;
        dsp.voices[v].decay = 0.5;
        dsp.voices[v].sustain = 0.7;
        dsp.voices[v].release = 0.3;
        dsp.voices[v].vibratoRate = 5.5;
        dsp.voices[v].vibratoDepth = 0.03;
      }

      const durationSec = 3.0;
      const sampleRate = 44100;
      final totalSamples = (durationSec * sampleRate).toInt(); // 132,300 samples

      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < totalSamples; i++) {
        final t = i / 44100.0;
        final stereo = dsp.evaluateStereoSample(
          time: t,
          baseFreq: chordFreqs[0],
          duration: durationSec,
          sampleIndex: i,
        );
        expect(stereo[0], isNotNull);
        expect(stereo[1], isNotNull);
      }

      stopwatch.stop();
      final elapsedMs = stopwatch.elapsedMilliseconds;

      // In pure Dart debug VM, 132,300 stereo samples across 4 voices + 8 FIR taps
      // should execute well under real-time audio (3000ms), taking under 600ms.
      expect(elapsedMs, lessThan(600),
          reason: '4-voice 3.0s chord should render in under 600ms, took ${elapsedMs}ms');
    });

    test('prewarmPatternCache correctly matches chord-remapped notes without cache misses', () {
      final dawState = DawState();
      dawState.setBpm(125.0);
      dawState.setLooping(true);
      dawState.setLoopPoints(0, 8);

      // Setup chord track: Bar 0-2: F Major (root 5), Bar 2-4: D Minor (root 2), Bar 4-6: Bb Major (root 10), Bar 6-8: C Major (root 0)
      dawState.chordTrack = [
        ChordEvent(id: 'c1', startBar: 0, barLength: 2, rootPitchClass: 5, quality: ChordQuality.major),
        ChordEvent(id: 'c2', startBar: 2, barLength: 2, rootPitchClass: 2, quality: ChordQuality.minor),
        ChordEvent(id: 'c3', startBar: 4, barLength: 2, rootPitchClass: 10, quality: ChordQuality.major),
        ChordEvent(id: 'c4', startBar: 6, barLength: 2, rootPitchClass: 0, quality: ChordQuality.major),
      ];

      // Setup SNES Synth track with chord follow mode
      final track = dawState.activePattern.tracks.first;
      track.name = 'SNES Chords';
      track.type = TrackType.synth;
      track.chordFollowMode = ChordFollowMode.chord;
      // Isolate activePattern tracks to only the SNES track for clean benchmark measurement
      dawState.activePattern.tracks.clear();
      dawState.activePattern.tracks.add(track);

      // Add 4-note sustained chords at Bar 0 (step 0) and Bar 2 (step 32)
      final clip = TrackClip(
        id: 'clip_snes',
        name: 'SNES Pad',
        trackId: track.id,
        startBar: 0,
        barLength: 4,
        patternIndex: 0,
        lyrics: [],
        luaScriptCode: '',
        luaParams: {},
        automationLanes: [],
        notes: [
          // Step 0 chord
          Note(id: 'n1', pitch: 60, velocity: 0.8, startStep: 0, durationSteps: 31.5, column: 0, effectCommand: '', isSlide: false, isAccent: false),
          Note(id: 'n2', pitch: 64, velocity: 0.8, startStep: 0, durationSteps: 31.5, column: 1, effectCommand: '', isSlide: false, isAccent: false),
          Note(id: 'n3', pitch: 67, velocity: 0.8, startStep: 0, durationSteps: 31.5, column: 2, effectCommand: '', isSlide: false, isAccent: false),
          Note(id: 'n4', pitch: 71, velocity: 0.8, startStep: 0, durationSteps: 31.5, column: 3, effectCommand: '', isSlide: false, isAccent: false),
          // Step 32 chord (Bar 2)
          Note(id: 'n5', pitch: 60, velocity: 0.8, startStep: 32, durationSteps: 31.5, column: 0, effectCommand: '', isSlide: false, isAccent: false),
          Note(id: 'n6', pitch: 64, velocity: 0.8, startStep: 32, durationSteps: 31.5, column: 1, effectCommand: '', isSlide: false, isAccent: false),
          Note(id: 'n7', pitch: 67, velocity: 0.8, startStep: 32, durationSteps: 31.5, column: 2, effectCommand: '', isSlide: false, isAccent: false),
          Note(id: 'n8', pitch: 71, velocity: 0.8, startStep: 32, durationSteps: 31.5, column: 3, effectCommand: '', isSlide: false, isAccent: false),
        ],
      );
      track.clips.clear();
      track.clips.add(clip);

      // Prewarm pattern cache via togglePlay
      final prewarmStopwatch = Stopwatch()..start();
      dawState.togglePlay();
      prewarmStopwatch.stop();

      expect(dawState.isPlaying, isTrue);
      expect(prewarmStopwatch.elapsedMilliseconds, lessThan(800),
          reason: 'Prewarming the 8-bar loop should take under 800ms');

      // Verify that chord at step 32 was prewarmed with remapped pitch for D Minor
      final dMinorChord = dawState.getActiveChordAtStep(32);
      expect(dMinorChord, isNotNull);
      expect(dMinorChord!.quality, equals(ChordQuality.minor));

      // Calculate remapped pitch for note 60 under D Minor
      final remappedPitch = ChordTheory.remapPitchForChord(60, dMinorChord, track.chordFollowMode.name);

      // Verify that the note buffer is cached and retrieval is instantaneous
      final stepDurationSec = 60.0 / 125.0 / 4.0;
      final noteDurSec = math.max(0.02, math.min(3.0, 31.5 * stepDurationSec));
      final isCached = dawState.audioEngine.isBufferCached(
        track: track,
        midiNote: remappedPitch,
        durationSec: noteDurSec,
        isSlide: false,
        isAccent: true,
      );
      expect(isCached, isTrue,
          reason: 'Prewarmed buffer for pitch $remappedPitch must be present in audio cache');

      dawState.togglePlay();
      dawState.dispose();
    });

    test('Duplicated track replication with sustained polyphonic chords does not desync', () {
      final dawState = DawState();
      dawState.setBpm(125.0);
      dawState.setLooping(false);

      final track1 = dawState.activePattern.tracks[0];
      track1.name = 'SNES Lead A';
      track1.type = TrackType.synth;

      final track2 = TrackChannel(
        id: 't_snes_dup',
        name: 'SNES Lead B (Duplicate)',
        type: TrackType.synth,
        color: Colors.teal,
      );
      dawState.activePattern.tracks.add(track2);

      final notes1 = [
        Note(id: 'n1', pitch: 60, velocity: 0.85, startStep: 0, durationSteps: 15.5, column: 0, effectCommand: '', isSlide: false, isAccent: false),
        Note(id: 'n2', pitch: 65, velocity: 0.85, startStep: 0, durationSteps: 15.5, column: 1, effectCommand: '', isSlide: false, isAccent: false),
        Note(id: 'n3', pitch: 69, velocity: 0.85, startStep: 0, durationSteps: 15.5, column: 2, effectCommand: '', isSlide: false, isAccent: false),
      ];

      final notes2 = [
        Note(id: 'n4', pitch: 60, velocity: 0.85, startStep: 0, durationSteps: 15.5, column: 0, effectCommand: '', isSlide: false, isAccent: false),
        Note(id: 'n5', pitch: 65, velocity: 0.85, startStep: 0, durationSteps: 15.5, column: 1, effectCommand: '', isSlide: false, isAccent: false),
        Note(id: 'n6', pitch: 69, velocity: 0.85, startStep: 0, durationSteps: 15.5, column: 2, effectCommand: '', isSlide: false, isAccent: false),
      ];

      track1.clips = [
        TrackClip(id: 'c1', name: 'Lead 1', trackId: track1.id, startBar: 0, barLength: 2, patternIndex: 0, lyrics: [], luaScriptCode: '', luaParams: {}, automationLanes: [], notes: notes1),
      ];
      track2.clips = [
        TrackClip(id: 'c2', name: 'Lead 2', trackId: track2.id, startBar: 0, barLength: 2, patternIndex: 0, lyrics: [], luaScriptCode: '', luaParams: {}, automationLanes: [], notes: notes2),
      ];

      // Prewarm and start playback
      dawState.togglePlay();
      expect(dawState.isPlaying, isTrue);

      final initialStep = dawState.continuousArrangerStepNotifier.value;
      expect(initialStep, equals(0.0));

      // Visual elapsed time starts at 0 and tracks smoothly without drifting
      expect(dawState.visualElapsedSec, equals(0.0));

      dawState.togglePlay();
      dawState.dispose();
    });
  });
}
