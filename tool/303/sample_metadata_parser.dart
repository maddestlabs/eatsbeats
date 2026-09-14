import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Parsed metadata describing how to synthesize a matching note for calibration.
class SampleMetadata {
  final String filename;
  final int midiNote;
  final double freq;
  final double durationSec;
  final bool isAccent;
  final bool isSlide;
  final int? targetMidiNote;
  final Map<String, double> params;

  SampleMetadata({
    required this.filename,
    required this.midiNote,
    required this.freq,
    required this.durationSec,
    required this.isAccent,
    required this.isSlide,
    this.targetMidiNote,
    required this.params,
  });

  static SampleMetadata parse(
    File wavFile, {
    double fallbackDuration = 0.5,
    Float32List? audio,
    int sampleRate = 44100,
  }) {
    final baseName = wavFile.uri.pathSegments.last;
    final jsonFile = File('${wavFile.path.replaceAll(RegExp(r'\.wav$', caseSensitive: false), '')}.json');

    // Detect active audible duration if audio is provided (trim trailing silence)
    double detectedDuration = fallbackDuration;
    int? acousticMidi;
    if (audio != null && audio.isNotEmpty) {
      int lastAudible = -1;
      for (int i = audio.length - 1; i >= 0; i--) {
        if (audio[i].abs() > 0.005) {
          lastAudible = i;
          break;
        }
      }
      if (lastAudible > 0) {
        // Add 50ms decay tail buffer
        final tailSamples = (sampleRate * 0.05).toInt();
        final activeSamples = math.min(audio.length, lastAudible + tailSamples);
        detectedDuration = math.max(0.1, activeSamples / sampleRate);
      }

      // Detect acoustic fundamental from first 2048 samples of active note
      acousticMidi = _detectFundamentalMidi(audio, sampleRate);
    }

    if (jsonFile.existsSync()) {
      try {
        final content = jsonDecode(jsonFile.readAsStringSync());
        final noteStr = content['note']?.toString() ?? 'C2';
        final midi = acousticMidi ?? _parseNoteToMidi(noteStr);
        final isAcc = content['isAccent'] == true;
        final isSld = content['isSlide'] == true;
        final dur = (content['durationSec'] as num?)?.toDouble() ?? detectedDuration;

        final rawParams = (content['params'] as Map<String, dynamic>?) ?? {};
        final Map<String, double> params = {};
        rawParams.forEach((k, v) {
          if (v is num) params[k] = v.toDouble();
        });

        final wave = content['waveform']?.toString().toLowerCase();
        if (wave == 'saw') params['Waveform'] = 0.0;
        if (wave == 'sqr' || wave == 'square') params['Waveform'] = 1.0;

        return SampleMetadata(
          filename: baseName,
          midiNote: midi,
          freq: midiToFreq(midi),
          durationSec: dur,
          isAccent: isAcc,
          isSlide: isSld,
          params: params,
        );
      } catch (_) {}
    }

    // Fallback: Parse filename tags
    final lower = baseName.toLowerCase();

    // 1. Waveform
    double waveform = 0.0;
    if (lower.contains('sqr') || lower.contains('square')) {
      waveform = 1.0;
    }

    // 2. Note Name (e.g., c2, c#2, db2, g1, 36)
    int midiNote = acousticMidi ?? 36;
    if (acousticMidi == null) {
      final noteMatch = RegExp(r'(?:^|[_\-\s])([a-g][#b]?[0-8])(?:[_\-\s]|$)', caseSensitive: false).firstMatch(baseName);
      if (noteMatch != null) {
        midiNote = _parseNoteToMidi(noteMatch.group(1)!);
      } else {
        final numNoteMatch = RegExp(r'note(\d+)', caseSensitive: false).firstMatch(baseName);
        if (numNoteMatch != null) {
          midiNote = int.tryParse(numNoteMatch.group(1)!) ?? 36;
        }
      }
    }

    // 3. Accent & Slide flags
    final bool isAccent = lower.contains('acc1') || lower.contains('accent') || lower.contains('acc_1');
    final bool isSlide = lower.contains('slide1') || lower.contains('slide') || lower.contains('portamento');

    // 4. Parameter tags
    final params = <String, double>{
      'Waveform': waveform,
      'Cutoff': 1600.0,
      'Resonance': 8.0,
      'EnvMod': 0.75,
      'Decay': 0.28,
      'Accent': isAccent ? 0.8 : 0.4,
      'Drive': 0.2,
    };

    // Parse cutoff e.g. cut50, cut0.5, cutoff80
    final cutMatch = RegExp(r'(?:cut|cutoff)(\d+(?:\.\d+)?)', caseSensitive: false).firstMatch(baseName);
    if (cutMatch != null) {
      final val = double.tryParse(cutMatch.group(1)!) ?? 50.0;
      params['Cutoff'] = val > 1.0 ? (val / 100.0).clamp(0.0, 1.0) : val.clamp(0.0, 1.0);
    }

    // Parse res e.g. res80, res0.8, reso90
    final resMatch = RegExp(r'(?:res|reso|resonance)(\d+(?:\.\d+)?)', caseSensitive: false).firstMatch(baseName);
    if (resMatch != null) {
      final val = double.tryParse(resMatch.group(1)!) ?? 50.0;
      params['Resonance'] = val > 1.0 ? (val / 100.0).clamp(0.0, 1.0) : val.clamp(0.0, 1.0);
    }

    // Parse env e.g. env70, envmod0.8
    final envMatch = RegExp(r'(?:env|envmod)(\d+(?:\.\d+)?)', caseSensitive: false).firstMatch(baseName);
    if (envMatch != null) {
      final val = double.tryParse(envMatch.group(1)!) ?? 75.0;
      params['EnvMod'] = val > 1.0 ? (val / 100.0).clamp(0.0, 1.0) : val.clamp(0.0, 1.0);
    }

    // Parse decay e.g. dec30, decay0.4
    final decMatch = RegExp(r'(?:dec|decay)(\d+(?:\.\d+)?)', caseSensitive: false).firstMatch(baseName);
    if (decMatch != null) {
      final val = double.tryParse(decMatch.group(1)!) ?? 28.0;
      params['Decay'] = val > 1.0 ? (val / 100.0).clamp(0.0, 1.0) : val.clamp(0.0, 1.0);
    }

    return SampleMetadata(
      filename: baseName,
      midiNote: midiNote,
      freq: midiToFreq(midiNote),
      durationSec: detectedDuration,
      isAccent: isAccent,
      isSlide: isSlide,
      params: params,
    );
  }

  static int? _detectFundamentalMidi(Float32List audio, int sampleRate) {
    final size = math.min(4096, audio.length);
    if (size < 512) return null;

    int start = 0;
    while (start < audio.length - size && audio[start].abs() < 0.01) {
      start++;
    }

    double maxMag = 0.0;
    int bestK = -1;
    final minK = (30.0 * size / sampleRate).toInt().clamp(1, size ~/ 2);
    final maxK = (1000.0 * size / sampleRate).toInt().clamp(minK, size ~/ 2);

    for (int k = minK; k <= maxK; k++) {
      double r = 0.0, im = 0.0;
      final w = 2.0 * math.pi * k / size;
      for (int n = 0; n < size; n++) {
        final s = audio[start + n];
        r += s * math.cos(w * n);
        im -= s * math.sin(w * n);
      }
      final mag = r * r + im * im;
      if (mag > maxMag) {
        maxMag = mag;
        bestK = k;
      }
    }

    if (bestK > 0) {
      final freq = bestK * sampleRate / size;
      return (12.0 * math.log(freq / 440.0) / math.ln2 + 69.0).round();
    }
    return null;
  }

  static double midiToFreq(int midi) {
    return 440.0 * math.pow(2.0, (midi - 69) / 12.0);
  }

  static int _parseNoteToMidi(String noteStr) {
    final clean = noteStr.trim().toUpperCase();
    final match = RegExp(r'^([A-G])([#B]?)(-?\d+)$').firstMatch(clean);
    if (match == null) return 36;

    final step = match.group(1)!;
    final accidental = match.group(2)!;
    final octave = int.tryParse(match.group(3)!) ?? 2;

    int semitone = switch (step) {
      'C' => 0,
      'D' => 2,
      'E' => 4,
      'F' => 5,
      'G' => 7,
      'A' => 9,
      'B' => 11,
      _ => 0,
    };

    if (accidental == '#' || accidental == 'S') {
      semitone += 1;
    } else if (accidental == 'B') {
      semitone -= 1;
    }

    // MIDI 12 is C0 (or 24 depending on notation, standard 60 is C4 -> octave + 1)
    return (octave + 1) * 12 + semitone;
  }
}
