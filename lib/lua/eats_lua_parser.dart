import 'dart:ui';
import 'lua_preset_library.dart';
import 'lua_script_library.dart';
import '../models/daw_state.dart';
import '../models/track_model.dart';
import '../models/chord_model.dart';
import '../models/automation_model.dart';
import '../models/lyric_model.dart';
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

  /// Parses a snippet of Lua code (or JSON) representing a list of [Note] objects.
  static List<Note> parseNotes(String code) {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return [];

    try {
      final parser = _LuaValueParser(trimmed);
      final raw = parser.parseTopLevel();
      final List<dynamic> noteItems;
      if (raw is List) {
        noteItems = raw;
      } else if (raw is Map && raw['notes'] is List) {
        noteItems = raw['notes'] as List;
      } else if (raw is Map && raw.containsKey('pitch')) {
        noteItems = [raw];
      } else {
        return [];
      }

      final notes = <Note>[];
      for (int i = 0; i < noteItems.length; i++) {
        final item = noteItems[i];
        if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          final noteObj = Note.fromJson(m);
          if (noteObj.id.isEmpty) {
            noteObj.id = (m['id'] as String?) ?? 'pasted_${DateTime.now().microsecondsSinceEpoch}_$i';
          }
          notes.add(noteObj);
        } else if (item is List && item.isNotEmpty) {
          final pitch = (item[0] as num).toInt();
          final start = item.length > 1 ? (item[1] as num).toDouble() : 0.0;
          final dur = item.length > 2 ? (item[2] as num).toDouble() : 1.0;
          final vel = item.length > 3 ? (item[3] as num).toDouble() : 0.85;
          notes.add(Note(
            id: 'pasted_${DateTime.now().microsecondsSinceEpoch}_$i',
            pitch: pitch.clamp(0, 127),
            startStep: start.clamp(0.0, 64.0),
            durationSteps: dur.clamp(0.1, 64.0),
            velocity: vel.clamp(0.01, 1.0),
          ));
        }
      }
      return notes;
    } catch (_) {
      return [];
    }
  }

  /// Restores [DawState] from `.eats.lua` code. Returns project title.
  static String populateDawState(DawState dawState, String luaCode) {
    final map = parseLuaTableToMap(luaCode);
    if (map.isEmpty) return 'Untitled Song';

    // 1. Meta / Transport settings
    final meta = map['meta'] is Map ? Map<String, dynamic>.from(map['meta']) : {};
    final title = (meta['title'] as String?) ?? 'Untitled Song';
    final author = (meta['author'] as String?) ?? 'Anonymous Producer';
    final songKey = (meta['songKey'] as String?) ?? 'C Major';
    final bpm = (meta['bpm'] as num?)?.toDouble() ?? 124.0;
    final masterVol = (meta['masterVolume'] as num?)?.toDouble() ?? 0.85;
    final isSongMode = (meta['isSongMode'] as bool?) ?? false;
    final isLooping = (meta['isLooping'] as bool?) ?? true;
    final loopStartBar = (meta['loopStartBar'] as int?) ?? 0;
    final loopEndBar = (meta['loopEndBar'] as int?) ?? 2;

    dawState.setProjectDetails(title, author);
    dawState.setSongKey(songKey);
    dawState.setBpm(bpm);
    dawState.setMasterVolume(masterVol);
    dawState.isSongMode = isSongMode;
    dawState.setLoopPoints(loopStartBar, loopEndBar);
    dawState.setLooping(isLooping);

    final masterEqMap = meta['masterEq'] is Map ? Map<String, dynamic>.from(meta['masterEq']) : {};
    dawState.setMasterEq(
      subCut: (masterEqMap['subCut'] as num?)?.toDouble() ?? 25.0,
      lowGain: (masterEqMap['lowGain'] as num?)?.toDouble() ?? 0.0,
      midFreq: (masterEqMap['midFreq'] as num?)?.toDouble() ?? 320.0,
      midGain: (masterEqMap['midGain'] as num?)?.toDouble() ?? 0.0,
      highGain: (masterEqMap['highGain'] as num?)?.toDouble() ?? 0.0,
    );

    final masterLimiterMap = meta['masterLimiter'] is Map ? Map<String, dynamic>.from(meta['masterLimiter']) : {};
    dawState.setMasterLimiter(
      enabled: _parseBool(masterLimiterMap['enabled'], true),
      ceilingDbfs: (masterLimiterMap['ceilingDbfs'] as num?)?.toDouble() ?? -0.3,
      driveDb: (masterLimiterMap['driveDb'] as num?)?.toDouble() ?? 0.0,
      targetLufs: (masterLimiterMap['targetLufs'] as num?)?.toDouble() ?? -14.0,
    );

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

    // 5. Chord Track if present
    final rawChords = map['chordTrack'];
    if (rawChords is List) {
      final loadedChords = <ChordEvent>[];
      for (final ch in rawChords) {
        if (ch is Map) {
          loadedChords.add(ChordEvent.fromJson(Map<String, dynamic>.from(ch)));
        }
      }
      dawState.chordTrack = loadedChords;
    } else {
      dawState.chordTrack = [];
    }

    // 6. Master FX Rack if present
    final rawMasterFx = map['masterFx'];
    if (rawMasterFx is List) {
      dawState.masterTrack.fxRack.clear();
      for (final f in rawMasterFx) {
        if (f is Map) {
          final fMap = Map<String, dynamic>.from(f);
          dawState.masterTrack.fxRack.add(_parseFxInsert(fMap, dawState.masterTrack.fxRack.length));
        }
      }
    }

    dawState.notifyState();
    return title;
  }

  static FXInsert _parseFxInsert(Map<String, dynamic> fMap, int fallbackIndex) {
    final fxName = fMap['name']?.toString() ?? 'FX';
    final fxType = FXType.values.firstWhere((e) => e.name == fMap['type'], orElse: () => FXType.biquadFilter);
    var luaScript = fMap['luaScriptCode'] as String?;
    var presetId = fMap['presetId'] as String?;
    final irSampleName = fMap['irSampleName'] as String?;
    final luaParams = fMap['luaParams'] is Map
        ? Map<String, double>.from((fMap['luaParams'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toDouble())))
        : <String, double>{};
    final params = fMap['params'] is Map
        ? Map<String, double>.from((fMap['params'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toDouble())))
        : <String, double>{};

    // If luaScript is not provided in file, look up matching Audio FX in LuaPresetLibrary
    if (luaScript == null || luaScript.trim().isEmpty) {
      LuaPreset? match;
      if (presetId != null && presetId.isNotEmpty) {
        match = LuaPresetLibrary.getPresetById(presetId);
      }
      if (match == null) {
        final lowerName = fxName.toLowerCase();
        final lowerId = (fMap['id']?.toString() ?? '').toLowerCase();
        if (lowerName.contains('room') || lowerName.contains('room designer') || lowerId.contains('room')) {
          match = LuaPresetLibrary.getPresetById('room_designer');
        } else if (lowerName.contains('cab') || lowerName.contains('cabinet') || lowerName.contains('cab designer') || lowerId.contains('cab')) {
          match = LuaPresetLibrary.getPresetById('cab_designer');
        } else if (lowerName.contains('conv') || lowerName.contains('convolution') || lowerName.contains('reverb') || lowerId.contains('conv') || lowerId.contains('reverb')) {
          match = LuaPresetLibrary.getPresetById('room_designer');
        } else if (lowerName.contains('crush') || lowerName.contains('bitcrush') || lowerName.contains('8-bit') || lowerId.contains('crush')) {
          match = LuaPresetLibrary.getPresetById('bitcrusher');
        } else if (lowerName.contains('shaper') || lowerName.contains('waveshaper') || lowerId.contains('shaper')) {
          match = LuaPresetLibrary.getPresetById('waveshaper');
        } else if (lowerName.contains('delay') || lowerName.contains('stereo delay') || lowerId.contains('delay')) {
          match = LuaPresetLibrary.getPresetById('stereo_delay');
        } else if (lowerName.contains('lowpass') || lowerName.contains('filter') || lowerId.contains('filter')) {
          match = LuaPresetLibrary.getPresetById('lowpass_filter');
        } else if (lowerName.contains('limiter') || lowerId.contains('limiter')) {
          match = LuaPresetLibrary.getPresetById('master_limiter');
        } else if (lowerName.contains('compressor') || lowerId.contains('compressor')) {
          match = LuaPresetLibrary.getPresetById('dynamics_compressor');
        } else if (lowerName.contains('scope') || lowerName.contains('oscilloscope') || lowerId.contains('scope')) {
          match = LuaPresetLibrary.getPresetById('eats_scope');
        } else if (lowerName.contains('spectrum') || lowerName.contains('analyzer') || lowerId.contains('spectrum')) {
          match = LuaPresetLibrary.getPresetById('eats_spectrum');
        } else if (lowerName.contains('teleprompter') || lowerId.contains('teleprompter')) {
          match = LuaPresetLibrary.getPresetById('retro_crt_teleprompter');
        } else if (lowerName.contains('lyric') || lowerId.contains('lyric')) {
          match = LuaPresetLibrary.getPresetById('kinetic_lyric_visualizer');
        } else {
          // Check by FXType enum fallback
          switch (fxType) {
            case FXType.bitcrusher:
              match = LuaPresetLibrary.getPresetById('bitcrusher');
              break;
            case FXType.delay:
              match = LuaPresetLibrary.getPresetById('stereo_delay');
              break;
            case FXType.convolutionReverb:
              match = LuaPresetLibrary.getPresetById('room_designer');
              break;
            case FXType.biquadFilter:
              match = LuaPresetLibrary.getPresetById('lowpass_filter');
              break;
            case FXType.distortion:
              match = LuaPresetLibrary.getPresetById('waveshaper');
              break;
            case FXType.limiter:
              match = LuaPresetLibrary.getPresetById('master_limiter');
              break;
            case FXType.compressor:
              match = LuaPresetLibrary.getPresetById('dynamics_compressor');
              break;
            default:
              break;
          }
        }
      }
      if (match != null) {
        luaScript = match.code;
        presetId ??= match.id;
      }
    }

    if (luaParams.isEmpty && params.isNotEmpty) {
      luaParams.addAll(params);
    }

    return FXInsert(
      id: fMap['id'] ?? 'fx_$fallbackIndex',
      name: fxName,
      type: fxType,
      enabled: _parseBool(fMap['enabled'], true),
      mix: (fMap['mix'] as num?)?.toDouble() ?? 0.5,
      params: params,
      irSampleName: irSampleName,
      luaScriptCode: luaScript,
      presetId: presetId,
      luaParams: luaParams,
    );
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
      for (int i = 0; i < rawNotes.length; i++) {
        final n = rawNotes[i];
        if (n is Map) {
          final nMap = Map<String, dynamic>.from(n);
          final noteObj = Note.fromJson(nMap);
          if (noteObj.id.isEmpty) {
            noteObj.id = (nMap['id'] as String?) ?? 'note_${notes.length}';
          }
          notes.add(noteObj);
        } else if (n is List && n.isNotEmpty) {
          final pitch = (n[0] as num).toInt();
          final start = n.length > 1 ? (n[1] as num).toDouble() : 0.0;
          final dur = n.length > 2 ? (n[2] as num).toDouble() : 1.0;
          final vel = n.length > 3 ? (n[3] as num).toDouble() : 0.85;
          notes.add(Note(
            id: 'note_${notes.length}',
            pitch: pitch.clamp(0, 127),
            startStep: start.clamp(0.0, 64.0),
            durationSteps: dur.clamp(0.1, 64.0),
            velocity: vel.clamp(0.01, 1.0),
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

          final cLyrics = <LyricCue>[];
          if (cMap['lyrics'] is List) {
            for (final cl in cMap['lyrics']) {
              if (cl is Map) {
                cLyrics.add(LyricCue.fromJson(Map<String, dynamic>.from(cl)));
              }
            }
          }

          final cAutomation = <AutomationLane>[];
          if (cMap['automationLanes'] is List) {
            for (final ca in cMap['automationLanes']) {
              if (ca is Map) {
                cAutomation.add(AutomationLane.fromJson(Map<String, dynamic>.from(ca)));
              }
            }
          }

          clips.add(TrackClip(
            id: cMap['id'] ?? 'clip_${clips.length}',
            name: cMap['name'] ?? 'Clip ${clips.length + 1}',
            trackId: cMap['trackId'] ?? (map['id'] ?? ''),
            startBar: (cMap['startBar'] as num?)?.toInt() ?? 0,
            barLength: (cMap['barLength'] as num?)?.toInt() ?? 2,
            patternIndex: (cMap['patternIndex'] as num?)?.toInt() ?? clips.length,
            loopLengthBars: (cMap['loopLengthBars'] as num?)?.toInt(),
            isAudioClip: cMap['isAudioClip'] == true,
            audioSampleName: cMap['audioSampleName'] as String?,
            audioPitchOffset: (cMap['audioPitchOffset'] as num?)?.toDouble() ?? 0.0,
            notes: cNotes,
            lyrics: cLyrics,
            automationLanes: cAutomation,
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
        luaScriptCode: '',
        luaParams: {},
      ));
    } else {
      if (clips.length == 1) {
        if (notes.isEmpty && clips.first.notes.isNotEmpty) {
          notes.addAll(clips.first.notes);
        }
        clips.first.notes = notes;
      } else {
        if (notes.isEmpty) {
          for (final c in clips) {
            notes.addAll(c.notes);
          }
        }
      }
    }

    // Parse FX Rack
    final fxRack = <FXInsert>[];
    final rawFx = map['fxRack'];
    if (rawFx is List) {
      for (final f in rawFx) {
        if (f is Map) {
          final fMap = Map<String, dynamic>.from(f);
          fxRack.add(_parseFxInsert(fMap, fxRack.length));
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

    final rawScript = map['luaScriptCode'] as String? ?? '';
    final presetId = (map['presetId'] as String?) ?? (map['preset'] as String?);
    String scriptCode = rawScript;

    if (scriptCode.trim().isEmpty && presetId != null && presetId.isNotEmpty) {
      final preset = LuaScriptLibrary.getPresetById(presetId);
      if (preset != null) {
        scriptCode = preset.code;
      }
    }

    if (scriptCode.trim().isEmpty) {
      final matchedPreset = LuaScriptLibrary.findMatchingScript('', fallbackName: map['name']);
      if (matchedPreset != null) {
        scriptCode = matchedPreset.code;
      }
    }

    final trackTypeStr = map['type'] as String? ?? (scriptCode.isNotEmpty ? 'luaScript' : 'synth');
    final trackType = TrackType.values.firstWhere(
      (t) => t.name == trackTypeStr,
      orElse: () => scriptCode.isNotEmpty ? TrackType.luaScript : TrackType.synth,
    );

    final activeViewStr = map['activeView'] as String? ?? 'pianoRoll';
    final activeView = MusicViewType.values.firstWhere(
      (v) => v.name == activeViewStr,
      orElse: () => MusicViewType.pianoRoll,
    );

    final chordFollowModeStr = map['chordFollowMode'] as String? ?? 'off';
    final chordFollowMode = ChordFollowMode.values.firstWhere(
      (m) => m.name == chordFollowModeStr,
      orElse: () => ChordFollowMode.off,
    );

    // Parse built-in EQ and tags
    final eqMap = map['eq'] is Map ? Map<String, dynamic>.from(map['eq']) : {};
    final eqEnabled = _parseBool(eqMap['enabled'], false);
    final eqHpf = (eqMap['hpf'] as num?)?.toDouble() ?? 20.0;
    final eqLowGain = (eqMap['lowGain'] as num?)?.toDouble() ?? 0.0;
    final eqMidFreq = (eqMap['midFreq'] as num?)?.toDouble() ?? 1000.0;
    final eqMidGain = (eqMap['midGain'] as num?)?.toDouble() ?? 0.0;
    final eqMidQ = (eqMap['midQ'] as num?)?.toDouble() ?? 1.0;
    final eqHighGain = (eqMap['highGain'] as num?)?.toDouble() ?? 0.0;

    final tags = (map['tags'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];

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
      eqEnabled: eqEnabled,
      eqHpf: eqHpf,
      eqLowGain: eqLowGain,
      eqMidFreq: eqMidFreq,
      eqMidGain: eqMidGain,
      eqMidQ: eqMidQ,
      eqHighGain: eqHighGain,
      tags: tags,
      luaScriptCode: scriptCode,
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
      chordFollowMode: chordFollowMode,
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
    // Skip optional 'local' prefix
    if (source.startsWith('local', pos)) {
      pos += 5;
      _skipWhitespace();
    }
    // Skip optional 'return' prefix
    if (source.startsWith('return', pos)) {
      pos += 6;
      _skipWhitespace();
    }
    if (source.startsWith('eatsbeats.song', pos)) {
      pos += 14;
      _skipWhitespace();
    } else if (source.startsWith('eatsbits.song', pos)) {
      pos += 13;
      _skipWhitespace();
    } else if (source.startsWith('eats.song', pos)) {
      pos += 9;
      _skipWhitespace();
    }

    // Check if there is an assignment like "notes = {" or "data = {"
    final eqIdx = source.indexOf('=', pos);
    if (eqIdx != -1) {
      final prefix = source.substring(pos, eqIdx).trim();
      if (RegExp(r'^[a-zA-Z_][a-zA-Z0-9_\.]*$').hasMatch(prefix)) {
        pos = eqIdx + 1;
        _skipWhitespace();
      }
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
