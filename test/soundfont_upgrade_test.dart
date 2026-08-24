import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/audio/soundfont_decoder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TinySoundFont Upgraded SF2 Engine Tests', () {
    test('Sf2Zone holds correct generator & ADSR envelope values', () {
      final zone = Sf2Zone(
        sampleHeaderIdx: 0,
        minKey: 36,
        maxKey: 72,
        minVel: 10,
        maxVel: 120,
        rootKeyOverride: 60,
        coarseTune: 2,
        fineTune: 10,
        pan: -0.5,
        sampleModes: 1, // Looping
        startLoopOffset: 10,
        endLoopOffset: 20,
        volEnvAttack: 0.05,
        volEnvDecay: 0.2,
        volEnvSustain: 0.8,
        volEnvRelease: 0.3,
      );

      expect(zone.sampleHeaderIdx, equals(0));
      expect(zone.minKey, equals(36));
      expect(zone.maxKey, equals(72));
      expect(zone.sampleModes, equals(1));
      expect(zone.coarseTune, equals(2));
      expect(zone.fineTune, equals(10));
      expect(zone.volEnvSustain, equals(0.8));
    });

    test('SoundFontData & Sf2Zone find matching preset and zone', () {
      final sampleHeader = Sf2SampleHeader(
        name: 'Looping Pad',
        startSample: 0,
        endSample: 100,
        startLoop: 20,
        endLoop: 80,
        sampleRate: 44100,
        originalPitch: 60,
        pitchCorrection: 0,
        sampleType: 1,
      );

      final pcmData = Float32List.fromList(List<double>.generate(100, (i) => (i % 10) / 10.0));

      final zone = Sf2Zone(
        sampleHeaderIdx: 0,
        minKey: 0,
        maxKey: 127,
        minVel: 0,
        maxVel: 127,
        sampleModes: 1, // Continuous loop mode (TinySoundFont spec)
        rootKeyOverride: 60,
        volEnvAttack: 0.01,
        volEnvDecay: 0.05,
        volEnvSustain: 0.7,
        volEnvRelease: 0.05,
      );

      final preset = Sf2Preset(
        name: 'Pad Preset',
        presetNum: 0,
        bankNum: 0,
        zones: [zone],
      );

      final sfData = SoundFontData(
        fontName: 'Test Bank',
        pcmData: pcmData,
        sampleHeaders: [sampleHeader],
        presets: [preset],
      );

      final foundPreset = sfData.findPreset(0);
      expect(foundPreset, isNotNull);
      expect(foundPreset!.name, equals('Pad Preset'));

      final foundZone = sfData.findZone(foundPreset, 60, 64);
      expect(foundZone, isNotNull);
      expect(foundZone!.sampleModes, equals(1));
      expect(foundZone.sampleHeaderIdx, equals(0));
    });

    test('GeneralMidiNames formats bank and drum preset names correctly', () {
      expect(GeneralMidiNames.getPresetDisplayName(0, 0, 'Acoustic Grand Piano'), equals('000: Acoustic Grand Piano'));
      expect(GeneralMidiNames.getPresetDisplayName(0, 6, 'Harpsichord'), equals('006: Harpsichord'));
      expect(GeneralMidiNames.getPresetDisplayName(8, 6, 'Coupled Harpsichord'), equals('[Bank 8] 006: Coupled Harpsichord'));
      expect(GeneralMidiNames.getPresetDisplayName(128, 56, 'SFX Kit'), equals('[Drums] 056: SFX Kit'));
      expect(GeneralMidiNames.getPresetDisplayName(128, 0, ''), equals('[Drums] 000: Drum Kit'));
    });

    test('Multi-zone melodic instrument key split maps to correct sample zone', () {
      final lowZone = Sf2Zone(
        sampleHeaderIdx: 0,
        minKey: 0,
        maxKey: 47, // C0 to B2
        rootKeyOverride: 36,
      );
      final midZone = Sf2Zone(
        sampleHeaderIdx: 1,
        minKey: 48,
        maxKey: 71, // C3 to B4
        rootKeyOverride: 60,
      );
      final highZone = Sf2Zone(
        sampleHeaderIdx: 2,
        minKey: 72,
        maxKey: 127, // C5 to G9
        rootKeyOverride: 84,
      );

      final pianoPreset = Sf2Preset(
        name: 'Concert Grand',
        presetNum: 0,
        bankNum: 0,
        zones: [lowZone, midZone, highZone],
      );

      final sfData = SoundFontData(
        fontName: 'Concert Grand Bank',
        pcmData: Float32List(1),
        sampleHeaders: [],
        presets: [pianoPreset],
      );

      // Low note C2 (36) -> lowZone (sampleHeaderIdx: 0)
      final z1 = sfData.findZone(pianoPreset, 36);
      expect(z1, isNotNull);
      expect(z1!.sampleHeaderIdx, equals(0));

      // Middle C (60) -> midZone (sampleHeaderIdx: 1)
      final z2 = sfData.findZone(pianoPreset, 60);
      expect(z2, isNotNull);
      expect(z2!.sampleHeaderIdx, equals(1));

      // High note C6 (84) -> highZone (sampleHeaderIdx: 2)
      final z3 = sfData.findZone(pianoPreset, 84);
      expect(z3, isNotNull);
      expect(z3!.sampleHeaderIdx, equals(2));
    });
  });
}
