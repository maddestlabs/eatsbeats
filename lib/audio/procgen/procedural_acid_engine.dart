// Pure-Dart procedural TB-303 acid pattern generator for Eatsbeats.
// Generates authentic acid basslines mapped to Eats-303 with realistic gate lengths,
// 60ms constant-rate portamento slides, syncopated accent distributions, and octave leaps.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../eatscript/eats_script_library.dart';
import '../../eatscript/project_script_engine.dart';
import '../../models/chord_model.dart';
import '../../models/daw_state.dart';
import '../../models/track_model.dart';
import 'procedural_piano_engine.dart';

class ProceduralAcidEngine {
  static const List<String> styles = [
    'Classic Chicago Acid (1987)',
    '90s Acid Trance / Goa',
    'Hard Acid Techno (Warehouse)',
    'Wonky IDM / Brain-Dance',
    'Electro Acid Funk',
    'Minimalist Hypnotic Acid',
  ];

  static const List<String> scales = [
    'Minor Pentatonic',
    'Phrygian (Dark)',
    'Dorian (Groovy)',
    'Natural Minor',
    'Acid Blues (Flatted 5th)',
    'Whole Tone (Trippy)',
  ];

  static const List<String> rootOptions = [
    'Auto (From Song Key)',
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
  ];

  static const List<String> octaveOptions = [
    '1 Octave (Tight Bass)',
    '2 Octaves (Classic 303 Leaps)',
    '3 Octaves (Wide Goa Arps)',
  ];

  static const List<String> waveformOptions = [
    'Sawtooth (Buzzy / Classic)',
    'Square (Hollow / Aggressive)',
    'Keep Existing / Random',
  ];

  static const List<String> companionOptions = [
    'None (Acid Bassline Only)',
    '4-on-Floor 909 Groove (Kick + Open Hat + Clap)',
  ];

  /// Returns scale interval offsets in semitones.
  static List<int> getScaleIntervals(String scaleName) {
    switch (scaleName) {
      case 'Phrygian (Dark)':
        return [0, 1, 3, 5, 7, 8, 10];
      case 'Dorian (Groovy)':
        return [0, 2, 3, 5, 7, 9, 10];
      case 'Natural Minor':
        return [0, 2, 3, 5, 7, 8, 10];
      case 'Acid Blues (Flatted 5th)':
        return [0, 3, 5, 6, 7, 10];
      case 'Whole Tone (Trippy)':
        return [0, 2, 4, 6, 8, 10];
      case 'Minor Pentatonic':
      default:
        return [0, 3, 5, 7, 10];
    }
  }

  /// Generates a list of Note objects conforming to authentic TB-303 sequencing rules.
  static List<Note> generatePattern({
    required String style,
    required String scaleName,
    int rootPitchClass = 0, // 0 = C
    int baseMidiOctave = 36, // MIDI 36 = C2 (classic 303 base)
    int bars = 2,
    double density = 0.75,
    double tieProb = 0.30,
    double slideProb = 0.40,
    double accentProb = 0.35,
    int octaveRange = 2, // 1, 2, or 3 octaves
    int seed = 303,
  }) {
    final rng = Mulberry32Rng(seed);
    final List<Note> notes = [];
    final scaleIntervals = getScaleIntervals(scaleName);

    // Build available MIDI notes across the specified octave range
    final List<int> availablePitches = [];
    for (int oct = 0; oct < octaveRange; oct++) {
      for (final interval in scaleIntervals) {
        final pitch = baseMidiOctave + (oct * 12) + rootPitchClass + interval;
        if (pitch <= 84 && !availablePitches.contains(pitch)) {
          availablePitches.add(pitch);
        }
      }
    }
    availablePitches.sort();

    // Style-specific behavioral parameters
    final double syncopationBias;
    final double octaveJumpProb;
    final double turnaroundFillProb;
    final double repetitionTendency;
    final double styleTieMultiplier;

    switch (style) {
      case '90s Acid Trance / Goa':
        syncopationBias = 0.85;
        octaveJumpProb = 0.60;
        turnaroundFillProb = 0.80;
        repetitionTendency = 0.25;
        styleTieMultiplier = 0.65;
        break;
      case 'Hard Acid Techno (Warehouse)':
        syncopationBias = 0.60;
        octaveJumpProb = 0.35;
        turnaroundFillProb = 0.65;
        repetitionTendency = 0.70;
        styleTieMultiplier = 0.80;
        break;
      case 'Wonky IDM / Brain-Dance':
        syncopationBias = 0.90;
        octaveJumpProb = 0.75;
        turnaroundFillProb = 0.90;
        repetitionTendency = 0.15;
        styleTieMultiplier = 1.25;
        break;
      case 'Electro Acid Funk':
        syncopationBias = 0.80;
        octaveJumpProb = 0.45;
        turnaroundFillProb = 0.50;
        repetitionTendency = 0.55;
        styleTieMultiplier = 1.15;
        break;
      case 'Minimalist Hypnotic Acid':
        syncopationBias = 0.45;
        octaveJumpProb = 0.25;
        turnaroundFillProb = 0.30;
        repetitionTendency = 0.80;
        styleTieMultiplier = 1.50;
        break;
      case 'Classic Chicago Acid (1987)':
      default:
        syncopationBias = 0.70;
        octaveJumpProb = 0.50;
        turnaroundFillProb = 0.60;
        repetitionTendency = 0.60;
        styleTieMultiplier = 1.00;
        break;
    }

    // Generate 16-step grid for each bar
    // Structure: StepDecision(hasNote, pitch, isSlide, isAccent, isTie)
    final List<_AcidStep> steps = [];
    final int totalSteps = bars * 16;
    final double effectiveTieProb = (tieProb * styleTieMultiplier).clamp(0.0, 0.85);

    // We generate bar 0 as reference motif, and then vary subsequent bars
    final List<_AcidStep> referenceBar = _generateBarTemplate(
      rng: rng,
      availablePitches: availablePitches,
      rootPitch: baseMidiOctave + rootPitchClass,
      scaleIntervals: scaleIntervals,
      density: density,
      syncopationBias: syncopationBias,
      octaveJumpProb: octaveJumpProb,
      tieProb: effectiveTieProb,
      slideProb: slideProb,
      accentProb: accentProb,
    );

    for (int bar = 0; bar < bars; bar++) {
      final bool isTurnaroundBar = (bar % 2 == 1);

      for (int stepInBar = 0; stepInBar < 16; stepInBar++) {
        final refStep = referenceBar[stepInBar];

        if (bar == 0) {
          steps.add(refStep.clone());
        } else {
          // In subsequent bars, apply subtle variation based on repetitionTendency
          final bool isLast4Steps = stepInBar >= 12;

          if (isTurnaroundBar && isLast4Steps && rng.chance(turnaroundFillProb)) {
            // Turnaround fill: rapid notes, slide runs, or high accents
            final newNote = rng.chance(0.85);
            if (newNote) {
              final pitch = _pickPlausiblePitch(
                rng: rng,
                availablePitches: availablePitches,
                lastPitch: steps.isNotEmpty ? steps.last.pitch : availablePitches.first,
                octaveJumpProb: 0.70,
              );
              final bool isSlideTurn = rng.chance(slideProb * 1.3);
              steps.add(_AcidStep(
                active: true,
                pitch: pitch,
                isSlide: isSlideTurn,
                isAccent: rng.chance(0.60),
                isTie: false,
              ));
            } else {
              steps.add(_AcidStep(active: false, pitch: refStep.pitch));
            }
          } else if (rng.chance(repetitionTendency)) {
            // Keep identical note from reference bar
            steps.add(refStep.clone());
          } else {
            // Slight mutation: either flip gate, toggle slide, or shift octave
            if (!refStep.active) {
              final activate = rng.chance(density * 0.3);
              steps.add(_AcidStep(
                active: activate,
                pitch: refStep.pitch,
                isSlide: rng.chance(slideProb),
                isAccent: rng.chance(accentProb),
                isTie: false,
              ));
            } else {
              int pitch = refStep.pitch;
              // Mutate octave with 30% chance
              if (rng.chance(0.30) && availablePitches.isNotEmpty) {
                final shift = rng.chance(0.5) ? 12 : -12;
                if (availablePitches.contains(pitch + shift)) {
                  pitch += shift;
                }
              }
              final bool isTieStep = refStep.isTie ? rng.chance(0.70) : rng.chance(effectiveTieProb * 0.4);
              steps.add(_AcidStep(
                active: true,
                pitch: pitch,
                isSlide: rng.chance(slideProb),
                isAccent: refStep.isAccent || rng.chance(accentProb * 0.5),
                isTie: isTieStep,
              ));
            }
          }
        }
      }
    }

    // Convert step array to Note objects with authentic 303 gate lengths & tied notes
    int i = 0;
    while (i < totalSteps) {
      final current = steps[i];
      if (!current.active) {
        i++;
        continue;
      }

      final double startStep = i.toDouble();

      // Count consecutive tied steps that hold the current pitch without triggering a new attack
      int tieCount = 0;
      int j = i + 1;
      while (j < totalSteps &&
          steps[j].active &&
          steps[j].isTie &&
          steps[j].pitch == current.pitch &&
          !steps[j].isSlide) {
        tieCount++;
        j++;
      }

      // Check following step for slide connection
      final bool hasFollower = (j < totalSteps) && steps[j].active;
      final bool followerIsSlide = hasFollower &&
          (steps[j].isSlide || (current.isSlide && steps[j].pitch != current.pitch));

      double durationSteps;
      if (followerIsSlide) {
        // Seamless bridge into the slide step (0.05 step overlap to guarantee legato glide)
        durationSteps = (1 + tieCount).toDouble() + 0.05;
        steps[j].isSlide = true; // Ensure destination note activates slide glissando
      } else if (hasFollower && current.isSlide) {
        durationSteps = (1 + tieCount).toDouble() + 0.05;
        steps[j].isSlide = true;
      } else {
        // Authentic 303 envelope decay release: staccato 16th or sustained hold with breathing room
        durationSteps = math.max(0.60, (1 + tieCount).toDouble() - 0.35);
      }

      final double velocity = current.isAccent ? 0.95 : 0.68;

      notes.add(Note(
        id: 'acid_303_${i}_${current.pitch}',
        pitch: current.pitch,
        startStep: startStep,
        durationSteps: durationSteps,
        velocity: velocity,
        isSlide: current.isSlide,
        isAccent: current.isAccent,
      ));

      i = j;
    }

    return notes;
  }

  /// Generates a single 16-step reference bar template.
  static List<_AcidStep> _generateBarTemplate({
    required Mulberry32Rng rng,
    required List<int> availablePitches,
    required int rootPitch,
    required List<int> scaleIntervals,
    required double density,
    required double syncopationBias,
    required double octaveJumpProb,
    required double tieProb,
    required double slideProb,
    required double accentProb,
  }) {
    final List<_AcidStep> bar = [];
    int lastPitch = rootPitch;

    // Classic 303 rhythmic step weights:
    // Steps 0, 4, 8, 12 = Downbeats (quarter notes)
    // Steps 2, 6, 10, 14 = Offbeat 8ths
    // Steps 1, 3, 5, 7, 9, 11, 13, 15 = 16th syncopations
    for (int s = 0; s < 16; s++) {
      final bool isDownbeat = (s % 4 == 0);
      final bool isOffbeat8th = (s % 4 == 2);
      final bool isPickup = (s == 15 || s == 7);

      // Check if step should tie/sustain the previous note
      int consecutiveTies = 0;
      for (int lookback = s - 1; lookback >= 0; lookback--) {
        if (bar[lookback].active && bar[lookback].isTie) {
          consecutiveTies++;
        } else {
          break;
        }
      }

      final bool canTie = (s > 0) && bar[s - 1].active && (consecutiveTies < 3);
      if (canTie && rng.chance(tieProb)) {
        // Tied step: continues sounding the previous note without attack retrigger
        final bool glideInTie = rng.chance(slideProb * 0.45);
        final pitch = glideInTie
            ? _pickPlausiblePitch(
                rng: rng,
                availablePitches: availablePitches,
                lastPitch: lastPitch,
                octaveJumpProb: octaveJumpProb * 0.5,
              )
            : lastPitch;
        lastPitch = pitch;

        bar.add(_AcidStep(
          active: true,
          pitch: pitch,
          isSlide: glideInTie || (pitch != bar[s - 1].pitch),
          isAccent: rng.chance(accentProb * 0.3),
          isTie: true,
        ));
        continue;
      }

      double stepDensityWeight = density;
      if (isDownbeat) {
        stepDensityWeight = math.min(1.0, density * 1.15);
      } else if (isOffbeat8th) {
        stepDensityWeight = math.min(1.0, density * (0.9 + syncopationBias * 0.2));
      } else if (isPickup) {
        stepDensityWeight = math.min(1.0, density * (0.8 + syncopationBias * 0.3));
      } else {
        stepDensityWeight = density * 0.85;
      }

      final bool hasNote = rng.chance(stepDensityWeight);
      if (!hasNote) {
        bar.add(_AcidStep(active: false, pitch: lastPitch));
        continue;
      }

      final pitch = _pickPlausiblePitch(
        rng: rng,
        availablePitches: availablePitches,
        lastPitch: lastPitch,
        octaveJumpProb: octaveJumpProb,
      );
      lastPitch = pitch;

      // Slide probability: higher on 16th pickups or when jumping intervals
      double effectiveSlideProb = slideProb;
      if (isPickup || (s % 2 != 0)) {
        effectiveSlideProb *= 1.25;
      }
      final isSlide = rng.chance(effectiveSlideProb.clamp(0.0, 1.0));

      // Accent probability: heavily favored on syncopated offbeats (steps 3, 6, 10, 14)
      double effectiveAccentProb = accentProb;
      if (s == 3 || s == 6 || s == 10 || s == 14) {
        effectiveAccentProb *= 1.4;
      } else if (isDownbeat && rng.chance(0.4)) {
        effectiveAccentProb *= 1.2;
      }
      final isAccent = rng.chance(effectiveAccentProb.clamp(0.0, 1.0));

      bar.add(_AcidStep(
        active: true,
        pitch: pitch,
        isSlide: isSlide,
        isAccent: isAccent,
        isTie: false,
      ));
    }

    return bar;
  }

  /// Selects a musically coherent pitch adhering to 303 octave jumps and step-wise motion.
  static int _pickPlausiblePitch({
    required Mulberry32Rng rng,
    required List<int> availablePitches,
    required int lastPitch,
    required double octaveJumpProb,
  }) {
    if (availablePitches.isEmpty) return 48;

    // Check if an octave jump leap should occur (+12 or -12 from last pitch)
    if (rng.chance(octaveJumpProb)) {
      final leapDirection = rng.chance(0.55) ? 12 : -12;
      final leapPitch = lastPitch + leapDirection;
      if (availablePitches.contains(leapPitch)) {
        return leapPitch;
      }
    }

    // Weighted selection favoring neighboring scale degrees (step-wise motion)
    final neighbors = availablePitches.where((p) => (p - lastPitch).abs() <= 7).toList();
    if (neighbors.isNotEmpty && rng.chance(0.70)) {
      return rng.pick(neighbors);
    }

    return rng.pick(availablePitches);
  }

  /// Generates companion 909 drum groove (Kick, Open Hat on offbeats, Clap on 2 & 4).
  static List<Note> generateCompanion909Notes(int bars) {
    final List<Note> notes = [];
    const int kickPitch = 36;    // GM Bass Drum 1
    const int clapPitch = 39;    // GM Hand Clap
    const int openHatPitch = 46; // GM Open Hi-Hat
    const int closedHatPitch = 42; // GM Closed Hi-Hat

    final int totalSteps = bars * 16;

    for (int step = 0; step < totalSteps; step++) {
      final int stepInBar = step % 16;

      // 1. Kick on every quarter note (0, 4, 8, 12)
      if (stepInBar % 4 == 0) {
        notes.add(Note(
          id: 'drum_909_kick_$step',
          pitch: kickPitch,
          startStep: step.toDouble(),
          durationSteps: 0.9,
          velocity: 0.98,
        ));
      }

      // 2. Clap on beats 2 and 4 (steps 4 and 12)
      if (stepInBar == 4 || stepInBar == 12) {
        notes.add(Note(
          id: 'drum_909_clap_$step',
          pitch: clapPitch,
          startStep: step.toDouble(),
          durationSteps: 0.9,
          velocity: 0.92,
        ));
      }

      // 3. Open Hat on offbeat 8ths (steps 2, 6, 10, 14)
      if (stepInBar % 4 == 2) {
        notes.add(Note(
          id: 'drum_909_ophat_$step',
          pitch: openHatPitch,
          startStep: step.toDouble(),
          durationSteps: 0.8,
          velocity: 0.88,
        ));
      } else {
        // Subtle closed hat pulse on remaining 16ths
        notes.add(Note(
          id: 'drum_909_clhat_$step',
          pitch: closedHatPitch,
          startStep: step.toDouble(),
          durationSteps: 0.4,
          velocity: 0.45,
        ));
      }
    }

    return notes;
  }

  /// Orchestrates pattern generation into active DAW state.
  static ProjectScriptResult generateToDawState(DawState dawState, Map<String, dynamic> params) {
    // 1. Parse parameters
    final rawStyle = params['Style'] ?? params['style'];
    final String styleStr = rawStyle is num
        ? (rawStyle.toInt() >= 0 && rawStyle.toInt() < styles.length ? styles[rawStyle.toInt()] : styles[0])
        : (rawStyle?.toString() ?? styles[0]);

    final rawScale = params['Scale'] ?? params['scale'];
    final String scaleStr = rawScale is num
        ? (rawScale.toInt() >= 0 && rawScale.toInt() < scales.length ? scales[rawScale.toInt()] : scales[0])
        : (rawScale?.toString() ?? scales[0]);

    final rawRoot = params['Root'] ?? params['root'];
    int rootPitchClass;
    if (rawRoot == null || rawRoot == 0 || rawRoot == 'Auto (From Song Key)') {
      rootPitchClass = dawState.songKeyRoot;
    } else if (rawRoot is num) {
      rootPitchClass = (rawRoot.toInt() - 1).clamp(0, 11);
    } else {
      final parsedIdx = ChordTheory.pitchClassNames.indexOf(rawRoot.toString().trim());
      rootPitchClass = parsedIdx >= 0 ? parsedIdx : dawState.songKeyRoot;
    }

    final bars = ((params['Bars'] ?? params['bars'] ?? 2) as num).toInt().clamp(1, 16);
    final density = ((params['Density'] ?? params['density'] ?? 0.75) as num).toDouble().clamp(0.2, 1.0);
    final tieProb = ((params['TieProbability'] ?? params['tie_probability'] ?? 0.30) as num).toDouble().clamp(0.0, 1.0);
    final slideProb = ((params['SlideProbability'] ?? params['slide_probability'] ?? 0.40) as num).toDouble().clamp(0.0, 1.0);
    final accentProb = ((params['AccentProbability'] ?? params['accent_probability'] ?? 0.35) as num).toDouble().clamp(0.0, 1.0);

    final rawOctave = params['OctaveJumpRange'] ?? params['octave_jump_range'];
    final int octaveRange = rawOctave is num ? (rawOctave.toInt() + 1).clamp(1, 3) : 2;

    final rawWave = params['Waveform'] ?? params['waveform'];
    final int waveIdx = rawWave is num ? rawWave.toInt().clamp(0, 2) : 0;

    final raw909 = params['Companion909'] ?? params['companion_909'];
    final bool enable909 = (raw909 == 1 || raw909 == 1.0 || raw909 == companionOptions[1]);

    final seed = ((params['Seed'] ?? params['seed'] ?? 303) as num).toInt();

    // 2. Procedurally generate acid notes
    final notes = generatePattern(
      style: styleStr,
      scaleName: scaleStr,
      rootPitchClass: rootPitchClass,
      bars: bars,
      density: density,
      tieProb: tieProb,
      slideProb: slideProb,
      accentProb: accentProb,
      octaveRange: octaveRange,
      seed: seed,
    );

    // 3. Find existing Eats-303 track or create a new one
    TrackChannel? targetTrack;
    for (final t in dawState.activePattern.tracks) {
      if (t.luaScriptCode.contains('eats_303') || t.name.toLowerCase().contains('303') || t.name.toLowerCase().contains('acid')) {
        targetTrack = t;
        break;
      }
    }

    final eats303Preset = LuaPresetLibrary.getPresetById('eats_303');
    final String eats303Code = eats303Preset?.code ?? '';

    if (targetTrack == null) {
      final newTrackId = 'acid_303_track_${DateTime.now().millisecondsSinceEpoch}';
      targetTrack = TrackChannel(
        id: newTrackId,
        name: 'Acid 303 (Eats-303)',
        color: const Color(0xFF00FFE0), // Acid cyan
        type: TrackType.eatScript,
        luaScriptCode: eats303Code,
        luaParams: {
          'Waveform': waveIdx == 1 ? 1.0 : 0.0,
          'Cutoff': 1400.0,
          'Resonance': 9.2,
          'EnvMod': 0.75,
          'Decay': 0.28,
          'Accent': 0.78,
          'Drive': 0.35,
          'Slide': 0.0,
        },
      );
      dawState.activePattern.tracks.add(targetTrack);
    } else {
      if (!targetTrack.luaScriptCode.contains('eats_303') && eats303Code.isNotEmpty) {
        targetTrack.luaScriptCode = eats303Code;
      }
      if (waveIdx < 2) {
        targetTrack.luaParams['Waveform'] = waveIdx == 1 ? 1.0 : 0.0;
      }
    }

    // 4. Attach Acid Clip to Track
    final acidClip = TrackClip(
      id: 'clip_acid_303_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Acid 303 • $styleStr ($bars Bars)',
      trackId: targetTrack.id,
      startBar: 0,
      barLength: bars,
      notes: notes,
    );

    targetTrack.clips.add(acidClip);
    targetTrack.notes = notes.map((n) => n.copyWith()).toList();

    int totalTracksAffected = 1;
    int totalNotesGenerated = notes.length;

    // 5. Optionally generate companion 909 drum groove
    if (enable909) {
      TrackChannel? drumTrack;
      for (final t in dawState.activePattern.tracks) {
        if (t.luaScriptCode.contains('gm_standard_drum_kit') || t.name.toLowerCase().contains('drum')) {
          drumTrack = t;
          break;
        }
      }

      final drumPreset = LuaPresetLibrary.getPresetById('gm_standard_drum_kit');
      final drumCode = drumPreset?.code ?? '';

      if (drumTrack == null) {
        final drumTrackId = 'drum_909_track_${DateTime.now().millisecondsSinceEpoch}';
        drumTrack = TrackChannel(
          id: drumTrackId,
          name: '909 Drums (Beat Companion)',
          color: const Color(0xFFFF8C00),
          type: TrackType.eatScript,
          luaScriptCode: drumCode,
          luaParams: {
            'MasterTune': 0.0,
            'RoomLevel': 0.25,
            'KitDrive': 0.20,
          },
        );
        dawState.activePattern.tracks.add(drumTrack);
      }

      final drumNotes = generateCompanion909Notes(bars);
      final drumClip = TrackClip(
        id: 'clip_909_beat_${DateTime.now().millisecondsSinceEpoch}',
        name: '909 Acid Beat ($bars Bars)',
        trackId: drumTrack.id,
        startBar: 0,
        barLength: bars,
        notes: drumNotes,
      );

      drumTrack.clips.add(drumClip);
      drumTrack.notes = drumNotes.map((n) => n.copyWith()).toList();

      totalTracksAffected++;
      totalNotesGenerated += drumNotes.length;
    }

    dawState.triggerAutoSave();
    dawState.notifyListeners();

    final rootName = ChordTheory.pitchClassNames[rootPitchClass];
    final slideCount = notes.where((n) => n.isSlide).length;
    final accentCount = notes.where((n) => n.isAccent).length;

    return ProjectScriptResult(
      isSuccess: true,
      message: 'Generated $bars-bar "$styleStr" acid loop ($rootName $scaleStr) with ${notes.length} notes ($slideCount slides, $accentCount accents)!',
      affectedTracksCount: totalTracksAffected,
      affectedNotesCount: totalNotesGenerated,
    );
  }
}

class _AcidStep {
  bool active;
  int pitch;
  bool isSlide;
  bool isAccent;
  bool isTie;

  _AcidStep({
    required this.active,
    required this.pitch,
    this.isSlide = false,
    this.isAccent = false,
    this.isTie = false,
  });

  _AcidStep clone() => _AcidStep(
        active: active,
        pitch: pitch,
        isSlide: isSlide,
        isAccent: isAccent,
        isTie: isTie,
      );
}
