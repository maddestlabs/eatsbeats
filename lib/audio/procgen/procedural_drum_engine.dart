// Pure-Dart procedural drum pattern & groove generator for Eatsbeats.
// Generates dynamic, humanized drum patterns mapped to GM Standard Drum Kit (Notes 35–81).

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../eatscript/eat_script_library.dart';
import '../../eatscript/project_script_engine.dart';
import '../../models/daw_state.dart';
import '../../models/track_model.dart';
import 'procedural_piano_engine.dart';

class ProceduralDrumEngine {
  static const List<String> styles = [
    'Funk / Breakbeat',
    'Rock / Pop',
    'Hip-Hop / Boom-Bap',
    'Jazz / Swing',
    'Latin / Afro-Cuban',
    'House / Disco (4-on-Floor)',
    'Trap / Halftime',
    '16-Bit Console Action',
  ];

  static void _addNote(
    List<Note> notes, {
    required int pitch,
    required double startStep,
    double durationSteps = 1.0,
    double velocity = 0.9,
  }) {
    notes.add(Note(
      id: 'drum_n_${notes.length}_$pitch',
      pitch: pitch,
      startStep: startStep,
      durationSteps: durationSteps,
      velocity: velocity,
    ));
  }

  /// Generates drum notes based on procedural groove algorithms.
  static List<Note> generatePattern({
    required String style,
    int bars = 4,
    double density = 0.7,
    double swing = 0.2,
    double ghostProb = 0.25,
    double fillDensity = 0.35,
    double humanize = 0.25,
    int seed = 42,
  }) {
    final rng = Mulberry32Rng(seed);
    final List<Note> notes = [];

    final int totalSteps = bars * 16;

    for (int bar = 0; bar < bars; bar++) {
      final bool isFillBar = (bar % 4 == 3) && rng.chance(fillDensity);
      final int barStartStep = bar * 16;

      for (int stepInBar = 0; stepInBar < 16; stepInBar++) {
        final int step = barStartStep + stepInBar;
        final bool isLast4StepsOfBar = stepInBar >= 12;

        // Apply Swing micro-timing to even 16th steps (step % 2 != 0)
        double timeOffset = 0.0;
        if (stepInBar % 2 != 0) {
          timeOffset += swing * 0.33; // Shift towards triplet grid
        }
        // Humanize micro-timing jitter
        timeOffset += (rng.rand(-0.06, 0.06) * humanize);

        final double noteStart = (step + timeOffset).clamp(0.0, totalSteps.toDouble());

        // 1. If fill bar at end of bar, generate tom / snare roll
        if (isFillBar && isLast4StepsOfBar) {
          _generateFillStep(notes, stepInBar, noteStart, rng);
          continue;
        }

        // 2. Generate standard genre grooves
        switch (style) {
          case 'Funk / Breakbeat':
            _generateFunkStep(notes, stepInBar, noteStart, density, ghostProb, humanize, rng);
            break;
          case 'Rock / Pop':
            _generateRockStep(notes, stepInBar, noteStart, density, ghostProb, humanize, rng);
            break;
          case 'Hip-Hop / Boom-Bap':
            _generateBoomBapStep(notes, stepInBar, noteStart, density, ghostProb, humanize, rng);
            break;
          case 'Jazz / Swing':
            _generateJazzStep(notes, stepInBar, noteStart, density, ghostProb, humanize, rng);
            break;
          case 'Latin / Afro-Cuban':
            _generateLatinStep(notes, stepInBar, noteStart, density, ghostProb, humanize, rng);
            break;
          case 'House / Disco (4-on-Floor)':
            _generateFourOnFloorStep(notes, stepInBar, noteStart, density, ghostProb, humanize, rng);
            break;
          case '16-Bit Console Action':
            _generateSnesStep(notes, stepInBar, noteStart, density, ghostProb, humanize, rng);
            break;
          case 'Trap / Halftime':
          default:
            _generateTrapStep(notes, stepInBar, noteStart, density, ghostProb, humanize, rng);
            break;
        }

        // First beat of first bar Crash Cymbal accent
        if (step == 0) {
          _addNote(
            notes,
            pitch: 49, // Crash 1
            startStep: 0.0,
            durationSteps: 4.0,
            velocity: 0.95,
          );
        }
      }
    }

    return notes;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  GENRE PATTERN GENERATORS
  // ─────────────────────────────────────────────────────────────────────────

  static void _generateFunkStep(
    List<Note> notes,
    int stepInBar,
    double noteStart,
    double density,
    double ghostProb,
    double humanize,
    Mulberry32Rng rng,
  ) {
    // Kick: 0, and syncopated beats (e.g. 6, 10)
    if (stepInBar == 0 || stepInBar == 6 || (stepInBar == 10 && rng.chance(density))) {
      _addNote(
        notes,
        pitch: 36, // Kick 1
        startStep: noteStart,
        durationSteps: 1.0,
        velocity: _humanizeVel(0.90, humanize, rng),
      );
    }

    // Snare: Backbeat 4, 12 + ghost notes
    if (stepInBar == 4 || stepInBar == 12) {
      _addNote(
        notes,
        pitch: 38, // Snare
        startStep: noteStart,
        durationSteps: 1.0,
        velocity: _humanizeVel(0.95, humanize, rng),
      );
    } else if (rng.chance(ghostProb) && (stepInBar == 2 || stepInBar == 7 || stepInBar == 14)) {
      // Ghost Snare
      _addNote(
        notes,
        pitch: 38,
        startStep: noteStart,
        durationSteps: 0.5,
        velocity: _humanizeVel(0.32, humanize, rng),
      );
    }

    // Hi-Hats: Steady 16ths with accented 8ths & occasional open hat on 14
    if (stepInBar == 14 && rng.chance(0.5)) {
      _addNote(
        notes,
        pitch: 46, // Open Hat
        startStep: noteStart,
        durationSteps: 1.5,
        velocity: _humanizeVel(0.75, humanize, rng),
      );
    } else {
      final double vel = (stepInBar % 4 == 0) ? 0.75 : (stepInBar % 2 == 0 ? 0.60 : 0.42);
      _addNote(
        notes,
        pitch: 42, // Closed Hat
        startStep: noteStart,
        durationSteps: 0.5,
        velocity: _humanizeVel(vel, humanize, rng),
      );
    }
  }

  static void _generateRockStep(
    List<Note> notes,
    int stepInBar,
    double noteStart,
    double density,
    double ghostProb,
    double humanize,
    Mulberry32Rng rng,
  ) {
    // Kick: 0, 8, and optional 10
    if (stepInBar == 0 || stepInBar == 8 || (stepInBar == 10 && rng.chance(density * 0.7))) {
      _addNote(
        notes,
        pitch: 36,
        startStep: noteStart,
        durationSteps: 1.0,
        velocity: _humanizeVel(0.92, humanize, rng),
      );
    }

    // Snare: Driving backbeat on 4 and 12
    if (stepInBar == 4 || stepInBar == 12) {
      _addNote(
        notes,
        pitch: 38,
        startStep: noteStart,
        durationSteps: 1.0,
        velocity: _humanizeVel(1.0, humanize, rng),
      );
    }

    // Hi-Hats: Driving 8th notes (0, 2, 4, 6, 8, 10, 12, 14)
    if (stepInBar % 2 == 0) {
      _addNote(
        notes,
        pitch: 42,
        startStep: noteStart,
        durationSteps: 0.5,
        velocity: _humanizeVel(0.70, humanize, rng),
      );
    }
  }

  static void _generateBoomBapStep(
    List<Note> notes,
    int stepInBar,
    double noteStart,
    double density,
    double ghostProb,
    double humanize,
    Mulberry32Rng rng,
  ) {
    // Heavy Kick: 0, 7, 10
    if (stepInBar == 0 || (stepInBar == 7 && rng.chance(density)) || (stepInBar == 10 && rng.chance(density))) {
      _addNote(
        notes,
        pitch: 36,
        startStep: noteStart,
        durationSteps: 1.0,
        velocity: _humanizeVel(0.95, humanize, rng),
      );
    }

    // Crisp Snare + Clap layer on 4, 12
    if (stepInBar == 4 || stepInBar == 12) {
      _addNote(
        notes,
        pitch: 38, // Snare
        startStep: noteStart,
        durationSteps: 1.0,
        velocity: _humanizeVel(0.90, humanize, rng),
      );
      _addNote(
        notes,
        pitch: 39, // Clap layer
        startStep: noteStart,
        durationSteps: 1.0,
        velocity: _humanizeVel(0.65, humanize, rng),
      );
    }

    // Swung 16th Hats
    final double vel = (stepInBar % 4 == 0) ? 0.70 : 0.45;
    _addNote(
      notes,
      pitch: 42,
      startStep: noteStart,
      durationSteps: 0.5,
      velocity: _humanizeVel(vel, humanize, rng),
    );
  }

  static void _generateJazzStep(
    List<Note> notes,
    int stepInBar,
    double noteStart,
    double density,
    double ghostProb,
    double humanize,
    Mulberry32Rng rng,
  ) {
    // Soft feathering Kick on quarter notes
    if (stepInBar % 4 == 0 && rng.chance(0.6)) {
      _addNote(
        notes,
        pitch: 35, // Acoustic Bass Drum (feathery)
        startStep: noteStart,
        durationSteps: 1.0,
        velocity: _humanizeVel(0.40, humanize, rng),
      );
    }

    // Ride Cymbal pattern: Ding - ding-a ding (0, 4, 6, 8, 12, 14)
    if (stepInBar == 0 || stepInBar == 4 || stepInBar == 6 || stepInBar == 8 || stepInBar == 12 || stepInBar == 14) {
      _addNote(
        notes,
        pitch: (stepInBar == 0 && rng.chance(0.3)) ? 53 : 51, // Ride Bell or Ride
        startStep: noteStart,
        durationSteps: 1.0,
        velocity: _humanizeVel((stepInBar == 4 || stepInBar == 12) ? 0.85 : 0.65, humanize, rng),
      );
    }

    // Hi-Hat "chick" on 2 and 4 (beats 4 and 12)
    if (stepInBar == 4 || stepInBar == 12) {
      _addNote(
        notes,
        pitch: 44, // Pedal Hi-Hat
        startStep: noteStart,
        durationSteps: 0.5,
        velocity: _humanizeVel(0.70, humanize, rng),
      );
    }

    // Comping Snare brush/side stick
    if (rng.chance(ghostProb) && (stepInBar == 3 || stepInBar == 9 || stepInBar == 11)) {
      _addNote(
        notes,
        pitch: 37, // Side stick
        startStep: noteStart,
        durationSteps: 0.5,
        velocity: _humanizeVel(0.45, humanize, rng),
      );
    }
  }

  static void _generateLatinStep(
    List<Note> notes,
    int stepInBar,
    double noteStart,
    double density,
    double ghostProb,
    double humanize,
    Mulberry32Rng rng,
  ) {
    // Conga Tumbao pattern (62 Mute, 63 Open, 64 Low)
    if (stepInBar == 0 || stepInBar == 4) {
      _addNote(notes, pitch: 62, startStep: noteStart, durationSteps: 0.5, velocity: _humanizeVel(0.7, humanize, rng));
    } else if (stepInBar == 8 || stepInBar == 10) {
      _addNote(notes, pitch: 63, startStep: noteStart, durationSteps: 1.0, velocity: _humanizeVel(0.85, humanize, rng));
    }

    // Clave pattern (3-2 Son Clave: 0, 6, 10, 16, 20)
    if (stepInBar == 0 || stepInBar == 6 || stepInBar == 10) {
      _addNote(notes, pitch: 75, startStep: noteStart, durationSteps: 0.5, velocity: _humanizeVel(0.9, humanize, rng));
    }

    // Shakers / Maracas
    if (stepInBar % 2 == 0) {
      _addNote(notes, pitch: 70, startStep: noteStart, durationSteps: 0.5, velocity: _humanizeVel(0.6, humanize, rng));
    }

    // Cowbell pulse
    if (stepInBar % 4 == 0) {
      _addNote(notes, pitch: 56, startStep: noteStart, durationSteps: 1.0, velocity: _humanizeVel(0.75, humanize, rng));
    }
  }

  static void _generateFourOnFloorStep(
    List<Note> notes,
    int stepInBar,
    double noteStart,
    double density,
    double ghostProb,
    double humanize,
    Mulberry32Rng rng,
  ) {
    // 4-on-the-floor Kick (0, 4, 8, 12)
    if (stepInBar % 4 == 0) {
      _addNote(
        notes,
        pitch: 36,
        startStep: noteStart,
        durationSteps: 1.0,
        velocity: _humanizeVel(0.95, humanize, rng),
      );
    }

    // Snare / Clap on 4 and 12
    if (stepInBar == 4 || stepInBar == 12) {
      _addNote(
        notes,
        pitch: 39, // Clap
        startStep: noteStart,
        durationSteps: 1.0,
        velocity: _humanizeVel(0.90, humanize, rng),
      );
    }

    // Offbeat Open Hi-Hat (2, 6, 10, 14)
    if (stepInBar % 4 == 2) {
      _addNote(
        notes,
        pitch: 46, // Open Hat
        startStep: noteStart,
        durationSteps: 1.5,
        velocity: _humanizeVel(0.85, humanize, rng),
      );
    } else if (stepInBar % 2 == 0) {
      _addNote(
        notes,
        pitch: 42, // Closed Hat
        startStep: noteStart,
        durationSteps: 0.5,
        velocity: _humanizeVel(0.55, humanize, rng),
      );
    }
  }

  static void _generateTrapStep(
    List<Note> notes,
    int stepInBar,
    double noteStart,
    double density,
    double ghostProb,
    double humanize,
    Mulberry32Rng rng,
  ) {
    // Halftime Snare on Beat 8 (Beat 3 of bar)
    if (stepInBar == 8) {
      _addNote(
        notes,
        pitch: 38,
        startStep: noteStart,
        durationSteps: 1.0,
        velocity: _humanizeVel(1.0, humanize, rng),
      );
    }

    // Heavy Kick pattern
    if (stepInBar == 0 || (stepInBar == 11 && rng.chance(density)) || (stepInBar == 14 && rng.chance(density * 0.7))) {
      _addNote(
        notes,
        pitch: 36,
        startStep: noteStart,
        durationSteps: 1.0,
        velocity: _humanizeVel(0.95, humanize, rng),
      );
    }

    // Fast 16th hats with occasional roll triplets
    _addNote(
      notes,
      pitch: 42,
      startStep: noteStart,
      durationSteps: 0.25,
      velocity: _humanizeVel(stepInBar % 2 == 0 ? 0.70 : 0.45, humanize, rng),
    );
  }

  static void _generateSnesStep(
    List<Note> notes,
    int stepInBar,
    double noteStart,
    double density,
    double ghostProb,
    double humanize,
    Mulberry32Rng rng,
  ) {
    // 16-Bit Action Console Groove:
    // Driving punchy kick on 0, 8, with syncopated pushes on 6, 10
    if (stepInBar == 0 || stepInBar == 8 || (stepInBar == 6 && rng.chance(density)) || (stepInBar == 10 && rng.chance(density * 0.85))) {
      _addNote(
        notes,
        pitch: 36, // Kick 1
        startStep: noteStart,
        durationSteps: 1.0,
        velocity: _humanizeVel(0.92, humanize, rng),
      );
    }

    // Snare: Solid backbeat on 4, 12 + ghost hits on 7, 15
    if (stepInBar == 4 || stepInBar == 12) {
      _addNote(
        notes,
        pitch: 38, // Snare
        startStep: noteStart,
        durationSteps: 1.0,
        velocity: _humanizeVel(0.95, humanize, rng),
      );
    } else if (rng.chance(ghostProb) && (stepInBar == 7 || stepInBar == 15)) {
      _addNote(
        notes,
        pitch: 38,
        startStep: noteStart,
        durationSteps: 0.5,
        velocity: _humanizeVel(0.40, humanize, rng),
      );
    }

    // Hi-Hats: Driving 16ths with open hat sizzle on 14 or 6
    if ((stepInBar == 14 && rng.chance(0.6)) || (stepInBar == 6 && rng.chance(0.35))) {
      _addNote(
        notes,
        pitch: 46, // Open Hat
        startStep: noteStart,
        durationSteps: 1.5,
        velocity: _humanizeVel(0.78, humanize, rng),
      );
    } else {
      final double vel = (stepInBar % 4 == 0) ? 0.78 : (stepInBar % 2 == 0 ? 0.62 : 0.45);
      _addNote(
        notes,
        pitch: 42, // Closed Hat
        startStep: noteStart,
        durationSteps: 0.5,
        velocity: _humanizeVel(vel, humanize, rng),
      );
    }

    // Auxiliary 16-bit percussion: subtle tambourine or cowbell on upbeat 2, 10
    if ((stepInBar == 2 || stepInBar == 10) && rng.chance(0.25)) {
      _addNote(
        notes,
        pitch: 54, // Tambourine
        startStep: noteStart,
        durationSteps: 0.5,
        velocity: _humanizeVel(0.45, humanize, rng),
      );
    }
  }

  static void _generateFillStep(
    List<Note> notes,
    int stepInBar,
    double noteStart,
    Mulberry32Rng rng,
  ) {
    // High tom -> Mid tom -> Low tom -> Snare crescendo
    final int fillPitch;
    switch (stepInBar) {
      case 12:
        fillPitch = 50; // High Tom
        break;
      case 13:
        fillPitch = 47; // Mid Tom
        break;
      case 14:
        fillPitch = 41; // Low Floor Tom
        break;
      case 15:
      default:
        fillPitch = 38; // Snare hit
        break;
    }

    _addNote(
      notes,
      pitch: fillPitch,
      startStep: noteStart,
      durationSteps: 0.5,
      velocity: 0.85 + (stepInBar - 12) * 0.04,
    );
  }

  static double _humanizeVel(double base, double humanize, Mulberry32Rng rng) {
    final double j = rng.rand(-0.12, 0.12) * humanize;
    return (base + j).clamp(0.1, 1.0);
  }

  /// Generates drum pattern and writes it directly to the active DAW track.
  static ProjectScriptResult generateToDawState(DawState dawState, Map<String, dynamic> params) {
    final style = params['Style']?.toString() ?? 'Funk / Breakbeat';
    final bars = (params['Bars'] as num?)?.toInt() ?? 4;
    final density = ((params['Density'] as num?)?.toDouble() ?? 0.75).clamp(0.1, 1.0);
    final swing = ((params['Swing'] as num?)?.toDouble() ?? 0.20).clamp(0.0, 1.0);
    final ghostProb = ((params['GhostProbability'] as num?)?.toDouble() ?? 0.25).clamp(0.0, 1.0);
    final fillDensity = ((params['FillDensity'] as num?)?.toDouble() ?? 0.35).clamp(0.0, 1.0);
    final humanize = ((params['Humanize'] as num?)?.toDouble() ?? 0.25).clamp(0.0, 1.0);
    final seed = (params['Seed'] as num?)?.toInt() ?? 42;

    final notes = generatePattern(
      style: style,
      bars: bars,
      density: density,
      swing: swing,
      ghostProb: ghostProb,
      fillDensity: fillDensity,
      humanize: humanize,
      seed: seed,
    );

    // Target the active track if it's already gm_standard_drum_kit, or find/create one
    TrackChannel? targetTrack;
    for (final t in dawState.activePattern.tracks) {
      if (t.luaScriptCode.contains('gm_standard_drum_kit') || t.name.toLowerCase().contains('drum')) {
        targetTrack = t;
        break;
      }
    }

    final drumPreset = LuaPresetLibrary.getPresetById('gm_standard_drum_kit');
    final String drumCode = drumPreset?.code ?? '';

    if (targetTrack == null) {
      final newIndex = dawState.activePattern.tracks.length;
      final newTrackId = 'drum_track_${DateTime.now().millisecondsSinceEpoch}';
      targetTrack = TrackChannel(
        id: newTrackId,
        name: 'Drums (GM Standard Kit)',
        color: const Color(0xFFFF8C00),
        type: TrackType.eatScript,
        luaScriptCode: drumCode,
        luaParams: {
          'MasterTune': 0.0,
          'RoomLevel': 0.30,
          'KitDrive': 0.12,
          'Humanize': humanize,
          'StrikeDrift': 0.20,
        },
      );
      dawState.activePattern.tracks.add(targetTrack);
    } else {
      if (!targetTrack.luaScriptCode.contains('gm_standard_drum_kit')) {
        targetTrack.luaScriptCode = drumCode;
      }
    }

    final newClip = TrackClip(
      id: 'clip_proc_drums_${DateTime.now().millisecondsSinceEpoch}',
      name: '$style ($bars Bars)',
      trackId: targetTrack.id,
      startBar: 0,
      barLength: bars,
      notes: notes,
    );

    targetTrack.clips.add(newClip);
    targetTrack.notes = notes.map((n) => n.copyWith()).toList();

    dawState.notifyListeners();

    return ProjectScriptResult(
      isSuccess: true,
      message: 'Generated $bars-bar "$style" procedural drum groove with ${notes.length} notes!',
      affectedTracksCount: 1,
      affectedNotesCount: notes.length,
    );
  }
}
