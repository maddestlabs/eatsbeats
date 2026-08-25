import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/utils/midi_file_parser.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';

Uint8List _createMidiFile({
  required int bpm,
  required Map<String, List<({int pitch, int startTick, int durationTicks, int channel})>> tracks,
  int ppqn = 480,
}) {
  final builder = BytesBuilder();

  // Header chunk (Format 1, N tracks, PPQN)
  builder.add([0x4D, 0x54, 0x68, 0x64]); // MThd
  builder.add([0x00, 0x00, 0x00, 0x06]); // length 6
  builder.add([0x00, 0x01]); // Format 1
  builder.add([(tracks.length >> 8) & 0xFF, tracks.length & 0xFF]); // Num tracks
  builder.add([(ppqn >> 8) & 0xFF, ppqn & 0xFF]); // PPQN

  int trackIdx = 0;
  for (final entry in tracks.entries) {
    final trackBytes = BytesBuilder();
    final trackName = entry.key;
    final noteList = entry.value;

    // Track Name Meta Event
    final nameEncoded = utf8.encode(trackName);
    trackBytes.add([0x00, 0xFF, 0x03, nameEncoded.length]);
    trackBytes.add(nameEncoded);

    // Tempo meta event on first track
    if (trackIdx == 0) {
      final usPerQuarter = (60000000 / bpm).round();
      trackBytes.add([
        0x00,
        0xFF,
        0x51,
        0x03,
        (usPerQuarter >> 16) & 0xFF,
        (usPerQuarter >> 8) & 0xFF,
        usPerQuarter & 0xFF,
      ]);
    }

    // Build timeline of events
    final events = <({int tick, List<int> bytes})>[];
    for (final note in noteList) {
      final ch = note.channel.clamp(0, 15);
      // Note On
      events.add((
        tick: note.startTick,
        bytes: [0x90 | ch, note.pitch, 100],
      ));
      // Note Off
      events.add((
        tick: note.startTick + note.durationTicks,
        bytes: [0x80 | ch, note.pitch, 64],
      ));
    }

    events.sort((a, b) => a.tick.compareTo(b.tick));

    int lastTick = 0;
    for (final evt in events) {
      final delta = evt.tick - lastTick;
      lastTick = evt.tick;
      _writeVlq(trackBytes, delta);
      trackBytes.add(evt.bytes);
    }

    // End of Track
    trackBytes.add([0x00, 0xFF, 0x2F, 0x00]);

    final trackData = trackBytes.toBytes();
    builder.add([0x4D, 0x54, 0x72, 0x6B]); // MTrk
    builder.add([
      (trackData.length >> 24) & 0xFF,
      (trackData.length >> 16) & 0xFF,
      (trackData.length >> 8) & 0xFF,
      trackData.length & 0xFF,
    ]);
    builder.add(trackData);
    trackIdx++;
  }

  return builder.toBytes();
}

void _writeVlq(BytesBuilder builder, int value) {
  int buffer = value & 0x7F;
  while ((value >>= 7) > 0) {
    buffer <<= 8;
    buffer |= 0x80;
    buffer += (value & 0x7F);
  }
  while (true) {
    builder.addByte(buffer & 0xFF);
    if ((buffer & 0x80) != 0) {
      buffer >>= 8;
    } else {
      break;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MidiFileParser & SongGen Ingest Tests', () {
    test('Parses SongGen 5-track structure and calculates 16th steps', () {
      final testMidiBytes = _createMidiFile(
        bpm: 128,
        ppqn: 480,
        tracks: {
          'Track 1': [
            (pitch: 72, startTick: 0, durationTicks: 480, channel: 0),
          ],
          'Drums': [
            (pitch: 36, startTick: 0, durationTicks: 240, channel: 9),
            (pitch: 38, startTick: 480, durationTicks: 240, channel: 9),
          ],
          'Bass': [
            (pitch: 40, startTick: 0, durationTicks: 960, channel: 1),
            (pitch: 43, startTick: 960, durationTicks: 960, channel: 1),
          ],
          'Chords': [
            (pitch: 60, startTick: 0, durationTicks: 1920, channel: 2),
            (pitch: 64, startTick: 0, durationTicks: 1920, channel: 2),
            (pitch: 67, startTick: 0, durationTicks: 1920, channel: 2),
          ],
          'Lead': [
            (pitch: 69, startTick: 0, durationTicks: 480, channel: 3),
            (pitch: 71, startTick: 480, durationTicks: 480, channel: 3),
          ],
        },
      );

      final parsed = MidiFileParser.parse(testMidiBytes);
      expect(parsed, isNotNull);
      expect(parsed!.bpm, equals(128.0));
      expect(parsed.tracks.length, equals(5));

      final drumsTrack = parsed.tracks.firstWhere((t) => t.name == 'Drums');
      expect(drumsTrack.notes.length, equals(2));
      expect(drumsTrack.notes[0].pitch, equals(36));
      expect(drumsTrack.notes[0].startStep, equals(0.0));
      // 240 ticks at 480 PPQN is 0.5 beat = 2 steps
      expect(drumsTrack.notes[0].durationSteps, equals(2.0));

      final chordsTrack = parsed.tracks.firstWhere((t) => t.name == 'Chords');
      expect(chordsTrack.notes.length, equals(3));
      // 1920 ticks at 480 PPQN is 4 beats = 16 steps (1 bar)
      expect(chordsTrack.notes[0].durationSteps, equals(16.0));
    });

    test('DawState matches and replaces SongGen tracks while preserving soundfont presets and settings', () {
      final dawState = DawState();
      dawState.setBpm(90.0);

      // Set up project tracks with custom names and soundfonts
      dawState.activePattern.tracks.clear();

      final drums = TrackChannel(
        id: 'track_drums',
        name: 'Drums',
        color: const Color(0xFFFF8C00),
        type: TrackType.sampler,
        sampleName: 'super_small_font.sf2',
        iconName: 'drums',
      );
      final bass = TrackChannel(
        id: 'track_bass',
        name: 'Bass',
        color: const Color(0xFF21F4E8),
        type: TrackType.luaScript,
        sampleName: 'super_small_font.sf2',
        iconName: 'bass',
        luaParams: {'PresetNum': 33.0}, // Electric Bass preset
      );
      final chords = TrackChannel(
        id: 'track_chords',
        name: 'Chords',
        color: const Color(0xFFBD00FF),
        type: TrackType.luaScript,
        sampleName: 'super_small_font.sf2',
        iconName: 'piano',
        luaParams: {'PresetNum': 4.0}, // Electric Piano preset
      );
      final lead = TrackChannel(
        id: 'track_lead',
        name: 'Lead',
        color: const Color(0xFFFF0055),
        type: TrackType.luaScript,
        sampleName: 'super_small_font.sf2',
        iconName: 'synth',
        luaParams: {'PresetNum': 81.0}, // Lead Synth preset
      );

      // Pre-populate with dummy notes
      drums.notes.add(Note(id: 'old_drum', pitch: 99, startStep: 0, durationSteps: 1));
      bass.notes.add(Note(id: 'old_bass', pitch: 99, startStep: 0, durationSteps: 1));

      dawState.activePattern.tracks.addAll([drums, bass, chords, lead]);
      dawState.history.init(dawState);

      // Create incoming SongGen MIDI file
      final testMidiBytes = _createMidiFile(
        bpm: 140,
        ppqn: 480,
        tracks: {
          'Track 1': [
            (pitch: 72, startTick: 0, durationTicks: 480, channel: 0),
          ],
          'Drums': [
            (pitch: 36, startTick: 0, durationTicks: 240, channel: 9),
            (pitch: 38, startTick: 480, durationTicks: 240, channel: 9),
          ],
          'Bass': [
            (pitch: 41, startTick: 0, durationTicks: 480, channel: 1),
          ],
          'Chords': [
            (pitch: 60, startTick: 0, durationTicks: 1920, channel: 2),
            (pitch: 64, startTick: 0, durationTicks: 1920, channel: 2),
          ],
          'Lead': [
            (pitch: 76, startTick: 0, durationTicks: 480, channel: 3),
          ],
        },
      );

      final success = dawState.importMidiFileBytes(testMidiBytes, fileName: 'SongGen_Groove.mid');
      expect(success, isTrue);

      // Verify BPM updated
      expect(dawState.bpm.round(), equals(140));

      // Verify notes were replaced
      final updatedDrums = dawState.activePattern.tracks.firstWhere((t) => t.name == 'Drums');
      expect(updatedDrums.notes.any((n) => n.id == 'old_drum'), isFalse);
      expect(updatedDrums.notes.length, equals(2));
      expect(updatedDrums.notes.first.pitch, equals(36));

      final updatedBass = dawState.activePattern.tracks.firstWhere((t) => t.name == 'Bass');
      expect(updatedBass.notes.any((n) => n.id == 'old_bass'), isFalse);
      expect(updatedBass.notes.length, equals(1));
      expect(updatedBass.notes.first.pitch, equals(41));
      // Verify soundfont preset intact
      expect(updatedBass.luaParams['PresetNum'], equals(33.0));

      final updatedChords = dawState.activePattern.tracks.firstWhere((t) => t.name == 'Chords');
      expect(updatedChords.notes.length, equals(2));
      expect(updatedChords.luaParams['PresetNum'], equals(4.0));

      final updatedLead = dawState.activePattern.tracks.firstWhere((t) => t.name == 'Lead');
      expect(updatedLead.notes.length, equals(1));
      expect(updatedLead.notes.first.pitch, equals(76));
      expect(updatedLead.luaParams['PresetNum'], equals(81.0));

      // Verify undo restores previous state
      expect(dawState.history.canUndo, isTrue);
      dawState.history.undo(dawState);

      expect(dawState.bpm.round(), equals(90));
      final undoneDrums = dawState.activePattern.tracks.firstWhere((t) => t.name == 'Drums');
      expect(undoneDrums.notes.any((n) => n.id == 'old_drum'), isTrue);

      dawState.dispose();
    });
  });
}
