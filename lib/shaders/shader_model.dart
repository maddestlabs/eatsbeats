import 'dart:ui';

enum UniformType { float, color, boolean }

/// Definition of a single tunable uniform parameter for a shader.
class ShaderUniformSpec {
  final String key;
  final String label;
  final UniformType type;
  final double min;
  final double max;
  final double defaultValue;
  final double step;
  final String category;
  final String description;

  const ShaderUniformSpec({
    required this.key,
    required this.label,
    required this.type,
    this.min = 0.0,
    this.max = 1.0,
    this.defaultValue = 0.5,
    this.step = 0.01,
    this.category = 'General',
    this.description = '',
  });
}

/// Metadata and specification for a post-process screen shader.
class ShaderProfile {
  final String id;
  final String name;
  final String description;
  final String? assetPath;
  final bool isAnimated;
  final List<ShaderUniformSpec> uniforms;
  final Map<String, Map<String, double>> presets;

  /// Optional mathematical curvature mapping for pointer hit-testing remapping.
  /// Given normalized [uv] [0..1] and [uniformsMap], returns the corresponding
  /// internal UI coordinate [0..1].
  final Offset Function(Offset uv, Map<String, double> uniformsMap, Size size)? curvatureMap;

  const ShaderProfile({
    required this.id,
    required this.name,
    required this.description,
    this.assetPath,
    this.isAnimated = false,
    this.uniforms = const [],
    this.presets = const {},
    this.curvatureMap,
  });
}

/// Central catalog of built-in shader profiles in Eatsbeats.
class BuiltInShaders {
  static const String noneId = 'none';
  static const String apocalypseCrtId = 'apocalypse_crt';
  static const String accessibilityId = 'accessibility';

  static const ShaderProfile none = ShaderProfile(
    id: noneId,
    name: 'Normal (Direct Display)',
    description: 'Native Flutter rendering without post-processing shaders.',
  );

  static final ShaderProfile apocalypseCrt = ShaderProfile(
    id: apocalypseCrtId,
    name: 'Apocalypse CRT',
    description:
        'Authentic post-apocalyptic cathode ray tube monitor simulation with screen reflection onto virtual bezel frame, swaying environmental lighting, scanlines, phosphor aperture grille, rumble, and tube curvature.',
    assetPath: 'assets/shaders/apocalypse_crt.frag',
    isAnimated: true,
    curvatureMap: (Offset uv, Map<String, double> uniforms, Size size) {
      final curveStrength = uniforms['u_curve_strength'] ?? 0.35;
      final curveDist = uniforms['u_curve_distance'] ?? 2.5;
      final framePx = uniforms['u_frame_size'] ?? 18.0;

      var mappedUv = uv;
      if (curveStrength > 0.001) {
        final cc = mappedUv - const Offset(0.5, 0.5);
        final dist = (cc.dx * cc.dx + cc.dy * cc.dy);
        // Approximation of sqrt(dist)^curveDist
        mappedUv = mappedUv + cc * (dist * curveStrength);
      }

      final frame = size.width > 0 ? (framePx / size.width) : 0.0;
      if (frame > 0.0) {
        if (mappedUv.dx < frame || mappedUv.dx > 1.0 - frame || mappedUv.dy < frame || mappedUv.dy > 1.0 - frame) {
          return const Offset(-1.0, -1.0); // Inside outer bezel
        }
        mappedUv = Offset(
          (mappedUv.dx - frame) / (1.0 - 2.0 * frame),
          (mappedUv.dy - frame) / (1.0 - 2.0 * frame),
        );
      }

      return mappedUv;
    },
    uniforms: [
      // Visual Effects
      const ShaderUniformSpec(
        key: 'u_grille_level',
        label: 'Grille Level',
        type: UniformType.float,
        min: 0.0,
        max: 3.0,
        defaultValue: 0.95,
        step: 0.05,
        category: 'Visual Effects',
        description: 'Intensity of vertical phosphor aperture grille stripes.',
      ),
      const ShaderUniformSpec(
        key: 'u_grille_density',
        label: 'Grille Density',
        type: UniformType.float,
        min: 100.0,
        max: 1200.0,
        defaultValue: 800.0,
        step: 25.0,
        category: 'Visual Effects',
        description: 'Frequency of the phosphor grid pattern across the screen.',
      ),
      const ShaderUniformSpec(
        key: 'u_scanline_level',
        label: 'Scanline Level',
        type: UniformType.float,
        min: 0.0,
        max: 3.0,
        defaultValue: 0.80,
        step: 0.05,
        category: 'Visual Effects',
        description: 'Darkness and prominence of horizontal cathode scanlines.',
      ),
      const ShaderUniformSpec(
        key: 'u_scanlines',
        label: 'Scanline Density',
        type: UniformType.float,
        min: 0.5,
        max: 4.0,
        defaultValue: 1.0,
        step: 0.1,
        category: 'Visual Effects',
        description: 'Multiplier for scanline line frequency.',
      ),
      const ShaderUniformSpec(
        key: 'u_rgb_offset',
        label: 'RGB Chromatic Shift',
        type: UniformType.float,
        min: 0.0,
        max: 0.008,
        defaultValue: 0.001,
        step: 0.0002,
        category: 'Visual Effects',
        description: 'Red/blue color separation across the display.',
      ),

      // Distortion & Movement
      const ShaderUniformSpec(
        key: 'u_curve_strength',
        label: 'Curvature Strength',
        type: UniformType.float,
        min: 0.0,
        max: 1.50,
        defaultValue: 0.35,
        step: 0.02,
        category: 'Distortion & Movement',
        description: 'Barrel curvature distortion of the curved glass CRT screen.',
      ),
      const ShaderUniformSpec(
        key: 'u_curve_distance',
        label: 'Curvature Falloff',
        type: UniformType.float,
        min: 1.0,
        max: 5.0,
        defaultValue: 2.50,
        step: 0.1,
        category: 'Distortion & Movement',
        description: 'Distance power exponent for CRT tube bulging.',
      ),
      const ShaderUniformSpec(
        key: 'u_noise_level',
        label: 'Analog Noise',
        type: UniformType.float,
        min: 0.0,
        max: 1.0,
        defaultValue: 0.10,
        step: 0.02,
        category: 'Distortion & Movement',
        description: 'Static snow and high-frequency grain.',
      ),
      const ShaderUniformSpec(
        key: 'u_flicker',
        label: '60Hz Flicker',
        type: UniformType.float,
        min: 0.0,
        max: 1.0,
        defaultValue: 0.15,
        step: 0.02,
        category: 'Distortion & Movement',
        description: 'Analog AC power line flicker.',
      ),
      const ShaderUniformSpec(
        key: 'u_h_sync',
        label: 'H-Sync Jitter',
        type: UniformType.float,
        min: 0.0,
        max: 2.0,
        defaultValue: 0.02,
        step: 0.01,
        category: 'Distortion & Movement',
        description: 'Horizontal sync instability wave across the beam.',
      ),
      const ShaderUniformSpec(
        key: 'u_rumble',
        label: 'Earthquake Rumble',
        type: UniformType.float,
        min: 0.0,
        max: 2.0,
        defaultValue: 1.0,
        step: 0.1,
        category: 'Distortion & Movement',
        description: 'Periodic apocalyptic earthquake screen shake & dimming.',
      ),

      // Environmental Light & Frame
      const ShaderUniformSpec(
        key: 'u_light_speed',
        label: 'Swaying Light Speed',
        type: UniformType.float,
        min: 0.0,
        max: 2.0,
        defaultValue: 1.0,
        step: 0.1,
        category: 'Environmental Lighting & Bezel',
        description: 'Speed of the moving environmental ambient light source.',
      ),
      const ShaderUniformSpec(
        key: 'u_frame_size',
        label: 'Bezel Frame Width',
        type: UniformType.float,
        min: 0.0,
        max: 40.0,
        defaultValue: 18.0,
        step: 1.0,
        category: 'Environmental Lighting & Bezel',
        description: 'Thickness in pixels of the virtual CRT bezel casing.',
      ),
      const ShaderUniformSpec(
        key: 'u_frame_reflect',
        label: 'Bezel Reflection',
        type: UniformType.float,
        min: 0.0,
        max: 1.0,
        defaultValue: 0.60,
        step: 0.05,
        category: 'Environmental Lighting & Bezel',
        description: 'Reflects live DAW screen content onto the plastic frame rim.',
      ),
      const ShaderUniformSpec(
        key: 'u_frame_light',
        label: 'Frame Ambient Glow',
        type: UniformType.float,
        min: 0.0,
        max: 0.20,
        defaultValue: 0.05,
        step: 0.01,
        category: 'Environmental Lighting & Bezel',
        description: 'Base illumination of the monitor bezel casing.',
      ),
      const ShaderUniformSpec(
        key: 'u_frame_grain',
        label: 'Plastic Grain',
        type: UniformType.float,
        min: 0.0,
        max: 0.50,
        defaultValue: 0.15,
        step: 0.02,
        category: 'Environmental Lighting & Bezel',
        description: 'Textured plastic grain on the monitor frame.',
      ),

      // Color & Tinting
      const ShaderUniformSpec(
        key: 'u_glass_tint',
        label: 'Glass Tint Amount',
        type: UniformType.float,
        min: 0.0,
        max: 1.0,
        defaultValue: 0.15,
        step: 0.05,
        category: 'Color & Tinting',
        description: 'Strength of color cast applied over the tube glass.',
      ),
      const ShaderUniformSpec(
        key: 'u_glass_hue',
        label: 'Glass Hue',
        type: UniformType.float,
        min: 0.0,
        max: 1.0,
        defaultValue: 0.33, // Green phosphor
        step: 0.02,
        category: 'Color & Tinting',
        description: 'Phosphor tint hue (0.08: Amber, 0.33: Green, 0.6: Cyber Blue).',
      ),
      const ShaderUniformSpec(
        key: 'u_glass_sat',
        label: 'Glass Saturation',
        type: UniformType.float,
        min: 0.0,
        max: 1.0,
        defaultValue: 0.30,
        step: 0.05,
        category: 'Color & Tinting',
        description: 'Color saturation of the glass reflection/phosphor.',
      ),
      const ShaderUniformSpec(
        key: 'u_screen_tint',
        label: 'Screen Tint Amount',
        type: UniformType.float,
        min: 0.0,
        max: 1.0,
        defaultValue: 0.0,
        step: 0.05,
        category: 'Color & Tinting',
        description: 'Colorizes the display content itself.',
      ),
      const ShaderUniformSpec(
        key: 'u_screen_sat',
        label: 'Screen Saturation',
        type: UniformType.float,
        min: 0.0,
        max: 2.0,
        defaultValue: 1.0,
        step: 0.05,
        category: 'Color & Tinting',
        description: 'Global color saturation of the phosphor content.',
      ),
    ],
    presets: {
      'Default': {
        'u_grille_level': 0.95,
        'u_grille_density': 800.0,
        'u_scanline_level': 0.80,
        'u_scanlines': 1.0,
        'u_rgb_offset': 0.001,
        'u_curve_strength': 0.35,
        'u_curve_distance': 2.50,
        'u_noise_level': 0.10,
        'u_flicker': 0.15,
        'u_h_sync': 0.02,
        'u_rumble': 1.0,
        'u_light_speed': 1.0,
        'u_frame_size': 18.0,
        'u_frame_hue': 0.025,
        'u_frame_sat': 0.10,
        'u_frame_light': 0.05,
        'u_frame_reflect': 0.60,
        'u_frame_grain': 0.15,
        'u_glass_tint': 0.15,
        'u_glass_hue': 0.33,
        'u_glass_sat': 0.30,
        'u_screen_tint': 0.0,
        'u_screen_hue': 0.0,
        'u_screen_sat': 1.0,
      },
      'Retro Arcade Bezel': {
        'u_grille_level': 1.40,
        'u_grille_density': 650.0,
        'u_scanline_level': 1.20,
        'u_scanlines': 1.0,
        'u_rgb_offset': 0.002,
        'u_curve_strength': 0.50,
        'u_curve_distance': 2.20,
        'u_noise_level': 0.18,
        'u_flicker': 0.25,
        'u_h_sync': 0.05,
        'u_rumble': 1.2,
        'u_light_speed': 1.0,
        'u_frame_size': 26.0,
        'u_frame_hue': 0.025,
        'u_frame_sat': 0.15,
        'u_frame_light': 0.06,
        'u_frame_reflect': 0.85,
        'u_frame_grain': 0.20,
        'u_glass_tint': 0.25,
        'u_glass_hue': 0.33,
        'u_glass_sat': 0.45,
        'u_screen_tint': 0.0,
        'u_screen_hue': 0.0,
        'u_screen_sat': 1.1,
      },
      'Amber Terminal': {
        'u_grille_level': 1.10,
        'u_grille_density': 700.0,
        'u_scanline_level': 0.90,
        'u_scanlines': 1.0,
        'u_rgb_offset': 0.0012,
        'u_curve_strength': 0.30,
        'u_curve_distance': 2.50,
        'u_noise_level': 0.12,
        'u_flicker': 0.18,
        'u_h_sync': 0.03,
        'u_rumble': 0.8,
        'u_light_speed': 0.8,
        'u_frame_size': 18.0,
        'u_frame_hue': 0.08,
        'u_frame_sat': 0.20,
        'u_frame_light': 0.05,
        'u_frame_reflect': 0.70,
        'u_frame_grain': 0.15,
        'u_glass_tint': 0.45,
        'u_glass_hue': 0.08, // Amber / Orange
        'u_glass_sat': 0.75,
        'u_screen_tint': 0.35,
        'u_screen_hue': 0.08,
        'u_screen_sat': 1.2,
      },
      'Glitch Mode': {
        'u_grille_level': 2.0,
        'u_grille_density': 400.0,
        'u_scanline_level': 1.8,
        'u_scanlines': 2.0,
        'u_rgb_offset': 0.006,
        'u_curve_strength': 0.60,
        'u_curve_distance': 2.0,
        'u_noise_level': 0.50,
        'u_flicker': 0.60,
        'u_h_sync': 0.80,
        'u_rumble': 2.0,
        'u_light_speed': 1.8,
        'u_frame_size': 20.0,
        'u_frame_hue': 0.85,
        'u_frame_sat': 0.60,
        'u_frame_light': 0.08,
        'u_frame_reflect': 0.90,
        'u_frame_grain': 0.35,
        'u_glass_tint': 0.35,
        'u_glass_hue': 0.85,
        'u_glass_sat': 0.60,
        'u_screen_tint': 0.25,
        'u_screen_hue': 0.85,
        'u_screen_sat': 1.3,
      },
      'Subtle Flat': {
        'u_grille_level': 0.30,
        'u_grille_density': 900.0,
        'u_scanline_level': 0.25,
        'u_scanlines': 1.0,
        'u_rgb_offset': 0.0003,
        'u_curve_strength': 0.0,
        'u_curve_distance': 1.0,
        'u_noise_level': 0.02,
        'u_flicker': 0.03,
        'u_h_sync': 0.0,
        'u_rumble': 0.0,
        'u_light_speed': 0.5,
        'u_frame_size': 0.0,
        'u_frame_hue': 0.0,
        'u_frame_sat': 0.0,
        'u_frame_light': 0.0,
        'u_frame_reflect': 0.0,
        'u_frame_grain': 0.0,
        'u_glass_tint': 0.0,
        'u_glass_hue': 0.0,
        'u_glass_sat': 0.0,
        'u_screen_tint': 0.0,
        'u_screen_hue': 0.0,
        'u_screen_sat': 1.0,
      },
    },
  );

  static const ShaderProfile accessibility = ShaderProfile(
    id: accessibilityId,
    name: 'Color Profiles',
    description:
        'Color profiles, color vision correction (Protanopia, Deuteranopia, Tritanopia), high contrast, Black & White, inverted colors, and light-sensitive eye comfort.',
    assetPath: 'assets/shaders/accessibility_colorblind.frag',
    isAnimated: false,
    uniforms: [
      ShaderUniformSpec(
        key: 'u_mode',
        label: 'Vision Profile',
        type: UniformType.float,
        min: 0.0,
        max: 6.0,
        defaultValue: 1.0,
        step: 1.0,
        category: 'Vision Profile',
        description: '0: Custom / Invert, 1: Monochrome B&W, 2: Protanopia, 3: Deuteranopia, 4: Tritanopia, 5: High Contrast, 6: Light-Sensitive Muted',
      ),
      ShaderUniformSpec(
        key: 'u_intensity',
        label: 'Filter Strength',
        type: UniformType.float,
        min: 0.0,
        max: 1.0,
        defaultValue: 1.0,
        step: 0.02,
        category: 'Tuning',
        description: 'Blend amount between original output and profile.',
      ),
      ShaderUniformSpec(
        key: 'u_invert',
        label: 'Invert Colors',
        type: UniformType.float,
        min: 0.0,
        max: 1.0,
        defaultValue: 0.0,
        step: 0.05,
        category: 'Tuning',
        description: 'Inverts color luminance for high contrast and alternate theme styling.',
      ),
      ShaderUniformSpec(
        key: 'u_brightness',
        label: 'Brightness',
        type: UniformType.float,
        min: 0.5,
        max: 1.5,
        defaultValue: 1.0,
        step: 0.02,
        category: 'Tuning',
        description: 'Master display brightness adjustment.',
      ),
      ShaderUniformSpec(
        key: 'u_contrast',
        label: 'Contrast',
        type: UniformType.float,
        min: 0.5,
        max: 2.0,
        defaultValue: 1.0,
        step: 0.02,
        category: 'Tuning',
        description: 'Display dynamic range and contrast curve.',
      ),
      ShaderUniformSpec(
        key: 'u_saturation',
        label: 'Saturation',
        type: UniformType.float,
        min: 0.0,
        max: 2.0,
        defaultValue: 1.0,
        step: 0.02,
        category: 'Tuning',
        description: 'Global color vibrancy and saturation.',
      ),
    ],
    presets: {
      'Monochrome B&W': {
        'u_mode': 1.0,
        'u_intensity': 1.0,
        'u_invert': 0.0,
        'u_brightness': 1.0,
        'u_contrast': 1.0,
        'u_saturation': 1.0,
      },
      'Invert Colors': {
        'u_mode': 0.0,
        'u_intensity': 0.0,
        'u_invert': 1.0,
        'u_brightness': 1.0,
        'u_contrast': 1.0,
        'u_saturation': 1.0,
      },
      'Protanopia (Red-Weak)': {
        'u_mode': 2.0,
        'u_intensity': 1.0,
        'u_invert': 0.0,
        'u_brightness': 1.05,
        'u_contrast': 1.1,
        'u_saturation': 1.0,
      },
      'Deuteranopia (Green-Weak)': {
        'u_mode': 3.0,
        'u_intensity': 1.0,
        'u_invert': 0.0,
        'u_brightness': 1.05,
        'u_contrast': 1.1,
        'u_saturation': 1.0,
      },
      'Tritanopia (Blue-Weak)': {
        'u_mode': 4.0,
        'u_intensity': 1.0,
        'u_invert': 0.0,
        'u_brightness': 1.0,
        'u_contrast': 1.05,
        'u_saturation': 1.0,
      },
      'High Contrast': {
        'u_mode': 5.0,
        'u_intensity': 1.0,
        'u_invert': 0.0,
        'u_brightness': 1.0,
        'u_contrast': 1.3,
        'u_saturation': 1.2,
      },
      'Light Sensitive (Eye Comfort)': {
        'u_mode': 6.0,
        'u_intensity': 1.0,
        'u_invert': 0.0,
        'u_brightness': 0.85,
        'u_contrast': 0.9,
        'u_saturation': 0.8,
      },
    },
  );

  static final List<ShaderProfile> allProfiles = [
    none,
    apocalypseCrt,
    accessibility,
  ];

  static ShaderProfile getProfileById(String id) {
    return allProfiles.firstWhere(
      (p) => p.id == id,
      orElse: () => none,
    );
  }
}
