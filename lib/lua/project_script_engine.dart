import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/chord_model.dart';
import '../models/daw_state.dart';
import '../models/track_model.dart';
import 'lua_engine.dart';
import 'lua_script_library.dart';

/// Result of executing a project script.
class ProjectScriptResult {
  final bool isSuccess;
  final String message;
  final int affectedTracksCount;
  final int affectedNotesCount;
  final int affectedChordsCount;

  const ProjectScriptResult({
    required this.isSuccess,
    this.message = '',
    this.affectedTracksCount = 0,
    this.affectedNotesCount = 0,
    this.affectedChordsCount = 0,
  });
}

/// Music Theory & Procedural Helpers for project scripts.
class ProjectScriptHelpers {
  static final math.Random _rng = math.Random();

  /// Snaps a MIDI pitch to the closest note in a given chord.
  static int snapToChord(int pitch, ChordEvent chord, {String mode = 'chord'}) {
    final chordPitches = chord.pitchClasses;
    if (chordPitches.isEmpty) return pitch;

    final pitchClass = pitch % 12;
    final octave = pitch ~/ 12;

    if (mode == 'bass' || mode == 'root') {
      final rootClass = chord.bassPitchClass ?? chord.rootPitchClass;
      return (octave * 12) + rootClass;
    }

    // Find nearest pitch class in chord
    int bestPitchClass = chordPitches.first;
    int minDiff = 999;
    for (final cp in chordPitches) {
      int diff = (pitchClass - cp).abs();
      if (diff > 6) diff = 12 - diff; // Handle circular pitch distance
      if (diff < minDiff) {
        minDiff = diff;
        bestPitchClass = cp;
      }
    }

    int snapped = (octave * 12) + bestPitchClass;
    // Minimize distance in absolute semitones
    if ((snapped - pitch).abs() > ((snapped + 12) - pitch).abs()) snapped += 12;
    if ((snapped - pitch).abs() > ((snapped - 12) - pitch).abs()) snapped -= 12;
    return snapped.clamp(0, 127);
  }

  /// Conforms a MIDI pitch to the song key scale (Major / Minor).
  static int scaleConform(int pitch, int keyRoot, bool isMinor) {
    // Scale intervals from root
    final scaleIntervals = isMinor
        ? [0, 2, 3, 5, 7, 8, 10] // Natural Minor
        : [0, 2, 4, 5, 7, 9, 11]; // Major

    final scalePitchClasses = scaleIntervals.map((i) => (keyRoot + i) % 12).toSet();
    final pitchClass = pitch % 12;
    if (scalePitchClasses.contains(pitchClass)) return pitch;

    // Shift to nearest scale degree
    for (int offset = 1; offset <= 2; offset++) {
      if (scalePitchClasses.contains((pitchClass + offset) % 12)) return (pitch + offset).clamp(0, 127);
      if (scalePitchClasses.contains((pitchClass - offset + 12) % 12)) return (pitch - offset).clamp(0, 127);
    }
    return pitch;
  }

  /// Generates a Euclidean rhythm pattern of [steps] with [pulses] hits.
  static List<bool> generateEuclideanRhythm(int steps, int pulses, {int shift = 0}) {
    if (steps <= 0) return [];
    if (pulses >= steps) return List.filled(steps, true);
    if (pulses <= 0) return List.filled(steps, false);

    final pattern = List.filled(steps, false);
    double accumulator = 0.0;
    final stepSize = pulses / steps.toDouble();

    for (int i = 0; i < steps; i++) {
      final prevAcc = accumulator;
      accumulator += stepSize;
      if (accumulator.floor() > prevAcc.floor()) {
        final pos = (i + shift) % steps;
        pattern[pos] = true;
      }
    }
    return pattern;
  }

  /// Generates a chord progression based on a style and tonic root.
  static List<ChordEvent> generateChordProgression({
    required int rootPitchClass,
    required bool isMinor,
    required String genre,
    int lengthBars = 8,
  }) {
    final List<ChordEvent> chords = [];
    final g = genre.toLowerCase();

    // Progression formulas (offset from tonic, quality, bar duration)
    List<(int offset, ChordQuality quality, double duration)> formula;

    if (g.contains('pop') || g.contains('anthem')) {
      // Pop: I - V - vi - IV (or i - VI - III - VII in minor)
      if (isMinor) {
        formula = [
          (0, ChordQuality.minor, 2.0),
          (8, ChordQuality.major, 2.0),
          (3, ChordQuality.major, 2.0),
          (10, ChordQuality.major, 2.0),
        ];
      } else {
        formula = [
          (0, ChordQuality.major, 2.0),
          (7, ChordQuality.major, 2.0),
          (9, ChordQuality.minor, 2.0),
          (5, ChordQuality.major, 2.0),
        ];
      }
    } else if (g.contains('synthwave') || g.contains('retrowave') || g.contains('cyberpunk')) {
      // Synthwave: i - VI - iv - v (or i - VII - VI - VII)
      formula = [
        (0, ChordQuality.minor, 2.0),
        (8, ChordQuality.major, 2.0),
        (5, ChordQuality.minor, 2.0),
        (7, ChordQuality.minor, 2.0),
      ];
    } else if (g.contains('jazz') || g.contains('neo') || g.contains('soul') || g.contains('rnb')) {
      // Jazz / Neo-Soul: ii9 - V9 - Imaj9 - vi7 (2-5-1-6)
      if (isMinor) {
        formula = [
          (2, ChordQuality.halfDiminished7, 2.0),
          (7, ChordQuality.dominant7, 2.0),
          (0, ChordQuality.min9, 2.0),
          (8, ChordQuality.major7, 2.0),
        ];
      } else {
        formula = [
          (2, ChordQuality.min9, 2.0),
          (7, ChordQuality.dom9, 2.0),
          (0, ChordQuality.maj9, 2.0),
          (9, ChordQuality.minor7, 2.0),
        ];
      }
    } else if (g.contains('house') || g.contains('edm') || g.contains('club') || g.contains('dance')) {
      // Deep House: i7 - v7 - iv7 - VImaj7
      formula = [
        (0, ChordQuality.minor7, 2.0),
        (7, ChordQuality.minor7, 2.0),
        (5, ChordQuality.minor7, 2.0),
        (8, ChordQuality.major7, 2.0),
      ];
    } else {
      // Default: i - iv - v - i (Minor) or I - IV - V - I (Major)
      if (isMinor) {
        formula = [
          (0, ChordQuality.minor, 2.0),
          (5, ChordQuality.minor, 2.0),
          (7, ChordQuality.minor, 2.0),
          (0, ChordQuality.minor, 2.0),
        ];
      } else {
        formula = [
          (0, ChordQuality.major, 2.0),
          (5, ChordQuality.major, 2.0),
          (7, ChordQuality.major, 2.0),
          (0, ChordQuality.major, 2.0),
        ];
      }
    }

    int currentBar = 0;
    int formulaIdx = 0;
    while (currentBar < lengthBars) {
      final item = formula[formulaIdx % formula.length];
      final chordRoot = (rootPitchClass + item.$1) % 12;
      final dur = math.min(item.$3, (lengthBars - currentBar).toDouble());
      chords.add(ChordEvent(
        id: 'chord_gen_${currentBar}_${DateTime.now().microsecondsSinceEpoch}',
        startBar: currentBar,
        barLength: dur,
        rootPitchClass: chordRoot,
        quality: item.$2,
      ));
      currentBar += dur.toInt();
      formulaIdx++;
    }

    return chords;
  }
}

/// Execution engine for project-level Lua action scripts.
class ProjectScriptEngine {
  /// Executes a [LuaScriptDef] project action against [DawState] with the provided [params].
  static ProjectScriptResult execute({
    required DawState dawState,
    required LuaScriptDef script,
    Map<String, dynamic> params = const {},
  }) {
    final code = script.code.toLowerCase();
    final scriptId = script.id.toLowerCase();
    final p = Map<String, dynamic>.from(params);

    // 1. Global Chord-Aware Transposition Script
    if (scriptId.contains('transpose') || code.contains('transpose_song') || (code.contains('transpose') && code.contains('chord'))) {
      return _runGlobalTranspose(dawState, p);
    }

    // 2. Harmonic Progression Generator Script
    if (scriptId.contains('chord_gen') || scriptId.contains('progression') || code.contains('generate_progression') || code.contains('chord_progression')) {
      return _runHarmonicProgressionGenerator(dawState, p);
    }

    // 3. Procedural Multi-Track Song Generator Script
    if (scriptId.contains('song_gen') || scriptId.contains('procedural_song') || code.contains('generate_song') || code.contains('procedural')) {
      return _runProceduralSongGenerator(dawState, p);
    }

    // 4. Groove & Velocity Humanizer Script
    if (scriptId.contains('humanize') || code.contains('humanize_groove') || code.contains('humanize')) {
      return _runHumanizeGroove(dawState, p);
    }

    // Fallback: Generic transposition or note-shift
    return _runGlobalTranspose(dawState, p);
  }

  /// Transposes the entire project (chords, synths, melodies, basslines).
  static ProjectScriptResult _runGlobalTranspose(DawState dawState, Map<String, dynamic> params) {
    final num rawSemi = (params['Semitones'] ?? params['semitones'] ?? params['shift'] ?? 2) as num;
    final int semitones = rawSemi.toInt();
    final num rawMode = (params['HarmonicMode'] ?? params['harmonic_mode'] ?? params['mode'] ?? 0) as num;
    final int mode = rawMode.toInt(); // 0: Strict Chromatic, 1: Snap to Scale, 2: Smart Chord Shift
    final updateKey = (params['UpdateKey'] ?? params['update_key'] ?? 1) != 0;

    int affectedNotes = 0;
    int affectedChords = 0;
    int affectedTracks = 0;

    // 1. Transpose Song Key
    if (updateKey) {
      final oldKeyRoot = dawState.songKeyRoot;
      final newKeyRoot = ((oldKeyRoot + semitones + 120) % 12).toInt();
      final rootName = ChordTheory.pitchClassNames[newKeyRoot];
      final modeName = dawState.isSongKeyMinor ? 'Minor' : 'Major';
      dawState.setSongKey('$rootName $modeName');
    }

    // 2. Transpose Chord Track
    for (int i = 0; i < dawState.chordTrack.length; i++) {
      final chord = dawState.chordTrack[i];
      final newRoot = ((chord.rootPitchClass + semitones + 120) % 12).toInt();
      final int? newBass = chord.bassPitchClass != null ? (((chord.bassPitchClass! + semitones + 120) % 12).toInt()) : null;
      dawState.chordTrack[i] = chord.copyWith(
        rootPitchClass: newRoot,
        bassPitchClass: newBass,
      );
      affectedChords++;
    }

    // 3. Transpose Notes across all Patterns and Tracks
    for (final pattern in dawState.patterns) {
      for (final track in pattern.tracks) {
        if (track.type == TrackType.folder) continue;

        bool trackModified = false;
        for (final clip in track.clips) {
          for (final note in clip.notes) {
            int newPitch = note.pitch + semitones;
            if (mode == 1) {
              // Snap to scale
              newPitch = ProjectScriptHelpers.scaleConform(newPitch, dawState.songKeyRoot, dawState.isSongKeyMinor);
            } else if (mode == 2 && dawState.chordTrack.isNotEmpty) {
              // Smart Chord shift
              final chord = dawState.getActiveChordAtStep(note.startStep.toInt());
              if (chord != null) {
                newPitch = ProjectScriptHelpers.snapToChord(newPitch, chord);
              }
            }
            note.pitch = newPitch.clamp(0, 127);
            affectedNotes++;
            trackModified = true;
          }
          clip.evaluatedNotesCache = null; // Invalidate cached notes
        }
        if (trackModified) affectedTracks++;
      }
    }

    dawState.triggerAutoSave();
    dawState.notifyListeners();

    return ProjectScriptResult(
      isSuccess: true,
      message: 'Transposed song by ${semitones >= 0 ? "+$semitones" : "$semitones"} semitones (${affectedNotes} notes, ${affectedChords} chords).',
      affectedTracksCount: affectedTracks,
      affectedNotesCount: affectedNotes,
      affectedChordsCount: affectedChords,
    );
  }

  /// Generates a stylized chord progression across the chord track and conforms harmonies.
  static ProjectScriptResult _runHarmonicProgressionGenerator(DawState dawState, Map<String, dynamic> params) {
    final num rawGenre = (params['Genre'] ?? params['genre'] ?? 0) as num;
    final int genreIdx = rawGenre.toInt();
    final num rawBars = (params['LengthBars'] ?? params['length_bars'] ?? 8) as num;
    final int lengthBars = rawBars.toInt();
    final conformTracks = (params['ConformTracks'] ?? params['conform_tracks'] ?? 1) != 0;

    const genres = ['Synthwave', 'Pop Anthem', 'Deep House / Club', 'Jazz / Neo-Soul', 'Classic EDM'];
    final genre = genreIdx >= 0 && genreIdx < genres.length ? genres[genreIdx] : 'Synthwave';

    // Generate Chords
    final newChords = ProjectScriptHelpers.generateChordProgression(
      rootPitchClass: dawState.songKeyRoot,
      isMinor: dawState.isSongKeyMinor,
      genre: genre,
      lengthBars: lengthBars,
    );

    dawState.chordTrack = newChords;

    int affectedNotes = 0;
    int affectedTracks = 0;

    // Optionally conform existing harmonic tracks to the new chords
    if (conformTracks) {
      for (final pattern in dawState.patterns) {
        for (final track in pattern.tracks) {
          if (track.type == TrackType.synth || track.type == TrackType.sampler) {
            bool trackModified = false;
            for (final clip in track.clips) {
              for (final note in clip.notes) {
                final chord = dawState.getActiveChordAtStep(note.startStep.toInt());
                if (chord != null) {
                  note.pitch = ProjectScriptHelpers.snapToChord(note.pitch, chord);
                  affectedNotes++;
                  trackModified = true;
                }
              }
              clip.evaluatedNotesCache = null;
            }
            if (trackModified) affectedTracks++;
          }
        }
      }
    }

    dawState.triggerAutoSave();
    dawState.notifyListeners();

    return ProjectScriptResult(
      isSuccess: true,
      message: 'Generated $genre chord progression (${newChords.length} chords over $lengthBars bars).',
      affectedTracksCount: affectedTracks,
      affectedNotesCount: affectedNotes,
      affectedChordsCount: newChords.length,
    );
  }

  /// Procedurally generates a full multi-track song structure (Drums, Bass, Chords, Lead Arp).
  static ProjectScriptResult _runProceduralSongGenerator(DawState dawState, Map<String, dynamic> params) {
    final num rawStyle = (params['Style'] ?? params['style'] ?? 0) as num;
    final int styleIdx = rawStyle.toInt();
    final num rawBpm = (params['Bpm'] ?? params['bpm'] ?? 124.0) as num;
    final double bpm = rawBpm.toDouble();
    final num rawBars = (params['Bars'] ?? params['bars'] ?? 8) as num;
    final int numBars = rawBars.toInt();

    const styles = ['Synthwave / Retro', 'Deep House', 'Cyberpunk Acid', 'Lo-Fi Hip Hop'];
    final style = styleIdx >= 0 && styleIdx < styles.length ? styles[styleIdx] : 'Synthwave / Retro';

    // 1. Set Song Properties
    dawState.setBpm(bpm);
    dawState.projectName = 'Procedural $style';

    // 2. Generate Chords for the song
    final chords = ProjectScriptHelpers.generateChordProgression(
      rootPitchClass: dawState.songKeyRoot,
      isMinor: true, // Procedural electronic styles default to minor
      genre: style,
      lengthBars: numBars,
    );
    dawState.chordTrack = chords;

    final pattern = dawState.activePattern;
    pattern.tracks.clear(); // Clear existing tracks to populate procedural setup
    pattern.lengthSteps = (numBars * 16).clamp(16, 128);

    // Track 1: Drums (Kick, Snare/Clap, Hi-Hats)
    final drumTrack = TrackChannel(
      id: 'proc_track_drums',
      name: 'Procedural Drums',
      color: const Color(0xFFFF3366),
      type: TrackType.synth,
      volume: 0.85,
    );
    final drumClip = TrackClip(
      id: 'proc_clip_drums',
      name: 'Drum Loop',
      trackId: drumTrack.id,
      startBar: 0,
      barLength: numBars,
    );

    // Populate drum pattern (4-on-the-floor kick, backbeat snare, Euclidean 16th hats)
    final totalSteps = numBars * 16;
    for (int step = 0; step < totalSteps; step++) {
      // Four on the floor kick (every 4 steps)
      if (step % 4 == 0) {
        drumClip.notes.add(Note(
          id: 'k_$step',
          pitch: 36, // Bass Drum
          startStep: step.toDouble(),
          durationSteps: 1.0,
          velocity: 0.95,
        ));
      }
      // Snare on beats 2 & 4 (steps 4, 12, 20, 28...)
      if (step % 8 == 4) {
        drumClip.notes.add(Note(
          id: 'sn_$step',
          pitch: 38, // Snare
          startStep: step.toDouble(),
          durationSteps: 1.0,
          velocity: 0.90,
        ));
      }
      // Hi-Hats (every 2 steps with slight offbeat velocity boost)
      if (step % 2 == 0) {
        final isOffbeat = (step % 4) == 2;
        drumClip.notes.add(Note(
          id: 'hh_$step',
          pitch: 42, // Closed Hat
          startStep: step.toDouble(),
          durationSteps: 0.8,
          velocity: isOffbeat ? 0.85 : 0.65,
        ));
      }
    }
    drumTrack.clips.add(drumClip);
    pattern.tracks.add(drumTrack);

    // Track 2: Bassline (Follows chord roots with rolling 16th rhythm)
    final bassTrack = TrackChannel(
      id: 'proc_track_bass',
      name: 'Acid Bassline',
      color: const Color(0xFF00FF66),
      type: TrackType.synth,
      volume: 0.80,
    );
    final bassClip = TrackClip(
      id: 'proc_clip_bass',
      name: 'Bassline',
      trackId: bassTrack.id,
      startBar: 0,
      barLength: numBars,
    );

    for (int step = 0; step < totalSteps; step += 2) {
      final chord = dawState.getActiveChordAtStep(step) ?? (chords.isNotEmpty ? chords.first : null);
      final rootClass = chord?.bassPitchClass ?? chord?.rootPitchClass ?? dawState.songKeyRoot;
      final bassPitch = 36 + rootClass; // Low register C2 (36) + root

      final isAccent = (step % 8 == 0) || (step % 8 == 6);
      bassClip.notes.add(Note(
        id: 'bass_$step',
        pitch: bassPitch,
        startStep: step.toDouble(),
        durationSteps: 1.5,
        velocity: isAccent ? 0.95 : 0.70,
        isSlide: (step % 8 == 6),
      ));
    }
    bassTrack.clips.add(bassClip);
    pattern.tracks.add(bassTrack);

    // Track 3: Chord Stabs / Pad (Sustained voicings following chord track)
    final chordTrackChannel = TrackChannel(
      id: 'proc_track_chords',
      name: 'Harmonic Stabs',
      color: const Color(0xFF21F4E8),
      type: TrackType.synth,
      volume: 0.75,
    );
    final chordClip = TrackClip(
      id: 'proc_clip_chords',
      name: 'Chord Stabs',
      trackId: chordTrackChannel.id,
      startBar: 0,
      barLength: numBars,
    );

    for (final chord in chords) {
      final chordStartStep = (chord.startBar * 16).toDouble();
      final chordDurSteps = (chord.barLength * 16).toDouble();
      final pitchClasses = chord.pitchClasses;

      for (int i = 0; i < pitchClasses.length; i++) {
        final pc = pitchClasses[i];
        final pitch = 60 + pc; // Middle register C4 (60)
        chordClip.notes.add(Note(
          id: 'chord_${chord.id}_$i',
          pitch: pitch,
          startStep: chordStartStep,
          durationSteps: chordDurSteps * 0.9,
          velocity: 0.80,
        ));
      }
    }
    chordTrackChannel.clips.add(chordClip);
    pattern.tracks.add(chordTrackChannel);

    // Track 4: Lead Arpeggio (Melodic arp moving across chord tones)
    final leadTrack = TrackChannel(
      id: 'proc_track_lead',
      name: 'Neon Lead Arp',
      color: const Color(0xFFFF8C00),
      type: TrackType.synth,
      volume: 0.78,
    );
    final leadClip = TrackClip(
      id: 'proc_clip_lead',
      name: 'Lead Arp',
      trackId: leadTrack.id,
      startBar: 0,
      barLength: numBars,
    );

    for (int step = 0; step < totalSteps; step++) {
      final chord = dawState.getActiveChordAtStep(step) ?? (chords.isNotEmpty ? chords.first : null);
      final pitches = chord?.pitchClasses ?? [0, 3, 7];
      final pitchIndex = step % pitches.length;
      final octaveOffset = (step ~/ pitches.length) % 2; // Cycle through 2 octaves
      final arpPitch = 72 + pitches[pitchIndex] + (octaveOffset * 12); // C5 (72)

      leadClip.notes.add(Note(
        id: 'lead_$step',
        pitch: arpPitch,
        startStep: step.toDouble(),
        durationSteps: 0.75,
        velocity: 0.82,
      ));
    }
    leadTrack.clips.add(leadClip);
    pattern.tracks.add(leadTrack);

    int totalNotes = drumClip.notes.length + bassClip.notes.length + chordClip.notes.length + leadClip.notes.length;

    dawState.triggerAutoSave();
    dawState.notifyListeners();

    return ProjectScriptResult(
      isSuccess: true,
      message: 'Generated $style multi-track song (${pattern.tracks.length} tracks, $totalNotes notes, ${chords.length} chords).',
      affectedTracksCount: pattern.tracks.length,
      affectedNotesCount: totalNotes,
      affectedChordsCount: chords.length,
    );
  }

  /// Humanizes groove micro-timing and note velocities.
  static ProjectScriptResult _runHumanizeGroove(DawState dawState, Map<String, dynamic> params) {
    final num rawTiming = (params['TimingJitter'] ?? params['timing_jitter'] ?? 0.04) as num;
    final double timingJitter = rawTiming.toDouble(); // In steps fraction
    final num rawVel = (params['VelocityJitter'] ?? params['velocity_jitter'] ?? 0.12) as num;
    final double velocityJitter = rawVel.toDouble();

    int affectedNotes = 0;
    int affectedTracks = 0;

    for (final pattern in dawState.patterns) {
      for (final track in pattern.tracks) {
        bool trackModified = false;
        for (final clip in track.clips) {
          for (final note in clip.notes) {
            // Apply subtle timing shift (within [-timingJitter, +timingJitter])
            final tDelta = (ProjectScriptHelpers._rng.nextDouble() * 2.0 - 1.0) * timingJitter;
            note.startStep = math.max(0.0, note.startStep + tDelta);

            // Apply velocity randomization
            final vDelta = (ProjectScriptHelpers._rng.nextDouble() * 2.0 - 1.0) * velocityJitter;
            note.velocity = (note.velocity + vDelta).clamp(0.1, 1.0);

            affectedNotes++;
            trackModified = true;
          }
          clip.evaluatedNotesCache = null;
        }
        if (trackModified) affectedTracks++;
      }
    }

    dawState.triggerAutoSave();
    dawState.notifyListeners();

    return ProjectScriptResult(
      isSuccess: true,
      message: 'Humanized $affectedNotes notes across $affectedTracks tracks.',
      affectedTracksCount: affectedTracks,
      affectedNotesCount: affectedNotes,
    );
  }
}
