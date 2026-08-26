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

  /// Generates the default modular rack topology for legacy built-in presets based on signature.
  static ModularRackDefinition generateDefault(
    String signature, {
    Map<String, double>? params,
    String trackName = 'Track',
  }) {
    final Map<int, List<DynamicModuleDefinition>> modulesByRow = {1: [], 2: []};
    final List<DynamicPatchConnection> cables = [];

    switch (signature) {
      case 'acid_303':
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

      case 'fm_acoustic_kick':
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

      case 'generic':
      default:
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
