import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'procedural_ir_generator.dart';

class ConvolverEngine {
  static final ConvolverEngine instance = ConvolverEngine._internal();
  ConvolverEngine._internal();

  static List<String> get builtInIrNames => ProceduralIRGenerator.presets.keys.toList();

  final Map<String, List<double>> _irSamples = {};
  final Map<String, AcousticSpaceParams> _userPresets = {};

  Map<String, List<double>> get irSamples => Map.unmodifiable(_irSamples);
  Map<String, AcousticSpaceParams> get userPresets => Map.unmodifiable(_userPresets);

  /// Saves a custom user-designed space or cabinet preset and makes it available in Convolution Reverb.
  void saveUserPreset(AcousticSpaceParams params) {
    final presetName = params.name.trim();
    _userPresets[presetName] = params;
    bakeCustomSpace(params);
  }

  /// Removes a custom user preset.
  void deleteUserPreset(String name) {
    _userPresets.remove(name);
    unloadIr(name);
  }

  /// Registers a newly decoded or procedurally baked IR PCM audio buffer.
  bool registerIrSample(String name, List<double> pcm) {
    if (pcm.isEmpty) return false;
    final cleanName = name.replaceAll('\\', '/').split('/').last;
    _irSamples[cleanName] = pcm;
    _irSamples[name] = pcm;
    debugPrint('ConvolverEngine: Registered IR sample "$cleanName" (${pcm.length} samples)');
    return true;
  }

  /// Bakes a procedural space or amp cabinet on demand and registers it in memory.
  List<double> bakeCustomSpace(AcousticSpaceParams params, {int sampleRate = 44100}) {
    final pcm = ProceduralIRGenerator.generate(params, sampleRate: sampleRate);
    registerIrSample(params.name, pcm);
    return pcm;
  }

  /// Unloads a specific IR sample from memory.
  void unloadIr(String name) {
    final cleanName = name.replaceAll('\\', '/').split('/').last;
    _irSamples.remove(name);
    _irSamples.remove(cleanName);
  }

  /// Clears all loaded IR samples to free memory.
  void clearAllIrSamples() {
    _irSamples.clear();
  }

  /// Returns list of all available Impulse Response names (both built-in procedural and imported/downloaded).
  List<String> getAvailableIrNames() {
    final names = <String>{...builtInIrNames, ..._userPresets.keys};
    for (final k in _irSamples.keys) {
      if (!k.contains('/') && !k.startsWith('Room:') && !k.startsWith('Cab:')) {
        names.add(k);
      }
    }
    final list = names.toList();
    list.sort();
    return list;
  }

  /// Retrieves an IR sample buffer by name, generating procedural IRs lazily on-demand.
  List<double>? getIrSample(String name) {
    final cleanName = name.replaceAll('\\', '/').split('/').last;
    if (_irSamples.containsKey(name)) return _irSamples[name];
    if (_irSamples.containsKey(cleanName)) return _irSamples[cleanName];

    // Check custom user presets
    if (_userPresets.containsKey(cleanName)) {
      final generated = ProceduralIRGenerator.generate(_userPresets[cleanName]!);
      _irSamples[cleanName] = generated;
      _irSamples[name] = generated;
      return generated;
    }

    // Check procedural preset library with exact and substring matching
    for (final entry in ProceduralIRGenerator.presets.entries) {
      final entryKey = entry.key.toLowerCase();
      final target = cleanName.toLowerCase();
      if (entryKey == target ||
          target == entry.value.name.toLowerCase() ||
          entryKey.startsWith(target) ||
          target.startsWith(entryKey.split(' (').first)) {
        final generated = ProceduralIRGenerator.generate(entry.value);
        _irSamples[cleanName] = generated;
        _irSamples[name] = generated;
        return generated;
      }
    }

    // Fallback lazy generation
    final lazy = _generateLazyBuiltIn(cleanName);
    if (lazy != null) {
      _irSamples[cleanName] = lazy;
      _irSamples[name] = lazy;
      return lazy;
    }
    return getIrSample('Great Hall');
  }

  static List<double>? _generateLazyBuiltIn(String name) {
    final preset = ProceduralIRGenerator.presets[name];
    if (preset != null) {
      return ProceduralIRGenerator.generate(preset);
    }
    return null;
  }

  /// Real-time convolution / impulse reverb processing on PCM input buffer.
  List<double> processConvolver(List<double> input, String irName, double mix) {
    if (input.isEmpty || mix <= 0.001) return input;

    final ir = getIrSample(irName);
    if (ir == null || ir.isEmpty) return input;

    final output = List<double>.from(input);
    final blend = mix.clamp(0.0, 1.0);

    // Fast, zero-lag acoustic convolution loop
    final irLength = math.min(ir.length, 17640); // ~400ms IR kernel for acoustic realism
    final inputLen = input.length;
    final step = math.max(1, (irLength / 192).floor());
    final normScale = 1.0 / (irLength / step);

    for (int i = 0; i < inputLen; i++) {
      double convSum = 0.0;
      final maxK = math.min(i, irLength - 1);

      for (int k = 0; k <= maxK; k += step) {
        convSum += input[i - k] * ir[k];
      }

      output[i] = (input[i] * (1.0 - blend)) + (convSum * normScale * blend * 2.2);
    }

    return output;
  }
}

