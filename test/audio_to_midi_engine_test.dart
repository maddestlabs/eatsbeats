import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/audio/audio_to_midi_engine.dart';
import 'package:eatsbeats/audio/sampler_engine.dart';
import 'package:eatsbeats/models/chord_model.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/utils/audio_to_midi_pack_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioToMidiEngine Tests', () {
    test('Transcribes monophonic A4 (440 Hz) sine wave into MIDI Note 69', () async {
      const sampleRate = 44100;
      const durationSec = 1.0;
      final numSamples = (sampleRate * durationSec).toInt();
      final samples = List<double>.generate(numSamples, (i) {
        final t = i / sampleRate;
        return 0.8 * math.sin(2.0 * math.pi * 440.0 * t);
      });

      final audioBuffer = DecodedAudioBuffer(
        samples: samples,
        sampleRate: sampleRate,
        channels: 1,
      );

      final midiTrack = await AudioToMidiEngine.transcribeAudioBuffer(
        audioBuffer,
        options: const AudioToMidiOptions(
          onsetThreshold: 0.3,
          frameThreshold: 0.25,
          minMidiPitch: 60,
          maxMidiPitch: 80,
          minNoteDurationMs: 100.0,
        ),
      );

      expect(midiTrack.notes.isNotEmpty, isTrue);
      // Verify the detected pitch is A4 (MIDI 69)
      final primaryNote = midiTrack.notes.first;
      expect(primaryNote.pitch, equals(69));
      expect(primaryNote.velocity, greaterThan(0.2));
    });

    test('Transcribes monophonic C4 (261.63 Hz) tone into MIDI Note 60', () async {
      const sampleRate = 44100;
      const durationSec = 0.8;
      final numSamples = (sampleRate * durationSec).toInt();
      final samples = List<double>.generate(numSamples, (i) {
        final t = i / sampleRate;
        return 0.8 * math.sin(2.0 * math.pi * 261.63 * t);
      });

      final audioBuffer = DecodedAudioBuffer(
        samples: samples,
        sampleRate: sampleRate,
        channels: 1,
      );

      final midiTrack = await AudioToMidiEngine.transcribeAudioBuffer(
        audioBuffer,
        options: const AudioToMidiOptions(
          onsetThreshold: 0.3,
          frameThreshold: 0.25,
          minMidiPitch: 50,
          maxMidiPitch: 70,
          minNoteDurationMs: 100.0,
        ),
      );

      expect(midiTrack.notes.isNotEmpty, isTrue);
      final detectedPitches = midiTrack.notes.map((n) => n.pitch).toSet();
      expect(detectedPitches.contains(60), isTrue);
    });

    test('Transcribes polyphonic chord (C4 60 + G4 67)', () async {
      const sampleRate = 44100;
      const durationSec = 1.0;
      final numSamples = (sampleRate * durationSec).toInt();
      final samples = List<double>.generate(numSamples, (i) {
        final t = i / sampleRate;
        final s1 = 0.5 * math.sin(2.0 * math.pi * 261.63 * t); // C4
        final s2 = 0.5 * math.sin(2.0 * math.pi * 392.00 * t); // G4
        return s1 + s2;
      });

      final audioBuffer = DecodedAudioBuffer(
        samples: samples,
        sampleRate: sampleRate,
        channels: 1,
      );

      final midiTrack = await AudioToMidiEngine.transcribeAudioBuffer(
        audioBuffer,
        options: const AudioToMidiOptions(
          onsetThreshold: 0.25,
          frameThreshold: 0.2,
          minMidiPitch: 55,
          maxMidiPitch: 75,
          minNoteDurationMs: 100.0,
        ),
      );

      expect(midiTrack.notes.isNotEmpty, isTrue);
      final pitches = midiTrack.notes.map((n) => n.pitch).toSet();
      expect(pitches.contains(60), isTrue);
      expect(pitches.contains(67), isTrue);
    });

    test('Handles silence gracefully without phantom notes', () async {
      const sampleRate = 44100;
      final samples = List<double>.filled(44100, 0.0);

      final audioBuffer = DecodedAudioBuffer(
        samples: samples,
        sampleRate: sampleRate,
        channels: 1,
      );

      final midiTrack = await AudioToMidiEngine.transcribeAudioBuffer(
        audioBuffer,
        options: const AudioToMidiOptions(),
      );

      expect(midiTrack.notes.isEmpty, isTrue);
    });

    test('Cancellation token aborts long-running transcription immediately', () async {
      const sampleRate = 44100;
      final samples = List<double>.generate(sampleRate * 2, (i) => math.sin(i * 0.1));
      final audioBuffer = DecodedAudioBuffer(samples: samples, sampleRate: sampleRate, channels: 1);

      final token = CancellationToken();
      token.cancel(); // Pre-cancel

      final midiTrack = await AudioToMidiEngine.transcribeAudioBuffer(
        audioBuffer,
        cancellationToken: token,
      );

      expect(midiTrack.notes.isEmpty, isTrue);
      expect(midiTrack.name, equals('Cancelled'));
    });
  });

  group('ChordTheory Harmonic Detection & Studio One Workflow Tests', () {
    test('Detects C Major chord from MIDI pitches (60, 64, 67)', () {
      final detected = ChordTheory.detectChordFromPitches([60, 64, 67]);
      expect(detected, isNotNull);
      expect(detected!.$1, equals(0)); // C is pitch class 0
      expect(detected.$2, equals(ChordQuality.major));
    });

    test('Detects A Minor chord from MIDI pitches (57, 60, 64)', () {
      final detected = ChordTheory.detectChordFromPitches([57, 60, 64]);
      expect(detected, isNotNull);
      expect(detected!.$1, equals(9)); // A is pitch class 9
      expect(detected.$2, equals(ChordQuality.minor));
    });

    test('Extracts chord progression across multiple bars from notes', () {
      final notes = [
        // Bar 0 (steps 0..16): C Major triad (C4, E4, G4)
        Note(id: 'n1', pitch: 60, startStep: 0, durationSteps: 16, velocity: 0.8),
        Note(id: 'n2', pitch: 64, startStep: 0, durationSteps: 16, velocity: 0.8),
        Note(id: 'n3', pitch: 67, startStep: 0, durationSteps: 16, velocity: 0.8),
        // Bar 1 (steps 16..32): G Major triad (G3, B3, D4)
        Note(id: 'n4', pitch: 55, startStep: 16, durationSteps: 16, velocity: 0.8),
        Note(id: 'n5', pitch: 59, startStep: 16, durationSteps: 16, velocity: 0.8),
        Note(id: 'n6', pitch: 62, startStep: 16, durationSteps: 16, velocity: 0.8),
      ];

      final chords = ChordTheory.extractChordsFromNotes(notes, startBar: 0, totalBars: 2);
      expect(chords.length, equals(2));
      expect(chords[0].rootPitchClass, equals(0)); // C
      expect(chords[0].quality, equals(ChordQuality.major));
      expect(chords[0].startBar, equals(0));

      expect(chords[1].rootPitchClass, equals(7)); // G
      expect(chords[1].quality, equals(ChordQuality.major));
      expect(chords[1].startBar, equals(1));
    });
  });

  group('TrackClip Audio Properties & Serialization Tests', () {
    test('Serializes and deserializes audio clip fields and embedded MIDI notes', () {
      final originalClip = TrackClip(
        id: 'clip_audio_1',
        name: 'Vocal Stem',
        trackId: 'track_1',
        startBar: 2,
        barLength: 4,
        isAudioClip: true,
        audioSampleName: 'vocals_lead.wav',
        audioPitchOffset: 3.0,
        embeddedTranscribedNotes: [
          Note(id: 'emb_1', pitch: 69, startStep: 0, durationSteps: 4, velocity: 0.85),
        ],
      );

      final json = originalClip.toJson();
      expect(json['isAudioClip'], isTrue);
      expect(json['audioSampleName'], equals('vocals_lead.wav'));
      expect(json['audioPitchOffset'], equals(3.0));
      expect((json['embeddedTranscribedNotes'] as List).length, equals(1));

      final restored = TrackClip.fromJson(json);
      expect(restored.isAudioClip, isTrue);
      expect(restored.audioSampleName, equals('vocals_lead.wav'));
      expect(restored.audioPitchOffset, equals(3.0));
      expect(restored.hasEmbeddedMidi, isTrue);
      expect(restored.embeddedTranscribedNotes.first.pitch, equals(69));
    });
  });

  group('AudioToMidiPackManager Tests', () {
    test('Default pack definitions are configured', () {
      final manager = AudioToMidiPackManager.instance;
      expect(manager.packs.isNotEmpty, isTrue);
      final basicPitch = manager.packs.firstWhere((p) => p.id == 'basic_pitch_neural');
      expect(basicPitch.title, contains('Basic Pitch'));
      expect(basicPitch.fileName, equals('basic_pitch_model.onnx'));
      expect(basicPitch.fileSizeMb, equals(18));
    });
  });
}
