import 'dart:math' as math;
import 'package:flutter/foundation.dart';

class ConvolverEngine {
  static final ConvolverEngine instance = ConvolverEngine._internal();
  ConvolverEngine._internal();

  static const List<String> builtInIrNames = [
    'Great Hall',
    'Plate Reverb',
    'Warm Room',
    'Spring Tank',
  ];

  final Map<String, List<double>> _irSamples = {};

  Map<String, List<double>> get irSamples => Map.unmodifiable(_irSamples);

  /// Registers a newly decoded IR PCM audio buffer.
  bool registerIrSample(String name, List<double> pcm) {
    if (pcm.isEmpty) return false;
    final cleanName = name.replaceAll('\\', '/').split('/').last;
    _irSamples[cleanName] = pcm;
    _irSamples[name] = pcm;
    debugPrint('ConvolverEngine: Registered IR sample "$cleanName" (${pcm.length} samples)');
    return true;
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

  /// Returns list of all available Impulse Response names.
  List<String> getAvailableIrNames() {
    final names = <String>{...builtInIrNames};
    for (final k in _irSamples.keys) {
      if (!k.contains('/')) names.add(k);
    }
    final list = names.toList();
    list.sort();
    return list;
  }

  /// Retrieves an IR sample buffer by name, generating built-in synthetic IRs lazily on-demand.
  List<double>? getIrSample(String name) {
    final cleanName = name.replaceAll('\\', '/').split('/').last;
    if (_irSamples.containsKey(name)) return _irSamples[name];
    if (_irSamples.containsKey(cleanName)) return _irSamples[cleanName];

    // Lazy generation on demand
    final lazy = _generateLazyBuiltIn(cleanName);
    if (lazy != null) {
      _irSamples[cleanName] = lazy;
      _irSamples[name] = lazy;
      return lazy;
    }
    return getIrSample('Great Hall');
  }

  static List<double>? _generateLazyBuiltIn(String name) {
    switch (name.toLowerCase()) {
      case 'great hall':
        return _generateSyntheticIr(decaySec: 2.2, damping: 0.15);
      case 'plate reverb':
        return _generateSyntheticIr(decaySec: 1.4, damping: 0.05);
      case 'warm room':
        return _generateSyntheticIr(decaySec: 0.6, damping: 0.35);
      case 'spring tank':
        return _generateSyntheticIr(decaySec: 1.0, damping: 0.25);
      default:
        return null;
    }
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


  /// Generates a synthetic impulse response buffer with exponential decay and noise diffusion.
  static List<double> _generateSyntheticIr({required double decaySec, required double damping}) {
    final length = (44100 * decaySec).toInt();
    final ir = List<double>.filled(length, 0.0);
    final rng = math.Random(42);

    for (int i = 0; i < length; i++) {
      final t = i / 44100.0;
      final env = math.exp(-t * (4.0 / decaySec));
      final noise = (rng.nextDouble() * 2.0 - 1.0);
      ir[i] = noise * env * (1.0 - t * damping).clamp(0.0, 1.0);
    }

    return ir;
  }
}
