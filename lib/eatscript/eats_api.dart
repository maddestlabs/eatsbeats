import 'dart:math' as math;
import 'package:flutter/material.dart' show Color, Icons;
import '../models/track_model.dart';
import '../models/chord_model.dart';
import '../models/daw_state.dart';
import '../models/automation_model.dart';
import '../audio/easing.dart';
import '../audio/time_context.dart';
import 'eat_param_model.dart';
import 'midi_pipeline_engine.dart';
import 'project_script_engine.dart';
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
  final DawState? dawState;
  TrackChannel? activeTrack;
  TrackClip? activeClip;
  final List<String> logs;

  EatScriptContext({
    List<Note>? notes,
    List<LuaParamDef>? params,
    Map<String, dynamic>? paramValues,
    this.guiLayout,
    this.tempo = 120.0,
    this.keyRoot = 0, // C
    this.isMinor = false,
    this.timeContext,
    this.dawState,
    this.activeTrack,
    this.activeClip,
    List<String>? logs,
  })  : notes = notes ?? [],
        params = params ?? [],
        paramValues = paramValues ?? {},
        logs = logs ?? [];
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

      bool? allowVariance;
      if (kw.containsKey('allow_variance')) {
        allowVariance = kw['allow_variance'] == true;
      } else if (kw.containsKey('ignore_variance')) {
        allowVariance = kw['ignore_variance'] != true;
      } else if (kw.containsKey('variance')) {
        allowVariance = kw['variance'] == true;
      }
      final varianceScale = kw['variance_scale'] is num
          ? (kw['variance_scale'] as num).toDouble()
          : (kw['variance_amount'] is num ? (kw['variance_amount'] as num).toDouble() : 1.0);

      // Avoid duplicate registrations
      context.params.removeWhere((p) => p.name == name);
      final paramDef = LuaParamDef(
        name: name,
        min: min,
        max: max,
        defaultValue: def,
        step: step,
        options: options,
        allowVariance: allowVariance,
        varianceScale: varianceScale,
      );
      context.params.add(paramDef);

      // Return current bound value if present, else default
      return context.paramValues[name] ?? def;
    });

    // 1b. Variance Engine API
    eat['variance'] = EatNativeFunction('eat.variance', (pos, kw) {
      if (pos.isNotEmpty && pos[0] is Map) {
        final map = pos[0] as Map;
        return (map['Variance'] ?? map['variance'] ?? map['Humanize'] ?? map['Variation'] ?? 0.0) as num;
      }
      return (context.paramValues['Variance'] ?? context.paramValues['variance'] ?? context.paramValues['Humanize'] ?? context.paramValues['Variation'] ?? 0.0) as num;
    });

    eat['ignore_variance'] = EatNativeFunction('eat.ignore_variance', (pos, kw) {
      if (pos.isEmpty) return null;
      final name = pos[0].toString();
      context.paramValues['Variance_$name'] = 0.0;
      context.paramValues['ignore_variance_$name'] = 1.0;
      for (int i = 0; i < context.params.length; i++) {
        if (context.params[i].name == name) {
          final p = context.params[i];
          context.params[i] = LuaParamDef(
            name: p.name,
            min: p.min,
            max: p.max,
            defaultValue: p.defaultValue,
            step: p.step,
            options: p.options,
            allowVariance: false,
            varianceScale: 0.0,
          );
        }
      }
      return null;
    });

    eat['is_variance_exempt'] = EatNativeFunction('eat.is_variance_exempt', (pos, kw) {
      if (pos.isEmpty) return true;
      final name = pos[0].toString();
      final p = context.params.where((e) => e.name == name).firstOrNull;
      if (p != null) {
        return (!p.allowVariance || p.varianceScale <= 0.0);
      }
      final lower = name.toLowerCase();
      return context.paramValues['Variance_$name'] == 0.0 ||
          context.paramValues['ignore_variance_$name'] == 1.0 ||
          context.paramValues['allow_variance_$name'] == 0.0 ||
          lower.contains('octave') ||
          lower.contains('waveform') ||
          lower.contains('preset') ||
          lower.contains('bank') ||
          lower.contains('mode');
    });

    eat['vary'] = EatNativeFunction('eat.vary', (pos, kw) {
      if (pos.isEmpty) return 0.0;
      final val = (pos[0] as num).toDouble();
      final amount = pos.length > 1 ? (pos[1] as num).toDouble() : (kw['amount'] ?? kw['scale'] ?? 0.1).toDouble();
      final minVal = pos.length > 2 ? (pos[2] as num?)?.toDouble() : (kw['min'] as num?)?.toDouble();
      final maxVal = pos.length > 3 ? (pos[3] as num?)?.toDouble() : (kw['max'] as num?)?.toDouble();

      final rnd = _rng.nextDouble() * 2.0 - 1.0;
      final offset = (val.abs() > 1e-6 ? val * amount * rnd : amount * rnd);
      double result = val + offset;
      if (minVal != null && result < minVal) result = minVal;
      if (maxVal != null && result > maxVal) result = maxVal;
      return result;
    });

    eat['vary_param'] = EatNativeFunction('eat.vary_param', (pos, kw) {
      if (pos.isEmpty) return 0.0;
      final name = pos[0].toString();
      final params = (pos.length > 1 && pos[1] is Map) ? (pos[1] as Map) : (kw['params'] is Map ? (kw['params'] as Map) : context.paramValues);
      final rawVal = (params[name] ?? context.paramValues[name] ?? 0.0) as num;
      final double val = rawVal.toDouble();

      // Check if param is exempt via explicit flag or definition
      if (params['Variance_$name'] == 0.0 ||
          params['ignore_variance_$name'] == 1.0 ||
          params['allow_variance_$name'] == 0.0) {
        return val;
      }

      // Check if parameter definition exists and whether it allows variance
      final def = context.params.firstWhere((p) => p.name == name, orElse: () => LuaParamDef(name: name, min: 0, max: 1, defaultValue: val));
      if (!def.allowVariance || def.varianceScale <= 0.0) {
        return val;
      }

      final trackVar = (params['Variance'] ?? params['variance'] ?? params['Humanize'] ?? params['Variation'] ?? context.paramValues['Variance'] ?? 0.0) as num;
      if (trackVar <= 0.001) return val;

      final scale = pos.length > 2 ? (pos[2] as num).toDouble() : (kw['scale'] ?? kw['amount'] ?? 0.1).toDouble();
      final minVal = (pos.length > 3 ? (pos[3] as num?)?.toDouble() : (kw['min'] as num?)?.toDouble()) ?? def.min;
      final maxVal = (pos.length > 4 ? (pos[4] as num?)?.toDouble() : (kw['max'] as num?)?.toDouble()) ?? def.max;

      final effectiveAmount = trackVar * def.varianceScale * scale;
      final rnd = _rng.nextDouble() * 2.0 - 1.0;
      final offset = (val.abs() > 1e-6 ? val * effectiveAmount * rnd : effectiveAmount * rnd);
      double result = val + offset;
      if (result < minVal) result = minVal;
      if (result > maxVal) result = maxVal;
      return result;
    });

    eat['apply_variance'] = EatNativeFunction('eat.apply_variance', (pos, kw) {
      final inputMap = (pos.isNotEmpty && pos[0] is Map) ? (pos[0] as Map) : context.paramValues;
      final copy = Map<String, dynamic>.from(inputMap);
      final trackVar = (copy['Variance'] ?? copy['variance'] ?? copy['Humanize'] ?? copy['Variation'] ?? 0.0) as num;
      if (trackVar <= 0.001) return copy;

      for (final paramDef in context.params) {
        if (!paramDef.allowVariance || paramDef.varianceScale <= 0.0) continue;
        if (copy['Variance_${paramDef.name}'] == 0.0 ||
            copy['ignore_variance_${paramDef.name}'] == 1.0 ||
            copy['allow_variance_${paramDef.name}'] == 0.0) {
          continue;
        }
        final currentVal = copy[paramDef.name];
        if (currentVal is num) {
          final val = currentVal.toDouble();
          final effectiveAmount = trackVar * paramDef.varianceScale * 0.1;
          final rnd = _rng.nextDouble() * 2.0 - 1.0;
          final offset = (val.abs() > 1e-6 ? val * effectiveAmount * rnd : effectiveAmount * rnd);
          copy[paramDef.name] = (val + offset).clamp(paramDef.min, paramDef.max);
        }
      }
      return copy;
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
        final bpm = (pos[0] as num).toDouble().clamp(20.0, 999.0);
        context.tempo = bpm;
        context.dawState?.setBpm(bpm);
      }
      return context.tempo;
    });

    // 8. DAW & Macro Orchestration API (`eat.daw` & global `project`)
    final daw = <String, dynamic>{};

    daw['tempo'] = context.dawState?.bpm ?? context.tempo;
    daw['set_tempo'] = EatNativeFunction('eat.daw.set_tempo', (pos, kw) {
      if (pos.isNotEmpty && pos[0] is num) {
        final bpm = (pos[0] as num).toDouble().clamp(20.0, 999.0);
        context.dawState?.setBpm(bpm);
        context.tempo = bpm;
      }
      return context.dawState?.bpm ?? context.tempo;
    });

    daw['key'] = context.dawState?.songKey ?? 'C Major';
    daw['set_key'] = EatNativeFunction('eat.daw.set_key', (pos, kw) {
      if (pos.isNotEmpty) {
        final keyStr = pos[0].toString();
        context.dawState?.setSongKey(keyStr);
      }
      return context.dawState?.songKey ?? 'C Major';
    });

    daw['get_tracks'] = EatNativeFunction('eat.daw.get_tracks', (pos, kw) {
      final tracks = context.dawState?.activePattern.tracks ?? [];
      return tracks.map((t) => EatDawTrackWrapper(t, context.dawState!).toEatDict()).toList();
    });

    daw['get_track'] = EatNativeFunction('eat.daw.get_track', (pos, kw) {
      if (pos.isEmpty || context.dawState == null) return null;
      final query = pos[0].toString().toLowerCase();
      final tracks = context.dawState!.activePattern.tracks;
      for (final t in tracks) {
        if (t.id.toLowerCase() == query || t.name.toLowerCase() == query) {
          return EatDawTrackWrapper(t, context.dawState!).toEatDict();
        }
      }
      return null;
    });

    daw['add_track'] = EatNativeFunction('eat.daw.add_track', (pos, kw) {
      if (context.dawState == null) return null;
      final name = (pos.isNotEmpty ? pos[0] : kw['name'] ?? 'New Track').toString();
      final typeStr = (pos.length > 1 ? pos[1] : kw['type'] ?? 'synth').toString().toLowerCase();
      TrackType type = TrackType.synth;
      if (typeStr.contains('drum') || typeStr.contains('sampler')) {
        type = TrackType.sampler;
      } else if (typeStr.contains('bass')) {
        type = TrackType.bass;
      } else if (typeStr.contains('tts')) {
        type = TrackType.tts;
      } else if (typeStr.contains('script')) {
        type = TrackType.eatScript;
      } else {
        type = TrackType.synth;
      }

      final track = TrackChannel(
        id: 'track_${DateTime.now().microsecondsSinceEpoch}_${context.dawState!.activePattern.tracks.length}',
        name: name,
        type: type,
        color: const Color(0xFF00FFE0),
      );
      context.dawState!.activePattern.tracks.add(track);
      return EatDawTrackWrapper(track, context.dawState!).toEatDict();
    });

    daw['delete_track'] = EatNativeFunction('eat.daw.delete_track', (pos, kw) {
      if (pos.isEmpty || context.dawState == null) return false;
      final query = pos[0].toString().toLowerCase();
      final beforeCount = context.dawState!.activePattern.tracks.length;
      context.dawState!.activePattern.tracks.removeWhere((t) => t.id.toLowerCase() == query || t.name.toLowerCase() == query);
      return context.dawState!.activePattern.tracks.length < beforeCount;
    });

    daw['clear_tracks'] = EatNativeFunction('eat.daw.clear_tracks', (pos, kw) {
      if (context.dawState != null) {
        context.dawState!.activePattern.tracks.clear();
      }
      return null;
    });

    daw['checkpoint'] = EatNativeFunction('eat.daw.checkpoint', (pos, kw) {
      final label = (pos.isNotEmpty ? pos[0] : kw['label'] ?? 'Eatscript Macro').toString();
      context.dawState?.recordHistory(label, icon: Icons.auto_awesome, force: true);
      return null;
    });

    daw['log'] = EatNativeFunction('eat.daw.log', (pos, kw) {
      if (pos.isNotEmpty) {
        context.logs.add(pos[0].toString());
      }
      return null;
    });

    daw['get_chords'] = EatNativeFunction('eat.daw.get_chords', (pos, kw) {
      final chords = context.dawState?.chordTrack ?? [];
      return chords.map((c) => c.toJson()).toList();
    });

    daw['clear_chords'] = EatNativeFunction('eat.daw.clear_chords', (pos, kw) {
      context.dawState?.chordTrack.clear();
      return null;
    });

    daw['add_chord'] = EatNativeFunction('eat.daw.add_chord', (pos, kw) {
      if (context.dawState == null) return null;
      final startBar = (pos.isNotEmpty ? pos[0] : kw['start_bar'] ?? kw['bar'] ?? 0) as num;
      final len = (pos.length > 1 ? pos[1] : kw['length_bars'] ?? kw['length'] ?? 2.0) as num;
      final rootStr = (pos.length > 2 ? pos[2] : kw['root'] ?? 'C').toString();
      final qualityStr = (pos.length > 3 ? pos[3] : kw['quality'] ?? 'major').toString().toLowerCase();

      int rootPC = 0;
      final pcIdx = ChordTheory.pitchClassNames.indexOf(rootStr.toUpperCase());
      if (pcIdx != -1) rootPC = pcIdx;

      ChordQuality q = ChordQuality.major;
      if (qualityStr.contains('min')) {
        q = ChordQuality.minor;
      } else if (qualityStr.contains('maj7')) {
        q = ChordQuality.major7;
      } else if (qualityStr.contains('7')) {
        q = ChordQuality.dominant7;
      } else if (qualityStr.contains('dim')) {
        q = ChordQuality.diminished;
      }

      final chord = ChordEvent(
        id: 'chord_${DateTime.now().microsecondsSinceEpoch}',
        startBar: startBar.toInt(),
        barLength: len.toDouble(),
        rootPitchClass: rootPC,
        quality: q,
      );
      context.dawState!.chordTrack.add(chord);
      return chord.toJson();
    });

    // Audio and Video rendering pipeline integrations
    daw['render_video'] = EatNativeFunction('eat.daw.render_video', (pos, kw) {
      if (context.dawState == null) return false;
      final filename = (pos.isNotEmpty ? pos[0] : kw['filename'] ?? kw['file'] ?? 'eatsbeats_video.mp4').toString();
      final fps = (pos.length > 1 ? pos[1] : kw['fps'] ?? 30) as num;
      final width = (pos.length > 2 ? pos[2] : kw['width'] ?? 1920) as num;
      final height = (pos.length > 3 ? pos[3] : kw['height'] ?? 1080) as num;
      final bars = (pos.length > 4 ? pos[4] : kw['bars'] ?? kw['timeline_bars']) as num?;

      context.logs.add('Video export initiated: $width x $height @ ${fps}fps to "$filename"...');
      context.dawState!.renderVideoFrames(
        filename: filename,
        fps: fps.toInt(),
        width: width.toInt(),
        height: height.toInt(),
        totalTimelineBars: bars?.toInt(),
      );
      return true;
    });

    daw['render_audio'] = EatNativeFunction('eat.daw.render_audio', (pos, kw) {
      if (context.dawState == null) return false;
      final filename = (pos.isNotEmpty ? pos[0] : kw['filename'] ?? kw['file'] ?? 'eatsbeats_export.wav').toString();
      final bars = (pos.length > 1 ? pos[1] : kw['bars'] ?? kw['timeline_bars']) as num?;

      context.logs.add('Audio export initiated: "$filename"...');
      context.dawState!.exportWavSong(
        filename: filename,
        totalTimelineBars: bars?.toInt(),
      );
      return true;
    });

    eat['daw'] = daw;

    // Expose `eat` in the interpreter's global scope
    interpreter.globals.define('eat', eat);

    // Expose `project` (alias to `eat.daw`) in the interpreter's global scope
    interpreter.globals.define('project', daw);

    // Also expose parameter dictionary `params`
    interpreter.globals.define('params', context.paramValues);
  }
}

/// Dynamic Eatscript wrapper for [TrackChannel]
class EatDawTrackWrapper {
  final TrackChannel track;
  final DawState dawState;

  EatDawTrackWrapper(this.track, this.dawState);

  Map<String, dynamic> toEatDict() {
    final map = <String, dynamic>{
      'id': track.id,
      'name': track.name,
      'type': track.type.name,
      'volume': track.volume,
      'pan': track.pan,
      'muted': track.isMuted,
      'soloed': track.isSoloed,
    };

    map['set_volume'] = EatNativeFunction('track.set_volume', (pos, kw) {
      if (pos.isNotEmpty && pos[0] is num) {
        track.volume = (pos[0] as num).toDouble().clamp(0.0, 2.0);
      }
      return track.volume;
    });

    map['set_pan'] = EatNativeFunction('track.set_pan', (pos, kw) {
      if (pos.isNotEmpty && pos[0] is num) {
        track.pan = (pos[0] as num).toDouble().clamp(-1.0, 1.0);
      }
      return track.pan;
    });

    map['set_param'] = EatNativeFunction('track.set_param', (pos, kw) {
      if (pos.isNotEmpty) {
        final key = pos[0].toString();
        final val = pos.length > 1 ? (pos[1] as num).toDouble() : (kw['val'] ?? kw['value'] ?? 0.0) as num;
        track.luaParams[key] = val.toDouble();
      }
      return null;
    });

    map['mute'] = EatNativeFunction('track.mute', (pos, kw) {
      track.isMuted = pos.isNotEmpty ? (pos[0] == true) : !track.isMuted;
      return track.isMuted;
    });

    map['solo'] = EatNativeFunction('track.solo', (pos, kw) {
      track.isSoloed = pos.isNotEmpty ? (pos[0] == true) : !track.isSoloed;
      return track.isSoloed;
    });

    map['create_clip'] = EatNativeFunction('track.create_clip', (pos, kw) {
      final startBar = (pos.isNotEmpty ? pos[0] : kw['start_bar'] ?? kw['bar'] ?? 0) as num;
      final lengthBars = (pos.length > 1 ? pos[1] : kw['length_bars'] ?? kw['length'] ?? 4) as num;
      final name = (pos.length > 2 ? pos[2] : kw['name'] ?? '${track.name} Clip').toString();

      final clip = TrackClip(
        id: 'clip_${DateTime.now().microsecondsSinceEpoch}_${track.clips.length}',
        name: name,
        trackId: track.id,
        startBar: startBar.toInt(),
        barLength: lengthBars.toInt(),
      );
      track.clips.add(clip);
      return EatDawClipWrapper(clip, dawState).toEatDict();
    });

    map['get_clips'] = EatNativeFunction('track.get_clips', (pos, kw) {
      return track.clips.map((c) => EatDawClipWrapper(c, dawState).toEatDict()).toList();
    });

    map['clear_clips'] = EatNativeFunction('track.clear_clips', (pos, kw) {
      track.clips.clear();
      return null;
    });

    // Forward-compatible parameter automation hooks
    map['get_automation'] = EatNativeFunction('track.get_automation', (pos, kw) {
      if (pos.isEmpty) return null;
      final targetId = pos[0].toString();
      final lane = track.automationLanes.cast<AutomationLane?>().firstWhere(
            (l) => l?.target.id == targetId,
            orElse: () => null,
          );
      if (lane == null) return null;
      return {
        'id': lane.id,
        'name': lane.name,
        'points_count': lane.points.length,
      };
    });

    map['add_automation_point'] = EatNativeFunction('track.add_automation_point', (pos, kw) {
      final targetId = (pos.isNotEmpty ? pos[0] : kw['param'] ?? kw['target'])?.toString() ?? 'track.volume';
      final step = (pos.length > 1 ? pos[1] : kw['step'] ?? 0.0) as num;
      final value = (pos.length > 2 ? pos[2] : kw['value'] ?? kw['val'] ?? 1.0) as num;
      final easingStr = (pos.length > 3 ? pos[3] : kw['easing'] ?? 'linear').toString();

      var lane = track.automationLanes.cast<AutomationLane?>().firstWhere(
            (l) => l?.target.id == targetId,
            orElse: () => null,
          );

      if (lane == null) {
        lane = AutomationLane(
          id: 'lane_${DateTime.now().microsecondsSinceEpoch}',
          name: targetId,
          target: AutomationTarget(
            id: targetId,
            name: targetId,
            min: 0.0,
            max: 20000.0,
            defaultValue: value.toDouble(),
          ),
        );
        track.automationLanes.add(lane);
      }

      final pt = AutomationPoint(
        id: 'pt_${DateTime.now().microsecondsSinceEpoch}_${lane.points.length}',
        step: step.toDouble(),
        value: value.toDouble(),
        easing: EasingType.values.firstWhere(
          (e) => e.name.toLowerCase() == easingStr.toLowerCase(),
          orElse: () => EasingType.linear,
        ),
      );
      lane.points.removeWhere((p) => (p.step - step.toDouble()).abs() < 0.001);
      lane.points.add(pt);
      lane.points.sort((a, b) => a.step.compareTo(b.step));
      return pt.toJson();
    });

    map['clear_automation'] = EatNativeFunction('track.clear_automation', (pos, kw) {
      if (pos.isNotEmpty) {
        final targetId = pos[0].toString();
        track.automationLanes.removeWhere((l) => l.target.id == targetId);
      } else {
        track.automationLanes.clear();
      }
      return null;
    });

    return map;
  }
}

/// Dynamic Eatscript wrapper for [TrackClip]
class EatDawClipWrapper {
  final TrackClip clip;
  final DawState dawState;

  EatDawClipWrapper(this.clip, this.dawState);

  Map<String, dynamic> toEatDict() {
    final map = <String, dynamic>{
      'id': clip.id,
      'name': clip.name,
      'start_bar': clip.startBar,
      'bar_length': clip.barLength,
    };

    map['add_note'] = EatNativeFunction('clip.add_note', (pos, kw) {
      final pitch = (pos.isNotEmpty ? pos[0] : kw['pitch'] ?? 60) as num;
      final start = (pos.length > 1 ? pos[1] : kw['start'] ?? kw['step'] ?? 0.0) as num;
      final dur = (pos.length > 2 ? pos[2] : kw['duration'] ?? kw['length'] ?? 1.0) as num;
      final vel = (pos.length > 3 ? pos[3] : kw['velocity'] ?? kw['vel'] ?? 0.85) as num;

      final note = Note(
        id: 'note_${DateTime.now().microsecondsSinceEpoch}_${clip.notes.length}',
        pitch: pitch.toInt().clamp(0, 127),
        startStep: start.toDouble().clamp(0.0, 1024.0),
        durationSteps: dur.toDouble().clamp(0.05, 1024.0),
        velocity: vel.toDouble().clamp(0.01, 1.0),
      );
      clip.notes.add(note);
      return note.toJson();
    });

    map['get_notes'] = EatNativeFunction('clip.get_notes', (pos, kw) {
      return clip.notes.map((n) => n.toJson()).toList();
    });

    map['clear_notes'] = EatNativeFunction('clip.clear_notes', (pos, kw) {
      clip.notes.clear();
      return null;
    });

    // Forward-compatible parameter automation hooks on clip
    map['add_automation_point'] = EatNativeFunction('clip.add_automation_point', (pos, kw) {
      final targetId = (pos.isNotEmpty ? pos[0] : kw['param'] ?? kw['target'])?.toString() ?? 'filter.cutoff';
      final step = (pos.length > 1 ? pos[1] : kw['step'] ?? 0.0) as num;
      final value = (pos.length > 2 ? pos[2] : kw['value'] ?? kw['val'] ?? 1.0) as num;
      final easingStr = (pos.length > 3 ? pos[3] : kw['easing'] ?? 'linear').toString();

      var lane = clip.automationLanes.cast<AutomationLane?>().firstWhere(
            (l) => l?.target.id == targetId,
            orElse: () => null,
          );

      if (lane == null) {
        lane = AutomationLane(
          id: 'clip_lane_${DateTime.now().microsecondsSinceEpoch}',
          name: targetId,
          target: AutomationTarget(
            id: targetId,
            name: targetId,
            min: 0.0,
            max: 20000.0,
            defaultValue: value.toDouble(),
          ),
        );
        clip.automationLanes.add(lane);
      }

      final pt = AutomationPoint(
        id: 'clip_pt_${DateTime.now().microsecondsSinceEpoch}_${lane.points.length}',
        step: step.toDouble(),
        value: value.toDouble(),
        easing: EasingType.values.firstWhere(
          (e) => e.name.toLowerCase() == easingStr.toLowerCase(),
          orElse: () => EasingType.linear,
        ),
      );
      lane.points.removeWhere((p) => (p.step - step.toDouble()).abs() < 0.001);
      lane.points.add(pt);
      lane.points.sort((a, b) => a.step.compareTo(b.step));
      return pt.toJson();
    });

    map['clear_automation'] = EatNativeFunction('clip.clear_automation', (pos, kw) {
      if (pos.isNotEmpty) {
        final targetId = pos[0].toString();
        clip.automationLanes.removeWhere((l) => l.target.id == targetId);
      } else {
        clip.automationLanes.clear();
      }
      return null;
    });

    return map;
  }
}
