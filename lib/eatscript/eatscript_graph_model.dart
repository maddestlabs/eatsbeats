import 'dart:typed_data';
import 'package:flutter/material.dart' show Color, Offset;
import '../audio/graph/graph_node.dart';
import '../audio/graph/graph_primitives.dart';
import '../audio/graph/tr909_rom_data.dart';

/// Semantic port definition on a modular graph node.
class EatscriptPortDef {
  final String id;
  final String name;
  final bool isInput;
  final String signalType; // 'audio', 'cv', 'gate'

  const EatscriptPortDef({
    required this.id,
    required this.name,
    required this.isInput,
    this.signalType = 'audio',
  });
}

/// A modular graph node definition representing an Eatscript `eat.node.*` call.
class EatscriptNodeDef {
  final String id;
  final String type; // 'osc', 'sub', 'svf', 'adsr', 'saturate', 'delay', 'out'
  final String title;
  final Map<String, dynamic> params;
  final List<EatscriptPortDef> ports;
  Offset position;

  EatscriptNodeDef({
    required this.id,
    required this.type,
    required this.title,
    this.params = const {},
    List<EatscriptPortDef>? ports,
    this.position = Offset.zero,
  }) : ports = ports ?? _defaultPortsFor(type);

  static List<EatscriptPortDef> _defaultPortsFor(String type) {
    switch (type.toLowerCase()) {
      case 'osc':
        return const [
          EatscriptPortDef(id: 'pitch_cv', name: 'Pitch CV', isInput: true, signalType: 'cv'),
          EatscriptPortDef(id: 'fm_in', name: 'FM In', isInput: true, signalType: 'audio'),
          EatscriptPortDef(id: 'out', name: 'Audio Out', isInput: false, signalType: 'audio'),
        ];
      case 'sub':
        return const [
          EatscriptPortDef(id: 'pitch_cv', name: 'Pitch CV', isInput: true, signalType: 'cv'),
          EatscriptPortDef(id: 'out', name: 'Sub Out', isInput: false, signalType: 'audio'),
        ];
      case 'noise':
        return const [
          EatscriptPortDef(id: 'out', name: 'Noise Out', isInput: false, signalType: 'audio'),
        ];
      case 'lfo':
        return const [
          EatscriptPortDef(id: 'rate_cv', name: 'Rate CV', isInput: true, signalType: 'cv'),
          EatscriptPortDef(id: 'out', name: 'LFO Out', isInput: false, signalType: 'cv'),
        ];
      case 'svf':
        return const [
          EatscriptPortDef(id: 'in', name: 'Audio In', isInput: true, signalType: 'audio'),
          EatscriptPortDef(id: 'cutoff_cv', name: 'Cutoff CV', isInput: true, signalType: 'cv'),
          EatscriptPortDef(id: 'out', name: 'Filter Out', isInput: false, signalType: 'audio'),
        ];
      case 'moog':
        return const [
          EatscriptPortDef(id: 'in', name: 'Audio In', isInput: true, signalType: 'audio'),
          EatscriptPortDef(id: 'cutoff_cv', name: 'Cutoff CV', isInput: true, signalType: 'cv'),
          EatscriptPortDef(id: 'reso_cv', name: 'Reso CV', isInput: true, signalType: 'cv'),
          EatscriptPortDef(id: 'out', name: 'Ladder Out', isInput: false, signalType: 'audio'),
        ];
      case 'adsr':
        return const [
          EatscriptPortDef(id: 'gate', name: 'Gate In', isInput: true, signalType: 'gate'),
          EatscriptPortDef(id: 'env_out', name: 'Env Out', isInput: false, signalType: 'cv'),
        ];
      case 'saturate':
        return const [
          EatscriptPortDef(id: 'in', name: 'Audio In', isInput: true, signalType: 'audio'),
          EatscriptPortDef(id: 'out', name: 'Drive Out', isInput: false, signalType: 'audio'),
        ];
      case 'mix':
        return const [
          EatscriptPortDef(id: 'in_a', name: 'In A', isInput: true, signalType: 'audio'),
          EatscriptPortDef(id: 'in_b', name: 'In B', isInput: true, signalType: 'audio'),
          EatscriptPortDef(id: 'balance_cv', name: 'Bal CV', isInput: true, signalType: 'cv'),
          EatscriptPortDef(id: 'out', name: 'Mix Out', isInput: false, signalType: 'audio'),
        ];
      case 'hammer':
        return const [
          EatscriptPortDef(id: 'strike_cv', name: 'Strike CV', isInput: true, signalType: 'cv'),
          EatscriptPortDef(id: 'hardness_cv', name: 'Hardness', isInput: true, signalType: 'cv'),
          EatscriptPortDef(id: 'out', name: 'Impulse Out', isInput: false, signalType: 'audio'),
        ];
      case 'pluck':
        return const [
          EatscriptPortDef(id: 'trigger', name: 'Trigger', isInput: true, signalType: 'gate'),
          EatscriptPortDef(id: 'pos_cv', name: 'Position', isInput: true, signalType: 'cv'),
          EatscriptPortDef(id: 'out', name: 'Pluck Out', isInput: false, signalType: 'audio'),
        ];
      case 'bow':
        return const [
          EatscriptPortDef(id: 'pressure_cv', name: 'Pressure', isInput: true, signalType: 'cv'),
          EatscriptPortDef(id: 'speed_cv', name: 'Speed CV', isInput: true, signalType: 'cv'),
          EatscriptPortDef(id: 'out', name: 'Friction Out', isInput: false, signalType: 'audio'),
        ];
      case 'waveguide':
        return const [
          EatscriptPortDef(id: 'in', name: 'Exciter In', isInput: true, signalType: 'audio'),
          EatscriptPortDef(id: 'damp_cv', name: 'Damping', isInput: true, signalType: 'cv'),
          EatscriptPortDef(id: 'fb_cv', name: 'Feedback', isInput: true, signalType: 'cv'),
          EatscriptPortDef(id: 'out', name: 'String Out', isInput: false, signalType: 'audio'),
        ];
      case 'modal_bank':
        return const [
          EatscriptPortDef(id: 'in', name: 'Impulse In', isInput: true, signalType: 'audio'),
          EatscriptPortDef(id: 'decay_cv', name: 'Decay CV', isInput: true, signalType: 'cv'),
          EatscriptPortDef(id: 'out', name: 'Resonator Out', isInput: false, signalType: 'audio'),
        ];
      case 'acoustic_body':
        return const [
          EatscriptPortDef(id: 'in', name: 'Audio In', isInput: true, signalType: 'audio'),
          EatscriptPortDef(id: 'size_cv', name: 'Body Size', isInput: true, signalType: 'cv'),
          EatscriptPortDef(id: 'out', name: 'Body Out', isInput: false, signalType: 'audio'),
        ];
      case 'delay':
        return const [
          EatscriptPortDef(id: 'in', name: 'Audio In', isInput: true, signalType: 'audio'),
          EatscriptPortDef(id: 'out', name: 'Delay Out', isInput: false, signalType: 'audio'),
        ];
      case 'input':
      case 'audio_in':
        return const [
          EatscriptPortDef(id: 'out', name: 'Audio Out', isInput: false, signalType: 'audio'),
        ];
      case 'pitch_sweep':
        return const [
          EatscriptPortDef(id: 'out', name: 'Pitch CV', isInput: false, signalType: 'cv'),
        ];
      case 'decay':
        return const [
          EatscriptPortDef(id: 'gate', name: 'Gate In', isInput: true, signalType: 'gate'),
          EatscriptPortDef(id: 'out', name: 'Env Out', isInput: false, signalType: 'cv'),
        ];
      case 'gain':
        return const [
          EatscriptPortDef(id: 'in', name: 'Audio In', isInput: true, signalType: 'audio'),
          EatscriptPortDef(id: 'gain_cv', name: 'Gain CV', isInput: true, signalType: 'cv'),
          EatscriptPortDef(id: 'out', name: 'Audio Out', isInput: false, signalType: 'audio'),
        ];
      case 'multi_burst':
        return const [
          EatscriptPortDef(id: 'gate', name: 'Gate In', isInput: true, signalType: 'gate'),
          EatscriptPortDef(id: 'out', name: 'Burst Out', isInput: false, signalType: 'cv'),
        ];
      case 'metallic_cluster':
        return const [
          EatscriptPortDef(id: 'pitch_cv', name: 'Pitch CV', isInput: true, signalType: 'cv'),
          EatscriptPortDef(id: 'out', name: 'Cluster Out', isInput: false, signalType: 'audio'),
        ];
      case 'midi_to_cv':
      case 'cv':
        return const [
          EatscriptPortDef(id: 'pitch_cv', name: '1V/Oct', isInput: false, signalType: 'cv'),
          EatscriptPortDef(id: 'gate', name: 'Gate Out', isInput: false, signalType: 'gate'),
          EatscriptPortDef(id: 'vel_cv', name: 'Velocity', isInput: false, signalType: 'cv'),
        ];
      case 'bitcrush':
      case 'bitcrusher':
        return const [
          EatscriptPortDef(id: 'in', name: 'Audio In', isInput: true, signalType: 'audio'),
          EatscriptPortDef(id: 'out', name: 'Crushed Out', isInput: false, signalType: 'audio'),
        ];
      case 'chorus':
        return const [
          EatscriptPortDef(id: 'in', name: 'Audio In', isInput: true, signalType: 'audio'),
          EatscriptPortDef(id: 'rate_cv', name: 'Rate CV', isInput: true, signalType: 'cv'),
          EatscriptPortDef(id: 'out', name: 'Chorus Out', isInput: false, signalType: 'audio'),
        ];
      case 'tremolo':
        return const [
          EatscriptPortDef(id: 'in', name: 'Audio In', isInput: true, signalType: 'audio'),
          EatscriptPortDef(id: 'rate_cv', name: 'Rate CV', isInput: true, signalType: 'cv'),
          EatscriptPortDef(id: 'out', name: 'Trem Out', isInput: false, signalType: 'audio'),
        ];
      case 'compressor':
        return const [
          EatscriptPortDef(id: 'in', name: 'Audio In', isInput: true, signalType: 'audio'),
          EatscriptPortDef(id: 'sidechain', name: 'Sidechain', isInput: true, signalType: 'audio'),
          EatscriptPortDef(id: 'out', name: 'Comp Out', isInput: false, signalType: 'audio'),
        ];
      case 'limiter':
        return const [
          EatscriptPortDef(id: 'in', name: 'Audio In', isInput: true, signalType: 'audio'),
          EatscriptPortDef(id: 'out', name: 'Limiter Out', isInput: false, signalType: 'audio'),
        ];
      case 'tr909_kick':
      case 'tr909_snare':
      case 'tr909_sample':
      case 'tr909_voice':
      case 'tr909_hihat':
      case 'tr909_rimshot':
        return const [
          EatscriptPortDef(id: 'gate', name: 'Gate In', isInput: true, signalType: 'gate'),
          EatscriptPortDef(id: 'out', name: 'Drum Out', isInput: false, signalType: 'audio'),
        ];
      case 'melodic_tom':
        return const [
          EatscriptPortDef(id: 'gate', name: 'Gate In', isInput: true, signalType: 'gate'),
          EatscriptPortDef(id: 'pitch_cv', name: 'Pitch CV', isInput: true, signalType: 'cv'),
          EatscriptPortDef(id: 'out', name: 'Tom Out', isInput: false, signalType: 'audio'),
        ];
      case 'reverse_cymbal':
        return const [
          EatscriptPortDef(id: 'gate', name: 'Gate In', isInput: true, signalType: 'gate'),
          EatscriptPortDef(id: 'out', name: 'Cymbal Out', isInput: false, signalType: 'audio'),
        ];
      case 'out':
      default:
        return const [
          EatscriptPortDef(id: 'in', name: 'Main In', isInput: true, signalType: 'audio'),
          EatscriptPortDef(id: 'out', name: 'Master Out', isInput: false, signalType: 'audio'),
        ];
    }
  }

  EatscriptNodeDef copyWith({
    String? id,
    String? type,
    String? title,
    Map<String, dynamic>? params,
    List<EatscriptPortDef>? ports,
    Offset? position,
  }) {
    return EatscriptNodeDef(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      params: params ?? Map.from(this.params),
      ports: ports ?? this.ports,
      position: position ?? this.position,
    );
  }
}

/// A patch cable connecting two ports in the Eatscript modular graph.
class EatscriptCableDef {
  final String fromNodeId;
  final String fromPort;
  final String toNodeId;
  final String toPort;
  final Color color;

  const EatscriptCableDef({
    required this.fromNodeId,
    required this.fromPort,
    required this.toNodeId,
    required this.toPort,
    this.color = const Color(0xFF00FFE0),
  });

  String get key => '$fromNodeId:$fromPort->$toNodeId:$toPort';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EatscriptCableDef &&
          fromNodeId == other.fromNodeId &&
          fromPort == other.fromPort &&
          toNodeId == other.toNodeId &&
          toPort == other.toPort;

  @override
  int get hashCode =>
      fromNodeId.hashCode ^ fromPort.hashCode ^ toNodeId.hashCode ^ toPort.hashCode;
}

/// Complete in-memory representation of an Eatscript Modular Graph (`def graph():`).
class EatscriptGraphDef {
  final List<EatscriptNodeDef> nodes;
  final List<EatscriptCableDef> cables;

  const EatscriptGraphDef({
    required this.nodes,
    required this.cables,
  });

  EatscriptNodeDef? findNode(String id) {
    for (final n in nodes) {
      if (n.id == id) return n;
    }
    return null;
  }

  /// Parses an Eatscript code string for a `def graph():` block.
  /// Falls back to a canonical pre-wired modular synthesis graph if not yet declared.
  static EatscriptGraphDef parse(String code, {String trackName = 'Track'}) {
    final clean = code.trim();
    final hasGraphBlock = clean.contains('def graph(') || clean.contains('def graph :');

    if (hasGraphBlock) {
      final parsed = _parseGraphBlock(clean);
      if (parsed.nodes.isNotEmpty) return parsed;
    }

    return _generateDefaultGraph(clean, trackName);
  }

  static EatscriptGraphDef _parseGraphBlock(String code) {
    final nodes = <EatscriptNodeDef>[];
    final cables = <EatscriptCableDef>[];

    final graphRegex = RegExp(r'def\s+graph\s*\([^)]*\)\s*:([\s\S]*?)(?=(?:\ndef\s+|$))');
    final match = graphRegex.firstMatch(code);
    if (match == null) {
      return const EatscriptGraphDef(nodes: [], cables: []);
    }

    final block = match.group(1)!;
    final lines = block.split('\n');

    double curX = 20.0;
    double curY = 40.0;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      // Match node declaration: var_name = eat.node.<type>(...)
      final declMatch = RegExp(r'(\w+)\s*=\s*eat\.node\.(\w+)\s*\((.*?)\)').firstMatch(trimmed);
      if (declMatch != null) {
        final varId = declMatch.group(1)!;
        final nodeType = declMatch.group(2)!.toLowerCase();
        final argsStr = declMatch.group(3)!;
        final params = _parseArgParams(argsStr);

        final is303 = code.contains('303') || code.toLowerCase().contains('acid');
        final node = EatscriptNodeDef(
          id: varId,
          type: nodeType,
          title: _titleForType(nodeType, is303: is303),
          params: params,
          position: Offset(curX, curY),
        );
        nodes.add(node);
        curX += 160.0;
        if (curX > 700.0) {
          curX = 20.0;
          curY += 210.0;
        }

        // Infer connections from input parameters:
        for (final entry in params.entries) {
          final val = entry.value?.toString();
          if (val != null) {
            // Check if argument references another node
            for (final srcNode in nodes) {
              if (srcNode.id == val) {
                cables.add(EatscriptCableDef(
                  fromNodeId: srcNode.id,
                  fromPort: 'out',
                  toNodeId: varId,
                  toPort: entry.key == 'in_sig' ? 'in' : entry.key,
                  color: const Color(0xFF00FFE0),
                ));
              }
            }
          }
        }
      }

      // Check pipe operator connection: a >> b
      final pipeMatches = RegExp(r'(\w+)\s*>>\s*(\w+)').allMatches(trimmed);
      for (final pm in pipeMatches) {
        final src = pm.group(1)!;
        final dst = pm.group(2)!;
        cables.add(EatscriptCableDef(
          fromNodeId: src,
          fromPort: 'out',
          toNodeId: dst,
          toPort: 'in',
          color: const Color(0xFF00FFE0),
        ));
      }
    }

    return EatscriptGraphDef(nodes: nodes, cables: cables);
  }

  static Map<String, dynamic> _parseArgParams(String argsStr) {
    final map = <String, dynamic>{};
    if (argsStr.trim().isEmpty) return map;

    final parts = argsStr.split(',');
    for (final p in parts) {
      final kv = p.split('=');
      if (kv.length == 2) {
        final key = kv[0].trim();
        var valStr = kv[1].trim();
        valStr = valStr.replaceAll("'", '').replaceAll('"', '');
        final numVal = num.tryParse(valStr);
        map[key] = numVal ?? valStr;
      } else if (kv.length == 1 && kv[0].trim().isNotEmpty) {
        map['wave'] = kv[0].trim().replaceAll("'", '').replaceAll('"', '');
      }
    }
    return map;
  }

  static String _titleForType(String type, {bool is303 = false}) {
    switch (type.toLowerCase()) {
      case 'osc':
        return is303 ? '303 VCO' : 'VCO OSC';
      case 'sub':
        return 'SUB OSC';
      case 'noise':
        return 'WHITE NOISE GEN';
      case 'lfo':
        return 'LFO MODULATOR';
      case 'svf':
        return is303 ? '18DB RESO VCF' : 'SVF FILTER';
      case 'moog':
        return 'MOOG 24DB LADDER';
      case 'adsr':
        return is303 ? 'ACCENT ENVELOPE' : 'ADSR ENV';
      case 'saturate':
        return is303 ? 'OVERDRIVE' : 'SATURATOR';
      case 'mix':
        return 'SIGNAL MIXER';
      case 'hammer':
        return 'HAMMER EXCITER';
      case 'pluck':
        return 'PLECTRUM PLUCK';
      case 'bow':
        return 'BOWED FRICTION';
      case 'waveguide':
        return 'DIGITAL WAVEGUIDE';
      case 'modal_bank':
        return 'MODAL RESONATOR';
      case 'acoustic_body':
        return 'ACOUSTIC BODY';
      case 'delay':
        return 'STEREO DELAY';
      case 'compressor':
        return 'DYNAMICS COMPRESSOR';
      case 'limiter':
        return 'MASTER LIMITER';
      case 'tr909_kick':
        return 'TR-909 KICK';
      case 'tr909_snare':
        return 'TR-909 SNARE';
      case 'tr909_sample':
      case 'tr909_voice':
      case 'tr909_hihat':
        return 'TR-909 ROM VOICE';
      case 'tr909_rimshot':
        return 'TR-909 RIMSHOT';
      case 'melodic_tom':
        return 'MELODIC TOM';
      case 'reverse_cymbal':
        return 'REVERSE CYMBAL';
      case 'input':
      case 'audio_in':
        return 'AUDIO IN';
      case 'out':
      default:
        return 'MASTER OUT';
    }
  }

  static EatscriptGraphDef _generateDefaultGraph(String code, String trackName) {
    final is303 = trackName.toLowerCase().contains('303') ||
        trackName.toLowerCase().contains('acid') ||
        code.toLowerCase().contains('303') ||
        code.toLowerCase().contains('acid');

    final nodes = <EatscriptNodeDef>[
      EatscriptNodeDef(
        id: 'vco',
        type: 'osc',
        title: is303 ? '303 VCO' : 'DUAL VCO',
        params: {'wave': 'saw', 'detune': 3.0},
        position: const Offset(20, 20),
      ),
      EatscriptNodeDef(
        id: 'sub',
        type: 'sub',
        title: 'SUB OCTAVE',
        params: {'octave': -1, 'level': 0.5},
        position: const Offset(20, 220),
      ),
      EatscriptNodeDef(
        id: 'vcf',
        type: 'svf',
        title: is303 ? '18DB RESO VCF' : 'RESO SVF',
        params: {'cutoff': 'Cutoff', 'reso': 'Resonance', 'mode': 'lp'},
        position: const Offset(240, 20),
      ),
      EatscriptNodeDef(
        id: 'env',
        type: 'adsr',
        title: is303 ? 'ACCENT ENVELOPE' : 'AMP ADSR',
        params: {'attack': 'Attack', 'decay': 'Decay', 'sustain': 'Sustain', 'release': 'Release'},
        position: const Offset(240, 220),
      ),
      EatscriptNodeDef(
        id: 'sat',
        type: 'saturate',
        title: 'OVERDRIVE',
        params: {'drive': 'Drive'},
        position: const Offset(460, 20),
      ),
      EatscriptNodeDef(
        id: 'out',
        type: 'out',
        title: 'MASTER OUT',
        position: const Offset(660, 100),
      ),
    ];

    final cables = <EatscriptCableDef>[
      const EatscriptCableDef(
        fromNodeId: 'vco',
        fromPort: 'out',
        toNodeId: 'vcf',
        toPort: 'in',
        color: Color(0xFF00FFE0),
      ),
      const EatscriptCableDef(
        fromNodeId: 'sub',
        fromPort: 'out',
        toNodeId: 'vcf',
        toPort: 'in',
        color: Color(0xFF00FFE0),
      ),
      const EatscriptCableDef(
        fromNodeId: 'vcf',
        fromPort: 'out',
        toNodeId: 'sat',
        toPort: 'in',
        color: Color(0xFF00FFE0),
      ),
      const EatscriptCableDef(
        fromNodeId: 'env',
        fromPort: 'env_out',
        toNodeId: 'vcf',
        toPort: 'cutoff_cv',
        color: Color(0xFFFFD600),
      ),
      const EatscriptCableDef(
        fromNodeId: 'sat',
        fromPort: 'out',
        toNodeId: 'out',
        toPort: 'in',
        color: Color(0xFF00E676),
      ),
    ];

    return EatscriptGraphDef(nodes: nodes, cables: cables);
  }

  /// Serializes the modular graph definition into standard, clean, 4-space indented Pythonic Eatscript.
  /// Seamlessly injects or updates `def graph():` inside [existingCode].
  static String serialize(
    EatscriptGraphDef graph, {
    String existingCode = '',
    String instrumentName = 'Instrument',
  }) {
    final buffer = StringBuffer();
    buffer.writeln('def graph():');
    if (graph.nodes.isEmpty) {
      buffer.writeln('    pass');
      return buffer.toString();
    }

    for (final node in graph.nodes) {
      if (node.type == 'out') continue;

      final args = <String>[];
      for (final p in node.params.entries) {
        if (p.value is num) {
          args.add('${p.key}=${p.value}');
        } else {
          args.add('${p.key}="${p.value}"');
        }
      }

      // Check if input is fed by cable
      final inCable = graph.cables.where((c) => c.toNodeId == node.id && (c.toPort == 'in' || c.toPort == 'in_sig')).firstOrNull;
      if (inCable != null) {
        args.insert(0, 'in_sig=${inCable.fromNodeId}');
      }

      final argsJoined = args.join(', ');
      buffer.writeln('    ${node.id} = eat.node.${node.type}($argsJoined)');
    }

    // Connect to output
    final outCable = graph.cables.where((c) => c.toNodeId == 'out' || c.toPort == 'out_in').firstOrNull;
    final finalSignal = outCable?.fromNodeId ?? (graph.nodes.lastWhere((n) => n.type != 'out', orElse: () => graph.nodes.first).id);

    // Apply envelope if present
    final envNode = graph.nodes.where((n) => n.type == 'adsr').firstOrNull;
    if (envNode != null) {
      buffer.writeln('    return $finalSignal * ${envNode.id}');
    } else {
      buffer.writeln('    return $finalSignal');
    }

    final newGraphBlock = buffer.toString().trimRight();

    if (existingCode.trim().isEmpty) {
      return '# @id: ${instrumentName.toLowerCase().replaceAll(' ', '_')}\n# @name: $instrumentName\n\n$newGraphBlock\n';
    }

    // Replace existing def graph(): block
    final existingGraphRegex = RegExp(
      r'def\s+graph\s*\([^)]*\)\s*:[\s\S]*?(?=(?:\ndef\s+|$))',
      multiLine: true,
    );

    if (existingGraphRegex.hasMatch(existingCode)) {
      return existingCode.replaceAll(existingGraphRegex, newGraphBlock);
    }

    // Otherwise append cleanly to the end
    return '${existingCode.trimRight()}\n\n$newGraphBlock\n';
  }

  /// Compiles this modular graph directly into a native C/Dart [GraphNode] tree for audio synthesis.
  GraphNode compileToGraphNode([Map<String, double> params = const {}]) {
    final Map<String, GraphNode> builtNodes = {};

    double resolveNum(dynamic val, double fallback) {
      if (val is num) return val.toDouble();
      if (val is String) {
        final parsed = double.tryParse(val);
        if (parsed != null) return parsed;
        if (params.containsKey(val)) return params[val]!;
      }
      return fallback;
    }

    for (final node in nodes) {
      final t = node.type.toLowerCase();
      GraphNode? gn;

      switch (t) {
        case 'osc':
          final wave = node.params['wave']?.toString().toLowerCase() ?? 'saw';
          final pitchCable = cables.where((c) => c.toNodeId == node.id && (c.toPort == 'pitch_cv' || c.toPort == 'pitch')).firstOrNull;
          final pitchNode = pitchCable != null ? builtNodes[pitchCable.fromNodeId] : null;
          final staticF = resolveNum(node.params['freq'], 0.0);
          final fSource = pitchNode;
          if (wave.contains('sin')) {
            gn = SineOscNode(freqSource: fSource, staticFreq: staticF > 0 ? staticF : null);
          } else if (wave.contains('sqr') || wave.contains('square')) {
            gn = SquareOscNode(freqSource: fSource, staticFreq: staticF > 0 ? staticF : null);
          } else if (wave.contains('noise')) {
            gn = const NoiseNode();
          } else {
            gn = SawOscNode(freqSource: fSource, staticFreq: staticF > 0 ? staticF : null);
          }
          break;

        case 'sub':
          gn = const GainNode(input: SineOscNode(), staticGain: 0.5);
          break;

        case 'noise':
          gn = const NoiseNode();
          break;

        case 'lfo':
          final rate = resolveNum(node.params['rate'], 2.5);
          final depth = resolveNum(node.params['depth'], 1.0);
          gn = LfoNode(rateHz: rate, depth: depth);
          break;

        case 'pitch_sweep':
          final start = resolveNum(node.params['start'], 140.0);
          final end = resolveNum(node.params['end'], 46.0);
          final d = resolveNum(node.params['decay'], 0.045);
          gn = PitchSweepNode(startFreq: start, endFreq: end, decaySec: d);
          break;

        case 'decay':
          final d = resolveNum(node.params['decay'], 0.5);
          gn = DecayEnvNode(decaySec: d);
          break;

        case 'gain':
          final inCable = cables.where((c) => c.toNodeId == node.id && (c.toPort == 'in' || c.toPort == 'in_sig')).firstOrNull;
          final inNode = inCable != null ? (builtNodes[inCable.fromNodeId] ?? const SineOscNode()) : (builtNodes.values.lastOrNull ?? const SineOscNode());
          final cvCable = cables.where((c) => c.toNodeId == node.id && (c.toPort == 'gain_cv' || c.toPort == 'gain' || c.toPort == 'cv')).firstOrNull;
          final cvNode = cvCable != null ? builtNodes[cvCable.fromNodeId] : null;
          final g = resolveNum(node.params['gain'], 1.0);
          gn = GainNode(input: inNode, gainSource: cvNode, staticGain: g);
          break;

        case 'multi_burst':
          final bursts = resolveNum(node.params['bursts'], 4.0).toInt();
          final spread = resolveNum(node.params['spread'], 0.011);
          final d = resolveNum(node.params['decay'], 0.28);
          gn = MultiBurstEnvNode(burstCount: bursts, burstIntervalSec: spread, tailDecaySec: d);
          break;

        case 'metallic_cluster':
          final mult = resolveNum(node.params['tune'], 1.0);
          gn = MetallicClusterNode(pitchMultiplier: mult);
          break;

        case 'midi_to_cv':
        case 'cv':
          gn = const MidiToCvNode();
          break;

        case 'hammer':
          final h = resolveNum(node.params['hardness'], 1.0);
          final c = resolveNum(node.params['click'], 1.0);
          gn = HammerExciterNode(hardness: h, clickLevel: c);
          break;

        case 'pluck':
          final spread = resolveNum(node.params['spread'], 8.0);
          final bite = resolveNum(node.params['bite'], 1.0);
          gn = PlectrumStrumExciterNode(strumSpreadMs: spread, pickBite: bite);
          break;

        case 'bow':
          final press = resolveNum(node.params['pressure'], 1.0);
          final spd = resolveNum(node.params['speed'], 1.0);
          gn = BowedFrictionExciterNode(bowPressure: press, bowSpeed: spd);
          break;

        case 'svf':
          final inCable = cables.where((c) => c.toNodeId == node.id && (c.toPort == 'in' || c.toPort == 'in_sig')).firstOrNull;
          final inNode = inCable != null ? (builtNodes[inCable.fromNodeId] ?? const SineOscNode()) : (builtNodes.values.lastOrNull ?? const SineOscNode());
          final cutoffVal = resolveNum(node.params['cutoff'], 1000.0);
          final resoVal = resolveNum(node.params['reso'], 0.7);
          final gainVal = resolveNum(node.params['gain'], 0.0);
          BiquadType bType = BiquadType.lowpass;
          final tStr = node.params['type']?.toString().toLowerCase() ?? 'lowpass';
          if (tStr.contains('highshelf')) {
            bType = BiquadType.highshelf;
          } else if (tStr.contains('lowshelf')) {
            bType = BiquadType.lowshelf;
          } else if (tStr.contains('high')) {
            bType = BiquadType.highpass;
          } else if (tStr.contains('band')) {
            bType = BiquadType.bandpass;
          } else if (tStr.contains('notch')) {
            bType = BiquadType.notch;
          } else if (tStr.contains('peak')) {
            bType = BiquadType.peaking;
          }
          gn = BiquadFilterNode(input: inNode, type: bType, frequency: cutoffVal, q: resoVal, gainDb: gainVal);
          break;

        case 'moog':
          final inCable = cables.where((c) => c.toNodeId == node.id && (c.toPort == 'in' || c.toPort == 'in_sig')).firstOrNull;
          final inNode = inCable != null ? (builtNodes[inCable.fromNodeId] ?? const SineOscNode()) : (builtNodes.values.lastOrNull ?? const SineOscNode());
          final cutoffVal = resolveNum(node.params['cutoff'], 1000.0);
          final resoVal = resolveNum(node.params['reso'], 0.65);
          gn = MoogLadderFilterNode(input: inNode, cutoffHz: cutoffVal, resonance: resoVal);
          break;

        case 'waveguide':
          final inCable = cables.where((c) => c.toNodeId == node.id && (c.toPort == 'in' || c.toPort == 'in_sig')).firstOrNull;
          final inNode = inCable != null ? (builtNodes[inCable.fromNodeId] ?? const NoiseNode()) : (builtNodes.values.lastOrNull ?? const NoiseNode());
          final damp = resolveNum(node.params['damping'], 0.25);
          final fb = resolveNum(node.params['feedback'], 0.995);
          gn = WaveguideNode(exciter: inNode, damping: damp, feedback: fb);
          break;

        case 'modal_bank':
          final inCable = cables.where((c) => c.toNodeId == node.id && (c.toPort == 'in' || c.toPort == 'in_sig')).firstOrNull;
          final inNode = inCable != null ? (builtNodes[inCable.fromNodeId] ?? const NoiseNode()) : (builtNodes.values.lastOrNull ?? const NoiseNode());
          final structure = node.params['structure']?.toString() ?? 'bell';
          List<double> ratios = [1.0, 2.76, 5.4, 8.9];
          List<double> gains = [1.0, 0.6, 0.4, 0.25];
          List<double> qFactors = [80.0, 60.0, 45.0, 30.0];
          if (structure == 'bar' || structure == 'vibraphone') {
            ratios = [1.0, 3.98, 9.25, 16.3];
            gains = [1.0, 0.7, 0.35, 0.15];
            qFactors = [120.0, 90.0, 60.0, 40.0];
          } else if (structure == 'membrane' || structure == 'drum') {
            ratios = [1.0, 1.59, 2.14, 2.65];
            gains = [1.0, 0.8, 0.5, 0.3];
            qFactors = [25.0, 20.0, 15.0, 12.0];
          }
          gn = ModalResonatorBankNode(input: inNode, modeFreqRatios: ratios, modeGains: gains, modeQFactors: qFactors);
          break;

        case 'acoustic_body':
          final inCable = cables.where((c) => c.toNodeId == node.id && (c.toPort == 'in' || c.toPort == 'in_sig')).firstOrNull;
          final inNode = inCable != null ? (builtNodes[inCable.fromNodeId] ?? const SineOscNode()) : (builtNodes.values.lastOrNull ?? const SineOscNode());
          final profile = resolveNum(node.params['profile'], 0.5);
          final gain = resolveNum(node.params['gain'], 0.5);
          gn = MorphableAcousticBodyNode(input: inNode, bodyProfile: profile, woodGain: gain);
          break;

        case 'saturate':
          final inCable = cables.where((c) => c.toNodeId == node.id && (c.toPort == 'in' || c.toPort == 'in_sig')).firstOrNull;
          final inNode = inCable != null ? (builtNodes[inCable.fromNodeId] ?? const SineOscNode()) : (builtNodes.values.lastOrNull ?? const SineOscNode());
          final driveVal = resolveNum(node.params['drive'], 1.5);
          gn = DistortionNode(input: inNode, drive: driveVal);
          break;

        case 'bitcrush':
        case 'bitcrusher':
          final inCable = cables.where((c) => c.toNodeId == node.id && (c.toPort == 'in' || c.toPort == 'in_sig')).firstOrNull;
          final inNode = inCable != null ? (builtNodes[inCable.fromNodeId] ?? const SineOscNode()) : (builtNodes.values.lastOrNull ?? const SineOscNode());
          final b = resolveNum(node.params['bits'], 8.0);
          final ds = resolveNum(node.params['downsample'], 1.0);
          final m = resolveNum(node.params['mix'], 1.0);
          gn = BitcrusherNode(input: inNode, bits: b, downsample: ds, mix: m);
          break;

        case 'chorus':
          final inCable = cables.where((c) => c.toNodeId == node.id && (c.toPort == 'in' || c.toPort == 'in_sig')).firstOrNull;
          final inNode = inCable != null ? (builtNodes[inCable.fromNodeId] ?? const SineOscNode()) : (builtNodes.values.lastOrNull ?? const SineOscNode());
          final rate = resolveNum(node.params['rate'], 0.8);
          final depth = resolveNum(node.params['depth'], 0.65);
          final fb = resolveNum(node.params['feedback'], 0.2);
          final m = resolveNum(node.params['mix'], 0.5);
          gn = ChorusNode(input: inNode, rateHz: rate, depth: depth, feedback: fb, mix: m);
          break;

        case 'tremolo':
          final inCable = cables.where((c) => c.toNodeId == node.id && (c.toPort == 'in' || c.toPort == 'in_sig')).firstOrNull;
          final inNode = inCable != null ? (builtNodes[inCable.fromNodeId] ?? const SineOscNode()) : (builtNodes.values.lastOrNull ?? const SineOscNode());
          final rate = resolveNum(node.params['rate'], 4.5);
          final depth = resolveNum(node.params['depth'], 0.65);
          gn = StereoTremoloNode(input: inNode, rateHz: rate, depth: depth);
          break;

        case 'delay':
          final inCable = cables.where((c) => c.toNodeId == node.id && (c.toPort == 'in' || c.toPort == 'in_sig')).firstOrNull;
          final inNode = inCable != null ? (builtNodes[inCable.fromNodeId] ?? const SineOscNode()) : (builtNodes.values.lastOrNull ?? const SineOscNode());
          double timeVal = resolveNum(node.params['time'], 0.3);
          if (timeVal > 10.0) timeVal = timeVal / 1000.0;
          gn = DelayNode(input: inNode, delaySec: timeVal);
          break;

        case 'mix':
          final inA = cables.where((c) => c.toNodeId == node.id && c.toPort == 'in_a').firstOrNull;
          final inB = cables.where((c) => c.toNodeId == node.id && c.toPort == 'in_b').firstOrNull;
          final nodeA = inA != null ? builtNodes[inA.fromNodeId] : null;
          final nodeB = inB != null ? builtNodes[inB.fromNodeId] : null;
          final inputs = [if (nodeA != null) nodeA, if (nodeB != null) nodeB];
          gn = MixerNode(inputs.isNotEmpty ? inputs : [const SineOscNode()]);
          break;

        case 'input':
        case 'audio_in':
          gn = const AudioInputNode();
          break;

        case 'compressor':
          final inCable = cables.where((c) => c.toNodeId == node.id && (c.toPort == 'in' || c.toPort == 'in_sig')).firstOrNull;
          final inNode = inCable != null ? (builtNodes[inCable.fromNodeId] ?? const SineOscNode()) : (builtNodes.values.lastOrNull ?? const SineOscNode());
          final scCable = cables.where((c) => c.toNodeId == node.id && c.toPort == 'sidechain').firstOrNull;
          final scNode = scCable != null ? builtNodes[scCable.fromNodeId] : null;
          final thresh = resolveNum(node.params['threshold'], -18.0);
          final ratio = resolveNum(node.params['ratio'], 4.0);
          double att = resolveNum(node.params['attack'], 15.0);
          if (att < 1.0) att = att * 1000.0;
          double rel = resolveNum(node.params['release'], 100.0);
          if (rel < 5.0) rel = rel * 1000.0;
          final makeup = resolveNum(node.params['makeup'], 0.0);
          final mix = resolveNum(node.params['mix'], 1.0);
          gn = CompressorNode(
            input: inNode,
            sidechainInput: scNode,
            thresholdDb: thresh,
            ratio: ratio,
            attackMs: att,
            releaseMs: rel,
            makeupGainDb: makeup,
            mix: mix,
          );
          break;

        case 'limiter':
          final inCable = cables.where((c) => c.toNodeId == node.id && (c.toPort == 'in' || c.toPort == 'in_sig')).firstOrNull;
          final inNode = inCable != null ? (builtNodes[inCable.fromNodeId] ?? const SineOscNode()) : (builtNodes.values.lastOrNull ?? const SineOscNode());
          final ceil = resolveNum(node.params['ceiling'], -0.1);
          double rel = resolveNum(node.params['release'], 50.0);
          if (rel < 5.0) rel = rel * 1000.0;
          gn = LimiterNode(
            input: inNode,
            ceilingDb: ceil,
            releaseMs: rel,
          );
          break;

        case 'tr909_kick':
          final tune = resolveNum(node.params['tune'], 0.018);
          final decay = resolveNum(node.params['decay'], 0.05);
          final attack = resolveNum(node.params['attack'], 1.0);
          gn = Tr909KickNode(tune: tune, decay: decay, attackLevel: attack);
          break;

        case 'tr909_snare':
          final tune = resolveNum(node.params['tune'], 0.0);
          final tone = resolveNum(node.params['tone'], 0.12);
          final snappy = resolveNum(node.params['snappy'], 1.0);
          gn = Tr909SnareNode(tune: tune, tone: tone, snappy: snappy);
          break;

        case 'tr909_sample':
        case 'tr909_voice':
        case 'tr909_hihat':
        case 'tr909_rimshot':
          final voiceType = node.params['sample']?.toString().toLowerCase() ??
              (node.type.contains('rim') ? 'rim' : (node.params['type']?.toString().toLowerCase() ?? 'closed_hihat'));
          final tune = resolveNum(node.params['tune'], 0.0);
          final decay = resolveNum(node.params['decay'], 0.05);
          Float32List Function() bufGetter = () => Tr909RomData.closed_hihat;
          if (voiceType.contains('open')) {
            bufGetter = () => Tr909RomData.opened_hihat;
          } else if (voiceType.contains('rim')) {
            bufGetter = () => Tr909RomData.rim;
          } else if (voiceType.contains('clap')) {
            bufGetter = () => Tr909RomData.clap;
          }
          gn = Tr909SampleVoiceNode(getBuffer: bufGetter, tune: tune, decay: decay);
          break;

        case 'melodic_tom':
          final decay = resolveNum(node.params['decay'], 0.85);
          final coupling = resolveNum(node.params['coupling'], 0.55);
          final pitchBend = resolveNum(node.params['pitch_bend'], 0.4);
          final stick = resolveNum(node.params['stick'], 0.6);
          gn = MelodicTomNode(
            tomDecay: decay,
            headCoupling: coupling,
            pitchBend: pitchBend,
            stickCrack: stick,
          );
          break;

        case 'reverse_cymbal':
          final duration = resolveNum(node.params['duration'], 1.5);
          final curve = resolveNum(node.params['curve'], 2.2);
          final shimmer = resolveNum(node.params['shimmer'], 0.75);
          final choke = resolveNum(node.params['choke'], 0.6);
          gn = ReverseCymbalNode(
            swellDuration: duration,
            crescendoCurve: curve,
            shimmerAir: shimmer,
            chokeSnap: choke,
          );
          break;

        case 'adsr':
          // Envelope is applied at output stage
          break;
      }

      if (gn != null) {
        builtNodes[node.id] = gn;
      }
    }

    GraphNode signalChain;
    final outCable = cables.where((c) => c.toNodeId == 'out').firstOrNull;
    if (outCable != null && builtNodes.containsKey(outCable.fromNodeId)) {
      signalChain = builtNodes[outCable.fromNodeId]!;
    } else {
      signalChain = builtNodes.values.lastOrNull ?? const SineOscNode();
    }

    // Apply envelope if present
    final envNode = nodes.where((n) => n.type == 'adsr').firstOrNull;
    if (envNode != null) {
      final a = (params['Attack'] ?? (params['attack'] ?? 0.01)).clamp(0.001, 5.0);
      final d = (params['Decay'] ?? (params['decay'] ?? 0.15)).clamp(0.005, 10.0);
      final s = (params['Sustain'] ?? (params['sustain'] ?? 0.75)).clamp(0.0, 1.0);
      final r = (params['Release'] ?? (params['release'] ?? 0.20)).clamp(0.005, 10.0);
      final adsr = AdsrEnvNode(attack: a, decay: d, sustain: s, release: r);
      signalChain = GainNode(input: signalChain, gainSource: adsr);
    }

    return signalChain;
  }
}
