import '../lua/eats_lua_parser.dart';
import '../lua/lua_engine.dart';
import '../lua/lua_gui_parser.dart';
import 'eat_script_engine.dart';

/// Transpiles legacy Lua preset and script definitions into pure, Pythonic Eatscript.
class EatTranspiler {
  /// Transpiles a Lua preset script into idiomatic Eatscript.
  static String transpileLuaPreset(String luaCode) {
    final lines = luaCode.split('\n');
    final buffer = StringBuffer();

    // 1. Extract and convert header metadata
    String? id;
    String? name;
    String? category;
    String? description;
    final List<String> tags = [];

    for (final line in lines) {
      final trimmed = line.trim();
      final clean = trimmed.startsWith('--')
          ? trimmed.substring(2).trim()
          : (trimmed.startsWith('#') ? trimmed.substring(1).trim() : trimmed);

      if (clean.startsWith('@id:')) {
        id = clean.substring(4).trim();
      } else if (clean.startsWith('@name:')) {
        name = clean.substring(6).trim();
      } else if (clean.startsWith('@category:')) {
        category = clean.substring(10).trim();
      } else if (clean.startsWith('@description:')) {
        description = clean.substring(13).trim();
      } else if (clean.startsWith('@tags:') || clean.startsWith('@tag:')) {
        final prefixLen = clean.startsWith('@tags:') ? 6 : 5;
        final rawTags = clean.substring(prefixLen).split(',');
        for (final t in rawTags) {
          final ct = t.trim().toLowerCase();
          if (ct.isNotEmpty && !tags.contains(ct)) tags.add(ct);
        }
      }
    }

    if (id != null) buffer.writeln('# @id: $id');
    if (name != null) buffer.writeln('# @name: $name');
    if (category != null) buffer.writeln('# @category: $category');
    if (description != null) buffer.writeln('# @description: $description');
    if (tags.isNotEmpty) buffer.writeln('# @tags: ${tags.join(', ')}');
    buffer.writeln();

    // 2. Discover parameters from Param.add / Param.choice
    final compResult = LuaEngine.compile(luaCode);
    final params = compResult.params;

    buffer.writeln('# --- Parameter Definitions ---');
    buffer.writeln('def init():');
    buffer.writeln('    return {');
    for (final p in params) {
      if (p.options.isNotEmpty) {
        final optsStr = p.options.map((o) => '"$o"').join(', ');
        buffer.writeln('        "${p.name}": eat.param("${p.name}", ${p.min}, ${p.max}, ${p.defaultValue}, options=[$optsStr]),');
      } else {
        buffer.writeln('        "${p.name}": eat.param("${p.name}", ${p.min}, ${p.max}, ${p.defaultValue}, step=${p.step}),');
      }
    }
    buffer.writeln('    }');
    buffer.writeln();

    // 3. Extract and convert GUI layout if present
    if (luaCode.contains('gui') || luaCode.contains('GUI') || luaCode.contains('panel')) {
      final guiTableStr = _extractTableBlock(luaCode, 'gui');
      if (guiTableStr != null) {
        final parsedMap = EatsLuaParser.parseLuaTableToMap(guiTableStr);
        if (parsedMap.isNotEmpty) {
          buffer.writeln('# --- Hardware GUI Layout ---');
          buffer.writeln('def gui():');
          buffer.writeln('    return {');
          _formatMap(parsedMap, buffer, indentLevel: 2);
          buffer.writeln('    }');
          buffer.writeln();
        }
      }
    }

    // 4. Extract transform_notes / split / run / process algorithmic hooks if present
    if (luaCode.contains('transform_notes')) {
      buffer.writeln('# --- MIDI Transformation Hook ---');
      buffer.writeln('def transform_notes(notes, params, time_context):');
      if (luaCode.contains('arpeggiat') || luaCode.contains('Midi.arpeggiate')) {
        buffer.writeln('    return eat.arpeggiate(notes, rate=params.get("Rate", 1.0), octaves=params.get("Octaves", 2))');
      } else if (luaCode.contains('chord_follow') || luaCode.contains('Midi.chord_follow')) {
        buffer.writeln('    return eat.chord_follow(notes, mode=params.get("Mode", 0))');
      } else if (luaCode.contains('scale_snap') || luaCode.contains('Midi.scale_snap')) {
        buffer.writeln('    return eat.scale_snap(notes, key=params.get("Key", 0))');
      } else if (luaCode.contains('humanize') || luaCode.contains('Humanize')) {
        buffer.writeln('    return eat.humanize(notes, timing=params.get("Timing", 0.04), velocity=params.get("Velocity", 0.15))');
      } else {
        buffer.writeln('    return notes');
      }
      buffer.writeln();
    } else if (luaCode.contains('function split(')) {
      buffer.writeln('# --- Note Splitter Hook ---');
      buffer.writeln('def split(notes, params):');
      buffer.writeln('    return [');
      buffer.writeln('        {"name": "Voice 1", "notes": notes},');
      buffer.writeln('    ]');
      buffer.writeln();
    } else if (luaCode.contains('function run(')) {
      buffer.writeln('# --- Project Action Hook ---');
      buffer.writeln('def run(project, params):');
      buffer.writeln('    return params');
      buffer.writeln();
    } else if (luaCode.contains('.process(') || luaCode.contains('function process(')) {
      if (category == 'audioFx' || luaCode.contains('input_l') || luaCode.contains('input_r')) {
        buffer.writeln('# --- Audio FX DSP Process Hook ---');
        buffer.writeln('def process(input_l, input_r, params):');
        buffer.writeln('    return [input_l, input_r]');
        buffer.writeln();
      } else {
        buffer.writeln('# --- Synthesizer Voice DSP Process Hook ---');
        buffer.writeln('def process(time, freq, note, params):');
        buffer.writeln('    return 0.0');
        buffer.writeln();
      }
    }

    // 5. Preserve table name if present (for audio engine voice/DSP identifier matching)
    final tableNameMatch = RegExp(r'local\s+([A-Za-z0-9_]+)\s*=\s*\{\}').firstMatch(luaCode);
    final tableName = tableNameMatch?.group(1);
    if (tableName != null) {
      buffer.writeln('$tableName = True');
    }

    return buffer.toString();
  }

  static String? _extractTableBlock(String code, String functionName) {
    final idx = code.indexOf(functionName);
    if (idx == -1) return null;
    final braceIdx = code.indexOf('{', idx);
    if (braceIdx == -1) return null;

    int depth = 0;
    int endIdx = braceIdx;
    for (int i = braceIdx; i < code.length; i++) {
      if (code[i] == '{') {
        depth++;
      } else if (code[i] == '}') {
        depth--;
        if (depth == 0) {
          endIdx = i + 1;
          break;
        }
      }
    }
    return code.substring(braceIdx, endIdx);
  }

  static void _formatMap(Map<String, dynamic> map, StringBuffer buffer, {required int indentLevel}) {
    final indent = '    ' * indentLevel;
    for (final entry in map.entries) {
      final key = entry.key;
      final val = entry.value;

      if (val is Map) {
        buffer.writeln('$indent"$key": {');
        _formatMap(Map<String, dynamic>.from(val), buffer, indentLevel: indentLevel + 1);
        buffer.writeln('$indent},');
      } else if (val is List) {
        buffer.writeln('$indent"$key": [');
        _formatList(val, buffer, indentLevel: indentLevel + 1);
        buffer.writeln('$indent],');
      } else if (val is String) {
        buffer.writeln('$indent"$key": "$val",');
      } else if (val is bool) {
        buffer.writeln('$indent"$key": ${val ? "True" : "False"},');
      } else if (val == null) {
        buffer.writeln('$indent"$key": None,');
      } else {
        buffer.writeln('$indent"$key": $val,');
      }
    }
  }

  static void _formatList(List list, StringBuffer buffer, {required int indentLevel}) {
    final indent = '    ' * indentLevel;
    for (final item in list) {
      if (item is Map) {
        buffer.writeln('$indent{');
        _formatMap(Map<String, dynamic>.from(item), buffer, indentLevel: indentLevel + 1);
        buffer.writeln('$indent},');
      } else if (item is List) {
        buffer.writeln('$indent[');
        _formatList(item, buffer, indentLevel: indentLevel + 1);
        buffer.writeln('$indent],');
      } else if (item is String) {
        buffer.writeln('$indent"$item",');
      } else if (item is bool) {
        buffer.writeln('$indent${item ? "True" : "False"},');
      } else if (item == null) {
        buffer.writeln('${indent}None,');
      } else {
        buffer.writeln('$indent$item,');
      }
    }
  }
}
