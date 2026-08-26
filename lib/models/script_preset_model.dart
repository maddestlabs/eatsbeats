import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../utils/eats_storage_helper.dart';

/// Represents a saved sound patch or parameter snapshot for a specific DSP Script / Instrument / FX.
class ScriptPreset {
  final String id;
  final String scriptId; // Target script identifier (e.g. 'eats_303', 'subtractive_synth', 'space_reverb')
  final String name;
  final String category; // 'Bass', 'Lead', 'Pad', 'Pluck', 'FX', 'Drums', 'Utility'
  final String author;
  final bool isStock;
  final Map<String, double> params;
  final String? description;

  const ScriptPreset({
    required this.id,
    required this.scriptId,
    required this.name,
    required this.category,
    this.author = 'Eatsbeats Stock',
    this.isStock = true,
    required this.params,
    this.description,
  });

  ScriptPreset copyWith({
    String? id,
    String? scriptId,
    String? name,
    String? category,
    String? author,
    bool? isStock,
    Map<String, double>? params,
    String? description,
  }) {
    return ScriptPreset(
      id: id ?? this.id,
      scriptId: scriptId ?? this.scriptId,
      name: name ?? this.name,
      category: category ?? this.category,
      author: author ?? this.author,
      isStock: isStock ?? this.isStock,
      params: params ?? Map.from(this.params),
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'scriptId': scriptId,
        'name': name,
        'category': category,
        'author': author,
        'isStock': isStock,
        'params': params,
        'description': description,
      };

  factory ScriptPreset.fromJson(Map<String, dynamic> json) {
    return ScriptPreset(
      id: json['id'] as String? ?? 'preset_${DateTime.now().millisecondsSinceEpoch}',
      scriptId: json['scriptId'] as String? ?? '',
      name: json['name'] as String? ?? 'Custom Preset',
      category: json['category'] as String? ?? 'General',
      author: json['author'] as String? ?? 'User',
      isStock: json['isStock'] as bool? ?? false,
      params: (json['params'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          {},
      description: json['description'] as String?,
    );
  }
}

/// Global repository for Stock & User Script Presets.
class ScriptPresetLibrary extends ChangeNotifier {
  static final ScriptPresetLibrary instance = ScriptPresetLibrary._internal();
  ScriptPresetLibrary._internal() {
    _loadUserPresetsFromStorage();
  }

  static const String _storageKey = 'eatsbeats_user_script_presets';
  final List<ScriptPreset> _userPresets = [];

  // --- BUILT-IN FACTORY STOCK PRESETS ---
  static final List<ScriptPreset> _stockPresets = [
    // --- EATS-303 ACID SYNTH PRESETS ---
    const ScriptPreset(
      id: 'eats_303_classic_squelch',
      scriptId: 'eats_303',
      name: 'Classic Acid Squelch',
      category: 'Bass',
      author: 'Eatsbeats Factory',
      isStock: true,
      description: 'Iconic 303 screaming resonance with snappy decay.',
      params: {'Cutoff': 0.65, 'Resonance': 0.85, 'EnvMod': 0.80, 'Decay': 0.40, 'Accent': 0.70, 'Waveform': 1.0, 'Drive': 0.35},
    ),
    const ScriptPreset(
      id: 'eats_303_deep_sub',
      scriptId: 'eats_303',
      name: 'Deep Sub Acid',
      category: 'Bass',
      author: 'Eatsbeats Factory',
      isStock: true,
      description: 'Warm low-passed sawtooth sub bass with subtle envelope pluck.',
      params: {'Cutoff': 0.30, 'Resonance': 0.40, 'EnvMod': 0.45, 'Decay': 0.55, 'Accent': 0.50, 'Waveform': 0.0, 'Drive': 0.15},
    ),
    const ScriptPreset(
      id: 'eats_303_industrial_distort',
      scriptId: 'eats_303',
      name: 'Industrial Cyber Acid',
      category: 'Lead',
      author: 'Eatsbeats Factory',
      isStock: true,
      description: 'Heavily driven square wave with extreme high resonance.',
      params: {'Cutoff': 0.82, 'Resonance': 0.95, 'EnvMod': 0.90, 'Decay': 0.30, 'Accent': 0.90, 'Waveform': 1.0, 'Drive': 0.85},
    ),
    const ScriptPreset(
      id: 'eats_303_liquid_lead',
      scriptId: 'eats_303',
      name: 'Liquid Resonance Lead',
      category: 'Lead',
      author: 'Eatsbeats Factory',
      isStock: true,
      description: 'Silky smooth melodic lead with singing resonant peaks.',
      params: {'Cutoff': 0.75, 'Resonance': 0.78, 'EnvMod': 0.60, 'Decay': 0.70, 'Accent': 0.60, 'Waveform': 0.0, 'Drive': 0.20},
    ),

    // --- ANALOG SUBTRACTIVE SYNTH PRESETS ---
    const ScriptPreset(
      id: 'subtractive_init',
      scriptId: 'subtractive_synth',
      name: 'Init Saw Pluck',
      category: 'Pluck',
      author: 'Eatsbeats Factory',
      isStock: true,
      description: 'Crisp, fast envelope subtractive pluck.',
      params: {'Cutoff': 0.50, 'Resonance': 0.40, 'Attack': 0.01, 'Decay': 0.30, 'Sustain': 0.20, 'Release': 0.25, 'OscWave': 1.0},
    ),
    const ScriptPreset(
      id: 'subtractive_lush_pad',
      scriptId: 'subtractive_synth',
      name: 'Lush 80s Brass Pad',
      category: 'Pad',
      author: 'Eatsbeats Factory',
      isStock: true,
      description: 'Slow attack dual-oscillator warm analog pad.',
      params: {'Cutoff': 0.60, 'Resonance': 0.25, 'Attack': 0.45, 'Decay': 0.60, 'Sustain': 0.85, 'Release': 0.80, 'OscWave': 2.0},
    ),
    const ScriptPreset(
      id: 'subtractive_punchy_bass',
      scriptId: 'subtractive_synth',
      name: 'Moog Punch Bass',
      category: 'Bass',
      author: 'Eatsbeats Factory',
      isStock: true,
      description: 'Heavy low-end punch with 24dB ladder filter cutoff.',
      params: {'Cutoff': 0.38, 'Resonance': 0.50, 'Attack': 0.01, 'Decay': 0.40, 'Sustain': 0.10, 'Release': 0.15, 'OscWave': 1.0},
    ),

    // --- SNES SPC700 PRESETS ---
    const ScriptPreset(
      id: 'snes_retro_brr',
      scriptId: 'snes_spc700',
      name: '16-Bit RPG Horn',
      category: 'Lead',
      author: 'Eatsbeats Factory',
      isStock: true,
      description: 'Lo-fi 32kHz Gaussian interpolated retro game instrument.',
      params: {'EchoFeedback': 0.60, 'EchoDelay': 0.25, 'FilterCoeff': 0.50, 'BRRBitDepth': 16.0},
    ),
    const ScriptPreset(
      id: 'snes_chiptune_pad',
      scriptId: 'snes_spc700',
      name: 'Chrono Ambient Cave',
      category: 'Pad',
      author: 'Eatsbeats Factory',
      isStock: true,
      description: 'Atmospheric SNES echo buffer with pitch modulation.',
      params: {'EchoFeedback': 0.80, 'EchoDelay': 0.50, 'FilterCoeff': 0.35, 'BRRBitDepth': 16.0},
    ),

    // --- TAPE WARMTH & SATURATION FX PRESETS ---
    const ScriptPreset(
      id: 'tape_warmth_subtle',
      scriptId: 'tape_saturation',
      name: 'Subtle Console Glue',
      category: 'Utility',
      author: 'Eatsbeats Factory',
      isStock: true,
      description: 'Gentle harmonic tape saturation for master bus.',
      params: {'Drive': 0.25, 'Warmth': 0.60, 'Flutter': 0.05, 'Output': 1.0},
    ),
    const ScriptPreset(
      id: 'tape_warmth_lofi_cassette',
      scriptId: 'tape_saturation',
      name: 'Lofi Cassette Wobble',
      category: 'FX',
      author: 'Eatsbeats Factory',
      isStock: true,
      description: 'Vintage cassette flutter, hiss, and high-frequency roll-off.',
      params: {'Drive': 0.65, 'Warmth': 0.85, 'Flutter': 0.45, 'Output': 0.9},
    ),

    // --- STEREO DELAY FX PRESETS ---
    const ScriptPreset(
      id: 'delay_ping_pong',
      scriptId: 'stereo_delay',
      name: 'Ping-Pong 8th Notes',
      category: 'FX',
      author: 'Eatsbeats Factory',
      isStock: true,
      description: 'Wide alternating stereo echoes.',
      params: {'TimeMs': 250.0, 'Feedback': 0.45, 'Mix': 0.35},
    ),
    const ScriptPreset(
      id: 'delay_dub_space',
      scriptId: 'stereo_delay',
      name: 'Endless Dub Echo',
      category: 'FX',
      author: 'Eatsbeats Factory',
      isStock: true,
      description: 'High regeneration tape delay with filtered decay.',
      params: {'TimeMs': 450.0, 'Feedback': 0.80, 'Mix': 0.50},
    ),
  ];

  /// Returns all presets (both factory stock and custom user presets).
  List<ScriptPreset> get allPresets => [..._stockPresets, ..._userPresets];

  /// Returns presets applicable for a specific script ID.
  List<ScriptPreset> getPresetsForScript(String scriptId) {
    final clean = scriptId.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return allPresets.where((p) {
      final pScript = p.scriptId.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      return pScript.contains(clean) || clean.contains(pScript);
    }).toList();
  }

  /// Returns presets by category (e.g. 'Bass', 'Lead', 'Pad', 'FX').
  List<ScriptPreset> getPresetsByCategory(String category) {
    return allPresets.where((p) => p.category.toLowerCase() == category.toLowerCase()).toList();
  }

  /// Saves or updates a custom user preset and persists to disk.
  void saveUserPreset(ScriptPreset preset) {
    _userPresets.removeWhere((p) => p.id == preset.id || (p.name == preset.name && p.scriptId == preset.scriptId));
    _userPresets.add(preset.copyWith(isStock: false));
    _saveUserPresetsToStorage();
    notifyListeners();
  }

  /// Deletes a custom user preset.
  void deleteUserPreset(String presetId) {
    _userPresets.removeWhere((p) => p.id == presetId && !p.isStock);
    _saveUserPresetsToStorage();
    notifyListeners();
  }

  Future<void> _saveUserPresetsToStorage() async {
    try {
      final encoded = jsonEncode(_userPresets.map((p) => p.toJson()).toList());
      await EatsStorageHelper.setString(_storageKey, encoded);
    } catch (e) {
      debugPrint('ScriptPresetLibrary: Error saving user presets: $e');
    }
  }

  Future<void> _loadUserPresetsFromStorage() async {
    try {
      final raw = await EatsStorageHelper.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw);
        _userPresets.clear();
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            _userPresets.add(ScriptPreset.fromJson(item));
          }
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('ScriptPresetLibrary: Error loading user presets: $e');
    }
  }
}
