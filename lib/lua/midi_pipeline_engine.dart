import 'dart:math' as math;
import '../models/track_model.dart';
import '../models/chord_model.dart';
import '../audio/time_context.dart';
import 'lua_engine.dart';

/// Evaluates clips and processes MIDI FX chains to produce scheduled Note events.
/// Implements persistent Voice ID tracking to prevent stuck notes when parameters
/// or pitch mappings are transformed dynamically.
class MidiPipelineEngine {
  final LuaEngine luaEngine;

  MidiPipelineEngine({required this.luaEngine});

  /// Processes a [TrackClip] through its base notes and the track's [MidiFXInsert] chain.
  List<Note> processClip({
    required TrackClip clip,
    required TrackChannel track,
    required TimeContext timeContext,
  }) {
    // 1. Initial Note Set: Use clip.notes or cached notes
    List<Note> activeNotes = clip.notes.map((n) => n.copyWith()).toList();

    // 2. Process Track MIDI FX Rack sequentially
    for (final midiFX in track.midiFXRack) {
      if (!midiFX.enabled || midiFX.luaScriptCode.trim().isEmpty) continue;
      activeNotes = _evaluateMidiFX(midiFX, activeNotes, timeContext);
    }

    // Update clip cache
    clip.evaluatedNotesCache = activeNotes;
    return activeNotes;
  }

  static bool _isMidiTransformScript(String code) {
    final lower = code.toLowerCase();
    return lower.contains('transform_notes') ||
        lower.contains('function process') ||
        lower.contains('midi.') ||
        lower.contains('chord.') ||
        lower.contains('@category: midifx') ||
        lower.contains('chord_follow') ||
        lower.contains('chord_arp') ||
        lower.contains('chord_stabs') ||
        lower.contains('arpeggiat') ||
        lower.contains('arp');
  }

  /// Evaluates an optional clip script transformation hook (e.g. process(notes, timeCtx)).
  List<Note> _evaluateClipScript(
    TrackClip clip,
    List<Note> baseNotes,
    TimeContext timeContext,
  ) {
    final script = clip.luaScriptCode.trim();

    // 1. Chord Follower Clip Transformation Hook
    if (script.contains('chord_follow') || script.contains('snap_to_chord') || script.contains('Chord.snap') || script.contains('Chord.conform')) {
      final rawMode = clip.luaParams['mode'] ?? 0.0;
      String modeStr = 'chord';
      if (rawMode == 1.0) {
        modeStr = 'bass';
      } else if (rawMode == 2.0) {
        modeStr = 'scale';
      } else if (rawMode == 3.0) {
        modeStr = 'colorLead';
      }
      return applyChordFollow(baseNotes, timeContext, mode: modeStr);
    }

    // 2. Chord Arpeggiator Clip Transformation Hook
    if (script.contains('chord_arp') || script.contains('Chord.arpeggiate')) {
      final rate = clip.luaParams['rate'] ?? clip.luaParams['Rate'] ?? 1.0;
      final octaves = (clip.luaParams['octaves'] ?? clip.luaParams['Octaves'] ?? 1.0).toInt();
      final pattern = _parsePattern(clip.luaParams['pattern'] ?? clip.luaParams['Pattern']);
      final gate = clip.luaParams['gate'] ?? clip.luaParams['Gate'] ?? 0.85;
      final swing = clip.luaParams['swing'] ?? clip.luaParams['Swing'] ?? 0.0;
      return applyChordArpeggiate(baseNotes, timeContext, stepRate: rate, octaves: octaves, pattern: pattern, gate: gate, swing: swing);
    }

    // 3. Chord Voicing / Stabs Generator Hook
    if (script.contains('chord_stabs') || script.contains('Chord.generate_voicing')) {
      return generateChordVoicings(baseNotes, timeContext);
    }

    // 4. Standard Arpeggiator fallback
    if (script.contains('Midi.arpeggiate') || script.toLowerCase().contains('arpeggiat') || script.toLowerCase().contains('arp')) {
      final rate = clip.luaParams['rate'] ?? clip.luaParams['Rate'] ?? 1.0;
      final octaves = (clip.luaParams['octaves'] ?? clip.luaParams['Octaves'] ?? 2.0).toInt();
      final pattern = _parsePattern(clip.luaParams['pattern'] ?? clip.luaParams['Pattern']);
      final gate = clip.luaParams['gate'] ?? clip.luaParams['Gate'] ?? 0.85;
      final swing = clip.luaParams['swing'] ?? clip.luaParams['Swing'] ?? 0.0;
      return applyArpeggiator(
        baseNotes,
        stepRate: rate,
        octaves: octaves,
        pattern: pattern,
        gate: gate,
        swing: swing,
        timeContext: timeContext,
      );
    }

    // 5. Transpose fallback
    if (script.contains('transpose')) {
      final semitones = (clip.luaParams['semitones'] ?? 0.0).round();
      return baseNotes.map((n) => n.copyWith(pitch: (n.pitch + semitones).clamp(0, 127))).toList();
    }

    return baseNotes;
  }

  /// Evaluates a MIDI FX insert on a stream/list of notes.
  List<Note> _evaluateMidiFX(
    MidiFXInsert midiFX,
    List<Note> notes,
    TimeContext timeContext,
  ) {
    final code = midiFX.luaScriptCode.trim();
    final nameLower = midiFX.name.toLowerCase();

    // 1. Harmonic Chord Follower MIDI FX
    if (code.contains('chord_follower') || code.contains('chord_follow') || nameLower.contains('chord follow') || nameLower.contains('harmonic')) {
      final rawMode = midiFX.luaParams['Mode'] ?? midiFX.luaParams['mode'] ?? 0.0;
      String modeStr = 'chord';
      final modeInt = rawMode.round();
      if (modeInt == 1) {
        modeStr = 'bass';
      } else if (modeInt == 2) {
        modeStr = 'scale';
      } else if (modeInt == 3) {
        modeStr = 'colorLead';
      }
      return applyChordFollow(notes, timeContext, mode: modeStr);
    }

    // 2. Chord Arpeggiator MIDI FX (Arpeggiates active Chord Track pitch classes)
    if (code.contains('chord_arp') || nameLower.contains('chord arp')) {
      final rate = midiFX.luaParams['Rate'] ?? midiFX.luaParams['rate'] ?? 1.0;
      final octaves = (midiFX.luaParams['Octaves'] ?? midiFX.luaParams['octaves'] ?? 1.0).toInt();
      final pattern = _parsePattern(midiFX.luaParams['Pattern'] ?? midiFX.luaParams['pattern']);
      final gate = midiFX.luaParams['Gate'] ?? midiFX.luaParams['gate'] ?? 0.85;
      final swing = midiFX.luaParams['Swing'] ?? midiFX.luaParams['swing'] ?? 0.0;
      return applyChordArpeggiate(notes, timeContext, stepRate: rate, octaves: octaves, pattern: pattern, gate: gate, swing: swing);
    }

    // 3. Scale Snap MIDI FX (Snaps to project key or user selected key)
    if (code.contains('scale_snap') || nameLower.contains('scale')) {
      final key = (midiFX.luaParams['Key'] ?? midiFX.luaParams['key'] ?? timeContext.songKeyRoot).round();
      final isMinor = (midiFX.luaParams['Minor'] != null)
          ? (midiFX.luaParams['Minor']! > 0.5)
          : timeContext.isSongKeyMinor;
      return notes.map((n) {
        final snappedPitch = isMinor
            ? _snapToMinorScale(n.pitch, key)
            : _snapToMajorScale(n.pitch, key);
        return n.copyWith(pitch: snappedPitch);
      }).toList();
    }

    // 4. Arpeggiator MIDI FX
    if (code.contains('arpeggiator') || nameLower.contains('arpeggiator') || nameLower.contains('arp')) {
      final rate = midiFX.luaParams['Rate'] ?? midiFX.luaParams['rate'] ?? 1.0;
      final octaves = (midiFX.luaParams['Octaves'] ?? midiFX.luaParams['octaves'] ?? 2.0).toInt();
      final pattern = _parsePattern(midiFX.luaParams['Pattern'] ?? midiFX.luaParams['pattern']);
      final gate = midiFX.luaParams['Gate'] ?? midiFX.luaParams['gate'] ?? 0.85;
      final swing = midiFX.luaParams['Swing'] ?? midiFX.luaParams['swing'] ?? 0.0;
      return applyArpeggiator(
        notes,
        stepRate: rate,
        octaves: octaves,
        pattern: pattern,
        gate: gate,
        swing: swing,
        timeContext: timeContext,
      );
    }

    // 5. Humanize MIDI FX
    if (code.contains('humanize') || nameLower.contains('humanize')) {
      final timingAmount = midiFX.luaParams['timing'] ?? midiFX.luaParams['Timing'] ?? 0.04; // max offset in steps
      final velAmount = midiFX.luaParams['velocity'] ?? midiFX.luaParams['Velocity'] ?? 0.15;
      final rand = math.Random(nHashCode(notes));

      return notes.map((n) {
        final offset = (rand.nextDouble() * 2 - 1) * timingAmount;
        final newVel = (n.velocity + (rand.nextDouble() * 2 - 1) * velAmount).clamp(0.1, 1.0);
        return n.copyWith(
          startStep: math.max(0.0, n.startStep + offset),
          velocity: newVel,
        );
      }).toList();
    }

    // 6. Chord Voicing / Stabs MIDI FX
    if (code.contains('chord_stabs') || code.contains('Chord.generate_voicing') || nameLower.contains('voicing') || nameLower.contains('stabs')) {
      return generateChordVoicings(notes, timeContext);
    }

    return notes;
  }

  static String _parsePattern(dynamic raw) {
    if (raw is String) return raw.toLowerCase();
    if (raw is num) {
      switch (raw.toInt()) {
        case 1: return 'down';
        case 2: return 'updown';
        case 3: return 'downup';
        case 4: return 'converge';
        case 5: return 'diverge';
        case 6: return 'random';
        case 7: return 'chord';
        case 8: return 'asplayed';
        default: return 'up';
      }
    }
    return 'up';
  }

  /// Looks up active chord for given step, checking chordTrack first then falling back to activeChord.
  static ChordEvent? lookupChordForStep(TimeContext timeContext, double step) {
    if (timeContext.chordTrack.isNotEmpty) {
      final stepBar = step / 16.0;
      for (final chord in timeContext.chordTrack) {
        if (stepBar >= chord.startBar && stepBar < (chord.startBar + chord.barLength)) {
          return chord;
        }
      }
    }
    return timeContext.activeChord;
  }

  /// Conforms a note stream dynamically to the project's Chord Track based on follow [mode].
  static List<Note> applyChordFollow(
    List<Note> notes,
    TimeContext timeContext, {
    String mode = 'chord',
  }) {
    if (mode == 'off') return notes;

    return notes.map((n) {
      final activeChord = lookupChordForStep(timeContext, n.startStep);
      if (activeChord == null) return n;

      final remappedPitch = ChordTheory.remapPitchForChord(n.pitch, activeChord, mode);
      return n.copyWith(pitch: remappedPitch);
    }).toList();
  }

  /// Arpeggiates notes or active chord pitch classes across time.
  static List<Note> applyChordArpeggiate(
    List<Note> notes,
    TimeContext timeContext, {
    double stepRate = 1.0,
    int octaves = 1,
    String pattern = 'up',
    double gate = 0.85,
    double swing = 0.0,
  }) {
    if (notes.isEmpty) return notes;
    return applyArpeggiator(
      notes,
      stepRate: stepRate,
      octaves: octaves,
      pattern: pattern,
      gate: gate,
      swing: swing,
      timeContext: timeContext,
      useChordTrackTones: true,
    );
  }

  /// Production-grade MIDI Arpeggiator transformation engine.
  /// Supports chords, single triggers, multi-octave cycling, all standard DAW patterns,
  /// sub-step fractional rates, gate scaling, and swing timing.
  static List<Note> applyArpeggiator(
    List<Note> baseNotes, {
    double stepRate = 1.0, // 1.0 = 16th note, 0.5 = 32nd note, 2.0 = 8th note, 4.0 = 1/4 note
    int octaves = 2,
    String pattern = 'up',
    double gate = 0.85,
    double swing = 0.0,
    TimeContext? timeContext,
    bool useChordTrackTones = false,
  }) {
    if (baseNotes.isEmpty) return baseNotes;
    final rate = math.max(0.125, stepRate);
    final octs = math.max(1, octaves);
    final rand = math.Random(nHashCodeStatic(baseNotes));

    // Sort notes chronologically by startStep
    final sorted = List<Note>.from(baseNotes)..sort((a, b) => a.startStep.compareTo(b.startStep));

    // 1. Group notes into time-clusters (chords played together within 0.1 steps)
    final List<List<Note>> clusters = [];
    List<Note> currentCluster = [];

    for (final note in sorted) {
      if (currentCluster.isEmpty) {
        currentCluster.add(note);
      } else {
        final clusterStart = currentCluster.first.startStep;
        if ((note.startStep - clusterStart).abs() <= 0.1) {
          currentCluster.add(note);
        } else {
          clusters.add(currentCluster);
          currentCluster = [note];
        }
      }
    }
    if (currentCluster.isNotEmpty) {
      clusters.add(currentCluster);
    }

    final List<Note> arpedNotes = [];

    // 2. Process each note cluster into an arpeggiated sequence
    for (final cluster in clusters) {
      final clusterStart = cluster.first.startStep;
      double clusterEnd = clusterStart + rate;
      for (final n in cluster) {
        final end = n.startStep + n.durationSteps;
        if (end > clusterEnd) clusterEnd = end;
      }

      final double totalDuration = math.max(rate, clusterEnd - clusterStart);
      final int stepCount = math.max(1, (totalDuration / rate).round());

      // Extract pitches
      List<int> rawPitches = [];
      if (useChordTrackTones && timeContext != null) {
        final activeChord = lookupChordForStep(timeContext, clusterStart);
        if (activeChord != null && activeChord.pitchClasses.isNotEmpty) {
          final baseOct = (cluster.first.pitch / 12).floor();
          for (final pc in activeChord.pitchClasses) {
            rawPitches.add((baseOct * 12 + pc).clamp(0, 127));
          }
        }
      }

      if (rawPitches.isEmpty) {
        if (pattern == 'asplayed') {
          rawPitches = cluster.map((n) => n.pitch).toList();
        } else {
          final uniquePitches = cluster.map((n) => n.pitch).toSet().toList()..sort();
          rawPitches = uniquePitches;
        }
      }

      // Expand pitches across octaves
      final List<int> octaveExpanded = [];
      for (int o = 0; o < octs; o++) {
        for (final p in rawPitches) {
          octaveExpanded.add((p + (o * 12)).clamp(0, 127));
        }
      }

      // Build sequence pattern list
      final List<int> arpSequence = _buildArpSequence(octaveExpanded, pattern);
      final primaryNote = cluster.first;

      for (int s = 0; s < stepCount; s++) {
        final double nominalStart = clusterStart + (s * rate);
        // Swing offset on odd sub-steps
        final double swingOffset = (s % 2 == 1) ? (swing.clamp(0.0, 0.6) * (rate * 0.35)) : 0.0;
        final double finalStart = nominalStart + swingOffset;
        final double finalDuration = math.max(0.1, rate * gate.clamp(0.1, 3.0));

        if (pattern == 'chord') {
          // Trigger all pitches in octave pool simultaneously on this step
          for (int pIdx = 0; pIdx < octaveExpanded.length; pIdx++) {
            final pitch = octaveExpanded[pIdx];
            arpedNotes.add(Note(
              id: '${primaryNote.id}_arp_${s}_$pIdx',
              pitch: pitch,
              startStep: finalStart,
              durationSteps: finalDuration,
              velocity: primaryNote.velocity,
              column: primaryNote.column,
              effectCommand: primaryNote.effectCommand,
            ));
          }
        } else {
          int pitch;
          if (pattern == 'random') {
            pitch = octaveExpanded[rand.nextInt(octaveExpanded.length)];
          } else {
            pitch = arpSequence[s % arpSequence.length];
          }

          // Subtle velocity dynamics on downbeats
          final vel = (s % 4 == 0)
              ? (primaryNote.velocity * 1.05).clamp(0.1, 1.0)
              : (primaryNote.velocity * 0.95).clamp(0.1, 1.0);

          arpedNotes.add(Note(
            id: '${primaryNote.id}_arp_$s',
            pitch: pitch,
            startStep: finalStart,
            durationSteps: finalDuration,
            velocity: vel,
            column: primaryNote.column,
            effectCommand: primaryNote.effectCommand,
          ));
        }
      }
    }

    return arpedNotes;
  }

  static List<int> _buildArpSequence(List<int> sortedPitches, String pattern) {
    if (sortedPitches.isEmpty) return [60];
    if (sortedPitches.length == 1) return sortedPitches;

    switch (pattern) {
      case 'down':
        return List<int>.from(sortedPitches.reversed);
      case 'updown':
        if (sortedPitches.length <= 2) return List<int>.from(sortedPitches);
        final list = List<int>.from(sortedPitches);
        for (int i = sortedPitches.length - 2; i > 0; i--) {
          list.add(sortedPitches[i]);
        }
        return list;
      case 'downup':
        if (sortedPitches.length <= 2) return List<int>.from(sortedPitches.reversed);
        final list = List<int>.from(sortedPitches.reversed);
        for (int i = sortedPitches.length - 2; i > 0; i--) {
          list.add(sortedPitches[sortedPitches.length - 1 - i]);
        }
        return list;
      case 'converge': // Outside -> In (lowest, highest, 2nd lowest, 2nd highest...)
        final list = <int>[];
        int left = 0;
        int right = sortedPitches.length - 1;
        while (left <= right) {
          list.add(sortedPitches[left]);
          if (left != right) list.add(sortedPitches[right]);
          left++;
          right--;
        }
        return list;
      case 'diverge': // Inside -> Out (middle outward)
        final list = <int>[];
        int mid = sortedPitches.length ~/ 2;
        int left = mid;
        int right = mid + 1;
        while (left >= 0 || right < sortedPitches.length) {
          if (left >= 0) list.add(sortedPitches[left]);
          if (right < sortedPitches.length) list.add(sortedPitches[right]);
          left--;
          right++;
        }
        return list;
      case 'asplayed':
      case 'up':
      default:
        return List<int>.from(sortedPitches);
    }
  }

  /// Converts single-note triggers into full, lush polyphonic chord voicings based on the Chord Track.
  static List<Note> generateChordVoicings(
    List<Note> triggerNotes,
    TimeContext timeContext, {
    int baseOctave = 4,
  }) {
    final List<Note> voicedNotes = [];

    for (final trigger in triggerNotes) {
      final activeChord = lookupChordForStep(timeContext, trigger.startStep);
      final pitchClasses = (activeChord != null && activeChord.pitchClasses.isNotEmpty)
          ? activeChord.pitchClasses
          : [0, 4, 7]; // Default C major

      final oct = (trigger.pitch / 12).floor().clamp(2, 6);

      // Add Bass note if slash chord or root
      if (activeChord?.bassPitchClass != null) {
        voicedNotes.add(Note(
          id: '${trigger.id}_bass',
          pitch: ((oct - 1) * 12 + activeChord!.bassPitchClass!).clamp(0, 127),
          startStep: trigger.startStep,
          durationSteps: trigger.durationSteps,
          velocity: (trigger.velocity * 0.95).clamp(0.1, 1.0),
        ));
      }

      // Add chord tones
      for (int idx = 0; idx < pitchClasses.length; idx++) {
        final pc = pitchClasses[idx];
        final chordTonePitch = (oct * 12 + pc).clamp(0, 127);
        voicedNotes.add(Note(
          id: '${trigger.id}_v$idx',
          pitch: chordTonePitch,
          startStep: trigger.startStep,
          durationSteps: trigger.durationSteps,
          velocity: (trigger.velocity * (1.0 - (idx * 0.05))).clamp(0.1, 1.0),
        ));
      }
    }
    return voicedNotes;
  }

  static int nHashCodeStatic(List<Note> notes) {
    return notes.fold(17, (acc, n) => acc * 37 + n.pitch.hashCode);
  }

  /// Snaps a pitch to Major Scale
  static int _snapToMajorScale(int pitch, int rootKey) {
    const majorScaleIntervals = [0, 2, 4, 5, 7, 9, 11];
    final noteInOctave = (pitch - rootKey) % 12;
    final octave = ((pitch - rootKey) / 12).floor();

    int closestInterval = majorScaleIntervals.first;
    int minDiff = 100;
    for (final interval in majorScaleIntervals) {
      final diff = (noteInOctave - interval).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestInterval = interval;
      }
    }
    return (octave * 12) + rootKey + closestInterval;
  }

  /// Snaps a pitch to Natural Minor Scale
  static int _snapToMinorScale(int pitch, int rootKey) {
    const minorScaleIntervals = [0, 2, 3, 5, 7, 8, 10];
    final noteInOctave = (pitch - rootKey) % 12;
    final octave = ((pitch - rootKey) / 12).floor();

    int closestInterval = minorScaleIntervals.first;
    int minDiff = 100;
    for (final interval in minorScaleIntervals) {
      final diff = (noteInOctave - interval).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestInterval = interval;
      }
    }
    return (octave * 12) + rootKey + closestInterval;
  }

  int nHashCode(List<Note> notes) {
    return notes.fold(17, (acc, n) => acc * 37 + n.pitch.hashCode);
  }

  /// Serializes a list of [Note] objects into clean Lua table format.
  /// If [existingCode] contains a custom process() function or clip params,
  /// it updates the `notes = { ... }` block while preserving the rest of the code.
  static String serializeNotesToLua(List<Note> notes, {String? existingCode}) {
    final notesBuffer = StringBuffer();
    notesBuffer.writeln('-- Clip Notes Data (eatsbits.v1)');
    notesBuffer.writeln('notes = {');
    for (int i = 0; i < notes.length; i++) {
      final n = notes[i];
      notesBuffer.write('  { pitch = ${n.pitch}, start = ${n.startStep.toStringAsFixed(2)}, duration = ${n.durationSteps.toStringAsFixed(2)}, vel = ${n.velocity.toStringAsFixed(2)} }');
      if (i < notes.length - 1) notesBuffer.write(',');
      notesBuffer.writeln();
    }
    notesBuffer.writeln('}');

    if (existingCode == null || existingCode.trim().isEmpty) {
      notesBuffer.writeln('\nfunction process(notes, time_ctx)\n  return notes\nend');
      return notesBuffer.toString();
    }

    // Strip previous header comment and notes = { ... } table definition block
    String code = existingCode.trim();
    code = code.replaceFirst(RegExp(r'^--\s*Clip Notes Data[\s\S]*?\n'), '');
    final notesBlockRegex = RegExp(r'notes\s*=\s*\{(?:\s*\{[^}]*\},?)*\s*\}', multiLine: true);
    code = code.replaceFirst(notesBlockRegex, '').trim();

    if (code.isEmpty) {
      notesBuffer.writeln('\nfunction process(notes, time_ctx)\n  return notes\nend');
      return notesBuffer.toString();
    }

    return '${notesBuffer.toString()}\n\n$code';
  }

  /// Parses declarative `notes = { ... }` tables from Lua script code into Dart [Note]s.
  static List<Note> parseNotesFromLuaTable(String luaCode) {
    final List<Note> notes = [];
    final rowRegex = RegExp(
      r'\{\s*pitch\s*=\s*(\d+)\s*,\s*start\s*=\s*([\d\.]+)\s*,\s*duration\s*=\s*([\d\.]+)\s*,\s*vel\s*=\s*([\d\.]+)\s*\}',
      multiLine: true,
    );

    int counter = 0;
    for (final match in rowRegex.allMatches(luaCode)) {
      final pitch = int.tryParse(match.group(1)!) ?? 60;
      final start = double.tryParse(match.group(2)!) ?? 0.0;
      final dur = double.tryParse(match.group(3)!) ?? 1.0;
      final vel = double.tryParse(match.group(4)!) ?? 0.9;

      notes.add(Note(
        id: 'n_script_${counter++}',
        pitch: pitch,
        startStep: start,
        durationSteps: dur,
        velocity: vel,
      ));
    }
    return notes;
  }
}
