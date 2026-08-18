import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

class Sf2SampleHeader {
  final String name;
  final int startSample;
  final int endSample;
  final int startLoop;
  final int endLoop;
  final int sampleRate;
  final int originalPitch;
  final int pitchCorrection;
  final int sampleType;

  Sf2SampleHeader({
    required this.name,
    required this.startSample,
    required this.endSample,
    required this.startLoop,
    required this.endLoop,
    required this.sampleRate,
    required this.originalPitch,
    required this.pitchCorrection,
    required this.sampleType,
  });
}

class Sf2Preset {
  final String name;
  final int presetNum;
  final int bankNum;
  final List<Sf2Zone> zones;

  Sf2Preset({
    required this.name,
    required this.presetNum,
    required this.bankNum,
    required this.zones,
  });
}

class Sf2Zone {
  final int minKey;
  final int maxKey;
  final int minVel;
  final int maxVel;
  final int sampleHeaderIdx;
  final int? rootKeyOverride;
  final int coarseTune;
  final int fineTune;
  final double pan;
  final int sampleModes;
  final int startLoopOffset;
  final int endLoopOffset;
  final double volEnvDelay;
  final double volEnvAttack;
  final double volEnvHold;
  final double volEnvDecay;
  final double volEnvSustain;
  final double volEnvRelease;

  Sf2Zone({
    this.minKey = 0,
    this.maxKey = 127,
    this.minVel = 0,
    this.maxVel = 127,
    required this.sampleHeaderIdx,
    this.rootKeyOverride,
    this.coarseTune = 0,
    this.fineTune = 0,
    this.pan = 0.0,
    this.sampleModes = 0,
    this.startLoopOffset = 0,
    this.endLoopOffset = 0,
    this.volEnvDelay = 0.0,
    this.volEnvAttack = 0.001,
    this.volEnvHold = 0.0,
    this.volEnvDecay = 0.0,
    this.volEnvSustain = 1.0,
    this.volEnvRelease = 0.1,
  });
}

class GeneralMidiNames {
  static const List<String> melodicInstruments = [
    "000: Acoustic Grand Piano", "001: Bright Acoustic Piano", "002: Electric Grand Piano", "003: Honky-tonk Piano",
    "004: Electric Piano 1", "005: Electric Piano 2", "006: Harpsichord", "007: Clavinet",
    "008: Celesta", "009: Glockenspiel", "010: Music Box", "011: Vibraphone",
    "012: Marimba", "013: Xylophone", "014: Tubular Bells", "015: Dulcimer",
    "016: Drawbar Organ", "017: Percussive Organ", "018: Rock Organ", "019: Church Organ",
    "020: Reed Organ", "021: Accordion", "022: Harmonica", "023: Tango Accordion",
    "024: Acoustic Guitar (Nylon)", "025: Acoustic Guitar (Steel)", "026: Electric Guitar (Jazz)", "027: Electric Guitar (Clean)",
    "028: Electric Guitar (Muted)", "029: Overdriven Guitar", "030: Distortion Guitar", "031: Guitar Harmonics",
    "032: Acoustic Bass", "033: Electric Bass (Finger)", "034: Electric Bass (Pick)", "035: Fretless Bass",
    "036: Slap Bass 1", "037: Slap Bass 2", "038: Synth Bass 1", "039: Synth Bass 2",
    "040: Violin", "041: Viola", "042: Cello", "043: Contrabass",
    "044: Tremolo Strings", "045: Pizzicato Strings", "046: Orchestral Harp", "047: Timpani",
    "048: String Ensemble 1", "049: String Ensemble 2", "050: Synth Strings 1", "051: Synth Strings 2",
    "052: Choir Aahs", "053: Voice Oohs", "054: Synth Choir", "055: Orchestra Hit",
    "056: Trumpet", "057: Trombone", "058: Tuba", "059: Muted Trumpet",
    "060: French Horn", "061: Brass Section", "062: Synth Brass 1", "063: Synth Brass 2",
    "064: Soprano Sax", "065: Alto Sax", "066: Tenor Sax", "067: Baritone Sax",
    "068: Oboe", "069: English Horn", "070: Bassoon", "071: Clarinet",
    "072: Piccolo", "073: Flute", "074: Recorder", "075: Pan Flute",
    "076: Blown Bottle", "077: Shakuhachi", "078: Whistle", "079: Ocarina",
    "080: Lead 1 (Square)", "081: Lead 2 (Sawtooth)", "082: Lead 3 (Calliope)", "083: Lead 4 (Chiff)",
    "084: Lead 5 (Charang)", "085: Lead 6 (Voice)", "086: Lead 7 (Fifths)", "087: Lead 8 (Bass + Lead)",
    "088: Pad 1 (New Age)", "089: Pad 2 (Warm)", "090: Pad 3 (Polysynth)", "091: Pad 4 (Choir)",
    "092: Pad 5 (Bowed)", "093: Pad 6 (Metallic)", "094: Pad 7 (Halo)", "095: Pad 8 (Sweep)",
    "096: FX 1 (Rain)", "097: FX 2 (Soundtrack)", "098: FX 3 (Crystal)", "099: FX 4 (Atmosphere)",
    "100: FX 5 (Brightness)", "101: FX 6 (Goblins)", "102: FX 7 (Echoes)", "103: FX 8 (Sci-Fi)",
    "104: Sitar", "105: Banjo", "106: Shamisen", "107: Koto",
    "108: Kalimba", "109: Bagpipe", "110: Fiddle", "111: Shanai",
    "112: Tinkle Bell", "113: Agogo", "114: Steel Drums", "115: Woodblock",
    "116: Taiko Drum", "117: Melodic Tom", "118: Synth Drum", "119: Reverse Cymbal",
    "120: Guitar Fret Noise", "121: Breath Noise", "122: Seashore", "123: Bird Tweet",
    "124: Telephone Ring", "125: Helicopter", "126: Applause", "127: Gunshot"
  ];

  static String getPresetDisplayName(int bankNum, int presetNum, String sf2Name) {
    final progStr = presetNum.toString().padLeft(3, '0');
    final hasCustomName = sf2Name.isNotEmpty && sf2Name != 'Untitled';

    if (bankNum == 128 || bankNum == 127) {
      final drumName = hasCustomName ? sf2Name : 'Drum Kit';
      return "[Drums] $progStr: $drumName";
    }

    if (bankNum > 0) {
      final nameStr = hasCustomName
          ? sf2Name
          : (presetNum >= 0 && presetNum < melodicInstruments.length
              ? melodicInstruments[presetNum].replaceFirst(RegExp(r'^\d+:\s*'), '')
              : 'Program $presetNum');
      return "[Bank $bankNum] $progStr: $nameStr";
    }

    if (hasCustomName) {
      return "$progStr: $sf2Name";
    }
    if (presetNum >= 0 && presetNum < melodicInstruments.length) {
      return melodicInstruments[presetNum];
    }
    return "$progStr: Program $presetNum";
  }
}

class SoundFontData {
  final String fontName;
  final List<double> pcmData;
  final List<Sf2SampleHeader> sampleHeaders;
  final List<Sf2Preset> presets;

  SoundFontData({
    required this.fontName,
    required this.pcmData,
    required this.sampleHeaders,
    required this.presets,
  });

  Sf2Preset? findPreset(int presetNum, [int bankNum = -1]) {
    if (bankNum >= 0) {
      for (final p in presets) {
        if (p.presetNum == presetNum && p.bankNum == bankNum) {
          return p;
        }
      }
    }
    for (final p in presets) {
      if (p.presetNum == presetNum) {
        return p;
      }
    }
    return presets.isNotEmpty ? presets.first : null;
  }

  Sf2Zone? findZone(Sf2Preset preset, int midiNote, [int velocity = 64]) {
    for (final z in preset.zones) {
      if (midiNote >= z.minKey && midiNote <= z.maxKey && velocity >= z.minVel && velocity <= z.maxVel) {
        return z;
      }
    }
    return preset.zones.isNotEmpty ? preset.zones.first : null;
  }
}

class SoundFontDecoder {
  static SoundFontData? decode(Uint8List bytes) {
    if (bytes.length < 12) return null;

    final byteData = ByteData.sublistView(bytes);

    final magicRiff = String.fromCharCodes(bytes.sublist(0, 4)).toUpperCase();
    final magicSfbk = String.fromCharCodes(bytes.sublist(8, 12)).toUpperCase();

    if (magicRiff != 'RIFF' || magicSfbk != 'SFBK') {
      debugPrint('SoundFontDecoder: Invalid SF2 magic header ($magicRiff / $magicSfbk)');
      return null;
    }

    String fontName = 'SoundFont Bank';
    List<double> pcmData = [];
    List<Sf2SampleHeader> sampleHeaders = [];
    List<Sf2Preset> presets = [];

    int offset = 12;
    int sdtaOffset = -1;
    int sdtaLength = 0;
    int pdtaOffset = -1;

    while (offset + 8 <= bytes.length) {
      final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4)).toUpperCase();
      final chunkSize = byteData.getUint32(offset + 4, Endian.little);

      if (chunkId == 'LIST' && offset + 12 <= bytes.length) {
        final listType = String.fromCharCodes(bytes.sublist(offset + 8, offset + 12)).toLowerCase();
        if (listType == 'sdta') {
          sdtaOffset = offset + 12;
          sdtaLength = chunkSize - 4;
        } else if (listType == 'pdta') {
          pdtaOffset = offset + 12;
        }
      }

      offset += 8 + chunkSize;
      if (chunkSize % 2 != 0) offset++;
    }

    // 1. Decode PCM samples from sdta/smpl chunk
    if (sdtaOffset != -1) {
      int smplPos = sdtaOffset;
      while (smplPos + 8 <= sdtaOffset + sdtaLength && smplPos + 8 <= bytes.length) {
        final subId = String.fromCharCodes(bytes.sublist(smplPos, smplPos + 4));
        final subSize = byteData.getUint32(smplPos + 4, Endian.little);

        if (subId == 'smpl') {
          final sampleDataStart = smplPos + 8;
          final int16Count = subSize ~/ 2;
          pcmData = List<double>.filled(int16Count, 0.0);

          for (int i = 0; i < int16Count; i++) {
            final p = sampleDataStart + i * 2;
            if (p + 1 < bytes.length) {
              final val = byteData.getInt16(p, Endian.little);
              pcmData[i] = val / 32768.0;
            }
          }
          break;
        }
        smplPos += 8 + subSize;
        if (subSize % 2 != 0) smplPos++;
      }
    }

    // 2. Decode Preset & Generator Data from pdta chunk
    if (pdtaOffset != -1) {
      int pPos = pdtaOffset;
      final pdtaEnd = bytes.length;

      final rawSampleHeaders = <Sf2SampleHeader>[];
      final rawPresets = <Map<String, dynamic>>[];
      final rawPresetBags = <int>[];
      final rawPresetGens = <Map<String, int>>[];

      final rawInsts = <Map<String, dynamic>>[];
      final rawInstBags = <int>[];
      final rawInstGens = <Map<String, int>>[];

      while (pPos + 8 <= pdtaEnd) {
        final subId = String.fromCharCodes(bytes.sublist(pPos, pPos + 4));
        final subSize = byteData.getUint32(pPos + 4, Endian.little);
        final dataStart = pPos + 8;

        if (dataStart + subSize > bytes.length) break;

        if (subId == 'shdr') {
          final count = subSize ~/ 46;
          for (int i = 0; i < count; i++) {
            final b = dataStart + i * 46;
            final name = _readString(bytes, b, 20);
            final startSample = byteData.getUint32(b + 20, Endian.little);
            final endSample = byteData.getUint32(b + 24, Endian.little);
            final startLoop = byteData.getUint32(b + 28, Endian.little);
            final endLoop = byteData.getUint32(b + 32, Endian.little);
            final sampleRate = byteData.getUint32(b + 36, Endian.little);
            final origPitch = bytes[b + 40];
            final pitchCorr = byteData.getInt8(b + 41);
            final sampleType = byteData.getUint16(b + 44, Endian.little);

            rawSampleHeaders.add(Sf2SampleHeader(
              name: name,
              startSample: startSample,
              endSample: endSample,
              startLoop: startLoop,
              endLoop: endLoop,
              sampleRate: sampleRate,
              originalPitch: origPitch,
              pitchCorrection: pitchCorr,
              sampleType: sampleType,
            ));
          }
        } else if (subId == 'phdr') {
          final count = subSize ~/ 38;
          for (int i = 0; i < count; i++) {
            final b = dataStart + i * 38;
            final name = _readString(bytes, b, 20);
            final presetNum = byteData.getUint16(b + 20, Endian.little);
            final bankNum = byteData.getUint16(b + 22, Endian.little);
            final bagIdx = byteData.getUint16(b + 24, Endian.little);

            rawPresets.add({
              'name': name,
              'presetNum': presetNum,
              'bankNum': bankNum,
              'bagIdx': bagIdx,
            });
          }
        } else if (subId == 'pbag') {
          final count = subSize ~/ 4;
          for (int i = 0; i < count; i++) {
            final b = dataStart + i * 4;
            final genIdx = byteData.getUint16(b, Endian.little);
            rawPresetBags.add(genIdx);
          }
        } else if (subId == 'pgen') {
          final count = subSize ~/ 4;
          for (int i = 0; i < count; i++) {
            final b = dataStart + i * 4;
            final genId = byteData.getUint16(b, Endian.little);
            final genVal = byteData.getInt16(b + 2, Endian.little);
            rawPresetGens.add({'genId': genId, 'val': genVal});
          }
        } else if (subId == 'inst') {
          final count = subSize ~/ 22;
          for (int i = 0; i < count; i++) {
            final b = dataStart + i * 22;
            final name = _readString(bytes, b, 20);
            final bagIdx = byteData.getUint16(b + 20, Endian.little);
            rawInsts.add({'name': name, 'bagIdx': bagIdx});
          }
        } else if (subId == 'ibag') {
          final count = subSize ~/ 4;
          for (int i = 0; i < count; i++) {
            final b = dataStart + i * 4;
            final genIdx = byteData.getUint16(b, Endian.little);
            rawInstBags.add(genIdx);
          }
        } else if (subId == 'igen') {
          final count = subSize ~/ 4;
          for (int i = 0; i < count; i++) {
            final b = dataStart + i * 4;
            final genId = byteData.getUint16(b, Endian.little);
            final genVal = byteData.getInt16(b + 2, Endian.little);
            rawInstGens.add({'genId': genId, 'val': genVal});
          }
        }

        pPos += 8 + subSize;
        if (subSize % 2 != 0) pPos++;
      }

      sampleHeaders = rawSampleHeaders;

      // 3. Assemble Presets & Zones from SoundFont Generator hierarchy (SoundFont 2.04 spec)
      for (int i = 0; i < rawPresets.length - 1; i++) {
        final p = rawPresets[i];
        final name = p['name'] as String;
        final presetNum = p['presetNum'] as int;
        final bankNum = p['bankNum'] as int;
        final pBagStart = p['bagIdx'] as int;
        final pBagEnd = (i + 1 < rawPresets.length) ? (rawPresets[i + 1]['bagIdx'] as int) : rawPresetBags.length - 1;

        final zones = <Sf2Zone>[];
        final globalPresetGens = <int, int>{};

        for (int pBagIdx = pBagStart; pBagIdx < pBagEnd && pBagIdx < rawPresetBags.length - 1; pBagIdx++) {
          final pGenStart = rawPresetBags[pBagIdx];
          final pGenEnd = rawPresetBags[pBagIdx + 1];

          final pgenMap = <int, int>{};
          for (int g = pGenStart; g < pGenEnd && g < rawPresetGens.length; g++) {
            pgenMap[rawPresetGens[g]['genId']!] = rawPresetGens[g]['val']!;
          }

          // If no instrument operator (genId 41), treat as global preset generator zone
          if (!pgenMap.containsKey(41)) {
            globalPresetGens.addAll(pgenMap);
            continue;
          }

          // Effective preset-level generators (global preset gens overlaid by local preset zone gens)
          final effectivePresetGens = <int, int>{}
            ..addAll(globalPresetGens)
            ..addAll(pgenMap);

          // Parse Preset-level key and velocity range constraints (default 0..127)
          int pMinKey = 0, pMaxKey = 127;
          if (effectivePresetGens.containsKey(43)) {
            final val = effectivePresetGens[43]!;
            pMinKey = val & 0xFF;
            pMaxKey = (val >> 8) & 0xFF;
          }

          int pMinVel = 0, pMaxVel = 127;
          if (effectivePresetGens.containsKey(44)) {
            final val = effectivePresetGens[44]!;
            pMinVel = val & 0xFF;
            pMaxVel = (val >> 8) & 0xFF;
          }

          final instIdx = pgenMap[41]!;
          if (instIdx >= 0 && instIdx < rawInsts.length - 1) {
            final inst = rawInsts[instIdx];
            final iBagStart = inst['bagIdx'] as int;
            final iBagEnd = (instIdx + 1 < rawInsts.length) ? (rawInsts[instIdx + 1]['bagIdx'] as int) : rawInstBags.length - 1;

            final globalInstGens = <int, int>{};

            for (int iBagIdx = iBagStart; iBagIdx < iBagEnd && iBagIdx < rawInstBags.length - 1; iBagIdx++) {
              final iGenStart = rawInstBags[iBagIdx];
              final iGenEnd = rawInstBags[iBagIdx + 1];

              final igenMap = <int, int>{};
              for (int g = iGenStart; g < iGenEnd && g < rawInstGens.length; g++) {
                igenMap[rawInstGens[g]['genId']!] = rawInstGens[g]['val']!;
              }

              // If no sampleID operator (genId 53), treat as global instrument generator zone
              if (!igenMap.containsKey(53)) {
                globalInstGens.addAll(igenMap);
                continue;
              }

              final sampleHeaderIdx = igenMap[53]!;
              if (sampleHeaderIdx < 0 || sampleHeaderIdx >= sampleHeaders.length) continue;

              // Effective instrument-level generators (global inst gens overlaid by local inst zone gens)
              final effectiveInstGens = <int, int>{}
                ..addAll(globalInstGens)
                ..addAll(igenMap);

              // Parse Instrument-level key and velocity range constraints (default 0..127)
              int iMinKey = 0, iMaxKey = 127;
              if (effectiveInstGens.containsKey(43)) {
                final val = effectiveInstGens[43]!;
                iMinKey = val & 0xFF;
                iMaxKey = (val >> 8) & 0xFF;
              }

              int iMinVel = 0, iMaxVel = 127;
              if (effectiveInstGens.containsKey(44)) {
                final val = effectiveInstGens[44]!;
                iMinVel = val & 0xFF;
                iMaxVel = (val >> 8) & 0xFF;
              }

              // SoundFont 2.04 spec: Effective zone range is intersection of Preset and Instrument ranges
              final minKey = math.max(pMinKey, iMinKey);
              final maxKey = math.min(pMaxKey, iMaxKey);
              if (minKey > maxKey) continue; // Skip non-overlapping zone

              final minVel = math.max(pMinVel, iMinVel);
              final maxVel = math.min(pMaxVel, iMaxVel);
              if (minVel > maxVel) continue; // Skip non-overlapping velocity range

              // Tuning & Offsets combine additively
              final coarseTune = (effectiveInstGens[51] ?? 0) + (effectivePresetGens[51] ?? 0);
              final fineTune = (effectiveInstGens[52] ?? 0) + (effectivePresetGens[52] ?? 0);

              // Overriding Root Key (gen 58): Local inst overrides global inst, then preset
              final rootKeyVal = effectiveInstGens[58] ?? effectivePresetGens[58];
              final rootKeyOverride = (rootKeyVal != null && rootKeyVal > 0) ? rootKeyVal : null;

              // Pan (gen 17): pan amounts add together
              final instPan = effectiveInstGens.containsKey(17) ? (effectiveInstGens[17]! / 500.0) : 0.0;
              final presetPan = effectivePresetGens.containsKey(17) ? (effectivePresetGens[17]! / 500.0) : 0.0;
              final pan = (instPan + presetPan).clamp(-1.0, 1.0);

              // Sample loop mode is defined at instrument level (gen 54)
              final sampleModes = effectiveInstGens[54] ?? 0;

              // Loop address offsets
              final startLoopOffset = (effectiveInstGens[2] ?? 0) + ((effectiveInstGens[45] ?? 0) * 32768);
              final endLoopOffset = (effectiveInstGens[3] ?? 0) + ((effectiveInstGens[50] ?? 0) * 32768);

              // SoundFont 2.04 Volume Envelope generators (gen 33..38):
              // 33: delayVolEnv, 34: attackVolEnv, 35: holdVolEnv, 36: decayVolEnv, 37: sustainVolEnv, 38: releaseVolEnv
              final delayVal = (effectiveInstGens[33] ?? -32768) + (effectivePresetGens[33] ?? 0);
              final attackVal = (effectiveInstGens[34] ?? -32768) + (effectivePresetGens[34] ?? 0);
              final holdVal = (effectiveInstGens[35] ?? -32768) + (effectivePresetGens[35] ?? 0);
              final decayVal = (effectiveInstGens[36] ?? -32768) + (effectivePresetGens[36] ?? 0);
              final sustainVal = (effectiveInstGens[37] ?? 0) + (effectivePresetGens[37] ?? 0);
              final releaseVal = (effectiveInstGens[38] ?? -32768) + (effectivePresetGens[38] ?? 0);

              final volEnvDelay = _timecentsToSeconds(delayVal);
              final volEnvAttack = math.max(0.001, _timecentsToSeconds(attackVal));
              final volEnvHold = _timecentsToSeconds(holdVal);
              final volEnvDecay = math.max(0.001, _timecentsToSeconds(decayVal));
              final volEnvSustain = _cbToGain(sustainVal);
              final volEnvRelease = math.max(0.01, _timecentsToSeconds(releaseVal));

              zones.add(Sf2Zone(
                minKey: minKey,
                maxKey: maxKey,
                minVel: minVel,
                maxVel: maxVel,
                sampleHeaderIdx: sampleHeaderIdx,
                rootKeyOverride: rootKeyOverride,
                coarseTune: coarseTune,
                fineTune: fineTune,
                pan: pan,
                sampleModes: sampleModes,
                startLoopOffset: startLoopOffset,
                endLoopOffset: endLoopOffset,
                volEnvDelay: volEnvDelay,
                volEnvAttack: volEnvAttack,
                volEnvHold: volEnvHold,
                volEnvDecay: volEnvDecay,
                volEnvSustain: volEnvSustain,
                volEnvRelease: volEnvRelease,
              ));
            }
          }
        }

        // Fallback zone assignment if generator hierarchy was missing
        if (zones.isEmpty) {
          for (int sampleIdx = 0; sampleIdx < sampleHeaders.length; sampleIdx++) {
            final sh = sampleHeaders[sampleIdx];
            if (sh.endSample > sh.startSample && sh.startSample < pcmData.length) {
              zones.add(Sf2Zone(
                minKey: 0,
                maxKey: 127,
                minVel: 0,
                maxVel: 127,
                sampleHeaderIdx: sampleIdx,
                rootKeyOverride: sh.originalPitch > 0 ? sh.originalPitch : 60,
              ));
            }
          }
        }

        presets.add(Sf2Preset(
          name: name,
          presetNum: presetNum,
          bankNum: bankNum,
          zones: zones,
        ));
      }
    }

    // Sort presets systematically by Bank then Preset number (e.g. Bank 0 -> GS Variations -> Drum Bank 128)
    presets.sort((a, b) {
      final cmp = a.bankNum.compareTo(b.bankNum);
      if (cmp != 0) return cmp;
      return a.presetNum.compareTo(b.presetNum);
    });

    if (presets.isNotEmpty) {
      fontName = presets.first.name;
    }

    return SoundFontData(
      fontName: fontName,
      pcmData: pcmData,
      sampleHeaders: sampleHeaders,
      presets: presets,
    );
  }

  static double _timecentsToSeconds(int timecents) {
    if (timecents == -32768 || timecents <= -12000) return 0.0;
    return math.pow(2.0, timecents / 1200.0).toDouble();
  }

  static double _cbToGain(int cb) {
    if (cb <= 0) return 1.0;
    if (cb >= 1000) return 0.0;
    return math.pow(10.0, -cb / 200.0).toDouble();
  }

  static String _readString(Uint8List bytes, int offset, int length) {
    final sub = bytes.sublist(offset, math.min(offset + length, bytes.length));
    final nullIdx = sub.indexOf(0);
    final validBytes = nullIdx != -1 ? sub.sublist(0, nullIdx) : sub;
    return ascii.decode(validBytes, allowInvalid: true).trim();
  }
}


