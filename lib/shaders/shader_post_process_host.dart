import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/daw_state.dart';
import 'shader_distortion_remapper.dart';
import 'shader_model.dart';
import 'shader_settings_manager.dart';

/// Wraps the root application tree to host dynamic runtime fragment shaders,
/// feed audio-reactive DAW telemetry, and map mouse/touch distortion coordinates.
class ShaderPostProcessHost extends StatefulWidget {
  final Widget child;
  final DawState dawState;

  const ShaderPostProcessHost({
    super.key,
    required this.child,
    required this.dawState,
  });

  @override
  State<ShaderPostProcessHost> createState() => _ShaderPostProcessHostState();
}

class _ShaderPostProcessHostState extends State<ShaderPostProcessHost>
    with SingleTickerProviderStateMixin {
  final ShaderSettingsManager _settings = ShaderSettingsManager.instance;
  final Map<String, ui.FragmentProgram> _programCache = {};

  Ticker? _ticker;
  double _elapsedTime = 0.0;
  double _lastFrameTime = 0.0;

  // Audio reactivity smoothed metrics
  double _smoothedBeatPulse = 0.0;
  double _smoothedBassEnergy = 0.0;

  bool _isLoadingShader = false;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
    _loadActiveProgram();
    _updateTickerState();
  }

  @override
  void didUpdateWidget(ShaderPostProcessHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateTickerState();
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    _ticker?.dispose();
    super.dispose();
  }

  void _onSettingsChanged() {
    _loadActiveProgram();
    _updateTickerState();
    if (mounted) setState(() {});
  }

  Future<void> _loadActiveProgram() async {
    final profile = _settings.activeProfile;
    final path = profile.assetPath;
    if (path == null) {
      if (mounted) setState(() {});
      return;
    }

    if (_programCache.containsKey(path)) {
      if (mounted) setState(() {});
      return;
    }

    _isLoadingShader = true;
    try {
      final program = await ui.FragmentProgram.fromAsset(path);
      _programCache[path] = program;
    } catch (e) {
      debugPrint('Shader load error for $path: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingShader = false;
        });
      }
    }
  }

  void _updateTickerState() {
    final profile = _settings.activeProfile;
    final needsAnimation = profile.isAnimated ||
        (_settings.hasActiveShader && _settings.audioReactivityEnabled);

    if (needsAnimation) {
      if (_ticker == null) {
        _ticker = createTicker(_onTick)..start();
      } else if (!_ticker!.isActive) {
        _ticker!.start();
      }
    } else {
      _ticker?.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final currentSeconds = elapsed.inMicroseconds / 1000000.0;
    final dt = _lastFrameTime == 0.0 ? 0.016 : (currentSeconds - _lastFrameTime);
    _lastFrameTime = currentSeconds;
    _elapsedTime += dt;

    if (_settings.audioReactivityEnabled) {
      // 1. Calculate Beat Phase Pulse from DAW playhead & tempo
      double beatPulse = 0.0;
      if (widget.dawState.isPlaying && widget.dawState.bpm > 0) {
        final beatPhase = (_elapsedTime * (widget.dawState.bpm / 60.0)) % 1.0;
        // Fast attack, exponential decay envelope
        beatPulse = math.pow(math.max(0.0, 1.0 - beatPhase), 3.0).toDouble();
      }

      // 2. Calculate Bass & Transients from AudioEngine
      final peak = math.max(
        widget.dawState.audioEngine.leftPeak,
        widget.dawState.audioEngine.rightPeak,
      );

      // Smooth attack and decay
      final targetBeat = beatPulse * _settings.audioBeatPulseSensitivity;
      final targetBass = (peak * 1.5).clamp(0.0, 1.0) * _settings.audioBassSensitivity;

      _smoothedBeatPulse += (targetBeat - _smoothedBeatPulse) * math.min(1.0, dt * 25.0);
      _smoothedBassEnergy += (targetBass - _smoothedBassEnergy) * math.min(1.0, dt * 18.0);
    } else {
      _smoothedBeatPulse = 0.0;
      _smoothedBassEnergy = 0.0;
    }

    if (mounted) setState(() {});
  }

  ui.FragmentShader? _buildConfiguredShader(Size size) {
    final profile = _settings.activeProfile;
    final path = profile.assetPath;
    if (path == null) return null;

    final program = _programCache[path];
    if (program == null) return null;

    final shader = program.fragmentShader();
    final uniforms = _settings.getUniformsForShader(profile.id);

    // Uniform 0, 1: u_resolution
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);

    // Uniform 2: u_time
    shader.setFloat(2, _elapsedTime);

    if (profile.id == BuiltInShaders.apocalypseCrtId) {
      // 3: u_grille_level
      shader.setFloat(3, uniforms['u_grille_level'] ?? 0.95);
      // 4: u_grille_density
      shader.setFloat(4, uniforms['u_grille_density'] ?? 800.0);
      // 5: u_scanline_level
      shader.setFloat(5, uniforms['u_scanline_level'] ?? 0.80);
      // 6: u_scanlines
      shader.setFloat(6, uniforms['u_scanlines'] ?? 1.0);
      // 7: u_rgb_offset
      shader.setFloat(7, uniforms['u_rgb_offset'] ?? 0.001);

      // 8: u_curve_strength
      shader.setFloat(8, uniforms['u_curve_strength'] ?? 0.35);
      // 9: u_curve_distance
      shader.setFloat(9, uniforms['u_curve_distance'] ?? 2.50);
      // 10: u_noise_level
      shader.setFloat(10, uniforms['u_noise_level'] ?? 0.10);
      // 11: u_flicker
      shader.setFloat(11, uniforms['u_flicker'] ?? 0.15);
      // 12: u_h_sync
      shader.setFloat(12, uniforms['u_h_sync'] ?? 0.02);
      // 13: u_rumble
      shader.setFloat(13, uniforms['u_rumble'] ?? 1.0);

      // 14: u_light_speed
      shader.setFloat(14, uniforms['u_light_speed'] ?? 1.0);
      // 15: u_frame_size
      shader.setFloat(15, uniforms['u_frame_size'] ?? 18.0);
      // 16: u_frame_hue
      shader.setFloat(16, uniforms['u_frame_hue'] ?? 0.025);
      // 17: u_frame_sat
      shader.setFloat(17, uniforms['u_frame_sat'] ?? 0.10);
      // 18: u_frame_light
      shader.setFloat(18, uniforms['u_frame_light'] ?? 0.05);
      // 19: u_frame_reflect
      shader.setFloat(19, uniforms['u_frame_reflect'] ?? 0.60);
      // 20: u_frame_grain
      shader.setFloat(20, uniforms['u_frame_grain'] ?? 0.15);

      // 21: u_glass_tint
      shader.setFloat(21, uniforms['u_glass_tint'] ?? 0.15);
      // 22: u_glass_hue
      shader.setFloat(22, uniforms['u_glass_hue'] ?? 0.33);
      // 23: u_glass_sat
      shader.setFloat(23, uniforms['u_glass_sat'] ?? 0.30);
      // 24: u_screen_tint
      shader.setFloat(24, uniforms['u_screen_tint'] ?? 0.0);
      // 25: u_screen_hue
      shader.setFloat(25, uniforms['u_screen_hue'] ?? 0.0);
      // 26: u_screen_sat
      shader.setFloat(26, uniforms['u_screen_sat'] ?? 1.0);

      // 27: u_beat_pulse
      shader.setFloat(27, _smoothedBeatPulse);
      // 28: u_bass_energy
      shader.setFloat(28, _smoothedBassEnergy);
    } else if (profile.id == BuiltInShaders.accessibilityId) {
      // u_mode
      shader.setFloat(3, uniforms['u_mode'] ?? 1.0);
      // u_intensity
      shader.setFloat(4, uniforms['u_intensity'] ?? 1.0);
      // u_brightness
      shader.setFloat(5, uniforms['u_brightness'] ?? 1.0);
      // u_contrast
      shader.setFloat(6, uniforms['u_contrast'] ?? 1.0);
      // u_saturation
      shader.setFloat(7, uniforms['u_saturation'] ?? 1.0);
      // u_beat_pulse
      shader.setFloat(8, _smoothedBeatPulse);
      // u_bass_energy
      shader.setFloat(9, _smoothedBassEnergy);
    }

    return shader;
  }

  @override
  Widget build(BuildContext context) {
    final profile = _settings.activeProfile;

    // Fast path: No shader active or still loading
    if (profile.id == BuiltInShaders.noneId || _isLoadingShader) {
      return widget.child;
    }

    final uniforms = _settings.getUniformsForShader(profile.id);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final shader = _buildConfiguredShader(size);

        if (shader == null) {
          return widget.child;
        }

        // Pointer distortion remapper function
        Offset Function(Offset)? uvDistortionMap;
        if (profile.curvatureMap != null) {
          uvDistortionMap = (uv) => profile.curvatureMap!(uv, uniforms, size);
        }

        return ShaderDistortionPointerRemapper(
          uvDistortionMap: uvDistortionMap,
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.shader(shader),
            child: widget.child,
          ),
        );
      },
    );
  }
}
