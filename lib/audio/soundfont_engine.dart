import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'sampler_engine.dart';
import 'soundfont_decoder.dart';

class SoundFontEngine extends ChangeNotifier {
  static final SoundFontEngine instance = SoundFontEngine._internal();
  SoundFontEngine._internal();

  final Map<String, SoundFontData> _loadedFonts = {};
  final Map<String, String> _availablePacks = {};

  Map<String, SoundFontData> get loadedFonts => Map.unmodifiable(_loadedFonts);

  /// Registers an available (cached or discovered) pack so it shows up in UI menus without eagerly decoding.
  void registerAvailablePack(String fontId, String displayName) {
    _availablePacks[fontId] = displayName;
    notifyListeners();
  }

  /// Returns a clean map of primary Font IDs to human-friendly display names.
  Map<String, String> get loadedDisplayFonts {
    final result = <String, String>{..._availablePacks};
    for (final entry in _loadedFonts.entries) {
      final key = entry.key;
      // Skip alias keys like 'default.sf2', or non-.sf2 keys to avoid duplicates
      if (key == 'default.sf2') continue;
      if (!key.endsWith('.sf2')) continue;

      String name;
      final lowerKey = key.toLowerCase();
      if (lowerKey.contains('super_small')) {
        name = 'Super Small Font';
      } else if (lowerKey.contains('generaluser')) {
        name = 'GeneralUser GS';
      } else {
        name = entry.value.fontName.isNotEmpty && entry.value.fontName != 'SoundFont Bank'
            ? entry.value.fontName
            : key.replaceAll('.sf2', '').replaceAll('_', ' ');
      }
      result[key] = name;
    }
    return result;
  }

  /// Registers a `.sf2` SoundFont binary buffer.
  bool registerSoundFont(String fontId, Uint8List sf2Bytes) {
    try {
      final decoded = SoundFontDecoder.decode(sf2Bytes);
      if (decoded != null && decoded.sampleHeaders.isNotEmpty) {
        _loadedFonts[fontId] = decoded;
        _loadedFonts[fontId.replaceAll('\\', '/').split('/').last] = decoded;

        // Also register sample overview for visual waveform rendering
        if (decoded.pcmData.isNotEmpty) {
          SamplerEngine.instance.registerSampleBytes(
            fontId,
            Uint8List(0),
          );
        }

        debugPrint('SoundFontEngine: Loaded SF2 bank "$fontId" with ${decoded.presets.length} presets & ${decoded.sampleHeaders.length} samples.');
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('SoundFontEngine error decoding $fontId: $e');
    }
    return false;
  }

  /// Unloads a specific SoundFont from memory to free RAM.
  void unloadSoundFont(String fontId) {
    final cleanId = fontId.replaceAll('\\', '/').split('/').last;
    _loadedFonts.remove(fontId);
    _loadedFonts.remove(cleanId);
    if (fontId.toLowerCase().contains('generaluser') || cleanId.toLowerCase().contains('generaluser')) {
      _loadedFonts.remove('GeneralUser GS');
      _loadedFonts.remove('GeneralUser');
      _loadedFonts.remove('GeneralUser_GS.sf2');
    }
    debugPrint('SoundFontEngine: Unloaded SoundFont "$fontId" from memory.');
    notifyListeners();
  }

  /// Clears all loaded SoundFonts (except bundled fallback) from memory.
  void clearLoadedSoundFonts() {
    final fallback = _loadedFonts['default.sf2'];
    _loadedFonts.clear();
    if (fallback != null) {
      _loadedFonts['default.sf2'] = fallback;
      _loadedFonts['super_small_font.sf2'] = fallback;
      _loadedFonts['Super Small Font'] = fallback;
    }
    notifyListeners();
  }

  /// Asynchronously loads the core bundled fallback SoundFont from Flutter assets ('assets/soundfonts/super_small_font.sf2').
  Future<bool> loadDefaultBundledFont() async {
    if (_loadedFonts.containsKey('super_small_font.sf2') ||
        _loadedFonts.containsKey('default.sf2')) {
      return true;
    }
    try {
      final ByteData data = await rootBundle.load('assets/soundfonts/super_small_font.sf2');
      final Uint8List bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final bool loaded = registerSoundFont('super_small_font.sf2', bytes);
      if (loaded) {
        final defaultData = getSoundFont('super_small_font.sf2');
        if (defaultData != null) {
          _loadedFonts['default.sf2'] = defaultData;
          _loadedFonts['Super Small Font'] = defaultData;
        }
      }
      return loaded;
    } catch (e) {
      debugPrint('SoundFontEngine: Failed to load bundled default SoundFont: $e');
      return false;
    }
  }

  /// Retrieves a loaded SoundFont by ID or path.
  SoundFontData? getSoundFont(String fontId, {bool fallbackDefault = false}) {
    if (fontId.isNotEmpty) {
      final cleanId = fontId.replaceAll('\\', '/').split('/').last;
      final found = _loadedFonts[fontId] ?? _loadedFonts[cleanId];
      if (found != null) return found;
      if (fontId.toLowerCase().endsWith('.sf2')) return _loadedFonts['default.sf2'];
    }
    return fallbackDefault ? _loadedFonts['default.sf2'] : null;
  }

  /// Resamples and pitch-shifts matching SoundFont key-zone for a given MIDI note & preset.
  /// Features TinySoundFont-inspired continuous sample looping, coarse/fine tuning, and ADSR volume envelopes.
  List<double> getPitchShiftedBuffer({
    required String fontId,
    required int presetNum,
    int bankNum = 0,
    required int midiNote,
    double velocity = 0.9,
    double targetDurationSec = 0.8,
    bool fallbackDefault = false,
  }) {
    final font = getSoundFont(fontId, fallbackDefault: fallbackDefault);
    if (font == null || font.pcmData.isEmpty || font.presets.isEmpty) {
      return const [];
    }

    final preset = font.findPreset(presetNum, bankNum);
    if (preset == null) return const [];

    final zone = font.findZone(preset, midiNote, (velocity * 127).round());
    if (zone == null) return const [];

    if (zone.sampleHeaderIdx < 0 || zone.sampleHeaderIdx >= font.sampleHeaders.length) {
      return const [];
    }

    final sampleHeader = font.sampleHeaders[zone.sampleHeaderIdx];
    final startIdx = sampleHeader.startSample.clamp(0, font.pcmData.length - 1);
    final endIdx = sampleHeader.endSample.clamp(startIdx, font.pcmData.length);

    if (startIdx >= endIdx) return const [];

    final rootKey = zone.rootKeyOverride ?? (sampleHeader.originalPitch > 0 ? sampleHeader.originalPitch : 60);
    final totalCents = (midiNote - rootKey) * 100.0 + (zone.coarseTune * 100.0) + zone.fineTune + sampleHeader.pitchCorrection;
    final playbackRate = math.pow(2.0, totalCents / 1200.0).toDouble();

    final bool isLooping = (zone.sampleModes == 1 || zone.sampleModes == 3) &&
        sampleHeader.endLoop > sampleHeader.startLoop &&
        sampleHeader.startLoop >= sampleHeader.startSample &&
        sampleHeader.endLoop <= sampleHeader.endSample;

    final startLoop = (sampleHeader.startLoop + zone.startLoopOffset).clamp(startIdx, endIdx);
    final endLoop = (sampleHeader.endLoop + zone.endLoopOffset).clamp(startLoop, endIdx);
    final loopLength = endLoop - startLoop;

    final double totalSec = targetDurationSec + zone.volEnvRelease;
    final int targetSampleCount = isLooping
        ? (44100 * totalSec).round().clamp(500, 44100 * 5)
        : ((endIdx - startIdx) / playbackRate).round().clamp(100, 44100 * 5);

    final result = List<double>.filled(targetSampleCount, 0.0);
    double srcIndex = startIdx.toDouble();

    for (int i = 0; i < targetSampleCount; i++) {
      if (isLooping && loopLength > 0 && srcIndex >= endLoop) {
        srcIndex = startLoop + ((srcIndex - startLoop) % loopLength);
      }

      final idx0 = srcIndex.floor();
      final idx1 = (idx0 + 1).clamp(0, font.pcmData.length - 1);
      final frac = srcIndex - idx0;

      double sampleVal = 0.0;
      if (idx0 >= font.pcmData.length - 1) {
        sampleVal = font.pcmData.last;
      } else {
        sampleVal = (1.0 - frac) * font.pcmData[idx0] + frac * font.pcmData[idx1];
      }

      // Calculate ADSR Volume Envelope curve (TinySoundFont spec)
      final double t = i / 44100.0;
      double envGain = 1.0;

      final double delayT = zone.volEnvDelay;
      final double attackT = delayT + zone.volEnvAttack;
      final double holdT = attackT + zone.volEnvHold;
      final double decayT = holdT + zone.volEnvDecay;
      final double releaseStartT = targetDurationSec;

      if (t < delayT) {
        envGain = 0.0;
      } else if (t < attackT) {
        envGain = attackT > delayT ? (t - delayT) / (attackT - delayT) : 1.0;
      } else if (t < holdT) {
        envGain = 1.0;
      } else if (t < decayT) {
        final decayProgress = (t - holdT) / (decayT - holdT);
        envGain = 1.0 - (decayProgress * (1.0 - zone.volEnvSustain));
      } else if (t < releaseStartT) {
        envGain = zone.volEnvSustain;
      } else {
        final releaseProgress = (t - releaseStartT) / zone.volEnvRelease;
        envGain = (zone.volEnvSustain * (1.0 - releaseProgress)).clamp(0.0, 1.0);
      }

      result[i] = sampleVal * envGain;
      srcIndex += playbackRate;
    }

    return result;
  }
}
