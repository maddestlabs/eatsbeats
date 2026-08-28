import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../utils/eats_storage_helper.dart';
import 'shader_model.dart';

/// Manages active shader state, uniform adjustments, presets, audio-reactivity
/// toggles, and persistence to disk/storage.
class ShaderSettingsManager extends ChangeNotifier {
  static final ShaderSettingsManager instance = ShaderSettingsManager._internal();

  ShaderSettingsManager._internal() {
    _loadInitialState();
  }

  String _activeShaderId = BuiltInShaders.noneId;
  String get activeShaderId => _activeShaderId;

  bool _audioReactivityEnabled = true;
  bool get audioReactivityEnabled => _audioReactivityEnabled;

  double _audioBeatPulseSensitivity = 1.0;
  double get audioBeatPulseSensitivity => _audioBeatPulseSensitivity;

  double _audioBassSensitivity = 1.0;
  double get audioBassSensitivity => _audioBassSensitivity;

  final Map<String, Map<String, double>> _shaderUniforms = {};

  ShaderProfile get activeProfile => BuiltInShaders.getProfileById(_activeShaderId);

  bool get hasActiveShader => _activeShaderId != BuiltInShaders.noneId;

  Map<String, double> getUniformsForShader(String shaderId) {
    if (!_shaderUniforms.containsKey(shaderId)) {
      final profile = BuiltInShaders.getProfileById(shaderId);
      final defaults = <String, double>{};
      for (final u in profile.uniforms) {
        defaults[u.key] = u.defaultValue;
      }
      _shaderUniforms[shaderId] = defaults;
    }
    return Map<String, double>.from(_shaderUniforms[shaderId]!);
  }

  double getUniformValue(String shaderId, String uniformKey) {
    final uniforms = getUniformsForShader(shaderId);
    if (uniforms.containsKey(uniformKey)) {
      return uniforms[uniformKey]!;
    }
    final profile = BuiltInShaders.getProfileById(shaderId);
    final spec = profile.uniforms.firstWhere(
      (u) => u.key == uniformKey,
      orElse: () => ShaderUniformSpec(key: uniformKey, label: '', type: UniformType.float, defaultValue: 0.0),
    );
    return spec.defaultValue;
  }

  Future<void> _loadInitialState() async {
    // 1. Load active shader ID
    final savedId = await EatsStorageHelper.getString('screen_shader_active_id');
    if (savedId != null && savedId.isNotEmpty) {
      _activeShaderId = savedId;
    }

    // 2. Load audio reactivity settings
    _audioReactivityEnabled = (await EatsStorageHelper.getBool('screen_shader_audio_reactivity')) ?? true;
    _audioBeatPulseSensitivity = (await EatsStorageHelper.getDouble('screen_shader_beat_sens')) ?? 1.0;
    _audioBassSensitivity = (await EatsStorageHelper.getDouble('screen_shader_bass_sens')) ?? 1.0;

    // 3. Load persisted uniforms for each built-in profile
    for (final profile in BuiltInShaders.allProfiles) {
      final defaults = <String, double>{};
      for (final u in profile.uniforms) {
        defaults[u.key] = u.defaultValue;
      }
      final jsonStr = await EatsStorageHelper.getString('screen_shader_uniforms_${profile.id}');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        try {
          final decoded = jsonDecode(jsonStr);
          if (decoded is Map) {
            for (final entry in decoded.entries) {
              final val = (entry.value as num?)?.toDouble();
              if (val != null) {
                defaults[entry.key.toString()] = val;
              }
            }
          }
        } catch (e) {
          debugPrint('Error decoding shader uniforms for ${profile.id}: $e');
        }
      }
      _shaderUniforms[profile.id] = defaults;
    }
    notifyListeners();
  }

  Future<void> setActiveShader(String id) async {
    if (_activeShaderId == id) return;
    _activeShaderId = id;
    await EatsStorageHelper.setString('screen_shader_active_id', id);
    notifyListeners();
  }

  Future<void> setUniformValue(String shaderId, String uniformKey, double value) async {
    final uniforms = _shaderUniforms.putIfAbsent(shaderId, () => {});
    uniforms[uniformKey] = value;
    notifyListeners();

    // Persist asynchronously
    await EatsStorageHelper.setString(
      'screen_shader_uniforms_$shaderId',
      jsonEncode(uniforms),
    );
  }

  Future<void> applyPreset(String shaderId, String presetName) async {
    final profile = BuiltInShaders.getProfileById(shaderId);
    final presetMap = profile.presets[presetName];
    if (presetMap != null) {
      final uniforms = _shaderUniforms.putIfAbsent(shaderId, () => {});
      for (final entry in presetMap.entries) {
        uniforms[entry.key] = entry.value;
      }
      notifyListeners();
      await EatsStorageHelper.setString(
        'screen_shader_uniforms_$shaderId',
        jsonEncode(uniforms),
      );
    }
  }

  Future<void> resetToDefaults(String shaderId) async {
    final profile = BuiltInShaders.getProfileById(shaderId);
    final defaults = <String, double>{};
    for (final u in profile.uniforms) {
      defaults[u.key] = u.defaultValue;
    }
    _shaderUniforms[shaderId] = defaults;
    notifyListeners();
    await EatsStorageHelper.setString(
      'screen_shader_uniforms_$shaderId',
      jsonEncode(defaults),
    );
  }

  Future<void> setAudioReactivityEnabled(bool enabled) async {
    if (_audioReactivityEnabled == enabled) return;
    _audioReactivityEnabled = enabled;
    await EatsStorageHelper.setBool('screen_shader_audio_reactivity', enabled);
    notifyListeners();
  }

  Future<void> setAudioBeatPulseSensitivity(double val) async {
    _audioBeatPulseSensitivity = val;
    await EatsStorageHelper.setDouble('screen_shader_beat_sens', val);
    notifyListeners();
  }

  Future<void> setAudioBassSensitivity(double val) async {
    _audioBassSensitivity = val;
    await EatsStorageHelper.setDouble('screen_shader_bass_sens', val);
    notifyListeners();
  }
}
