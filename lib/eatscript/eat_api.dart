import 'dart:math' as math;
import '../models/track_model.dart';
import '../models/chord_model.dart';
import '../audio/time_context.dart';
import '../lua/lua_engine.dart';
import '../lua/midi_pipeline_engine.dart';
import '../lua/project_script_engine.dart';
import 'eat_interpreter.dart';

/// The host context in which an Eatscript executes.
class EatScriptContext {
  final List<Note> notes;
  final List<LuaParamDef> params;
  final Map<String, dynamic> paramValues;
  Map<String, dynamic>? guiLayout;
  double tempo;
  int keyRoot;
  bool isMinor;
  final TimeContext? timeContext;

  EatScriptContext({
    List<Note>? notes,
    List<LuaParamDef>? params,
    Map<String, dynamic>? paramValues,
    this.guiLayout,
    this.tempo = 120.0,
    this.keyRoot = 0, // C
    this.isMinor = false,
    this.timeContext,
  })  : notes = notes ?? [],
        params = params ?? [],
        paramValues = paramValues ?? {};
}

/// Binds the `eat` module and its musical API methods to the [EatInterpreter].
class EatHostApi {
  static final math.Random _rng = math.Random();

  static void install(EatInterpreter interpreter, EatScriptContext context) {
    final eat = <String, dynamic>{};

    // 1. Parameter Registration
    eat['param'] = EatNativeFunction('eat.param', (pos, kw) {
      if (pos.isEmpty) return null;
      final name = pos[0].toString();
      final min = pos.length > 1 ? (pos[1] as num).toDouble() : (kw['min'] ?? 0.0).toDouble();
      final max = pos.length > 2 ? (pos[2] as num).toDouble() : (kw['max'] ?? 1.0).toDouble();
      final def = pos.length > 3 ? (pos[3] as num).toDouble() : (kw['default'] ?? min).toDouble();
      final step = pos.length > 4 ? (pos[4] as num).toDouble() : (kw['step'] ?? 0.0).toDouble();
      final options = kw['options'] is List ? (kw['options'] as List).map((e) => e.toString()).toList() : <String>[];

      // Avoid duplicate registrations
      context.params.removeWhere((p) => p.name == name);
      final paramDef = LuaParamDef(
        name: name,
        min: min,
        max: max,
        defaultValue: def,
        step: step,
        options: options,
      );
      context.params.add(paramDef);

      // Return current bound value if present, else default
      return context.paramValues[name] ?? def;
    });

    // 2. Hardware GUI Declaration
    eat['gui'] = EatNativeFunction('eat.gui', (pos, kw) {
      if (pos.isNotEmpty && pos[0] is Map) {
        context.guiLayout = Map<String, dynamic>.from(pos[0] as Map);
      }
      return null;
    });

    // 3. Note Management
    eat['add_note'] = EatNativeFunction('eat.add_note', (pos, kw) {
      final pitch = (pos.isNotEmpty ? pos[0] : kw['pitch'] ?? 60) as num;
      final start = (pos.length > 1 ? pos[1] : kw['start'] ?? kw['step'] ?? 0.0) as num;
      final dur = (pos.length > 2 ? pos[2] : kw['duration'] ?? kw['length'] ?? 1.0) as num;
      final vel = (pos.length > 3 ? pos[3] : kw['velocity'] ?? kw['vel'] ?? 0.85) as num;

      final note = Note(
        id: 'eat_${DateTime.now().microsecondsSinceEpoch}_${context.notes.length}',
        pitch: pitch.toInt().clamp(0, 127),
        startStep: start.toDouble().clamp(0.0, 1024.0),
        durationSteps: dur.toDouble().clamp(0.05, 1024.0),
        velocity: vel.toDouble().clamp(0.01, 1.0),
      );
      context.notes.add(note);
      return {
        'id': note.id,
        'pitch': note.pitch,
        'start': note.startStep,
        'duration': note.durationSteps,
        'velocity': note.velocity,
      };
    });

    eat['clear_notes'] = EatNativeFunction('eat.clear_notes', (pos, kw) {
      context.notes.clear();
      return null;
    });

    eat['get_notes'] = EatNativeFunction('eat.get_notes', (pos, kw) {
      return context.notes
          .map((n) => {
                'id': n.id,
                'pitch': n.pitch,
                'start': n.startStep,
                'duration': n.durationSteps,
                'velocity': n.velocity,
              })
          .toList();
    });

    // 4. Music Theory: Scales & Chords
    eat['scale'] = EatNativeFunction('eat.scale', (pos, kw) {
      final rootStr = pos.isNotEmpty ? pos[0].toString() : (kw['root'] ?? 'C').toString();
      final scaleType = (pos.length > 1 ? pos[1] : (kw['type'] ?? 'major')).toString().toLowerCase();

      int root = 0;
      final match = RegExp(r'^([A-Ga-g][#b]?)(?:(\d))?$').firstMatch(rootStr);
      if (match != null) {
        final notePart = match.group(1)!.toUpperCase();
        final octPart = match.group(2) != null ? int.parse(match.group(2)!) : 4;
        final pc = ChordTheory.pitchClassNames.indexOf(notePart);
        root = (pc != -1 ? pc : 0) + (octPart + 1) * 12;
      } else if (int.tryParse(rootStr) != null) {
        root = int.parse(rootStr);
      }

      List<int> intervals;
      if (scaleType.contains('minor') && !scaleType.contains('pentatonic')) {
        intervals = [0, 2, 3, 5, 7, 8, 10]; // Natural Minor
      } else if (scaleType.contains('dorian')) {
        intervals = [0, 2, 3, 5, 7, 9, 10];
      } else if (scaleType.contains('mixolydian')) {
        intervals = [0, 2, 4, 5, 7, 9, 10];
      } else if (scaleType.contains('blues')) {
        intervals = [0, 3, 5, 6, 7, 10];
      } else if (scaleType.contains('pentatonic')) {
        intervals = scaleType.contains('minor') ? [0, 3, 5, 7, 10] : [0, 2, 4, 7, 9];
      } else {
        intervals = [0, 2, 4, 5, 7, 9, 11]; // Major
      }

      return intervals.map((i) => (root + i).clamp(0, 127)).toList();
    });

    eat['scale_conform'] = EatNativeFunction('eat.scale_conform', (pos, kw) {
      final pitch = (pos.isNotEmpty ? pos[0] : kw['pitch'] ?? 60) as num;
      final root = (pos.length > 1 ? pos[1] : kw['root'] ?? context.keyRoot) as num;
      final isMinor = (pos.length > 2 ? pos[2] : kw['is_minor'] ?? context.isMinor) as bool;
      return ProjectScriptHelpers.scaleConform(pitch.toInt(), root.toInt(), isMinor);
    });

    eat['snap_to_chord'] = EatNativeFunction('eat.snap_to_chord', (pos, kw) {
      final pitch = (pos.isNotEmpty ? pos[0] : kw['pitch'] ?? 60) as num;
      final chordName = (pos.length > 1 ? pos[1] : kw['chord'] ?? 'C').toString();
      final mode = (pos.length > 2 ? pos[2] : kw['mode'] ?? 'chord').toString();

      int rootPC = 0;
      ChordQuality quality = ChordQuality.major;
      int? bassPC;

      final slashIdx = chordName.indexOf('/');
      String basePart = chordName;
      if (slashIdx != -1) {
        basePart = chordName.substring(0, slashIdx).trim();
        final bassStr = chordName.substring(slashIdx + 1).trim();
        final bIdx = ChordTheory.pitchClassNames.indexOf(bassStr.toUpperCase());
        if (bIdx != -1) bassPC = bIdx;
      }

      final rootMatch = RegExp(r'^([A-Ga-g][#b]?)(.*)$').firstMatch(basePart);
      if (rootMatch != null) {
        final rName = rootMatch.group(1)!.toUpperCase();
        final qStr = rootMatch.group(2)!.trim().toLowerCase();
        final rIdx = ChordTheory.pitchClassNames.indexOf(rName);
        if (rIdx != -1) rootPC = rIdx;

        if (qStr == 'm' || qStr == 'min' || qStr == 'minor') {
          quality = ChordQuality.minor;
        } else if (qStr == 'maj7' || qStr == 'major7') {
          quality = ChordQuality.major7;
        } else if (qStr == 'm7' || qStr == 'min7') {
          quality = ChordQuality.minor7;
        } else if (qStr == '7') {
          quality = ChordQuality.dominant7;
        } else if (qStr == 'dim') {
          quality = ChordQuality.diminished;
        } else if (qStr == 'aug') {
          quality = ChordQuality.augmented;
        } else if (qStr == 'sus4') {
          quality = ChordQuality.sus4;
        } else if (qStr == 'sus2') {
          quality = ChordQuality.sus2;
        }
      }

      final parsed = ChordEvent(
        id: 'chord_query',
        startBar: 0,
        rootPitchClass: rootPC,
        quality: quality,
        bassPitchClass: bassPC,
      );
      return ProjectScriptHelpers.snapToChord(pitch.toInt(), parsed, mode: mode);
    });

    // 5. Rhythm & Transforms
    eat['euclidean'] = EatNativeFunction('eat.euclidean', (pos, kw) {
      final step = (pos.isNotEmpty ? pos[0] : kw['step'] ?? 0) as num;
      final steps = (pos.length > 1 ? pos[1] : kw['steps'] ?? 16) as num;
      final pulses = (pos.length > 2 ? pos[2] : kw['pulses'] ?? 4) as num;
      final shift = (pos.length > 3 ? pos[3] : kw['shift'] ?? 0) as num;

      final s = steps.toInt();
      final p = pulses.toInt();
      if (s <= 0 || p <= 0) return false;
      if (p >= s) return true;

      final idx = (step.toInt() - shift.toInt()) % s;
      final normalizedIdx = idx < 0 ? idx + s : idx;
      return (normalizedIdx * p) % s < p;
    });

    eat['humanize'] = EatNativeFunction('eat.humanize', (pos, kw) {
      dynamic targetList = context.notes;
      int argOffset = 0;
      if (pos.isNotEmpty && pos[0] is List) {
        targetList = pos[0];
        argOffset = 1;
      }
      final timing = (pos.length > argOffset ? pos[argOffset] : kw['timing'] ?? 0.02) as num;
      final velDrift = (pos.length > (argOffset + 1) ? pos[argOffset + 1] : kw['velocity'] ?? 0.08) as num;

      for (int i = 0; i < targetList.length; i++) {
        final n = targetList[i];
        final dt = (_rng.nextDouble() * 2.0 - 1.0) * timing;
        final dv = (_rng.nextDouble() * 2.0 - 1.0) * velDrift;
        if (n is Note) {
          targetList[i] = n.copyWith(
            startStep: math.max(0.0, n.startStep + dt),
            velocity: (n.velocity + dv).clamp(0.05, 1.0),
          );
        } else if (n is Map) {
          final start = ((n['start'] ?? n['startStep'] ?? 0.0) as num).toDouble();
          final vel = ((n['velocity'] ?? n['vel'] ?? 0.85) as num).toDouble();
          n['start'] = math.max(0.0, start + dt);
          n['startStep'] = n['start'];
          n['velocity'] = (vel + dv).clamp(0.05, 1.0);
          n['vel'] = n['velocity'];
        }
      }
      return targetList;
    });

    eat['transpose'] = EatNativeFunction('eat.transpose', (pos, kw) {
      dynamic targetList = context.notes;
      int argOffset = 0;
      if (pos.isNotEmpty && pos[0] is List) {
        targetList = pos[0];
        argOffset = 1;
      }
      final semitones = (pos.length > argOffset ? pos[argOffset] : kw['semitones'] ?? 0) as num;
      final shift = semitones.toInt();
      for (int i = 0; i < targetList.length; i++) {
        final n = targetList[i];
        if (n is Note) {
          targetList[i] = n.copyWith(
            pitch: (n.pitch + shift).clamp(0, 127),
          );
        } else if (n is Map) {
          final pitch = ((n['pitch'] ?? 60) as num).toInt();
          n['pitch'] = (pitch + shift).clamp(0, 127);
        }
      }
      return targetList;
    });

    List<Note> parseNotesList(dynamic rawNotes) {
      if (rawNotes is! List) return context.notes;
      final result = <Note>[];
      for (final item in rawNotes) {
        if (item is Note) {
          result.add(item);
        } else if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          final pitch = ((m['pitch'] ?? 60) as num).toInt().clamp(0, 127);
          final start = ((m['start'] ?? m['startStep'] ?? 0.0) as num).toDouble().clamp(0.0, 1024.0);
          final duration = ((m['duration'] ?? m['durationSteps'] ?? 1.0) as num).toDouble().clamp(0.05, 1024.0);
          final vel = ((m['velocity'] ?? m['vel'] ?? 0.85) as num).toDouble().clamp(0.01, 1.0);
          final id = (m['id'] as String?) ?? 'eat_${DateTime.now().microsecondsSinceEpoch}_${result.length}';
          result.add(Note(id: id, pitch: pitch, startStep: start, durationSteps: duration, velocity: vel));
        }
      }
      return result;
    }

    List<Map<String, dynamic>> notesToMaps(List<Note> noteList) {
      return noteList.map((n) => {
        'id': n.id,
        'pitch': n.pitch,
        'start': n.startStep,
        'duration': n.durationSteps,
        'velocity': n.velocity,
      }).toList();
    }

    eat['arpeggiate'] = EatNativeFunction('eat.arpeggiate', (pos, kw) {
      final inputNotes = pos.isNotEmpty ? parseNotesList(pos[0]) : context.notes;
      final rate = (pos.length > 1 ? pos[1] : kw['rate'] ?? 1.0) as num;
      final octaves = (pos.length > 2 ? pos[2] : kw['octaves'] ?? 2.0) as num;
      final pattern = (kw['pattern'] ?? (pos.length > 3 ? pos[3] : 'up')).toString();
      final gate = (kw['gate'] ?? (pos.length > 4 ? pos[4] : 0.85)) as num;
      final swing = (kw['swing'] ?? (pos.length > 5 ? pos[5] : 0.0)) as num;

      final res = MidiPipelineEngine.applyArpeggiator(
        inputNotes,
        stepRate: rate.toDouble(),
        octaves: octaves.toInt(),
        pattern: pattern.toLowerCase(),
        gate: gate.toDouble(),
        swing: swing.toDouble(),
        timeContext: context.timeContext,
      );
      if (pos.isEmpty) {
        context.notes.clear();
        context.notes.addAll(res);
      }
      return notesToMaps(res);
    });

    eat['chord_follow'] = EatNativeFunction('eat.chord_follow', (pos, kw) {
      final inputNotes = pos.isNotEmpty ? parseNotesList(pos[0]) : context.notes;
      final rawMode = (pos.length > 1 ? pos[1] : kw['mode'] ?? 0.0);
      String modeStr = 'chord';
      if (rawMode is String) {
        final lower = rawMode.toLowerCase();
        if (lower.contains('bass')) modeStr = 'bass';
        else if (lower.contains('scale')) modeStr = 'scale';
        else if (lower.contains('color') || lower.contains('lead')) modeStr = 'colorLead';
      } else if (rawMode is num) {
        final m = rawMode.toInt();
        if (m == 1) modeStr = 'bass';
        else if (m == 2) modeStr = 'scale';
        else if (m == 3) modeStr = 'colorLead';
      }

      final tc = context.timeContext ?? TimeContext(
        bpm: context.tempo,
        currentBar: 0.0,
        currentBeat: 0.0,
        audioTimeSeconds: 0.0,
        songKeyRoot: context.keyRoot,
        isSongKeyMinor: context.isMinor,
      );

      final res = MidiPipelineEngine.applyChordFollow(inputNotes, tc, mode: modeStr);
      if (pos.isEmpty) {
        context.notes.clear();
        context.notes.addAll(res);
      }
      return notesToMaps(res);
    });

    eat['chord_arp'] = EatNativeFunction('eat.chord_arp', (pos, kw) {
      final inputNotes = pos.isNotEmpty ? parseNotesList(pos[0]) : context.notes;
      final rate = (pos.length > 1 ? pos[1] : kw['rate'] ?? 1.0) as num;
      final octaves = (pos.length > 2 ? pos[2] : kw['octaves'] ?? 1.0) as num;
      final pattern = (kw['pattern'] ?? (pos.length > 3 ? pos[3] : 'up')).toString();
      final gate = (kw['gate'] ?? (pos.length > 4 ? pos[4] : 0.85)) as num;
      final swing = (kw['swing'] ?? (pos.length > 5 ? pos[5] : 0.0)) as num;

      final tc = context.timeContext ?? TimeContext(
        bpm: context.tempo,
        currentBar: 0.0,
        currentBeat: 0.0,
        audioTimeSeconds: 0.0,
        songKeyRoot: context.keyRoot,
        isSongKeyMinor: context.isMinor,
      );

      final res = MidiPipelineEngine.applyChordArpeggiate(
        inputNotes,
        tc,
        stepRate: rate.toDouble(),
        octaves: octaves.toInt(),
        pattern: pattern.toLowerCase(),
        gate: gate.toDouble(),
        swing: swing.toDouble(),
      );
      if (pos.isEmpty) {
        context.notes.clear();
        context.notes.addAll(res);
      }
      return notesToMaps(res);
    });

    eat['scale_snap'] = EatNativeFunction('eat.scale_snap', (pos, kw) {
      final inputNotes = pos.isNotEmpty ? parseNotesList(pos[0]) : context.notes;
      final key = (pos.length > 1 ? pos[1] : kw['key'] ?? context.keyRoot) as num;
      final rawScale = (pos.length > 2 ? pos[2] : kw['scale'] ?? (context.isMinor ? 1 : 0));
      bool isMinor = context.isMinor;
      if (rawScale is num) {
        isMinor = rawScale.toInt() == 1;
      } else if (rawScale is String) {
        isMinor = rawScale.toLowerCase().contains('minor');
      }

      final res = inputNotes.map((n) {
        final snapped = ProjectScriptHelpers.scaleConform(n.pitch, key.toInt(), isMinor);
        return n.copyWith(pitch: snapped);
      }).toList();

      if (pos.isEmpty) {
        context.notes.clear();
        context.notes.addAll(res);
      }
      return notesToMaps(res);
    });

    // 6. Randomness
    eat['random_int'] = EatNativeFunction('eat.random_int', (pos, kw) {
      final min = (pos.isNotEmpty ? pos[0] : kw['min'] ?? 0) as num;
      final max = (pos.length > 1 ? pos[1] : kw['max'] ?? 10) as num;
      final low = min.toInt();
      final high = max.toInt();
      if (high <= low) return low;
      return low + _rng.nextInt(high - low + 1);
    });

    eat['random_float'] = EatNativeFunction('eat.random_float', (pos, kw) {
      final min = (pos.isNotEmpty ? pos[0] : kw['min'] ?? 0.0) as num;
      final max = (pos.length > 1 ? pos[1] : kw['max'] ?? 1.0) as num;
      return min.toDouble() + _rng.nextDouble() * (max.toDouble() - min.toDouble());
    });

    eat['random_choice'] = EatNativeFunction('eat.random_choice', (pos, kw) {
      if (pos.isEmpty || pos[0] is! List) return null;
      final list = pos[0] as List;
      if (list.isEmpty) return null;
      return list[_rng.nextInt(list.length)];
    });

    // 7. Context Info
    eat['tempo'] = context.tempo;
    eat['set_tempo'] = EatNativeFunction('eat.set_tempo', (pos, kw) {
      if (pos.isNotEmpty && pos[0] is num) {
        context.tempo = (pos[0] as num).toDouble().clamp(20.0, 999.0);
      }
      return context.tempo;
    });

    // Expose `eat` in the interpreter's global scope
    interpreter.globals.define('eat', eat);

    // Also expose parameter dictionary `params`
    interpreter.globals.define('params', context.paramValues);
  }
}
