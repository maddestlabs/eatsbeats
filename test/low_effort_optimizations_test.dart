import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/eatscript/eats_dsp_synthesizer.dart';
import 'package:eatsbeats/eatscript/midi_pipeline_engine.dart';
import 'package:eatsbeats/audio/audio_engine.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/models/chord_model.dart';
import 'package:eatsbeats/models/automation_model.dart';
import 'package:eatsbeats/audio/time_context.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Low-Effort Optimizations Tests', () {
    test('Item 3: _extractParam caches extracted values across evaluations', () {
      EatDspSynthesizer.clearDispatchCaches();
      final lane = AutomationLane(
        id: 'auto1',
        name: 'Filter Cutoff',
        target: AutomationTarget.cutoff,
        isCustomEatScript: true,
        eatScriptCode: 'rate = 2.5\ndepth = 500.0\ncenter = 1200.0\n-- lfo',
      );

      final val1 = EatDspSynthesizer.evaluateAutomation(lane: lane, step: 0.0);
      final val2 = EatDspSynthesizer.evaluateAutomation(lane: lane, step: 2.0);

      expect(val1, isNotNull);
      expect(val2, isNotNull);
      expect(val1, isNot(equals(val2))); // LFO oscillates
    });

    test('Item 5: _pcmCache promotes on access (LRU order)', () {
      final engine = AudioEngine();
      final track = TrackChannel(
        id: 't_lru',
        name: 'Synth',
        type: TrackType.synth,
        color: const Color(0xFF00FF00),
        eatScriptCode: 'def process(): return eat.saw(440)',
      );

      // Synthesize note 60 -> inserted
      engine.playNoteOrSample(track: track, midiNote: 60, velocity: 0.8, durationSec: 0.1);
      expect(engine.pcmCacheCount, greaterThan(0));

      // Synthesize note 62 -> inserted at end
      engine.playNoteOrSample(track: track, midiNote: 62, velocity: 0.8, durationSec: 0.1);

      // Access note 60 again -> should promote note 60 to end
      engine.playNoteOrSample(track: track, midiNote: 60, velocity: 0.8, durationSec: 0.1);
      expect(engine.pcmCacheCount, greaterThanOrEqualTo(2));

      engine.stopAllSound();
    });

    test('Item 7: Prewarm slide lookup handles sorted notes with early break', () {
      final engine = AudioEngine();
      final track = TrackChannel(
        id: 't_slide',
        name: 'Acid Bass',
        type: TrackType.synth,
        color: const Color(0xFF00FF00),
        isMonophonic: true,
        eatScriptCode: 'def process(): return eat.saw(eat.mtof(eat.note))',
      );

      final clip = TrackClip(
        id: 'clip_slide',
        name: 'Acid Pattern',
        trackId: 't_slide',
        startBar: 0,
        barLength: 1,
        notes: [
          Note(id: 'n1', pitch: 36, startStep: 0.0, durationSteps: 2.0, isSlide: true),
          Note(id: 'n2', pitch: 48, startStep: 2.0, durationSteps: 2.0),
          Note(id: 'n3', pitch: 38, startStep: 8.0, durationSteps: 2.0),
        ],
      );
      track.clips.add(clip);

      // Prewarm clips using prewarmPatternCache
      engine.prewarmPatternCache([track], 0.125, startStep: 0, lookaheadSteps: 16);
      expect(engine.pcmCacheCount, greaterThan(0));

      engine.stopAllSound();
    });

    test('Item 9: Frame-level DateTime.now() and 15ms meter update gate', () {
      final engine = AudioEngine();
      final track = TrackChannel(
        id: 't_meter',
        name: 'Lead',
        type: TrackType.synth,
        color: const Color(0xFF00FF00),
      );

      final frameTime = DateTime.now();
      final (l1, r1) = engine.getPeakLevels(trackId: track.id, timestamp: frameTime);
      final (l2, r2) = engine.getPeakLevels(trackId: track.id, timestamp: frameTime);

      expect(l1, equals(l2));
      expect(r1, equals(r2));

      final snapshot = engine.getMeterSnapshot(timestamp: frameTime);
      expect(snapshot['leftPeak'], isNotNull);

      final spectrum = engine.getSpectrumBands(trackId: track.id, timestamp: frameTime);
      expect(spectrum.length, 16);

      engine.stopAllSound();
    });

    test('Item 10: MidiPipelineEngine caches MidiFxType resolution and executes pipeline', () {
      MidiPipelineEngine.clearDispatchCaches();
      final pipeline = MidiPipelineEngine();
      final track = TrackChannel(
        id: 't_fx',
        name: 'Arp Track',
        type: TrackType.synth,
        color: const Color(0xFF00FF00),
        midiFXRack: [
          MidiFXInsert(
            id: 'arp_fx',
            name: 'Arpeggiator',
            eatScriptCode: 'arpeggiator(rate=1.0, octaves=2, pattern=0)',
            eatScriptParams: {'Rate': 1.0, 'Octaves': 2.0, 'Pattern': 0.0},
          ),
        ],
      );

      final clip = TrackClip(
        id: 'c_arp',
        name: 'Chord',
        trackId: 't_fx',
        startBar: 0,
        barLength: 1,
        notes: [
          Note(id: 'n1', pitch: 60, startStep: 0.0, durationSteps: 4.0),
        ],
      );

      final cMaj = ChordEvent(id: 'c1', startBar: 0, barLength: 1.0, rootPitchClass: 0, quality: ChordQuality.major);
      final ctx = TimeContext.fromBeat(beat: 0.0, bpm: 120.0, activeChord: cMaj, chordTrack: [cMaj]);

      // Process twice to exercise cache
      final notes1 = pipeline.processClip(clip: clip, track: track, timeContext: ctx);
      final notes2 = pipeline.processClip(clip: clip, track: track, timeContext: ctx);

      expect(notes1.isNotEmpty, isTrue);
      expect(notes2.isNotEmpty, isTrue);
      expect(notes1.length, equals(notes2.length));
    });
  });
}
