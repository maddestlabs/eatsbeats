import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/audio/gm/gm_instrument_registry.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';

Uint8List _createMidiFileWithTracks({
  required int bpm,
  required List<({String name, int? program, int channel, List<int> notes})> tracks,
  int ppqn = 480,
}) {
  final builder = BytesBuilder();

  // Header chunk (Format 1, N tracks, PPQN)
  builder.add([0x4D, 0x54, 0x68, 0x64]); // MThd
  builder.add([0x00, 0x00, 0x00, 0x06]);
  builder.add([0x00, 0x01]);
  builder.add([(tracks.length >> 8) & 0xFF, tracks.length & 0xFF]);
  builder.add([(ppqn >> 8) & 0xFF, ppqn & 0xFF]);

  for (int i = 0; i < tracks.length; i++) {
    final t = tracks[i];
    final trackBytes = BytesBuilder();

    // Track Name Meta Event
    final nameEncoded = utf8.encode(t.name);
    trackBytes.add([0x00, 0xFF, 0x03, nameEncoded.length]);
    trackBytes.add(nameEncoded);

    // Tempo meta event on first track
    if (i == 0) {
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

    final ch = t.channel.clamp(0, 15);

    // Program Change if specified
    if (t.program != null) {
      trackBytes.add([0x00, 0xC0 | ch, t.program! & 0x7F]);
    }

    // Add note events
    for (int n = 0; n < t.notes.length; n++) {
      final pitch = t.notes[n];
      // Note On at delta 0
      trackBytes.add([0x00, 0x90 | ch, pitch, 100]);
      // Note Off at delta 480
      trackBytes.add([0x83, 0x60, 0x80 | ch, pitch, 64]);
    }

    // End of Track
    trackBytes.add([0x00, 0xFF, 0x2F, 0x00]);

    final trackData = trackBytes.toBytes();
    builder.add([0x4D, 0x54, 0x72, 0x6B]); // MTrk
    final len = trackData.length;
    builder.add([(len >> 24) & 0xFF, (len >> 16) & 0xFF, (len >> 8) & 0xFF, len & 0xFF]);
    builder.add(trackData);
  }

  return builder.toBytes();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GeneralMidiRegistry Specification & Coverage Audit Tests', () {
    test('GM Spec contains all 128 defined instruments across all 16 families', () {
      expect(GmInstrumentRegistry.spec.length, equals(128));

      // Verify sequential program numbers from 0 to 127
      for (int i = 0; i < 128; i++) {
        expect(GmInstrumentRegistry.spec[i].programNumber, equals(i));
        expect(GmInstrumentRegistry.spec[i].gmName.isNotEmpty, isTrue);
      }
    });

    test('Coverage calculation matches native and missing counts', () {
      final nativeList = GmInstrumentRegistry.nativeInstruments;
      final missingList = GmInstrumentRegistry.missingInstruments;

      expect(nativeList.length + missingList.length, equals(128));
      expect(GmInstrumentRegistry.nativeCount, equals(nativeList.length));
      expect(GmInstrumentRegistry.totalCount, equals(128));

      final calculatedPercent = (nativeList.length / 128.0) * 100.0;
      expect(GmInstrumentRegistry.nativeCoveragePercent, closeTo(calculatedPercent, 0.01));

      // Ensure we have significant native coverage (> 20%)
      expect(GmInstrumentRegistry.nativeCoveragePercent, greaterThan(20.0));
      debugPrint('Current Native GM Coverage: ${GmInstrumentRegistry.nativeCoveragePercent.toStringAsFixed(1)}% (${nativeList.length}/128 instruments)');
    });

    test('Missing instruments list accurately identifies unmodeled instruments', () {
      final missing = GmInstrumentRegistry.missingInstruments;
      final missingNames = missing.map((e) => e.gmName).toList();

      // Organs, Accordions & Timpani are currently soundfont fallbacks
      expect(missingNames, contains('Church Organ'));
      expect(missingNames, contains('Accordion'));
      expect(missingNames, contains('Harmonica'));
      expect(missingNames, contains('Timpani'));
      expect(missingNames, contains('Choir Aahs'));
    });

    test('Markdown coverage report generates comprehensive checklist', () {
      final report = GmInstrumentRegistry.generateMarkdownCoverageReport();
      expect(report, contains('General MIDI Specification Coverage Report'));
      expect(report, contains('Piano'));
      expect(report, contains('Solo Strings'));
      expect(report, contains('Acoustic Grand Piano'));
      expect(report, contains('Cello'));
      expect(report, contains('Channel 10 Percussion'));
    });
  });

  group('GeneralMidiRegistry Resolution Engine Tests', () {
    test('Resolves explicit Program Change to native instruments', () {
      // GM 0 -> Acoustic Grand Piano -> concert_grand_piano
      final piano = GmInstrumentRegistry.resolve(programNumber: 0, trackName: 'Track 1');
      expect(piano.isNative, isTrue);
      expect(piano.presetId, equals('concert_grand_piano'));
      expect(piano.iconName, equals('piano'));
      expect(piano.matchReason, equals('program_change'));

      // GM 42 -> Cello -> solo_cello
      final cello = GmInstrumentRegistry.resolve(programNumber: 42, trackName: 'Track 2');
      expect(cello.isNative, isTrue);
      expect(cello.presetId, equals('solo_cello'));
      expect(cello.iconName, equals('strings'));
      expect(cello.matchReason, equals('program_change'));

      // GM 5 -> DX7 FM E-Piano -> dx7_epiano
      final dx7 = GmInstrumentRegistry.resolve(programNumber: 5, trackName: 'Track 3');
      expect(dx7.isNative, isTrue);
      expect(dx7.presetId, equals('dx7_epiano'));

      // GM 4 -> Rhodes -> rhodes_epiano
      final rhodes = GmInstrumentRegistry.resolve(programNumber: 4, trackName: 'Track 4');
      expect(rhodes.isNative, isTrue);
      expect(rhodes.presetId, equals('rhodes_epiano'));

      // GM 24 -> Nylon Guitar -> spanish_guitar
      final guitar = GmInstrumentRegistry.resolve(programNumber: 24, trackName: 'Track 5');
      expect(guitar.isNative, isTrue);
      expect(guitar.presetId, equals('spanish_guitar'));

      // GM 11 -> Vibraphone -> vibraphone
      final vibe = GmInstrumentRegistry.resolve(programNumber: 11, trackName: 'Track 6');
      expect(vibe.isNative, isTrue);
      expect(vibe.presetId, equals('vibraphone'));
    });

    test('Resolves semantic track name when Program Change is absent or default 0', () {
      // No program number, but name is "Solo Cello"
      final celloByName = GmInstrumentRegistry.resolve(programNumber: null, trackName: 'Solo Cello');
      expect(celloByName.isNative, isTrue);
      expect(celloByName.presetId, equals('solo_cello'));
      expect(celloByName.matchReason, equals('semantic_keyword'));

      // Program 0 (Grand Piano default) but track name is "Electric Piano DX7"
      final dx7ByName = GmInstrumentRegistry.resolve(programNumber: 0, trackName: 'Electric Piano DX7');
      expect(dx7ByName.isNative, isTrue);
      expect(dx7ByName.presetId, equals('dx7_epiano'));

      // Clean guitar name
      final guitarByName = GmInstrumentRegistry.resolve(programNumber: null, trackName: 'Clean Guitar Lead');
      expect(guitarByName.isNative, isTrue);
      expect(guitarByName.presetId, equals('reggae_guitar'));
    });

    test('Falls back to SoundFont sampler with exact program number for unmodeled instruments', () {
      // GM 19 Church Organ (unmodeled fallback)
      final organ = GmInstrumentRegistry.resolve(programNumber: 19, trackName: 'Pipe Church Organ');
      expect(organ.isNative, isFalse);
      expect(organ.presetId, equals('soundfont_sampler'));
      expect(organ.presetNum, equals(19.0));
      expect(organ.matchReason, equals('soundfont_fallback'));

      // GM 47 Timpani (unmodeled fallback)
      final timpani = GmInstrumentRegistry.resolve(programNumber: 47, trackName: 'Timpani Roll');
      expect(timpani.isNative, isFalse);
      expect(timpani.presetId, equals('soundfont_sampler'));
      expect(timpani.presetNum, equals(47.0));
    });

    test('Resolves Channel 10 / Drum channel to drum kit', () {
      final drums = GmInstrumentRegistry.resolve(programNumber: null, trackName: 'Beat', channel: 9);
      expect(drums.iconName, equals('drums'));
      expect(drums.matchReason, equals('gm_drum_channel'));
      expect(drums.trackType, equals(TrackType.sampler));
      expect(drums.bankNum, equals(128.0));
    });
  });

  group('DawState End-to-End MIDI Ingest with Native GM Routing', () {
    test('Imports multi-track MIDI file with mixed native and SoundFont instruments', () {
      final dawState = DawState();
      dawState.activePattern.tracks.clear();

      final midiBytes = _createMidiFileWithTracks(
        bpm: 128,
        tracks: [
          // Track 1: Acoustic Grand Piano (GM 0 -> Native)
          (name: 'Grand Piano', program: 0, channel: 0, notes: [60, 64, 67]),
          // Track 2: Solo Cello (GM 42 -> Native)
          (name: 'Solo Cello', program: 42, channel: 1, notes: [48, 55]),
          // Track 3: Church Organ (GM 19 -> SoundFont Fallback)
          (name: 'Church Organ Solo', program: 19, channel: 2, notes: [52, 55, 59]),
          // Track 4: Drums (Channel 10 -> GM Drums)
          (name: 'Drums', program: null, channel: 9, notes: [36, 38, 42]),
        ],
      );

      final success = dawState.importMidiFileBytes(midiBytes, fileName: 'Symphonic_Suite.mid');
      expect(success, isTrue);
      expect(dawState.bpm, equals(128.0));
      expect(dawState.activePattern.tracks.length, equals(4));

      final pianoTrack = dawState.activePattern.tracks[0];
      expect(pianoTrack.name, equals('Grand Piano'));
      expect(pianoTrack.iconName, equals('piano'));
      expect(pianoTrack.luaScriptCode, contains('ConcertGrandPiano'));

      final celloTrack = dawState.activePattern.tracks[1];
      expect(celloTrack.name, equals('Solo Cello'));
      expect(celloTrack.iconName, equals('strings'));
      expect(celloTrack.luaScriptCode, contains('SoloCello'));

      final organTrack = dawState.activePattern.tracks[2];
      expect(organTrack.name, equals('Church Organ Solo'));
      expect(organTrack.sampleName, equals('super_small_font.sf2'));
      expect(organTrack.luaParams['PresetNum'], equals(19.0));

      final drumTrack = dawState.activePattern.tracks[3];
      expect(drumTrack.iconName, equals('drums'));
      expect(drumTrack.type, equals(TrackType.sampler));
    });
  });
}
