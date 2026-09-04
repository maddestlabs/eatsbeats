import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../utils/eats_storage_helper.dart';
import 'procedural_ir_generator.dart';

/// Central Audio Engine for Impulse Response management, convolution reverb processing,
/// and bi-directional acoustic room & amplifier cabinet preset synchronization.
class ConvolverEngine extends ChangeNotifier {
  static final ConvolverEngine instance = ConvolverEngine._internal();
  ConvolverEngine._internal() {
    _loadUserPresetsFromStorage();
  }

  static const String _storageKey = 'eatsbeats_user_space_presets';

  static List<String> get builtInIrNames => ProceduralIRGenerator.presets.keys.toList();

  final Map<String, List<double>> _irSamples = {};
  final Map<String, ({List<double> left, List<double> right})> _stereoIrSamples = {};
  final Map<String, AcousticSpaceParams> _userPresets = {};

  Map<String, List<double>> get irSamples => Map.unmodifiable(_irSamples);
  Map<String, ({List<double> left, List<double> right})> get stereoIrSamples => Map.unmodifiable(_stereoIrSamples);
  Map<String, AcousticSpaceParams> get userPresets => Map.unmodifiable(_userPresets);

  /// Returns all available Room presets (both stock and user created).
  List<AcousticSpaceParams> getRoomPresets() {
    final list = <AcousticSpaceParams>[];
    // Stock rooms
    for (final p in ProceduralIRGenerator.presets.values) {
      if (!p.isCabinetMode) list.add(p);
    }
    // User rooms
    for (final p in _userPresets.values) {
      if (!p.isCabinetMode) list.add(p);
    }
    return list;
  }

  /// Returns all available Cabinet presets (both stock and user created).
  List<AcousticSpaceParams> getCabPresets() {
    final list = <AcousticSpaceParams>[];
    // Stock cabs
    for (final p in ProceduralIRGenerator.presets.values) {
      if (p.isCabinetMode) list.add(p);
    }
    // User cabs
    for (final p in _userPresets.values) {
      if (p.isCabinetMode) list.add(p);
    }
    return list;
  }

  /// Finds an AcousticSpaceParams preset by name.
  AcousticSpaceParams? getSpacePreset(String name) {
    final clean = name.trim();
    if (_userPresets.containsKey(clean)) return _userPresets[clean];
    if (ProceduralIRGenerator.presets.containsKey(clean)) return ProceduralIRGenerator.presets[clean];
    for (final entry in _userPresets.entries) {
      if (entry.key.toLowerCase() == clean.toLowerCase()) return entry.value;
    }
    for (final entry in ProceduralIRGenerator.presets.entries) {
      if (entry.key.toLowerCase() == clean.toLowerCase()) return entry.value;
    }
    return null;
  }

  /// Saves a custom user-designed space or cabinet preset and makes it available in Convolution Reverb.
  void saveUserPreset(AcousticSpaceParams params) {
    final presetName = params.name.trim();
    _userPresets[presetName] = params;
    bakeCustomSpace(params);
    _saveUserPresetsToStorage();
    notifyListeners();
  }

  /// Removes a custom user preset.
  void deleteUserPreset(String name) {
    _userPresets.remove(name);
    unloadIr(name);
    _saveUserPresetsToStorage();
    notifyListeners();
  }

  /// Registers a newly decoded or procedurally baked IR PCM audio buffer.
  bool registerIrSample(String name, List<double> pcm, {List<double>? rightChannel}) {
    if (pcm.isEmpty) return false;
    final cleanName = name.replaceAll('\\', '/').split('/').last;
    _irSamples[cleanName] = pcm;
    _irSamples[name] = pcm;

    final rPcm = rightChannel ?? List<double>.from(pcm);
    final stereo = (left: pcm, right: rPcm);
    _stereoIrSamples[cleanName] = stereo;
    _stereoIrSamples[name] = stereo;

    debugPrint('ConvolverEngine: Registered stereo IR sample "$cleanName" (${pcm.length} samples)');
    return true;
  }

  /// Registers a stereo pair of IR PCM buffers.
  bool registerStereoIrSample(String name, ({List<double> left, List<double> right}) stereo) {
    if (stereo.left.isEmpty) return false;
    final cleanName = name.replaceAll('\\', '/').split('/').last;
    _irSamples[cleanName] = stereo.left;
    _irSamples[name] = stereo.left;
    _stereoIrSamples[cleanName] = stereo;
    _stereoIrSamples[name] = stereo;
    debugPrint('ConvolverEngine: Registered True Stereo IR "$cleanName" (L:${stereo.left.length}, R:${stereo.right.length})');
    return true;
  }

  /// Checks if a named IR sample is already registered in memory.
  bool hasIrSample(String name) {
    final cleanName = name.replaceAll('\\', '/').split('/').last;
    return _stereoIrSamples.containsKey(name) || _stereoIrSamples.containsKey(cleanName);
  }

  /// Bakes a procedural space or amp cabinet on demand and registers it in memory.
  /// Returns the cached stereo buffer immediately if already generated, preventing redundant UI thread freezing.
  List<double> bakeCustomSpace(AcousticSpaceParams params, {int sampleRate = 44100, bool force = false}) {
    final cleanName = params.name.replaceAll('\\', '/').split('/').last;
    if (!force && (_stereoIrSamples.containsKey(cleanName) || _stereoIrSamples.containsKey(params.name))) {
      final existing = _stereoIrSamples[cleanName] ?? _stereoIrSamples[params.name];
      if (existing != null && existing.left.isNotEmpty) {
        return existing.left;
      }
    }
    final stereo = ProceduralIRGenerator.generateStereo(params, sampleRate: sampleRate);
    registerStereoIrSample(params.name, stereo);
    return stereo.left;
  }

  /// Unloads a specific IR sample from memory.
  void unloadIr(String name) {
    final cleanName = name.replaceAll('\\', '/').split('/').last;
    _irSamples.remove(name);
    _irSamples.remove(cleanName);
    _stereoIrSamples.remove(name);
    _stereoIrSamples.remove(cleanName);
  }

  /// Clears all loaded IR samples to free memory.
  void clearAllIrSamples() {
    _irSamples.clear();
    _stereoIrSamples.clear();
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

  /// Retrieves a stereo IR sample pair by name, generating procedural IRs lazily on-demand.
  ({List<double> left, List<double> right})? getIrStereoSample(String name) {
    final cleanName = name.replaceAll('\\', '/').split('/').last;
    if (_stereoIrSamples.containsKey(name)) return _stereoIrSamples[name];
    if (_stereoIrSamples.containsKey(cleanName)) return _stereoIrSamples[cleanName];

    // Check custom user presets
    if (_userPresets.containsKey(cleanName)) {
      final generated = ProceduralIRGenerator.generateStereo(_userPresets[cleanName]!);
      registerStereoIrSample(cleanName, generated);
      registerStereoIrSample(name, generated);
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
        final generated = ProceduralIRGenerator.generateStereo(entry.value);
        registerStereoIrSample(cleanName, generated);
        registerStereoIrSample(name, generated);
        return generated;
      }
    }

    // Check if mono sample exists, generate stereo pair
    final mono = getIrSample(name);
    if (mono != null && mono.isNotEmpty) {
      final stereo = (left: mono, right: List<double>.from(mono));
      _stereoIrSamples[cleanName] = stereo;
      _stereoIrSamples[name] = stereo;
      return stereo;
    }

    final fallback = ProceduralIRGenerator.generateStereo(ProceduralIRGenerator.presets['Great Hall']!);
    registerStereoIrSample(cleanName, fallback);
    return fallback;
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

  Future<void> _saveUserPresetsToStorage() async {
    try {
      final encoded = jsonEncode(_userPresets.map((k, v) => MapEntry(k, v.toJson())));
      await EatsStorageHelper.setString(_storageKey, encoded);
    } catch (e) {
      debugPrint('ConvolverEngine: Error saving user space presets: $e');
    }
  }

  Future<void> _loadUserPresetsFromStorage() async {
    try {
      final raw = await EatsStorageHelper.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(raw);
        _userPresets.clear();
        for (final entry in decoded.entries) {
          if (entry.value is Map<String, dynamic>) {
            _userPresets[entry.key] = AcousticSpaceParams.fromJson(entry.value as Map<String, dynamic>);
          }
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('ConvolverEngine: Error loading user space presets: $e');
    }
  }
}
