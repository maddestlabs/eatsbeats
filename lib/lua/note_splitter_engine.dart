import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/track_model.dart';
import 'lua_engine.dart';
import 'lua_script_library.dart';

class NoteSplitterTrackResult {
  final String name;
  final List<Note> notes;
  final Color color;
  final TrackType type;

  NoteSplitterTrackResult({
    required this.name,
    required this.notes,
    this.color = const Color(0xFF21F4E8),
    this.type = TrackType.synth,
  });
}

class NoteSplitterEngine {
  /// Evaluates whether a given note is part of the Skyline (highest melodic line among concurrent notes).
  static bool isSkyline(Note target, List<Note> allNotes) {
    final targetStart = target.startStep;
    final targetEnd = target.startStep + target.durationSteps;

    for (final other in allNotes) {
      if (identical(target, other)) continue;
      final otherStart = other.startStep;
      final otherEnd = other.startStep + other.durationSteps;

      // Check temporal overlap
      if (otherStart < targetEnd && otherEnd > targetStart) {
        if (other.pitch > target.pitch) {
          return false;
        }
      }
    }
    return true;
  }

  /// Evaluates whether a given note is the lowest bass note playing at its active step window.
  static bool isBassNote(Note target, List<Note> allNotes) {
    final targetStart = target.startStep;
    final targetEnd = target.startStep + target.durationSteps;

    for (final other in allNotes) {
      if (identical(target, other)) continue;
      final otherStart = other.startStep;
      final otherEnd = other.startStep + other.durationSteps;

      // Check temporal overlap
      if (otherStart < targetEnd && otherEnd > targetStart) {
        if (other.pitch < target.pitch) {
          return false;
        }
      }
    }
    return true;
  }

  /// 3-Way Voice Splitter: Bass, Middle Harmony/Chords, and Skyline Lead Melody.
  static List<NoteSplitterTrackResult> split3WayVoice(
    List<Note> notes, {
    int bassSplitPitch = 48, // C3
    int leadThresholdPitch = 64, // E4
  }) {
    final List<Note> bassNotes = [];
    final List<Note> chordNotes = [];
    final List<Note> leadNotes = [];

    for (final note in notes) {
      if (note.pitch < bassSplitPitch) {
        bassNotes.add(note.copyWith());
      } else if (note.pitch >= leadThresholdPitch && isSkyline(note, notes)) {
        leadNotes.add(note.copyWith());
      } else {
        chordNotes.add(note.copyWith());
      }
    }

    return [
      if (bassNotes.isNotEmpty)
        NoteSplitterTrackResult(
          name: 'Bassline',
          notes: bassNotes,
          color: const Color(0xFF00FF66), // Acid Green
        ),
      if (chordNotes.isNotEmpty)
        NoteSplitterTrackResult(
          name: 'Harmony & Chords',
          notes: chordNotes,
          color: const Color(0xFF21F4E8), // Neon Cyan
        ),
      if (leadNotes.isNotEmpty)
        NoteSplitterTrackResult(
          name: 'Lead Melody',
          notes: leadNotes,
          color: const Color(0xFFFF007A), // Hot Pink
        ),
    ];
  }

  /// 2-Way Splitter: Bass Clef (Low) & Treble Clef (High).
  static List<NoteSplitterTrackResult> splitBassTreble(
    List<Note> notes, {
    int splitPitch = 60, // C4 (Middle C)
  }) {
    final List<Note> lowNotes = [];
    final List<Note> highNotes = [];

    for (final note in notes) {
      if (note.pitch < splitPitch) {
        lowNotes.add(note.copyWith());
      } else {
        highNotes.add(note.copyWith());
      }
    }

    return [
      if (lowNotes.isNotEmpty)
        NoteSplitterTrackResult(
          name: 'Bass Clef (Left Hand)',
          notes: lowNotes,
          color: const Color(0xFF3399FF),
        ),
      if (highNotes.isNotEmpty)
        NoteSplitterTrackResult(
          name: 'Treble Clef (Right Hand)',
          notes: highNotes,
          color: const Color(0xFFFFD700),
        ),
    ];
  }

  /// 4-Voice Polyphony Distribute: Distributes chord voicings into Soprano, Alto, Tenor, Bass tracks.
  static List<NoteSplitterTrackResult> split4VoicePolyphony(List<Note> notes) {
    if (notes.isEmpty) return [];

    // Group notes by time clusters
    final sorted = List<Note>.from(notes)..sort((a, b) => a.startStep.compareTo(b.startStep));
    final List<Note> soprano = [];
    final List<Note> alto = [];
    final List<Note> tenor = [];
    final List<Note> bass = [];

    double currentStep = -1;
    List<Note> activeCluster = [];

    void processCluster(List<Note> cluster) {
      if (cluster.isEmpty) return;
      // Sort cluster by pitch ascending
      cluster.sort((a, b) => a.pitch.compareTo(b.pitch));

      if (cluster.length == 1) {
        // Single note -> Soprano or Bass depending on register
        if (cluster.first.pitch < 55) {
          bass.add(cluster.first.copyWith());
        } else {
          soprano.add(cluster.first.copyWith());
        }
      } else if (cluster.length == 2) {
        bass.add(cluster[0].copyWith());
        soprano.add(cluster[1].copyWith());
      } else if (cluster.length == 3) {
        bass.add(cluster[0].copyWith());
        alto.add(cluster[1].copyWith());
        soprano.add(cluster[2].copyWith());
      } else {
        bass.add(cluster[0].copyWith());
        tenor.add(cluster[1].copyWith());
        alto.add(cluster[2].copyWith());
        soprano.add(cluster[3].copyWith());
      }
    }

    for (final note in sorted) {
      if (currentStep < 0 || (note.startStep - currentStep).abs() > 0.25) {
        processCluster(activeCluster);
        activeCluster = [note];
        currentStep = note.startStep;
      } else {
        activeCluster.add(note);
      }
    }
    processCluster(activeCluster);

    return [
      if (soprano.isNotEmpty)
        NoteSplitterTrackResult(name: 'Voice 1 (Soprano / Top)', notes: soprano, color: const Color(0xFFFF007A)),
      if (alto.isNotEmpty)
        NoteSplitterTrackResult(name: 'Voice 2 (Alto / High-Mid)', notes: alto, color: const Color(0xFFFF8C00)),
      if (tenor.isNotEmpty)
        NoteSplitterTrackResult(name: 'Voice 3 (Tenor / Low-Mid)', notes: tenor, color: const Color(0xFF21F4E8)),
      if (bass.isNotEmpty)
        NoteSplitterTrackResult(name: 'Voice 4 (Bass / Root)', notes: bass, color: const Color(0xFF00FF66)),
    ];
  }

  /// Drum & Percussion Demuxer (General MIDI drum map standard).
  static List<NoteSplitterTrackResult> splitDrumPercussion(List<Note> notes) {
    final List<Note> kickNotes = [];
    final List<Note> snareNotes = [];
    final List<Note> hatsCymbals = [];
    final List<Note> tomsPerc = [];

    for (final note in notes) {
      final p = note.pitch;
      if (p == 35 || p == 36) {
        // Bass Drum 1 & 2
        kickNotes.add(note.copyWith());
      } else if (p == 38 || p == 40 || p == 37 || p == 39) {
        // Acoustic/Electric Snare, Side Stick, Hand Clap
        snareNotes.add(note.copyWith());
      } else if (p == 42 || p == 44 || p == 46 || p == 49 || p == 51 || p == 52 || p == 55 || p == 57) {
        // Closed/Pedal/Open Hi-Hats, Crash, Ride, Splash, China cymbals
        hatsCymbals.add(note.copyWith());
      } else {
        // Toms and other percussion
        tomsPerc.add(note.copyWith());
      }
    }

    return [
      if (kickNotes.isNotEmpty)
        NoteSplitterTrackResult(name: 'Drums (Kick)', notes: kickNotes, color: const Color(0xFFFF3333)),
      if (snareNotes.isNotEmpty)
        NoteSplitterTrackResult(name: 'Drums (Snare & Clap)', notes: snareNotes, color: const Color(0xFFFF8C00)),
      if (hatsCymbals.isNotEmpty)
        NoteSplitterTrackResult(name: 'Drums (Hi-Hats & Cymbals)', notes: hatsCymbals, color: const Color(0xFFFFE600)),
      if (tomsPerc.isNotEmpty)
        NoteSplitterTrackResult(name: 'Drums (Toms & Perc)', notes: tomsPerc, color: const Color(0xFFBD00FF)),
    ];
  }

  /// Splits notes using a LuaScriptDef note splitter preset.
  static List<NoteSplitterTrackResult> splitWithPreset(
    List<Note> notes,
    LuaScriptDef preset, {
    Map<String, double>? params,
  }) {
    if (notes.isEmpty) return [];

    final code = preset.code.toLowerCase();
    final p = params ?? {};

    // 1. Check for 3-Way Voice Splitter
    if (code.contains('3-way') || code.contains('voice_split') || (code.contains('bass') && code.contains('lead'))) {
      final bassSplit = (p['bass_split'] ?? p['bass_split_pitch'] ?? 48.0).toInt();
      final leadSplit = (p['lead_split'] ?? p['lead_min_pitch'] ?? 64.0).toInt();
      return split3WayVoice(notes, bassSplitPitch: bassSplit, leadThresholdPitch: leadSplit);
    }

    // 2. Check for Bass/Treble Clef Splitter
    if (code.contains('treble') || code.contains('clef') || code.contains('piano_split') || code.contains('2-way')) {
      final splitPitch = (p['split_pitch'] ?? p['pivot_pitch'] ?? 60.0).toInt();
      return splitBassTreble(notes, splitPitch: splitPitch);
    }

    // 3. Check for 4-Voice Polyphony Distribute
    if (code.contains('polyphony') || code.contains('satb') || code.contains('distribute') || code.contains('voice_distribute')) {
      return split4VoicePolyphony(notes);
    }

    // 4. Check for Drum & Percussion Demuxer
    if (code.contains('drum') || code.contains('percussion') || code.contains('demux')) {
      return splitDrumPercussion(notes);
    }

    // Default fallback: 3-Way Voice Split
    return split3WayVoice(notes);
  }
}
