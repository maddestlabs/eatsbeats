import 'package:flutter/material.dart';
import 'modular_theme.dart';
import 'modular_module_search_dialog.dart';

/// Identifies a physical jack on a module in the rack
class JackKey {
  final int row;
  final int moduleIndex;
  final int jackIndex;
  final String label;

  const JackKey({
    required this.row,
    required this.moduleIndex,
    required this.jackIndex,
    required this.label,
  });

  String get serializedKey => '$row:$moduleIndex:$jackIndex';

  static JackKey? fromSerializedKey(String key, {String label = 'Jack'}) {
    final parts = key.split(':');
    if (parts.length >= 3) {
      final r = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final j = int.tryParse(parts[2]);
      if (r != null && m != null && j != null) {
        return JackKey(row: r, moduleIndex: m, jackIndex: j, label: label);
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JackKey &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          moduleIndex == other.moduleIndex &&
          jackIndex == other.jackIndex;

  @override
  int get hashCode => row.hashCode ^ moduleIndex.hashCode ^ jackIndex.hashCode;
}

/// Dynamic Connection between two jacks
class DynamicPatchConnection {
  final JackKey fromKey;
  final JackKey toKey;
  final Color color;
  final double tension;

  const DynamicPatchConnection({
    required this.fromKey,
    required this.toKey,
    this.color = ModularTheme.cableAudio,
    this.tension = 0.5,
  });

  DynamicPatchConnection copyWith({
    JackKey? fromKey,
    JackKey? toKey,
    Color? color,
    double? tension,
  }) {
    return DynamicPatchConnection(
      fromKey: fromKey ?? this.fromKey,
      toKey: toKey ?? this.toKey,
      color: color ?? this.color,
      tension: tension ?? this.tension,
    );
  }
}

/// Complete In-Memory Representation of a Modular Synthesizer Rack Configuration
class ModularRackDefinition {
  final int totalRows;
  final Map<int, List<DynamicModuleDefinition>> modulesByRow;
  final List<DynamicPatchConnection> cables;

  const ModularRackDefinition({
    required this.totalRows,
    required this.modulesByRow,
    required this.cables,
  });

  ModularRackDefinition copyWith({
    int? totalRows,
    Map<int, List<DynamicModuleDefinition>>? modulesByRow,
    List<DynamicPatchConnection>? cables,
  }) {
    return ModularRackDefinition(
      totalRows: totalRows ?? this.totalRows,
      modulesByRow: modulesByRow ?? this.modulesByRow,
      cables: cables ?? this.cables,
    );
  }
}

/// Bi-directional Parser and Serializer between Lua Script code and the Modular Rack Canvas.
class ModularRackDsl {
  /// Parses a Lua script for declarative `rack()` or `rack = { ... }` definitions.
  static ModularRackDefinition? parse(String luaCode) {
    if (!luaCode.contains('.rack') && !luaCode.contains('rack =') && !luaCode.contains('rack=')) {
      return null;
    }

    try {
      final Map<int, List<DynamicModuleDefinition>> modulesByRow = {};
      final List<DynamicPatchConnection> cables = [];
      int maxRow = 2;

      // Extract cables: { from = "1:0:2", to = "1:1:0", color = "audio" }
      final cableRegex = RegExp(r'''\{\s*from\s*=\s*["']([^"']+)["']\s*,\s*to\s*=\s*["']([^"']+)["'](?:\s*,\s*color\s*=\s*["']([^"']+)["'])?''');
      for (final match in cableRegex.allMatches(luaCode)) {
        final fromStr = match.group(1);
        final toStr = match.group(2);
        final colorStr = match.group(3) ?? 'audio';

        if (fromStr != null && toStr != null) {
          final fromKey = JackKey.fromSerializedKey(fromStr);
          final toKey = JackKey.fromSerializedKey(toStr);
          if (fromKey != null && toKey != null) {
            Color cableColor = ModularTheme.cableAudio;
            if (colorStr == 'modulation' || colorStr == 'mod') {
              cableColor = ModularTheme.cableModulation;
            } else if (colorStr == 'pitch' || colorStr == 'cv') {
              cableColor = ModularTheme.cablePitchCv;
            } else if (colorStr == 'gate') {
              cableColor = ModularTheme.cableGate;
            } else if (colorStr == 'digital') {
              cableColor = ModularTheme.cableDigital;
            }

            cables.add(DynamicPatchConnection(
              fromKey: fromKey,
              toKey: toKey,
              color: cableColor,
            ));
          }
        }
      }

      // Extract modules: { id = "...", type = "...", hp = 12, row = 1, category = "..." }
      final moduleRegex = RegExp(r'''\{\s*id\s*=\s*["']([^"']+)["']\s*,\s*(?:title|type)\s*=\s*["']([^"']+)["']\s*,\s*hp\s*=\s*(\d+)(?:\s*,\s*row\s*=\s*(\d+))?(?:\s*,\s*category\s*=\s*["']([^"']+)["'])?''');
      for (final match in moduleRegex.allMatches(luaCode)) {
        final id = match.group(1) ?? 'mod';
        final title = match.group(2) ?? 'MODULE';
        final hp = int.tryParse(match.group(3) ?? '10') ?? 10;
        final row = int.tryParse(match.group(4) ?? '1') ?? 1;
        final category = match.group(5) ?? 'CORE';

        if (row > maxRow) maxRow = row;

        Color accentColor = const Color(0xFF00E5FF);
        if (category == 'VCO') accentColor = const Color(0xFFFF5722);
        if (category == 'VCF') accentColor = const Color(0xFFFF9800);
        if (category == 'MOD') accentColor = const Color(0xFF00E676);
        if (category == 'FX') accentColor = const Color(0xFF00BCD4);
        if (category == 'OUT') accentColor = const Color(0xFFFFD600);

        modulesByRow.putIfAbsent(row, () => []).add(
          DynamicModuleDefinition(
            id: id,
            title: title,
            subtitle: category,
            hpWidth: hp,
            accentColor: accentColor,
            category: category,
            inputJacks: ['In 1', 'In 2'],
            outputJacks: ['Out 1', 'Out 2'],
          ),
        );
      }

      if (modulesByRow.isEmpty && cables.isEmpty) {
        return null;
      }

      return ModularRackDefinition(
        totalRows: maxRow,
        modulesByRow: modulesByRow,
        cables: cables,
      );
    } catch (_) {
      return null;
    }
  }

  /// Detects the preset topology signature from Lua code or track name.
  static String detectSignature(String code, {String trackName = ''}) {
    final cleanCode = code.toLowerCase();
    final cleanName = trackName.toLowerCase();

    if (code.contains('FmAcousticKick') || cleanCode.contains('fm_acoustic_kick') || cleanName.contains('kick')) return 'fm_acoustic_kick';
    if (code.contains('FmAcousticSnare') || cleanCode.contains('fm_acoustic_snare') || cleanName.contains('snare')) return 'fm_acoustic_snare';
    if (code.contains('FmAcousticTom') || cleanCode.contains('fm_acoustic_tom') || cleanName.contains('tom')) return 'fm_acoustic_tom';
    if (code.contains('FmAcousticHiHat') || cleanCode.contains('fm_acoustic_hihat') || cleanName.contains('hihat') || cleanName.contains('hi-hat')) return 'fm_acoustic_hihat';
    if (code.contains('Analog808Kick') || cleanName.contains('808 kick')) return 'analog_808_kick';
    if (code.contains('Analog808Snare') || cleanName.contains('808 snare')) return 'analog_808_snare';
    if (code.contains('Analog808HiHat') || cleanName.contains('808 hihat')) return 'analog_808_hihat';
    if (code.contains('Analog808Cowbell') || cleanName.contains('808 cowbell')) return 'analog_808_cowbell';
    if (code.contains('Analog808Tom') || cleanName.contains('808 tom')) return 'analog_808_tom';
    if (code.contains('Analog909Kick') || cleanName.contains('909 kick')) return 'analog_909_kick';
    if (code.contains('Analog909Snare') || cleanName.contains('909 snare')) return 'analog_909_snare';
    if (code.contains('Analog909ClosedHiHat') || cleanName.contains('909 closed') || cleanName.contains('909 hi-hat') || cleanName.contains('909 hihat')) return 'analog_909_closed_hihat';
    if (code.contains('Analog909OpenHiHat') || cleanName.contains('909 open')) return 'analog_909_open_hihat';
    if (code.contains('Analog909Clap') || cleanName.contains('909 clap') || cleanName.contains('clap')) return 'analog_909_clap';
    if (code.contains('Analog909Rimshot') || cleanName.contains('909 rim') || cleanName.contains('rimshot')) return 'analog_909_rimshot';
    if (code.contains('Acid303') || code.contains('Eats303') || cleanName.contains('303') || cleanName.contains('acid')) return 'acid_303';
    if (code.contains('PolyLeadSynth') || cleanName.contains('poly lead')) return 'poly_lead';
    if (code.contains('YM2612') || cleanName.contains('genesis') || cleanName.contains('ym2612')) return 'ym2612_synth';
    if (code.contains('OPL3') || cleanName.contains('opl3') || cleanName.contains('chiptune')) return 'opl3_retro';
    if (code.contains('SNESSFX') || code.contains('SFXR') || cleanName.contains('sfxr')) return 'eats_sfxr';
    if (code.contains('SNESConsole') || code.contains('SNES Synth') || cleanName.contains('snes')) return 'snes_console_synth';
    if (code.contains('SoundFontSampler') || cleanName.contains('soundfont') || cleanName.contains('sf2')) return 'soundfont_sampler';
    if (code.contains('DrumKitSampler') || cleanName.contains('drum sampler') || cleanName.contains('drum kit')) return 'drum_kit_sampler';
    if (code.contains('SamplerInstrument') || cleanName.contains('sampler')) return 'sampler_instrument';
    if (code.contains('StereoDelay') || cleanName.contains('delay')) return 'lua_delay';
    if (code.contains('StereoChorus') || cleanName.contains('chorus')) return 'lua_chorus';
    if (code.contains('Bitcrusher') || cleanName.contains('crusher') || cleanName.contains('bit')) return 'bitcrusher_fx';
    if (code.contains('TubeDistortion') || cleanName.contains('tube') || cleanName.contains('distortion')) return 'tube_distortion';
    return 'generic';
  }

  /// Generates the default modular rack topology for legacy built-in presets based on signature.
  static ModularRackDefinition generateDefault(
    String signatureOrCode, {
    Map<String, double>? params,
    String trackName = 'Track',
  }) {
    final signature = signatureOrCode.contains(' ') || signatureOrCode.contains('\n')
        ? detectSignature(signatureOrCode, trackName: trackName)
        : signatureOrCode;

    final Map<int, List<DynamicModuleDefinition>> modulesByRow = {1: [], 2: []};
    final List<DynamicPatchConnection> cables = [];

    switch (signature) {
      case 'acid_303':
        modulesByRow[1] = [
          const DynamicModuleDefinition(id: 'vco', title: 'TB-303 VCO', subtitle: 'VCO', hpWidth: 12, accentColor: Color(0xFFFF5722), category: 'VCO', inputJacks: ['CV', 'Gate'], outputJacks: ['Saw', 'Square']),
          const DynamicModuleDefinition(id: 'vcf', title: '18DB RESO VCF', subtitle: 'VCF', hpWidth: 14, accentColor: Color(0xFFFF9800), category: 'VCF', inputJacks: ['Audio', 'Cutoff CV'], outputJacks: ['LP Out', 'HP Out']),
          const DynamicModuleDefinition(id: 'vca', title: 'ANALOG VCA', subtitle: 'VCA', hpWidth: 12, accentColor: Color(0xFFFFD600), category: 'OUT', inputJacks: ['Audio', 'CV'], outputJacks: ['Audio L', 'Audio R']),
        ];
        modulesByRow[2] = [
          const DynamicModuleDefinition(id: 'env', title: 'ACID ENVELOPE', subtitle: 'MOD', hpWidth: 14, accentColor: Color(0xFF00E676), category: 'MOD', inputJacks: ['Gate', 'Accent'], outputJacks: ['Env Out', 'Inv Out']),
          const DynamicModuleDefinition(id: 'master', title: 'MASTER STEREO OUT', subtitle: 'OUT', hpWidth: 14, accentColor: Color(0xFFFFD600), category: 'OUT', inputJacks: ['L In', 'R In'], outputJacks: ['Main L', 'Main R']),
        ];
        cables.addAll([
          const DynamicPatchConnection(
            fromKey: JackKey(row: 1, moduleIndex: 0, jackIndex: 1, label: 'Saw Out'),
            toKey: JackKey(row: 1, moduleIndex: 1, jackIndex: 0, label: 'Audio In'),
            color: ModularTheme.cableAudio,
            tension: 0.55,
          ),
          const DynamicPatchConnection(
            fromKey: JackKey(row: 2, moduleIndex: 0, jackIndex: 1, label: 'Env Out'),
            toKey: JackKey(row: 1, moduleIndex: 1, jackIndex: 1, label: 'Env In'),
            color: ModularTheme.cableModulation,
            tension: 0.65,
          ),
          const DynamicPatchConnection(
            fromKey: JackKey(row: 1, moduleIndex: 1, jackIndex: 2, label: 'VCF Out'),
            toKey: JackKey(row: 1, moduleIndex: 2, jackIndex: 0, label: 'In'),
            color: ModularTheme.cableAudio,
            tension: 0.45,
          ),
          const DynamicPatchConnection(
            fromKey: JackKey(row: 1, moduleIndex: 2, jackIndex: 1, label: 'Out'),
            toKey: JackKey(row: 2, moduleIndex: 1, jackIndex: 0, label: 'Audio In'),
            color: ModularTheme.cableAudio,
            tension: 0.5,
          ),
        ]);
        break;

      case 'ym2612_synth':
        modulesByRow[1] = [
          const DynamicModuleDefinition(id: 'op12', title: 'OP1-OP2 FM VCO', subtitle: 'VCO', hpWidth: 14, accentColor: Color(0xFFFF5722), category: 'VCO', inputJacks: ['Pitch', 'FM In'], outputJacks: ['FM Out', 'Direct Out']),
          const DynamicModuleDefinition(id: 'op34', title: 'OP3-OP4 FM VCO', subtitle: 'VCO', hpWidth: 14, accentColor: Color(0xFFFF5722), category: 'VCO', inputJacks: ['Carrier In', 'Mod In'], outputJacks: ['Out 1', 'Out 2']),
          const DynamicModuleDefinition(id: 'env', title: 'SSG-EG ENVELOPE', subtitle: 'MOD', hpWidth: 12, accentColor: Color(0xFF00E676), category: 'MOD', inputJacks: ['Gate', 'Trig'], outputJacks: ['EG 1', 'EG 2']),
        ];
        modulesByRow[2] = [
          const DynamicModuleDefinition(id: 'dac', title: 'YM2612 9-BIT DAC', subtitle: 'OUT', hpWidth: 14, accentColor: Color(0xFF00BCD4), category: 'FX', inputJacks: ['DAC In', 'Clock'], outputJacks: ['Analog Out', 'Ladder']),
          const DynamicModuleDefinition(id: 'master', title: 'MASTER STEREO OUT', subtitle: 'OUT', hpWidth: 14, accentColor: Color(0xFFFFD600), category: 'OUT', inputJacks: ['L In', 'R In'], outputJacks: ['Main L', 'Main R']),
        ];
        cables.addAll([
          const DynamicPatchConnection(
            fromKey: JackKey(row: 1, moduleIndex: 0, jackIndex: 2, label: 'FM Out'),
            toKey: JackKey(row: 1, moduleIndex: 2, jackIndex: 0, label: 'Carrier In'),
            color: ModularTheme.cableModulation,
            tension: 0.55,
          ),
          const DynamicPatchConnection(
            fromKey: JackKey(row: 1, moduleIndex: 2, jackIndex: 1, label: 'DAC Out'),
            toKey: JackKey(row: 2, moduleIndex: 0, jackIndex: 0, label: 'DAC In'),
            color: ModularTheme.cableAudio,
            tension: 0.45,
          ),
          const DynamicPatchConnection(
            fromKey: JackKey(row: 2, moduleIndex: 0, jackIndex: 1, label: 'Analog Out'),
            toKey: JackKey(row: 2, moduleIndex: 1, jackIndex: 0, label: 'L In'),
            color: ModularTheme.cableAudio,
            tension: 0.65,
          ),
        ]);
        break;

      case 'snes_console_synth':
        modulesByRow[1] = [
          const DynamicModuleDefinition(id: 'brr_vco', title: 'BRR WAVETABLE VCO', subtitle: 'VCO', hpWidth: 16, accentColor: Color(0xFFFF5722), category: 'VCO', inputJacks: ['Pitch', 'Table CV'], outputJacks: ['BRR L', 'BRR R']),
          const DynamicModuleDefinition(id: 'snes_adsr', title: 'ADSR / GAIN ENV', subtitle: 'MOD', hpWidth: 14, accentColor: Color(0xFF00E676), category: 'MOD', inputJacks: ['Gate', 'PMOD'], outputJacks: ['Env Out', 'Gain Out']),
        ];
        modulesByRow[2] = [
          const DynamicModuleDefinition(id: 'echo', title: '8-TAP FIR ECHO', subtitle: 'FX', hpWidth: 16, accentColor: Color(0xFF00BCD4), category: 'FX', inputJacks: ['Audio L', 'Audio R'], outputJacks: ['Echo L', 'Echo R']),
          const DynamicModuleDefinition(id: 'master', title: 'S-DSP MASTER OUT', subtitle: 'OUT', hpWidth: 14, accentColor: Color(0xFFFFD600), category: 'OUT', inputJacks: ['Main L', 'Main R'], outputJacks: ['Stereo L', 'Stereo R']),
        ];
        cables.addAll([
          const DynamicPatchConnection(
            fromKey: JackKey(row: 1, moduleIndex: 0, jackIndex: 2, label: 'BRR L'),
            toKey: JackKey(row: 2, moduleIndex: 0, jackIndex: 0, label: 'Audio L'),
            color: ModularTheme.cableAudio,
            tension: 0.5,
          ),
          const DynamicPatchConnection(
            fromKey: JackKey(row: 1, moduleIndex: 1, jackIndex: 1, label: 'Env Out'),
            toKey: JackKey(row: 2, moduleIndex: 0, jackIndex: 1, label: 'Audio R'),
            color: ModularTheme.cableModulation,
            tension: 0.6,
          ),
          const DynamicPatchConnection(
            fromKey: JackKey(row: 2, moduleIndex: 0, jackIndex: 2, label: 'Echo L'),
            toKey: JackKey(row: 2, moduleIndex: 1, jackIndex: 0, label: 'Main L'),
            color: ModularTheme.cableAudio,
            tension: 0.45,
          ),
        ]);
        break;

      case 'fm_acoustic_kick':
        modulesByRow[1] = [
          const DynamicModuleDefinition(id: 'exciter', title: 'NOISE FM EXCITER', subtitle: 'MOD', hpWidth: 11, accentColor: Color(0xFF00E676), category: 'MOD', inputJacks: ['Trig', 'Decay CV'], outputJacks: ['FM Out', 'Noise Out']),
          const DynamicModuleDefinition(id: 'carrier', title: 'BATTER CARRIER VCO', subtitle: 'VCO', hpWidth: 15, accentColor: Color(0xFFFF5722), category: 'VCO', inputJacks: ['FM In', 'Pitch In'], outputJacks: ['Sine Out', 'Sub Out', 'Audio Out']),
          const DynamicModuleDefinition(id: 'sub_eq', title: 'SUB PEAKING EQ', subtitle: 'VCF', hpWidth: 11, accentColor: Color(0xFFFF9800), category: 'VCF', inputJacks: ['Audio In', 'Gain CV'], outputJacks: ['EQ Out', 'Direct Out']),
        ];
        modulesByRow[2] = [
          const DynamicModuleDefinition(id: 'room_vco', title: 'ROOM FARFIELD VCO', subtitle: 'VCO', hpWidth: 11, accentColor: Color(0xFFFF5722), category: 'VCO', inputJacks: ['Pitch In', 'Mod In'], outputJacks: ['Room Out', 'Sub Out']),
          const DynamicModuleDefinition(id: 'delay', title: 'ROOM DELAY LINE', subtitle: 'FX', hpWidth: 14, accentColor: Color(0xFF00BCD4), category: 'FX', inputJacks: ['In', 'Distance CV'], outputJacks: ['Delayed Out', 'Wet Out']),
          const DynamicModuleDefinition(id: 'master', title: 'MASTER DUAL-MIC OUT', subtitle: 'OUT', hpWidth: 15, accentColor: Color(0xFFFFD600), category: 'OUT', inputJacks: ['Near In', 'Far In'], outputJacks: ['Master L', 'Master R', 'Direct Out']),
        ];
        cables.addAll([
          const DynamicPatchConnection(
            fromKey: JackKey(row: 1, moduleIndex: 0, jackIndex: 1, label: 'FM Out'),
            toKey: JackKey(row: 1, moduleIndex: 1, jackIndex: 0, label: 'FM In'),
            color: ModularTheme.cableModulation,
            tension: 0.6,
          ),
          const DynamicPatchConnection(
            fromKey: JackKey(row: 1, moduleIndex: 1, jackIndex: 2, label: 'Audio Out'),
            toKey: JackKey(row: 1, moduleIndex: 2, jackIndex: 0, label: 'Audio In'),
            color: ModularTheme.cableAudio,
            tension: 0.55,
          ),
          const DynamicPatchConnection(
            fromKey: JackKey(row: 1, moduleIndex: 2, jackIndex: 1, label: 'EQ Out'),
            toKey: JackKey(row: 2, moduleIndex: 2, jackIndex: 0, label: 'Near In'),
            color: ModularTheme.cableAudio,
            tension: 0.4,
          ),
          const DynamicPatchConnection(
            fromKey: JackKey(row: 2, moduleIndex: 0, jackIndex: 1, label: 'Room Out'),
            toKey: JackKey(row: 2, moduleIndex: 1, jackIndex: 0, label: 'In'),
            color: ModularTheme.cablePitchCv,
            tension: 0.65,
          ),
          const DynamicPatchConnection(
            fromKey: JackKey(row: 2, moduleIndex: 1, jackIndex: 1, label: 'Delayed Out'),
            toKey: JackKey(row: 2, moduleIndex: 2, jackIndex: 1, label: 'Far In'),
            color: ModularTheme.cablePitchCv,
            tension: 0.5,
          ),
        ]);
        break;

      case 'fm_acoustic_snare':
        modulesByRow[1] = [
          const DynamicModuleDefinition(id: 'shell_osc', title: 'DUAL SHELL VCO', subtitle: 'VCO', hpWidth: 14, accentColor: Color(0xFFFF5722), category: 'VCO', inputJacks: ['Pitch', 'Decay'], outputJacks: ['Tone Out', 'Sub Out']),
          const DynamicModuleDefinition(id: 'wire_mod', title: 'SNARE WIRE NOISE', subtitle: 'MOD', hpWidth: 14, accentColor: Color(0xFF00E676), category: 'MOD', inputJacks: ['Trig', 'Snappy'], outputJacks: ['Wire Out', 'White Noise']),
        ];
        modulesByRow[2] = [
          const DynamicModuleDefinition(id: 'snare_vcf', title: 'WIRE HPF VCF', subtitle: 'VCF', hpWidth: 14, accentColor: Color(0xFFFF9800), category: 'VCF', inputJacks: ['Wire In', 'Tone In'], outputJacks: ['Filtered Out', 'Direct Out']),
          const DynamicModuleDefinition(id: 'master', title: 'STEREO OUT VCA', subtitle: 'OUT', hpWidth: 14, accentColor: Color(0xFFFFD600), category: 'OUT', inputJacks: ['L In', 'R In'], outputJacks: ['Main L', 'Main R']),
        ];
        cables.addAll([
          const DynamicPatchConnection(
            fromKey: JackKey(row: 1, moduleIndex: 0, jackIndex: 1, label: 'Tone Out'),
            toKey: JackKey(row: 2, moduleIndex: 0, jackIndex: 1, label: 'Tone In'),
            color: ModularTheme.cableAudio,
            tension: 0.5,
          ),
          const DynamicPatchConnection(
            fromKey: JackKey(row: 1, moduleIndex: 1, jackIndex: 1, label: 'Wire Out'),
            toKey: JackKey(row: 2, moduleIndex: 0, jackIndex: 0, label: 'Wire In'),
            color: ModularTheme.cableAudio,
            tension: 0.5,
          ),
        ]);
        break;

      case 'eats_sfxr':
        modulesByRow[1] = [
          const DynamicModuleDefinition(id: 'sfx_vco', title: 'SFX GENERATOR VCO', subtitle: 'VCO', hpWidth: 16, accentColor: Color(0xFFE52521), category: 'VCO', inputJacks: ['Gate', 'Pitch CV'], outputJacks: ['Audio', 'Noise']),
          const DynamicModuleDefinition(id: 'sweep_env', title: 'PITCH SWEEP ENV', subtitle: 'MOD', hpWidth: 14, accentColor: Color(0xFF00E5FF), category: 'MOD', inputJacks: ['Gate', 'Mod In'], outputJacks: ['Pitch Out', 'Env Out']),
        ];
        modulesByRow[2] = [
          const DynamicModuleDefinition(id: 'echo_fir', title: '8-TAP FIR ECHO', subtitle: 'FX', hpWidth: 16, accentColor: Color(0xFFE52521), category: 'FX', inputJacks: ['Audio In', 'FB CV'], outputJacks: ['Echo Out', 'Wet Out']),
          const DynamicModuleDefinition(id: 'master', title: 'SFXR MASTER OUT', subtitle: 'OUT', hpWidth: 14, accentColor: Color(0xFFFFD600), category: 'OUT', inputJacks: ['L In', 'R In'], outputJacks: ['Main L', 'Main R']),
        ];
        cables.addAll([
          const DynamicPatchConnection(
            fromKey: JackKey(row: 1, moduleIndex: 1, jackIndex: 1, label: 'Pitch Out'),
            toKey: JackKey(row: 1, moduleIndex: 0, jackIndex: 1, label: 'Pitch CV'),
            color: ModularTheme.cablePitchCv,
            tension: 0.45,
          ),
          const DynamicPatchConnection(
            fromKey: JackKey(row: 1, moduleIndex: 0, jackIndex: 1, label: 'Audio Out'),
            toKey: JackKey(row: 2, moduleIndex: 0, jackIndex: 0, label: 'Audio In'),
            color: ModularTheme.cableAudio,
            tension: 0.55,
          ),
          const DynamicPatchConnection(
            fromKey: JackKey(row: 2, moduleIndex: 0, jackIndex: 1, label: 'Echo Out'),
            toKey: JackKey(row: 2, moduleIndex: 1, jackIndex: 0, label: 'L In'),
            color: ModularTheme.cableAudio,
            tension: 0.45,
          ),
        ]);
        break;

      case 'snes_console_synth':
        modulesByRow[1] = [
          const DynamicModuleDefinition(id: 'brr_vco', title: 'BRR WAVETABLE VCO', subtitle: 'VCO', hpWidth: 16, accentColor: Color(0xFFE52521), category: 'VCO', inputJacks: ['Pitch CV', 'Gate In'], outputJacks: ['Raw Wave', 'Audio Out']),
          const DynamicModuleDefinition(id: 'snes_adsr', title: 'ADSR / GAIN ENV', subtitle: 'MOD', hpWidth: 14, accentColor: Color(0xFF00E5FF), category: 'MOD', inputJacks: ['Gate In', 'Mod In'], outputJacks: ['Env Out', 'Gain Out']),
        ];
        modulesByRow[2] = [
          const DynamicModuleDefinition(id: 'echo', title: '8-TAP FIR ECHO', subtitle: 'FX', hpWidth: 16, accentColor: Color(0xFFE52521), category: 'FX', inputJacks: ['Audio In', 'Delay CV'], outputJacks: ['Echo Out', 'Wet Out']),
          const DynamicModuleDefinition(id: 'master', title: 'S-DSP MASTER OUT', subtitle: 'OUT', hpWidth: 14, accentColor: Color(0xFFFFD600), category: 'OUT', inputJacks: ['L In', 'R In'], outputJacks: ['Main L', 'Main R']),
        ];
        cables.addAll([
          const DynamicPatchConnection(
            fromKey: JackKey(row: 1, moduleIndex: 0, jackIndex: 2, label: 'Audio Out'),
            toKey: JackKey(row: 2, moduleIndex: 0, jackIndex: 0, label: 'Audio In'),
            color: ModularTheme.cableAudio,
            tension: 0.5,
          ),
          const DynamicPatchConnection(
            fromKey: JackKey(row: 1, moduleIndex: 1, jackIndex: 1, label: 'Env Out'),
            toKey: JackKey(row: 2, moduleIndex: 0, jackIndex: 1, label: 'Mod In'),
            color: ModularTheme.cableModulation,
            tension: 0.6,
          ),
          const DynamicPatchConnection(
            fromKey: JackKey(row: 2, moduleIndex: 0, jackIndex: 2, label: 'Echo Out'),
            toKey: JackKey(row: 2, moduleIndex: 1, jackIndex: 0, label: 'L In'),
            color: ModularTheme.cableAudio,
            tension: 0.45,
          ),
        ]);
        break;

      case 'generic':
      default:
        modulesByRow[1] = [
          const DynamicModuleDefinition(id: 'core', title: 'LUA SCRIPT DSP CORE', subtitle: 'DSP', hpWidth: 16, accentColor: Color(0xFF00E5FF), category: 'VCO', inputJacks: ['Pitch CV', 'Gate CV'], outputJacks: ['Audio L', 'Audio R', 'Aux Out']),
          const DynamicModuleDefinition(id: 'vcf', title: 'MULTIMODE VCF', subtitle: 'VCF', hpWidth: 14, accentColor: Color(0xFFFF9800), category: 'VCF', inputJacks: ['Audio In', 'Cutoff CV'], outputJacks: ['LP Out', 'BP Out', 'HP Out']),
        ];
        modulesByRow[2] = [
          const DynamicModuleDefinition(id: 'env', title: 'ADSR ENVELOPE', subtitle: 'MOD', hpWidth: 14, accentColor: Color(0xFF00E676), category: 'MOD', inputJacks: ['Gate In', 'Trig In'], outputJacks: ['Env Out', 'Inv Out']),
          const DynamicModuleDefinition(id: 'master', title: 'MASTER STEREO OUT', subtitle: 'OUT', hpWidth: 16, accentColor: Color(0xFFFFD600), category: 'OUT', inputJacks: ['L In', 'R In'], outputJacks: ['Main L', 'Main R']),
        ];
        cables.addAll([
          const DynamicPatchConnection(
            fromKey: JackKey(row: 1, moduleIndex: 0, jackIndex: 2, label: 'Audio L'),
            toKey: JackKey(row: 1, moduleIndex: 1, jackIndex: 0, label: 'Audio In'),
            color: ModularTheme.cableAudio,
            tension: 0.5,
          ),
          const DynamicPatchConnection(
            fromKey: JackKey(row: 2, moduleIndex: 0, jackIndex: 1, label: 'Env Out'),
            toKey: JackKey(row: 1, moduleIndex: 1, jackIndex: 1, label: 'Cutoff CV'),
            color: ModularTheme.cableModulation,
            tension: 0.6,
          ),
          const DynamicPatchConnection(
            fromKey: JackKey(row: 1, moduleIndex: 1, jackIndex: 2, label: 'LP Out'),
            toKey: JackKey(row: 2, moduleIndex: 1, jackIndex: 0, label: 'L In'),
            color: ModularTheme.cableAudio,
            tension: 0.5,
          ),
        ]);
        break;
    }

    return ModularRackDefinition(
      totalRows: 2,
      modulesByRow: modulesByRow,
      cables: cables,
    );
  }

  /// Ensures that [scriptCode] contains a declarative `function <Name>.rack()` block.
  /// If missing, synthesizes and injects the default rack definition based on preset signature.
  static String ensureRackBlock(String scriptCode, {String trackName = ''}) {
    if (scriptCode.contains('.rack') || scriptCode.contains('rack =') || scriptCode.contains('rack=')) {
      return scriptCode;
    }
    final defaultRack = generateDefault(scriptCode, trackName: trackName);
    return serialize(
      totalRows: defaultRack.totalRows,
      customModulesByRow: defaultRack.modulesByRow,
      cables: defaultRack.cables,
      existingScriptCode: scriptCode,
      instrumentName: trackName.isNotEmpty ? trackName : 'Instrument',
    );
  }

  /// Serializes the current modular rack state into standard, readable Lua code.
  /// If [existingScriptCode] is provided, replaces or injects the `function <Name>.rack()` block.
  static String serialize({
    required int totalRows,
    required Map<int, List<DynamicModuleDefinition>> customModulesByRow,
    required List<DynamicPatchConnection> cables,
    String? existingScriptCode,
    String instrumentName = 'Instrument',
  }) {
    // Detect instrument table name from existing code (e.g. 'local FmAcousticKick = {}')
    String tableName = instrumentName;
    if (existingScriptCode != null) {
      final nameMatch = RegExp(r'local\s+([A-Za-z0-9_]+)\s*=\s*\{\}').firstMatch(existingScriptCode);
      if (nameMatch != null) {
        tableName = nameMatch.group(1) ?? instrumentName;
      }
    }

    final buffer = StringBuffer();
    buffer.writeln('function $tableName.rack()');
    buffer.writeln('  return {');
    buffer.writeln('    rows = {');

    for (int r = 1; r <= totalRows; r++) {
      final modules = customModulesByRow[r] ?? [];
      buffer.writeln('      -- ROW $r');
      buffer.writeln('      {');
      for (final mod in modules) {
        buffer.writeln('        { id = "${mod.id}", title = "${mod.title}", hp = ${mod.hpWidth}, row = $r, category = "${mod.category}" },');
      }
      buffer.writeln('      },');
    }
    buffer.writeln('    },');

    buffer.writeln('    cables = {');
    for (final conn in cables) {
      String colorStr = 'audio';
      if (conn.color == ModularTheme.cableModulation) colorStr = 'modulation';
      if (conn.color == ModularTheme.cablePitchCv) colorStr = 'pitch';
      if (conn.color == ModularTheme.cableGate) colorStr = 'gate';
      if (conn.color == ModularTheme.cableDigital) colorStr = 'digital';

      buffer.writeln('      { from = "${conn.fromKey.serializedKey}", to = "${conn.toKey.serializedKey}", color = "$colorStr" },');
    }
    buffer.writeln('    }');
    buffer.writeln('  }');
    buffer.writeln('end');

    final rackBlock = buffer.toString();

    if (existingScriptCode == null || existingScriptCode.trim().isEmpty) {
      return '-- @name: $instrumentName\nlocal $tableName = {}\n\n$rackBlock\n\nreturn $tableName\n';
    }

    // Check if function <Name>.rack() already exists and replace it
    final existingRackRegex = RegExp(
      r'function\s+[A-Za-z0-9_]+\.rack\(\)[\s\S]*?end\n?',
      multiLine: true,
    );

    if (existingRackRegex.hasMatch(existingScriptCode)) {
      return existingScriptCode.replaceAll(existingRackRegex, rackBlock);
    }

    // Otherwise insert before 'return <Name>'
    final returnRegex = RegExp(r'return\s+[A-Za-z0-9_]+');
    if (returnRegex.hasMatch(existingScriptCode)) {
      return existingScriptCode.replaceFirst(returnRegex, '$rackBlock\nreturn $tableName');
    }

    // Fallback: append to end
    return '$existingScriptCode\n\n$rackBlock\n';
  }
}
