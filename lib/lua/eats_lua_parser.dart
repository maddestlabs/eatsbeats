import 'dart:ui';
import '../models/daw_state.dart';
import '../models/track_model.dart';
import '../theme/eats_theme.dart';

class EatsLuaParser {
  /// Parses a `.eats.lua` project string and updates/populates [DawState].
  static Map<String, dynamic> parseLuaTableToMap(String luaCode) {
    final parser = _LuaValueParser(luaCode);
    final result = parser.parseTopLevel();
    if (result is Map<String, dynamic>) {
      return result;
    }
    return {};
  }

  /// Restores [DawState] from `.eats.lua` code. Returns project title.
  static String populateDawState(DawState dawState, String luaCode) {
    final map = parseLuaTableToMap(luaCode);
    if (map.isEmpty) return 'Untitled Song';

    // 1. Meta / Transport settings
    final meta = map['meta'] is Map ? Map<String, dynamic>.from(map['meta']) : {};
    final title = (meta['title'] as String?) ?? 'Untitled Song';
    final author = (meta['author'] as String?) ?? 'Anonymous Producer';
    final bpm = (meta['bpm'] as num?)?.toDouble() ?? 124.0;
    final masterVol = (meta['masterVolume'] as num?)?.toDouble() ?? 0.85;
    final isSongMode = (meta['isSongMode'] as bool?) ?? false;
    final isLooping = (meta['isLooping'] as bool?) ?? true;
    final loopStartBar = (meta['loopStartBar'] as int?) ?? 0;
    final loopEndBar = (meta['loopEndBar'] as int?) ?? 2;

    dawState.setProjectDetails(title, author);
    dawState.setBpm(bpm);
    dawState.setMasterVolume(masterVol);
    dawState.isSongMode = isSongMode;
    dawState.setLoopPoints(loopStartBar, loopEndBar);
    dawState.setLooping(isLooping);

    // 2. Patterns & Tracks
    final rawPatterns = map['patterns'];
    if (rawPatterns is List && rawPatterns.isNotEmpty) {
      final loadedPatterns = <Pattern>[];
      for (int i = 0; i < rawPatterns.length; i++) {
        if (rawPatterns[i] is Map) {
          final pMap = Map<String, dynamic>.from(rawPatterns[i]);
          final pTracks = <TrackChannel>[];
          if (pMap['tracks'] is List) {
            for (final tData in pMap['tracks']) {
              if (tData is Map) {
                pTracks.add(_parseTrack(Map<String, dynamic>.from(tData)));
              }
            }
          }
          loadedPatterns.add(Pattern(
            id: pMap['id'] ?? 'pattern_$i',
            name: pMap['name'] ?? 'Pattern ${i + 1}',
            lengthSteps: pMap['lengthSteps'] ?? 16,
            tracks: pTracks,
          ));
        }
      }
      if (loadedPatterns.isNotEmpty) {
        dawState.patterns = loadedPatterns;
        dawState.resetActiveIndices();
      }
    } else {
      // Backward compatibility fallback for top-level tracks
      final rawTracks = map['tracks'];
      if (rawTracks is List) {
        final loadedTracks = <TrackChannel>[];
        for (final tData in rawTracks) {
          if (tData is Map) {
            final tMap = Map<String, dynamic>.from(tData);
            loadedTracks.add(_parseTrack(tMap));
          }
        }

        if (loadedTracks.isNotEmpty) {
          dawState.patterns = [
            Pattern(
              id: 'pattern_0',
              name: 'Pattern 1',
              lengthSteps: 16,
              tracks: loadedTracks,
            )
          ];
          dawState.resetActiveIndices();
        }
      }
    }

    // 4. Arranger playlist items if present
    final arranger = map['arranger'] is Map ? Map<String, dynamic>.from(map['arranger']) : {};
    final rawItems = arranger['items'];
    if (rawItems is List) {
      final items = <ArrangementItem>[];
      for (final itemData in rawItems) {
        if (itemData is Map) {
          final iMap = Map<String, dynamic>.from(itemData);
          items.add(ArrangementItem(
            patternId: iMap['patternId'] ?? 'pattern_0',
            startBar: iMap['startBar'] ?? 0,
            barLength: iMap['barLength'] ?? 1,
          ));
        }
      }
      if (items.isNotEmpty) {
        dawState.arrangement = items;
      }
    }

    dawState.notifyState();
    return title;
  }

  static bool _parseBool(dynamic val, [bool fallback = false]) {
    if (val is bool) return val;
    if (val is String) {
      if (val.toLowerCase() == 'true') return true;
      if (val.toLowerCase() == 'false') return false;
    }
    return fallback;
  }

  static TrackChannel _parseTrack(Map<String, dynamic> map) {
    final colorVal = _parseColorVal(map['color']);

    // Parse step events map/list
    final steps = List<StepEvent>.generate(32, (_) => StepEvent());
    final rawSteps = map['steps'];
    if (rawSteps is Map) {
      rawSteps.forEach((key, val) {
        final stepIdx = (key is int ? key : int.tryParse(key.toString()) ?? 1) - 1;
        if (stepIdx >= 0 && stepIdx < 32 && val is Map) {
          final sMap = Map<String, dynamic>.from(val);
          steps[stepIdx] = StepEvent(
            active: true,
            pitch: sMap['pitch'] ?? 60,
            velocity: (sMap['velocity'] as num?)?.toDouble() ?? 0.8,
            isSlide: _parseBool(sMap['isSlide']),
            isAccent: _parseBool(sMap['isAccent']),
          );
        }
      });
    } else if (rawSteps is List) {
      for (int i = 0; i < rawSteps.length; i++) {
        final val = rawSteps[i];
        if (i < 32 && val is Map) {
          final sMap = Map<String, dynamic>.from(val);
          steps[i] = StepEvent(
            active: true,
            pitch: sMap['pitch'] ?? 60,
            velocity: (sMap['velocity'] as num?)?.toDouble() ?? 0.8,
            isSlide: _parseBool(sMap['isSlide']),
            isAccent: _parseBool(sMap['isAccent']),
          );
        }
      }
    }

    // Parse piano roll notes
    final notes = <Note>[];
    final rawNotes = map['notes'];
    if (rawNotes is List) {
      for (final n in rawNotes) {
        if (n is Map) {
          final nMap = Map<String, dynamic>.from(n);
          notes.add(Note(
            id: nMap['id'] ?? 'note_${notes.length}',
            pitch: nMap['pitch'] ?? 60,
            startStep: (nMap['startStep'] as num?)?.toDouble() ?? 0.0,
            durationSteps: (nMap['durationSteps'] as num?)?.toDouble() ?? 1.0,
            velocity: (nMap['velocity'] as num?)?.toDouble() ?? 0.9,
            column: nMap['column'] ?? 0,
            effectCommand: nMap['effectCommand'] ?? '00',
            isSlide: _parseBool(nMap['isSlide']),
            isAccent: _parseBool(nMap['isAccent']),
          ));
        }
      }
    }

    // Parse clips
    final clips = <TrackClip>[];
    final rawClips = map['clips'];
    if (rawClips is List) {
      for (final c in rawClips) {
        if (c is Map) {
          final cMap = Map<String, dynamic>.from(c);
          final cNotes = <Note>[];
          if (cMap['notes'] is List) {
            for (final cn in cMap['notes']) {
              if (cn is Map) {
                final cnMap = Map<String, dynamic>.from(cn);
                cNotes.add(Note.fromJson(cnMap));
              }
            }
          }
          clips.add(TrackClip(
            id: cMap['id'] ?? 'clip_${clips.length}',
            name: cMap['name'] ?? 'Clip ${clips.length + 1}',
            trackId: cMap['trackId'] ?? (map['id'] ?? ''),
            startBar: cMap['startBar'] ?? 0,
            barLength: cMap['barLength'] ?? 2,
            notes: cNotes,
            luaScriptCode: cMap['luaScriptCode'] ?? '',
            luaParams: cMap['luaParams'] is Map ? Map<String, double>.from(
              (cMap['luaParams'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
            ) : {},
          ));
        }
      }
    }

    // Unify track notes and clip notes list reference
    if (clips.isEmpty) {
      clips.add(TrackClip(
        id: 'clip_${map['id'] ?? 'tr'}_0',
        name: '${map['name'] ?? 'Track'} Clip',
        trackId: map['id'] ?? '',
        startBar: 0,
        barLength: 2,
        notes: notes,
        luaScriptCode: map['luaScriptCode'] ?? '',
        luaParams: map['luaParams'] is Map ? Map<String, double>.from(
          (map['luaParams'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
        ) : {},
      ));
    } else {
      for (final c in clips) {
        if (notes.isEmpty && c.notes.isNotEmpty) {
          notes.addAll(c.notes);
        }
        c.notes = notes;
      }
    }

    // Parse FX Rack
    final fxRack = <FXInsert>[];
    final rawFx = map['fxRack'];
    if (rawFx is List) {
      for (final f in rawFx) {
        if (f is Map) {
          final fMap = Map<String, dynamic>.from(f);
          fxRack.add(FXInsert(
            id: fMap['id'] ?? 'fx_${fxRack.length}',
            name: fMap['name'] ?? 'FX',
            type: FXType.values.firstWhere((e) => e.name == fMap['type'], orElse: () => FXType.biquadFilter),
            enabled: _parseBool(fMap['enabled'], true),
            mix: (fMap['mix'] as num?)?.toDouble() ?? 0.5,
            params: fMap['params'] is Map ? Map<String, double>.from(
              (fMap['params'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
            ) : {},
          ));
        }
      }
    }

    // Parse MIDI FX Rack
    final midiFXRack = <MidiFXInsert>[];
    final rawMidiFx = map['midiFXRack'];
    if (rawMidiFx is List) {
      for (final mf in rawMidiFx) {
        if (mf is Map) {
          final mfMap = Map<String, dynamic>.from(mf);
          midiFXRack.add(MidiFXInsert(
            id: mfMap['id'] ?? 'mfx_${midiFXRack.length}',
            name: mfMap['name'] ?? 'MIDI FX',
            enabled: _parseBool(mfMap['enabled'], true),
            luaScriptCode: mfMap['luaScriptCode'] ?? '',
            luaParams: mfMap['luaParams'] is Map ? Map<String, double>.from(
              (mfMap['luaParams'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
            ) : {},
          ));
        }
      }
    }

    final trackTypeStr = map['type'] as String? ?? 'synth';
    final trackType = TrackType.values.firstWhere(
      (t) => t.name == trackTypeStr,
      orElse: () => TrackType.synth,
    );

    final activeViewStr = map['activeView'] as String? ?? 'pianoRoll';
    final activeView = MusicViewType.values.firstWhere(
      (v) => v.name == activeViewStr,
      orElse: () => MusicViewType.pianoRoll,
    );

    return TrackChannel(
      id: map['id'] ?? 'tr_${DateTime.now().millisecondsSinceEpoch}',
      name: map['name'] ?? 'Track',
      color: Color(colorVal),
      type: trackType,
      volume: (map['volume'] as num?)?.toDouble() ?? 0.8,
      pan: (map['pan'] as num?)?.toDouble() ?? 0.0,
      isMuted: _parseBool(map['isMuted']),
      isSoloed: _parseBool(map['isSoloed']),
      sampleName: map['sampleName'] ?? 'kick',
      synthWaveform: map['synthWaveform'] ?? 'sawtooth',
      cutoff: (map['cutoff'] as num?)?.toDouble() ?? 3000.0,
      resonance: (map['resonance'] as num?)?.toDouble() ?? 1.0,
      attack: (map['attack'] as num?)?.toDouble() ?? 0.01,
      release: (map['release'] as num?)?.toDouble() ?? 0.3,
      luaScriptCode: map['luaScriptCode'] ?? '',
      luaParams: map['luaParams'] is Map ? Map<String, double>.from(
        (map['luaParams'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
      ) : {},
      steps: steps,
      notes: notes,
      clips: clips,
      fxRack: fxRack,
      midiFXRack: midiFXRack,
      trackerColumns: map['trackerColumns'] ?? 4,
      activeView: activeView,
    );
  }

  static int _parseColorVal(dynamic val) {
    if (val is int) return val;
    if (val is String) {
      if (val.startsWith('0x') || val.startsWith('0X')) {
        return int.tryParse(val.substring(2), radix: 16) ?? 0xFF00E5FF;
      }
      return int.tryParse(val) ?? 0xFF00E5FF;
    }
    return 0xFF00E5FF;
  }
}

/// Recursive descent parser for Lua tables and primitives.
class _LuaValueParser {
  final String source;
  int pos = 0;

  _LuaValueParser(this.source);

  dynamic parseTopLevel() {
    _skipWhitespace();
    // Skip optional 'return eatsbits.song' prefix
    if (source.startsWith('return', pos)) {
      pos += 6;
      _skipWhitespace();
    }
    if (source.startsWith('eatsbits.song', pos)) {
      pos += 13;
      _skipWhitespace();
    }

    return _parseValue();
  }

  dynamic _parseValue() {
    _skipWhitespace();
    if (pos >= source.length) return null;

    final char = source[pos];
    if (char == '{') {
      return _parseTable();
    } else if (char == '"' || char == "'") {
      return _parseQuotedString();
    } else if (char == '[' && _isLongBracketStart()) {
      return _parseLongBracketString();
    } else if (char == 't' && source.startsWith('true', pos)) {
      pos += 4;
      return true;
    } else if (char == 'f' && source.startsWith('false', pos)) {
      pos += 5;
      return false;
    } else if (char == 'n' && source.startsWith('nil', pos)) {
      pos += 3;
      return null;
    } else {
      return _parseNumberOrLiteral();
    }
  }

  dynamic _parseTable() {
    _expect('{');
    final map = <String, dynamic>{};
    final list = <dynamic>[];
    int autoIndex = 1;
    int lastPos = -1;

    while (pos < source.length) {
      _skipWhitespace();
      if (pos >= source.length || source[pos] == '}') {
        if (pos < source.length && source[pos] == '}') pos++;
        break;
      }

      if (pos == lastPos) {
        // Prevent infinite loop if syntax fails to advance pos
        pos++;
        continue;
      }
      lastPos = pos;

      // Check key format
      if (source[pos] == '[') {
        if (_isLongBracketStart()) {
          // Long bracket string as value in list
          final val = _parseLongBracketString();
          list.add(val);
          _consumeSeparator();
          continue;
        }

        // Bracketed key like [1] = ... or ["key"] = ...
        pos++; // skip '['
        _skipWhitespace();
        final keyVal = _parseValue();
        _skipWhitespace();
        if (pos < source.length && source[pos] == ']') pos++;
        _skipWhitespace();

        if (pos < source.length && source[pos] == '=') {
          pos++; // skip '='
          final val = _parseValue();
          if (keyVal is int) {
            map[keyVal.toString()] = val;
            list.add(val);
          } else if (keyVal != null) {
            map[keyVal.toString()] = val;
          }
        }
      } else {
        // Try reading identifier key e.g. title = "..."
        final keyMatch = _readKeyIdentifier();
        if (keyMatch != null) {
          _skipWhitespace();
          if (pos < source.length && source[pos] == '=') {
            pos++; // skip '='
            final val = _parseValue();
            map[keyMatch] = val;
          } else {
            // It was a literal identifier string in a list
            list.add(keyMatch);
          }
        } else {
          // Plain value entry in array table
          final val = _parseValue();
          if (val != null) {
            list.add(val);
            map[autoIndex.toString()] = val;
            autoIndex++;
          }
        }
      }

      _consumeSeparator();
    }

    if (map.length == list.length && list.isNotEmpty) {
      return list;
    }
    if (list.isNotEmpty && map.length > list.length) {
      // Mixed table with both list items and named keys
      map['__list'] = list;
    }
    return map;
  }

  String _parseQuotedString() {
    final quote = source[pos++];
    final buf = StringBuffer();
    while (pos < source.length) {
      final char = source[pos++];
      if (char == quote) break;
      if (char == '\\' && pos < source.length) {
        final esc = source[pos++];
        if (esc == 'n') {
          buf.write('\n');
        } else if (esc == 'r') {
          buf.write('\r');
        } else if (esc == 't') {
          buf.write('\t');
        } else {
          buf.write(esc);
        }
      } else {
        buf.write(char);
      }
    }
    return buf.toString();
  }

  bool _isLongBracketStart() {
    if (pos >= source.length || source[pos] != '[') return false;
    int p = pos + 1;
    while (p < source.length && source[p] == '=') {
      p++;
    }
    return p < source.length && source[p] == '[';
  }

  String _parseLongBracketString() {
    pos++; // skip initial '['
    int equalsCount = 0;
    while (pos < source.length && source[pos] == '=') {
      equalsCount++;
      pos++;
    }
    if (pos < source.length && source[pos] == '[') pos++; // skip second '['

    final equalsStr = '=' * equalsCount;
    final closingSequence = ']$equalsStr]';
    final startIdx = pos;
    final endIdx = source.indexOf(closingSequence, pos);

    if (endIdx != -1) {
      final result = source.substring(startIdx, endIdx);
      pos = endIdx + closingSequence.length;
      return result.trim();
    } else {
      final result = source.substring(startIdx);
      pos = source.length;
      return result.trim();
    }
  }

  dynamic _parseNumberOrLiteral() {
    final start = pos;
    while (pos < source.length) {
      final c = source[pos];
      if (c == ',' || c == ';' || c == '}' || c == ']' || c == '=' || c == ' ' || c == '\t' || c == '\n' || c == '\r') {
        break;
      }
      pos++;
    }
    if (start == pos) {
      pos++;
      return null;
    }
    final raw = source.substring(start, pos);
    if (raw.startsWith('0x') || raw.startsWith('0X')) {
      return int.tryParse(raw.substring(2), radix: 16) ?? raw;
    }
    final intVal = int.tryParse(raw);
    if (intVal != null) return intVal;
    final doubleVal = double.tryParse(raw);
    if (doubleVal != null) return doubleVal;
    return raw;
  }

  String? _readKeyIdentifier() {
    _skipWhitespace();
    final start = pos;
    if (pos >= source.length) return null;
    final first = source[pos];
    if (!_isAlpha(first) && first != '_') return null;

    while (pos < source.length) {
      final c = source[pos];
      if (_isAlphaNum(c) || c == '_') {
        pos++;
      } else {
        break;
      }
    }
    return source.substring(start, pos);
  }

  void _skipWhitespace() {
    while (pos < source.length) {
      final c = source[pos];
      if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
        pos++;
      } else if (c == '-' && pos + 1 < source.length && source[pos + 1] == '-') {
        // Handle Lua comment --
        pos += 2;
        if (pos + 1 < source.length && source[pos] == '[' && source[pos + 1] == '[') {
          // Block comment --[[ ... ]]
          pos += 2;
          final endBlock = source.indexOf(']]', pos);
          if (endBlock != -1) {
            pos = endBlock + 2;
          } else {
            pos = source.length;
          }
        } else {
          // Single line comment -- ... \n
          while (pos < source.length && source[pos] != '\n' && source[pos] != '\r') {
            pos++;
          }
        }
      } else {
        break;
      }
    }
  }

  void _consumeSeparator() {
    _skipWhitespace();
    while (pos < source.length && (source[pos] == ',' || source[pos] == ';')) {
      pos++;
      _skipWhitespace();
    }
  }

  void _expect(String s) {
    _skipWhitespace();
    if (source.startsWith(s, pos)) {
      pos += s.length;
    }
  }

  bool _isAlpha(String c) {
    final code = c.codeUnitAt(0);
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
  }

  bool _isAlphaNum(String c) {
    final code = c.codeUnitAt(0);
    return _isAlpha(c) || (code >= 48 && code <= 57);
  }
}
