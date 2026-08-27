import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Supported acoustic materials with frequency-dependent absorption coefficients.
enum AcousticMaterialType {
  birchPlywood,
  pineWood,
  acousticFoam,
  concrete,
  studioWood,
  velvetDrapes,
  sheetMetal,
  carpet,
}

class AcousticMaterial {
  final AcousticMaterialType type;
  final String displayName;
  final double alphaLow;  // 125 - 250 Hz absorption (0.0 to 1.0)
  final double alphaMid;  // 500 - 1000 Hz absorption (0.0 to 1.0)
  final double alphaHigh; // 2000 - 4000 Hz absorption (0.0 to 1.0)
  final double diffusion; // Scattering coefficient (0.0 to 1.0)

  const AcousticMaterial({
    required this.type,
    required this.displayName,
    required this.alphaLow,
    required this.alphaMid,
    required this.alphaHigh,
    required this.diffusion,
  });

  static const Map<AcousticMaterialType, AcousticMaterial> materials = {
    AcousticMaterialType.birchPlywood: AcousticMaterial(
      type: AcousticMaterialType.birchPlywood,
      displayName: '18mm Birch Plywood (Cab)',
      alphaLow: 0.28,
      alphaMid: 0.15,
      alphaHigh: 0.10,
      diffusion: 0.25,
    ),
    AcousticMaterialType.pineWood: AcousticMaterial(
      type: AcousticMaterialType.pineWood,
      displayName: 'Pine Wood (Vintage Cab)',
      alphaLow: 0.24,
      alphaMid: 0.18,
      alphaHigh: 0.12,
      diffusion: 0.30,
    ),
    AcousticMaterialType.acousticFoam: AcousticMaterial(
      type: AcousticMaterialType.acousticFoam,
      displayName: 'Acoustic Foam / Studio',
      alphaLow: 0.15,
      alphaMid: 0.70,
      alphaHigh: 0.95,
      diffusion: 0.85,
    ),
    AcousticMaterialType.concrete: AcousticMaterial(
      type: AcousticMaterialType.concrete,
      displayName: 'Hard Concrete / Marble',
      alphaLow: 0.01,
      alphaMid: 0.02,
      alphaHigh: 0.03,
      diffusion: 0.10,
    ),
    AcousticMaterialType.studioWood: AcousticMaterial(
      type: AcousticMaterialType.studioWood,
      displayName: 'Wood Paneling (Live Room)',
      alphaLow: 0.20,
      alphaMid: 0.12,
      alphaHigh: 0.08,
      diffusion: 0.45,
    ),
    AcousticMaterialType.velvetDrapes: AcousticMaterial(
      type: AcousticMaterialType.velvetDrapes,
      displayName: 'Heavy Velvet Drapes',
      alphaLow: 0.05,
      alphaMid: 0.35,
      alphaHigh: 0.75,
      diffusion: 0.60,
    ),
    AcousticMaterialType.sheetMetal: AcousticMaterial(
      type: AcousticMaterialType.sheetMetal,
      displayName: 'Sheet Metal / Plate',
      alphaLow: 0.02,
      alphaMid: 0.03,
      alphaHigh: 0.04,
      diffusion: 0.05,
    ),
    AcousticMaterialType.carpet: AcousticMaterial(
      type: AcousticMaterialType.carpet,
      displayName: 'Thin Carpet on Concrete',
      alphaLow: 0.02,
      alphaMid: 0.15,
      alphaHigh: 0.50,
      diffusion: 0.40,
    ),
  };

  static AcousticMaterial get(AcousticMaterialType type) =>
      materials[type] ?? materials[AcousticMaterialType.birchPlywood]!;
}

/// Parameters defining a physical room or tight enclosure/cabinet space.
class AcousticSpaceParams {
  final String name;
  final double width;     // meters (Lx)
  final double length;    // meters (Ly)
  final double height;    // meters (Lz)
  final double sourceX;   // normalized or meters
  final double sourceY;
  final double sourceZ;
  final double listenerX;
  final double listenerY;
  final double listenerZ;
  final AcousticMaterialType material;
  final double rt60;      // seconds (decay time)
  final double damping;   // 0.0 (bright) to 1.0 (heavy absorption)
  final bool isCabinetMode;
  final double micDistance; // meters (e.g. 0.025 to 0.5m in cab mode)
  final double micAngleDeg; // 0 to 90 degrees off-axis
  final bool isOpenBack;    // dipole cancellation for open combo cabs

  final double stereoWidth; // meters (ear or mic spacing, default 0.20m)

  const AcousticSpaceParams({
    required this.name,
    this.width = 8.0,
    this.length = 12.0,
    this.height = 4.0,
    this.sourceX = 0.5,
    this.sourceY = 0.5,
    this.sourceZ = 0.5,
    this.listenerX = 0.5,
    this.listenerY = 0.8,
    this.listenerZ = 0.5,
    this.material = AcousticMaterialType.studioWood,
    this.rt60 = 1.8,
    this.damping = 0.5,
    this.isCabinetMode = false,
    this.micDistance = 0.05,
    this.micAngleDeg = 0.0,
    this.isOpenBack = false,
    this.stereoWidth = 0.20,
  });

  AcousticSpaceParams copyWith({
    String? name,
    double? width,
    double? length,
    double? height,
    double? sourceX,
    double? sourceY,
    double? sourceZ,
    double? listenerX,
    double? listenerY,
    double? listenerZ,
    AcousticMaterialType? material,
    double? rt60,
    double? damping,
    bool? isCabinetMode,
    double? micDistance,
    double? micAngleDeg,
    bool? isOpenBack,
    double? stereoWidth,
  }) {
    return AcousticSpaceParams(
      name: name ?? this.name,
      width: width ?? this.width,
      length: length ?? this.length,
      height: height ?? this.height,
      sourceX: sourceX ?? this.sourceX,
      sourceY: sourceY ?? this.sourceY,
      sourceZ: sourceZ ?? this.sourceZ,
      listenerX: listenerX ?? this.listenerX,
      listenerY: listenerY ?? this.listenerY,
      listenerZ: listenerZ ?? this.listenerZ,
      material: material ?? this.material,
      rt60: rt60 ?? this.rt60,
      damping: damping ?? this.damping,
      isCabinetMode: isCabinetMode ?? this.isCabinetMode,
      micDistance: micDistance ?? this.micDistance,
      micAngleDeg: micAngleDeg ?? this.micAngleDeg,
      isOpenBack: isOpenBack ?? this.isOpenBack,
      stereoWidth: stereoWidth ?? this.stereoWidth,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'width': width,
    'length': length,
    'height': height,
    'sourceX': sourceX,
    'sourceY': sourceY,
    'sourceZ': sourceZ,
    'listenerX': listenerX,
    'listenerY': listenerY,
    'listenerZ': listenerZ,
    'material': material.index,
    'rt60': rt60,
    'damping': damping,
    'isCabinetMode': isCabinetMode,
    'micDistance': micDistance,
    'micAngleDeg': micAngleDeg,
    'isOpenBack': isOpenBack,
    'stereoWidth': stereoWidth,
  };

  factory AcousticSpaceParams.fromJson(Map<String, dynamic> json) {
    return AcousticSpaceParams(
      name: json['name'] as String? ?? 'Custom Space',
      width: (json['width'] as num?)?.toDouble() ?? 8.0,
      length: (json['length'] as num?)?.toDouble() ?? 12.0,
      height: (json['height'] as num?)?.toDouble() ?? 4.0,
      sourceX: (json['sourceX'] as num?)?.toDouble() ?? 0.5,
      sourceY: (json['sourceY'] as num?)?.toDouble() ?? 0.5,
      sourceZ: (json['sourceZ'] as num?)?.toDouble() ?? 0.5,
      listenerX: (json['listenerX'] as num?)?.toDouble() ?? 0.5,
      listenerY: (json['listenerY'] as num?)?.toDouble() ?? 0.8,
      listenerZ: (json['listenerZ'] as num?)?.toDouble() ?? 0.5,
      material: AcousticMaterialType.values[(json['material'] as int?) ?? 0],
      rt60: (json['rt60'] as num?)?.toDouble() ?? 1.8,
      damping: (json['damping'] as num?)?.toDouble() ?? 0.5,
      isCabinetMode: json['isCabinetMode'] as bool? ?? false,
      micDistance: (json['micDistance'] as num?)?.toDouble() ?? 0.05,
      micAngleDeg: (json['micAngleDeg'] as num?)?.toDouble() ?? 0.0,
      isOpenBack: json['isOpenBack'] as bool? ?? false,
      stereoWidth: (json['stereoWidth'] as num?)?.toDouble() ?? 0.20,
    );
  }
}

/// Generates high-fidelity Impulse Responses purely through physics-based geometric modeling
/// and filtered velvet noise stochastic synthesis.
class ProceduralIRGenerator {
  static const double speedOfSound = 343.0; // m/s

  /// Standard Presets for Rooms and Amp Cabinets
  static const Map<String, AcousticSpaceParams> presets = {
    // --- Room & Hall Presets ---
    'Stone Cathedral': AcousticSpaceParams(
      name: 'Stone Cathedral',
      width: 24.0,
      length: 45.0,
      height: 18.0,
      material: AcousticMaterialType.concrete,
      rt60: 3.8,
      damping: 0.15,
      isCabinetMode: false,
    ),
    'Great Hall': AcousticSpaceParams(
      name: 'Great Hall',
      width: 15.0,
      length: 25.0,
      height: 10.0,
      material: AcousticMaterialType.studioWood,
      rt60: 1.6,
      damping: 0.25,
      isCabinetMode: false,
    ),
    'Studio Live Room': AcousticSpaceParams(
      name: 'Studio Live Room',
      width: 6.5,
      length: 9.0,
      height: 3.5,
      material: AcousticMaterialType.studioWood,
      rt60: 0.65,
      damping: 0.40,
      isCabinetMode: false,
    ),
    'Warm Room': AcousticSpaceParams(
      name: 'Warm Room',
      width: 5.0,
      length: 6.5,
      height: 3.0,
      material: AcousticMaterialType.studioWood,
      rt60: 0.60,
      damping: 0.35,
      isCabinetMode: false,
    ),
    'Small Vocal Booth': AcousticSpaceParams(
      name: 'Small Vocal Booth',
      width: 1.8,
      length: 2.0,
      height: 2.3,
      material: AcousticMaterialType.acousticFoam,
      rt60: 0.18,
      damping: 0.85,
      isCabinetMode: false,
    ),
    'Tile Bathroom': AcousticSpaceParams(
      name: 'Tile Bathroom',
      width: 2.5,
      length: 3.0,
      height: 2.6,
      material: AcousticMaterialType.concrete,
      rt60: 1.1,
      damping: 0.10,
      isCabinetMode: false,
    ),
    'Plate Reverb': AcousticSpaceParams(
      name: 'Plate Reverb',
      width: 3.0,
      length: 4.0,
      height: 2.0,
      material: AcousticMaterialType.sheetMetal,
      rt60: 1.5,
      damping: 0.08,
      isCabinetMode: false,
    ),
    'Spring Tank': AcousticSpaceParams(
      name: 'Spring Tank',
      width: 1.2,
      length: 0.6,
      height: 0.4,
      material: AcousticMaterialType.sheetMetal,
      rt60: 1.2,
      damping: 0.35,
      isCabinetMode: false,
    ),

    // --- Amp Cabinet & Enclosure Presets ---
    '4x12 Vintage Stack (Closed)': AcousticSpaceParams(
      name: '4x12 Vintage Stack (Closed)',
      width: 0.76,
      length: 0.76,
      height: 0.36,
      material: AcousticMaterialType.birchPlywood,
      rt60: 0.035, // 35ms IR
      damping: 0.55,
      isCabinetMode: true,
      micDistance: 0.05,
      micAngleDeg: 0.0,
      isOpenBack: false,
    ),
    '2x12 British Celestion': AcousticSpaceParams(
      name: '2x12 British Celestion',
      width: 0.70,
      length: 0.52,
      height: 0.30,
      material: AcousticMaterialType.birchPlywood,
      rt60: 0.030,
      damping: 0.50,
      isCabinetMode: true,
      micDistance: 0.08,
      micAngleDeg: 25.0,
      isOpenBack: false,
    ),
    '1x12 Tweed Combo (Open-Back)': AcousticSpaceParams(
      name: '1x12 Tweed Combo (Open-Back)',
      width: 0.50,
      length: 0.42,
      height: 0.24,
      material: AcousticMaterialType.pineWood,
      rt60: 0.025,
      damping: 0.45,
      isCabinetMode: true,
      micDistance: 0.03,
      micAngleDeg: 15.0,
      isOpenBack: true,
    ),
    'Bass 8x10 Fridge': AcousticSpaceParams(
      name: 'Bass 8x10 Fridge',
      width: 0.66,
      length: 1.22,
      height: 0.41,
      material: AcousticMaterialType.birchPlywood,
      rt60: 0.045,
      damping: 0.60,
      isCabinetMode: true,
      micDistance: 0.10,
      micAngleDeg: 0.0,
      isOpenBack: false,
    ),
    'Small Radio Speaker': AcousticSpaceParams(
      name: 'Small Radio Speaker',
      width: 0.20,
      length: 0.15,
      height: 0.12,
      material: AcousticMaterialType.pineWood,
      rt60: 0.020,
      damping: 0.75,
      isCabinetMode: true,
      micDistance: 0.04,
      micAngleDeg: 0.0,
      isOpenBack: true,
    ),
  };

  /// Generates a synthesized Impulse Response PCM buffer (`List<double>`) from acoustic parameters.
  static List<double> generate(AcousticSpaceParams p, {int sampleRate = 44100}) {
    final stereo = generateStereo(p, sampleRate: sampleRate);
    return stereo.left;
  }

  /// Generates a true stereo pair of synthesized Impulse Response buffers (`left` and `right`).
  static ({List<double> left, List<double> right}) generateStereo(AcousticSpaceParams p, {int sampleRate = 44100}) {
    if (p.isCabinetMode) {
      return _generateCabinetIRStereo(p, sampleRate: sampleRate);
    } else {
      return _generateRoomIRStereo(p, sampleRate: sampleRate);
    }
  }

  /// Synthesizes binaural room impulse responses using dual-ear ISM early reflections + decorrelated Velvet Noise.
  static ({List<double> left, List<double> right}) _generateRoomIRStereo(AcousticSpaceParams p, {required int sampleRate}) {
    final totalSamples = math.max(512, (p.rt60 * sampleRate).toInt());
    final irL = List<double>.filled(totalSamples, 0.0);
    final irR = List<double>.filled(totalSamples, 0.0);
    final mat = AcousticMaterial.get(p.material);

    final sx = (p.sourceX * p.width).clamp(0.01, p.width - 0.01);
    final sy = (p.sourceY * p.length).clamp(0.01, p.length - 0.01);
    final sz = (p.sourceZ * p.height).clamp(0.01, p.height - 0.01);

    final earOffset = (p.stereoWidth * 0.5).clamp(0.02, p.width * 0.4);
    final rxCenter = (p.listenerX * p.width).clamp(0.05, p.width - 0.05);
    final ry = (p.listenerY * p.length).clamp(0.01, p.length - 0.01);
    final rz = (p.listenerZ * p.height).clamp(0.01, p.height - 0.01);

    final rxL = (rxCenter - earOffset).clamp(0.01, p.width - 0.01);
    final rxR = (rxCenter + earOffset).clamp(0.01, p.width - 0.01);

    // --- Phase A: Early Reflections (Image Source Method, Order <= 3) ---
    const order = 3;
    final avgReflect = 1.0 - ((mat.alphaLow + mat.alphaMid + mat.alphaHigh) / 3.0);
    final userDampFactor = 1.0 - (p.damping * 0.4).clamp(0.0, 0.8);

    for (int u = -order; u <= order; ++u) {
      for (int v = -order; v <= order; ++v) {
        for (int w = -order; w <= order; ++w) {
          if (u == 0 && v == 0 && w == 0) continue; // Direct path handled separately

          // Virtual image source calculation
          final ix = (u.isEven ? u * p.width + sx : u * p.width + (p.width - sx));
          final iy = (v.isEven ? v * p.length + sy : v * p.length + (p.length - sy));
          final iz = (w.isEven ? w * p.height + sz : w * p.height + (p.height - sz));

          final bounces = u.abs() + v.abs() + w.abs();
          final sign = (bounces % 2 == 0) ? 1.0 : -1.0;
          final bounceAtten = math.pow(avgReflect * userDampFactor, bounces);

          // Left Ear Ray
          final dxL = ix - rxL;
          final dyL = iy - ry;
          final dzL = iz - rz;
          final distL = math.sqrt(dxL * dxL + dyL * dyL + dzL * dzL);
          final delaySamplesL = (distL / speedOfSound * sampleRate).toInt();
          if (delaySamplesL < totalSamples) {
            final attenL = (1.0 / (distL + 1.0)) * bounceAtten;
            irL[delaySamplesL] += (sign * attenL).toDouble();
          }

          // Right Ear Ray
          final dxR = ix - rxR;
          final dyR = iy - ry;
          final dzR = iz - rz;
          final distR = math.sqrt(dxR * dxR + dyR * dyR + dzR * dzR);
          final delaySamplesR = (distR / speedOfSound * sampleRate).toInt();
          if (delaySamplesR < totalSamples) {
            final attenR = (1.0 / (distR + 1.0)) * bounceAtten;
            irR[delaySamplesR] += (sign * attenR).toDouble();
          }
        }
      }
    }

    // Direct Arrival Spikes for Left and Right Ears
    final directDistL = math.sqrt(math.pow(sx - rxL, 2) + math.pow(sy - ry, 2) + math.pow(sz - rz, 2));
    final directDelayL = (directDistL / speedOfSound * sampleRate).toInt().clamp(0, totalSamples - 1);
    irL[directDelayL] += 1.0 / (directDistL + 1.0);

    final directDistR = math.sqrt(math.pow(sx - rxR, 2) + math.pow(sy - ry, 2) + math.pow(sz - rz, 2));
    final directDelayR = (directDistR / speedOfSound * sampleRate).toInt().clamp(0, totalSamples - 1);
    irR[directDelayR] += 1.0 / (directDistR + 1.0);

    // --- Phase B: Dual-Seed Velvet Noise Late Diffuse Tail (Stereo Decorrelation) ---
    final decayCoeff = 6.907755 / (p.rt60 * sampleRate); // ln(1000) / (rt60 * fs)
    const velvetGrid = 4; // Dense ternary pulse grid
    final rngL = math.Random(1337);
    final rngR = math.Random(7331); // Decorrelated seed for Right Channel

    final lpAlpha = (1.0 - (p.damping * 0.6 + mat.alphaHigh * 0.3)).clamp(0.05, 0.98);
    double lpStateL = 0.0;
    double lpStateR = 0.0;

    for (int n = 0; n < totalSamples; n++) {
      final env = math.exp(-decayCoeff * n);

      // Left Channel Pulse
      double pulseL = 0.0;
      if (n % velvetGrid == 0) {
        final r = rngL.nextInt(3);
        pulseL = (r == 1) ? 1.0 : (r == 2) ? -1.0 : 0.0;
      }
      lpStateL = (1.0 - lpAlpha) * (pulseL * env) + lpAlpha * lpStateL;
      irL[n] += lpStateL * 0.35;

      // Right Channel Pulse
      double pulseR = 0.0;
      if (n % velvetGrid == 0) {
        final r = rngR.nextInt(3);
        pulseR = (r == 1) ? 1.0 : (r == 2) ? -1.0 : 0.0;
      }
      lpStateR = (1.0 - lpAlpha) * (pulseR * env) + lpAlpha * lpStateR;
      irR[n] += lpStateR * 0.35;
    }

    // --- Phase C: Peak Normalization across both stereo channels ---
    _normalizeStereo(irL, irR);
    return (left: irL, right: irR);
  }

  /// Synthesizes tight-space amp cabinet stereo impulse responses.
  static ({List<double> left, List<double> right}) _generateCabinetIRStereo(AcousticSpaceParams p, {required int sampleRate}) {
    final totalSamples = math.max(256, (p.rt60.clamp(0.015, 0.08) * sampleRate).toInt());
    final irL = List<double>.filled(totalSamples, 0.0);
    final irR = List<double>.filled(totalSamples, 0.0);

    final bassFreq = p.name.contains('Bass') ? 55.0 : 85.0;
    final highCutFreq = p.name.contains('Radio') ? 3500.0 : 5000.0;
    final presenceFreq = 3200.0;

    final angleRadL = (p.micAngleDeg.clamp(0.0, 90.0)) * (math.pi / 180.0);
    final angleRadR = ((p.micAngleDeg + 8.0).clamp(0.0, 90.0)) * (math.pi / 180.0);
    final offAxisHighDampingL = math.cos(angleRadL).clamp(0.2, 1.0);
    final offAxisHighDampingR = math.cos(angleRadR).clamp(0.2, 1.0);

    irL[0] = 1.0;
    irR[0] = 1.0;

    final enclosureDims = [p.width, p.length, p.height];
    final mat = AcousticMaterial.get(p.material);
    final boxReflect = 1.0 - ((mat.alphaLow + mat.alphaMid) / 2.0);

    for (int dim = 0; dim < 3; dim++) {
      final dimDist = enclosureDims[dim];
      final roundTripTime = (dimDist * 2.0) / speedOfSound;
      final roundTripSamples = (roundTripTime * sampleRate).toInt();

      if (roundTripSamples > 0 && roundTripSamples < totalSamples) {
        irL[roundTripSamples] += 0.45 * boxReflect;
        irR[roundTripSamples] += 0.42 * boxReflect;
        if (roundTripSamples * 2 < totalSamples) {
          irL[roundTripSamples * 2] -= 0.25 * boxReflect * boxReflect;
          irR[roundTripSamples * 2] -= 0.23 * boxReflect * boxReflect;
        }
      }
    }

    if (p.isOpenBack) {
      final rearPathDist = p.length + p.micDistance;
      final rearDelaySamples = (rearPathDist / speedOfSound * sampleRate).toInt();
      if (rearDelaySamples < totalSamples) {
        irL[rearDelaySamples] -= 0.65;
        irR[rearDelaySamples] -= 0.60;
      }
    }

    final filteredL = _applySpeakerFilter(
      irL,
      sampleRate: sampleRate.toDouble(),
      bassFreq: bassFreq,
      presenceFreq: presenceFreq,
      highCutFreq: highCutFreq * offAxisHighDampingL,
    );

    final filteredR = _applySpeakerFilter(
      irR,
      sampleRate: sampleRate.toDouble(),
      bassFreq: bassFreq * 1.02,
      presenceFreq: presenceFreq * 0.98,
      highCutFreq: highCutFreq * offAxisHighDampingR,
    );

    for (int i = 0; i < filteredL.length; i++) {
      final decay = math.exp(-i / (totalSamples * 0.4));
      filteredL[i] *= decay;
      filteredR[i] *= decay;
    }

    _normalizeStereo(filteredL, filteredR);
    return (left: filteredL, right: filteredR);
  }

  static void _normalizeStereo(List<double> left, List<double> right) {
    double peak = 0.0;
    for (final s in left) {
      final abs = s.abs();
      if (abs > peak) peak = abs;
    }
    for (final s in right) {
      final abs = s.abs();
      if (abs > peak) peak = abs;
    }

    if (peak > 1e-6) {
      final gain = 0.95 / peak;
      for (int i = 0; i < left.length; i++) {
        left[i] *= gain;
        right[i] *= gain;
      }
    }
  }

  /// Digital Biquad filter chain applying speaker cone physical impedance & frequency response.
  static List<double> _applySpeakerFilter(
    List<double> input, {
    required double sampleRate,
    required double bassFreq,
    required double presenceFreq,
    required double highCutFreq,
  }) {
    final output = List<double>.from(input);

    // A. 2nd-order High-Pass (Bass resonance bump with Q=1.8)
    final hpf = _BiquadFilter.highPass(sampleRate, bassFreq, 1.8);
    hpf.processInPlace(output);

    // B. Presence Peak Filter (~3.2 kHz, +4.5 dB, Q=1.4)
    final peak = _BiquadFilter.peakingEQ(sampleRate, presenceFreq, 1.4, 4.5);
    peak.processInPlace(output);

    // C. 2nd-order Low-Pass (Speaker cone treble cutoff ~5 kHz, Q=0.707)
    final lpf = _BiquadFilter.lowPass(sampleRate, highCutFreq, 0.8);
    lpf.processInPlace(output);

    return output;
  }

  /// Normalizes peak amplitude to -0.5 dBFS (0.944).
  static List<double> _normalize(List<double> buffer) {
    double peak = 0.0;
    for (final s in buffer) {
      final abs = s.abs();
      if (abs > peak) peak = abs;
    }

    if (peak > 1e-6) {
      final gain = 0.95 / peak;
      for (int i = 0; i < buffer.length; i++) {
        buffer[i] *= gain;
      }
    }
    return buffer;
  }
}

/// Helper Biquad Filter for DSP speaker frequency shaping.
class _BiquadFilter {
  double b0 = 1, b1 = 0, b2 = 0, a1 = 0, a2 = 0;
  double x1 = 0, x2 = 0, y1 = 0, y2 = 0;

  _BiquadFilter();

  factory _BiquadFilter.highPass(double fs, double fc, double q) {
    final f = _BiquadFilter();
    final w0 = 2.0 * math.pi * fc / fs;
    final alpha = math.sin(w0) / (2.0 * q);
    final cosw0 = math.cos(w0);

    final a0 = 1.0 + alpha;
    f.b0 = ((1.0 + cosw0) / 2.0) / a0;
    f.b1 = (-(1.0 + cosw0)) / a0;
    f.b2 = ((1.0 + cosw0) / 2.0) / a0;
    f.a1 = (-2.0 * cosw0) / a0;
    f.a2 = (1.0 - alpha) / a0;
    return f;
  }

  factory _BiquadFilter.lowPass(double fs, double fc, double q) {
    final f = _BiquadFilter();
    final w0 = 2.0 * math.pi * fc / fs;
    final alpha = math.sin(w0) / (2.0 * q);
    final cosw0 = math.cos(w0);

    final a0 = 1.0 + alpha;
    f.b0 = ((1.0 - cosw0) / 2.0) / a0;
    f.b1 = (1.0 - cosw0) / a0;
    f.b2 = ((1.0 - cosw0) / 2.0) / a0;
    f.a1 = (-2.0 * cosw0) / a0;
    f.a2 = (1.0 - alpha) / a0;
    return f;
  }

  factory _BiquadFilter.peakingEQ(double fs, double fc, double q, double gainDb) {
    final f = _BiquadFilter();
    final a = math.pow(10.0, gainDb / 40.0).toDouble();
    final w0 = 2.0 * math.pi * fc / fs;
    final alpha = math.sin(w0) / (2.0 * q);
    final cosw0 = math.cos(w0);

    final a0 = 1.0 + alpha / a;
    f.b0 = (1.0 + alpha * a) / a0;
    f.b1 = (-2.0 * cosw0) / a0;
    f.b2 = (1.0 - alpha * a) / a0;
    f.a1 = (-2.0 * cosw0) / a0;
    f.a2 = (1.0 - alpha / a) / a0;
    return f;
  }

  void processInPlace(List<double> buffer) {
    for (int i = 0; i < buffer.length; i++) {
      final x = buffer[i];
      final y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
      x2 = x1;
      x1 = x;
      y2 = y1;
      y1 = y;
      buffer[i] = y;
    }
  }
}
