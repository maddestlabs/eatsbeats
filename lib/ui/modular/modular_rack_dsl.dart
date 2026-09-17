import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'modular_theme.dart';
import 'modular_module_search_dialog.dart';
import '../../eatscript/eats_script_engine.dart';
import '../../eatscript/eatscript_graph_model.dart';

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

/// Bi-directional Parser and Serializer between EatScript code and the Modular Rack Canvas.
class ModularRackDsl {
  /// Converts a semantic [EatscriptGraphDef] into a full [ModularRackDefinition] for visual canvas rendering.
  static ModularRackDefinition fromEatscriptGraph(EatscriptGraphDef graph) {
    final Map<int, List<DynamicModuleDefinition>> modulesByRow = {1: [], 2: []};
    final List<DynamicPatchConnection> cables = [];

    final Map<String, JackKey> outJackMap = {};
    final Map<String, Map<String, JackKey>> inJackMap = {};

    for (final node in graph.nodes) {
      int row = 1;
      if (node.type == 'adsr' ||
          node.type == 'lfo' ||
          node.type == 'decay' ||
          node.type == 'multi_burst' ||
          node.type == 'gain' ||
          node.type == 'saturate' ||
          node.type == 'delay' ||
          node.type == 'chorus' ||
          node.type == 'tremolo' ||
          node.type == 'bitcrush' ||
          node.type == 'bitcrusher' ||
          node.type == 'acoustic_body' ||
          node.type == 'mix' ||
          node.type == 'out') {
        row = 2;
      }
      final rowIndex = row;
      final modIdx = modulesByRow[rowIndex]!.length;

      Color accentColor = const Color(0xFF00E5FF);
      String category = 'CORE';
      int hp = 12;

      switch (node.type.toLowerCase()) {
        case 'osc':
          category = 'VCO';
          accentColor = const Color(0xFFFF5722);
          hp = 12;
          break;
        case 'sub':
          category = 'VCO';
          accentColor = const Color(0xFFFF7043);
          hp = 10;
          break;
        case 'noise':
          category = 'VCO';
          accentColor = const Color(0xFFB0BEC5);
          hp = 8;
          break;
        case 'lfo':
          category = 'MOD';
          accentColor = const Color(0xFFE040FB);
          hp = 10;
          break;
        case 'pitch_sweep':
          category = 'MOD';
          accentColor = const Color(0xFFE040FB);
          hp = 10;
          break;
        case 'decay':
          category = 'MOD';
          accentColor = const Color(0xFF76FF03);
          hp = 8;
          break;
        case 'gain':
          category = 'UTIL';
          accentColor = const Color(0xFF64FFDA);
          hp = 8;
          break;
        case 'multi_burst':
          category = 'MOD';
          accentColor = const Color(0xFFFFD600);
          hp = 10;
          break;
        case 'metallic_cluster':
          category = 'VCO';
          accentColor = const Color(0xFF90A4AE);
          hp = 12;
          break;
        case 'midi_to_cv':
        case 'cv':
          category = 'UTIL';
          accentColor = const Color(0xFFFF4081);
          hp = 8;
          break;
        case 'svf':
          category = 'VCF';
          accentColor = const Color(0xFFFF9800);
          hp = 14;
          break;
        case 'moog':
          category = 'VCF';
          accentColor = const Color(0xFFFF9100);
          hp = 14;
          break;
        case 'adsr':
          category = 'MOD';
          accentColor = const Color(0xFF00E676);
          hp = 12;
          break;
        case 'saturate':
          category = 'FX';
          accentColor = const Color(0xFF00BCD4);
          hp = 10;
          break;
        case 'bitcrush':
        case 'bitcrusher':
          category = 'FX';
          accentColor = const Color(0xFFFFD700);
          hp = 10;
          break;
        case 'chorus':
          category = 'FX';
          accentColor = const Color(0xFFAB47BC);
          hp = 10;
          break;
        case 'tremolo':
          category = 'FX';
          accentColor = const Color(0xFF00E5FF);
          hp = 10;
          break;
        case 'compressor':
          category = 'FX';
          accentColor = const Color(0xFF00FF9D);
          hp = 14;
          break;
        case 'limiter':
          category = 'FX';
          accentColor = const Color(0xFFFF3366);
          hp = 12;
          break;
        case 'tr909_kick':
          category = 'VCO';
          accentColor = const Color(0xFFFF5722);
          hp = 14;
          break;
        case 'tr909_snare':
          category = 'VCO';
          accentColor = const Color(0xFFFF9800);
          hp = 14;
          break;
        case 'tr909_sample':
        case 'tr909_voice':
        case 'tr909_hihat':
        case 'tr909_rimshot':
          category = 'VCO';
          accentColor = const Color(0xFFFFD600);
          hp = 12;
          break;
        case 'mix':
          category = 'UTIL';
          accentColor = const Color(0xFF78909C);
          hp = 10;
          break;
        case 'hammer':
          category = 'PHYSICAL';
          accentColor = const Color(0xFFFF5252);
          hp = 10;
          break;
        case 'pluck':
          category = 'PHYSICAL';
          accentColor = const Color(0xFFFF7043);
          hp = 10;
          break;
        case 'bow':
          category = 'PHYSICAL';
          accentColor = const Color(0xFFFF4081);
          hp = 10;
          break;
        case 'waveguide':
          category = 'PHYSICAL';
          accentColor = const Color(0xFF00E5FF);
          hp = 14;
          break;
        case 'modal_bank':
          category = 'PHYSICAL';
          accentColor = const Color(0xFF00B0FF);
          hp = 14;
          break;
        case 'acoustic_body':
          category = 'PHYSICAL';
          accentColor = const Color(0xFF8D6E63);
          hp = 12;
          break;
        case 'melodic_tom':
          category = 'PHYSICAL';
          accentColor = const Color(0xFF3A86FF);
          hp = 14;
          break;
        case 'reverse_cymbal':
          category = 'PHYSICAL';
          accentColor = const Color(0xFFFFBE0B);
          hp = 14;
          break;
        case 'delay':
          category = 'FX';
          accentColor = const Color(0xFF00E5FF);
          hp = 12;
          break;
        case 'input':
        case 'audio_in':
          category = 'UTIL';
          accentColor = const Color(0xFF00E676);
          hp = 8;
          break;
        case 'out':
          category = 'OUT';
          accentColor = const Color(0xFFFFD600);
          hp = 10;
          break;
      }

      final inJacks = node.ports.where((p) => p.isInput).map((p) => p.name).toList();
      final outJacks = node.ports.where((p) => !p.isInput).map((p) => p.name).toList();

      final modDef = DynamicModuleDefinition(
        id: node.id,
        title: node.title,
        subtitle: category,
        hpWidth: hp,
        accentColor: accentColor,
        category: category,
        inputJacks: inJacks.isNotEmpty ? inJacks : ['In'],
        outputJacks: outJacks.isNotEmpty ? outJacks : ['Out'],
      );
      modulesByRow[rowIndex]!.add(modDef);

      final outJackIdx = inJacks.length;
      outJackMap[node.id] = JackKey(row: rowIndex, moduleIndex: modIdx, jackIndex: outJackIdx, label: outJacks.firstOrNull ?? 'Out');

      inJackMap[node.id] = {};
      final inputPortDefs = node.ports.where((p) => p.isInput).toList();
      for (int i = 0; i < inputPortDefs.length; i++) {
        final p = inputPortDefs[i];
        inJackMap[node.id]![p.id] = JackKey(row: rowIndex, moduleIndex: modIdx, jackIndex: i, label: p.name);
        inJackMap[node.id]![p.name] = JackKey(row: rowIndex, moduleIndex: modIdx, jackIndex: i, label: p.name);
      }
    }

    for (final c in graph.cables) {
      final fromJack = outJackMap[c.fromNodeId];
      final nodeInJacks = inJackMap[c.toNodeId];
      final toJack = nodeInJacks?[c.toPort] ?? nodeInJacks?['in'] ?? nodeInJacks?.values.firstOrNull;

      if (fromJack != null && toJack != null) {
        cables.add(DynamicPatchConnection(
          fromKey: fromJack,
          toKey: toJack,
          color: c.color,
          tension: 0.5,
        ));
      }
    }

    return ModularRackDefinition(
      totalRows: math.max(2, modulesByRow.keys.reduce(math.max)),
      modulesByRow: modulesByRow,
      cables: cables,
    );
  }

  /// Parses an Eatscript or Eatscript script for declarative modular rack definitions.
  static ModularRackDefinition? parse(String scriptCode) {
    if (scriptCode.contains('def graph') || (EatScriptEngine.isEatScript(scriptCode) && !scriptCode.contains('function'))) {
      final graph = EatscriptGraphDef.parse(scriptCode);
      return fromEatscriptGraph(graph);
    }

    if (!scriptCode.contains('.rack') && !scriptCode.contains('rack =') && !scriptCode.contains('rack=')) {
      return null;
    }

    try {
      final Map<int, List<DynamicModuleDefinition>> modulesByRow = {};
      final List<DynamicPatchConnection> cables = [];
      int maxRow = 2;

      // Extract cables: { from = "1:0:2", to = "1:1:0", color = "audio" }
      final cableRegex = RegExp(r'''\{\s*from\s*=\s*["']([^"']+)["']\s*,\s*to\s*=\s*["']([^"']+)["'](?:\s*,\s*color\s*=\s*["']([^"']+)["'])?''');
      for (final match in cableRegex.allMatches(scriptCode)) {
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
      for (final match in moduleRegex.allMatches(scriptCode)) {
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

  /// Detects the preset topology signature from Eatscript code or track name.
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
    if (code.contains('StereoDelay') || cleanName.contains('delay')) return 'eat_delay';
    if (code.contains('StereoChorus') || cleanName.contains('chorus')) return 'eat_chorus';
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
          const DynamicModuleDefinition(id: 'vco', title: '303 VCO', subtitle: 'VCO', hpWidth: 12, accentColor: Color(0xFFFF5722), category: 'VCO', inputJacks: ['1V/Oct', 'Gate'], outputJacks: ['Saw Out', 'Square']),
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

      case 'generic':
      default:
        modulesByRow[1] = [
          const DynamicModuleDefinition(id: 'core', title: 'EATSCRIPT DSP CORE', subtitle: 'DSP', hpWidth: 16, accentColor: Color(0xFF00E5FF), category: 'VCO', inputJacks: ['Pitch CV', 'Gate CV'], outputJacks: ['Audio L', 'Audio R', 'Aux Out']),
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
    if (EatScriptEngine.isEatScript(scriptCode) || scriptCode.contains('def graph')) {
      if (scriptCode.contains('def graph')) return scriptCode;
      final defaultGraph = EatscriptGraphDef.parse(scriptCode, trackName: trackName);
      return EatscriptGraphDef.serialize(defaultGraph, existingCode: scriptCode, instrumentName: trackName);
    }
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

  /// Serializes the current modular rack state into standard, readable Eatscript code.
  /// If [existingScriptCode] is provided, replaces or injects the modular graph definition.
  static String serialize({
    required int totalRows,
    required Map<int, List<DynamicModuleDefinition>> customModulesByRow,
    required List<DynamicPatchConnection> cables,
    String? existingScriptCode,
    String instrumentName = 'Instrument',
  }) {
    final isEatScript = existingScriptCode != null &&
        (EatScriptEngine.isEatScript(existingScriptCode) || existingScriptCode.contains('def graph')) &&
        !existingScriptCode.contains('function');

    if (isEatScript) {
      final nodes = <EatscriptNodeDef>[];
      final graphCables = <EatscriptCableDef>[];
      final Map<String, String> jackToNodeMap = {};

      for (int r = 1; r <= totalRows; r++) {
        final mods = customModulesByRow[r] ?? [];
        for (int m = 0; m < mods.length; m++) {
          final mod = mods[m];
          String type = 'osc';
          if (mod.category == 'VCF' || mod.title.contains('VCF') || mod.title.contains('FILTER')) {
            type = 'svf';
          } else if (mod.category == 'MOD' || mod.title.contains('ADSR') || mod.title.contains('ENV')) {
            type = 'adsr';
          } else if (mod.category == 'FX' && (mod.title.contains('TAPE') || mod.title.contains('DELAY'))) {
            type = 'delay';
          } else if (mod.category == 'FX' || mod.title.contains('DRIVE') || mod.title.contains('SATURAT')) {
            type = 'saturate';
          } else if (mod.category == 'OUT' || mod.title.contains('OUT') || mod.title.contains('MASTER')) {
            type = 'out';
          } else if (mod.title.contains('SUB')) {
            type = 'sub';
          }

          final node = EatscriptNodeDef(
            id: mod.id.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_').toLowerCase(),
            type: type,
            title: mod.title,
            params: mod.defaultParams ?? {},
          );
          nodes.add(node);

          for (int j = 0; j < (mod.inputJacks.length + mod.outputJacks.length); j++) {
            jackToNodeMap['$r:$m:$j'] = node.id;
          }
        }
      }

      for (final conn in cables) {
        final fromNode = jackToNodeMap[conn.fromKey.serializedKey];
        final toNode = jackToNodeMap[conn.toKey.serializedKey];
        if (fromNode != null && toNode != null) {
          graphCables.add(EatscriptCableDef(
            fromNodeId: fromNode,
            fromPort: 'out',
            toNodeId: toNode,
            toPort: 'in',
            color: conn.color,
          ));
        }
      }

      final graphDef = EatscriptGraphDef(nodes: nodes, cables: graphCables);
      return EatscriptGraphDef.serialize(
        graphDef,
        existingCode: existingScriptCode,
        instrumentName: instrumentName,
      );
    }

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
      return '# @name: $instrumentName\nlocal $tableName = {}\n\n$rackBlock\n\nreturn $tableName\n';
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
