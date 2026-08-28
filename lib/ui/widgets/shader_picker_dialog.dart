import 'package:flutter/material.dart';

import '../../shaders/shader_model.dart';
import '../../shaders/shader_settings_manager.dart';
import '../../theme/eats_theme.dart';
import 'skeuomorphic_hardware_button.dart';
import 'skeuomorphic_hardware_switch.dart';

/// Interactive dialog for selecting screen shaders, applying presets, and
/// tuning uniform parameters in real time.
class ShaderPickerDialog extends StatefulWidget {
  const ShaderPickerDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => const ShaderPickerDialog(),
    );
  }

  @override
  State<ShaderPickerDialog> createState() => _ShaderPickerDialogState();
}

class _ShaderPickerDialogState extends State<ShaderPickerDialog> {
  final ShaderSettingsManager _settings = ShaderSettingsManager.instance;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsUpdated);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsUpdated);
    super.dispose();
  }

  void _onSettingsUpdated() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final activeProfile = _settings.activeProfile;
    final uniforms = _settings.getUniformsForShader(activeProfile.id);

    // Group uniforms by category
    final groupedUniforms = <String, List<ShaderUniformSpec>>{};
    for (final u in activeProfile.uniforms) {
      groupedUniforms.putIfAbsent(u.category, () => []).add(u);
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 620,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        decoration: BoxDecoration(
          color: EatsTheme.panelBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: EatsTheme.panelHeader, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dialog Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: EatsTheme.panelHeader,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.tv,
                    size: 18,
                    color: _settings.hasActiveShader ? EatsTheme.primaryCyan : EatsTheme.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'SCREEN SHADERS & CRT FX',
                      style: TextStyle(
                        color: EatsTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_settings.hasActiveShader) ...[
                    const SizedBox(width: 8),
                    SkeuomorphicHardwareButton(
                      label: 'RESET DEFAULTS',
                      icon: Icons.restore,
                      isActive: false,
                      activeColor: EatsTheme.accentGold,
                      onTap: () => _settings.resetToDefaults(activeProfile.id),
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    ),
                  ],
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: EatsTheme.textMuted,
                    hoverColor: Colors.white12,
                    splashRadius: 16,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Flexible(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Shader Selector Cards
                  Text(
                    'SELECT SHADER EFFECT',
                    style: TextStyle(
                      color: EatsTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: BuiltInShaders.allProfiles.map((profile) {
                      final isSelected = profile.id == _settings.activeShaderId;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: InkWell(
                            onTap: () => _settings.setActiveShader(profile.id),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? EatsTheme.primaryCyan.withValues(alpha: 0.15)
                                    : EatsTheme.controlBackground,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected ? EatsTheme.primaryCyan : EatsTheme.panelHeader,
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    profile.id == BuiltInShaders.noneId
                                        ? Icons.block
                                        : profile.id == BuiltInShaders.apocalypseCrtId
                                            ? Icons.tv
                                            : Icons.accessibility_new,
                                    size: 20,
                                    color: isSelected ? EatsTheme.primaryCyan : EatsTheme.textMuted,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    profile.name,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isSelected
                                          ? EatsTheme.primaryCyan
                                          : EatsTheme.textPrimary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 12),
                  // Description
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: EatsTheme.controlBackground.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: EatsTheme.panelHeader.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      activeProfile.description,
                      style: TextStyle(
                        color: EatsTheme.textMuted,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ),

                  // If shader is active, show presets & uniform categories
                  if (_settings.hasActiveShader) ...[
                    // Preset Selector Chips
                    if (activeProfile.presets.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'FACTORY PRESETS',
                        style: TextStyle(
                          color: EatsTheme.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: activeProfile.presets.keys.map((presetName) {
                          return SkeuomorphicHardwareButton(
                            label: presetName.toUpperCase(),
                            isActive: false,
                            activeColor: EatsTheme.primaryCyan,
                            onTap: () => _settings.applyPreset(activeProfile.id, presetName),
                            height: 28,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          );
                        }).toList(),
                      ),
                    ],

                    // Audio Reactivity Section
                    const SizedBox(height: 16),
                    _buildAudioReactivitySection(),

                    // Categorized Uniform Sliders
                    for (final entry in groupedUniforms.entries) ...[
                      const SizedBox(height: 16),
                      Text(
                        entry.key.toUpperCase(),
                        style: TextStyle(
                          color: EatsTheme.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: EatsTheme.controlBackground,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: EatsTheme.panelHeader),
                        ),
                        child: Column(
                          children: entry.value.map((spec) {
                            final currentVal = uniforms[spec.key] ?? spec.defaultValue;
                            return _buildUniformSlider(activeProfile.id, spec, currentVal);
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: EatsTheme.panelHeader,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _settings.hasActiveShader
                          ? 'Shaders compiled via Impeller / Skia (Low VRAM footprint)'
                          : 'No post-process shader active (0% GPU/CPU overhead)',
                      style: TextStyle(color: EatsTheme.textMuted, fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SkeuomorphicHardwareButton(
                    label: 'DONE',
                    icon: Icons.check,
                    isActive: true,
                    activeColor: EatsTheme.primaryCyan,
                    onTap: () => Navigator.of(context).pop(),
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioReactivitySection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: EatsTheme.controlBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _settings.audioReactivityEnabled
              ? EatsTheme.primaryCyan.withValues(alpha: 0.6)
              : EatsTheme.panelHeader,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.graphic_eq,
                      size: 16,
                      color: _settings.audioReactivityEnabled
                          ? EatsTheme.primaryCyan
                          : EatsTheme.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DAW AUDIO REACTIVITY',
                            style: TextStyle(
                              color: EatsTheme.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Syncs CRT rumble, pulse & RGB jitter to master bus audio & BPM tempo',
                            style: TextStyle(color: EatsTheme.textMuted, fontSize: 9),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SkeuomorphicHardwareSwitch(
                value: _settings.audioReactivityEnabled,
                activeColor: EatsTheme.primaryCyan,
                tooltip: 'Toggle audio reactivity',
                onChanged: (val) => _settings.setAudioReactivityEnabled(val),
              ),
            ],
          ),
          if (_settings.audioReactivityEnabled) ...[
            const Divider(height: 16, color: Colors.white10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Beat Pulse Sensitivity',
                              style: TextStyle(color: EatsTheme.textMuted, fontSize: 10)),
                          Text(
                            '${(_settings.audioBeatPulseSensitivity * 100).toInt()}%',
                            style: TextStyle(
                              color: EatsTheme.primaryCyan,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: _sliderTheme(),
                        child: Slider(
                          value: _settings.audioBeatPulseSensitivity,
                          min: 0.0,
                          max: 2.0,
                          onChanged: (v) => _settings.setAudioBeatPulseSensitivity(v),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Bass Kick Expansion',
                              style: TextStyle(color: EatsTheme.textMuted, fontSize: 10)),
                          Text(
                            '${(_settings.audioBassSensitivity * 100).toInt()}%',
                            style: TextStyle(
                              color: EatsTheme.primaryCyan,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: _sliderTheme(),
                        child: Slider(
                          value: _settings.audioBassSensitivity,
                          min: 0.0,
                          max: 2.0,
                          onChanged: (v) => _settings.setAudioBassSensitivity(v),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUniformSlider(String shaderId, ShaderUniformSpec spec, double currentVal) {
    String formattedVal;
    if (spec.max >= 100) {
      formattedVal = currentVal.toStringAsFixed(0);
    } else if (spec.step < 0.01) {
      formattedVal = currentVal.toStringAsFixed(4);
    } else if (spec.step < 0.1) {
      formattedVal = currentVal.toStringAsFixed(2);
    } else {
      formattedVal = currentVal.toStringAsFixed(1);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              spec.label,
              style: TextStyle(
                color: EatsTheme.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: _sliderTheme(),
              child: Slider(
                value: currentVal.clamp(spec.min, spec.max),
                min: spec.min,
                max: spec.max,
                onChanged: (v) {
                  _settings.setUniformValue(shaderId, spec.key, v);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            child: Text(
              formattedVal,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: EatsTheme.primaryCyan,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  SliderThemeData _sliderTheme() {
    return SliderTheme.of(context).copyWith(
      trackHeight: 3.0,
      activeTrackColor: EatsTheme.primaryCyan,
      inactiveTrackColor: Colors.white12,
      thumbColor: EatsTheme.primaryCyan,
      overlayColor: EatsTheme.primaryCyan.withValues(alpha: 0.2),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
    );
  }
}
