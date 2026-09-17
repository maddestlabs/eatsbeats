// Pure-Dart procedural ensemble composition & orchestration engine for Eatsbeats.
// Supports arbitrary N-track ensembles, 5 universal functional roles,
// variable meters (4/4, 3/4, 6/8), and dynamic evolving arrangements.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../eatscript/eats_script_library.dart';
import '../../eatscript/project_script_engine.dart';
import '../../models/chord_model.dart';
import '../../models/daw_state.dart';
import '../../models/track_model.dart';
import 'ensemble_blueprint.dart';
import 'procedural_piano_engine.dart';
import 'song_archetype.dart';
import 'song_archetype_registry.dart';

class ProceduralEnsembleEngine {
  /// Available offline ensemble templates.
  static const List<String> availableTemplates = [
    'RPG Fireside Tavern (Lute & Flute Duet, 3/4 Waltz)',
    'Evolving Action Theme (Calm Intro to Full Drop)',
    'Ambient Ethereal Dungeon (Harp, Pad, Ocarina)',
    'C64 3-Voice Tracker (Bass, Lead, Noise Drum)',
    'Neo-Soul / Jazz Trio (Upright, Rhodes, Vibraphone)',
    'Orchestral Battle March (Timpani, Cellos, Strings, Brass)',
  ];

  /// Main execution method: renders any [SongStructureBlueprint] into [DawState].
  static ProjectScriptResult renderBlueprint(
    DawState dawState,
    SongStructureBlueprint blueprint, {
    int seed = 42,
    double swing = 0.0,
    double humanize = 0.20,
  }) {
    dawState.setSongBlueprint(blueprint, seed: seed);

    // Resolve active archetype from blueprint ID or DAW state
    SongArchetype? archetype;
    if (blueprint.archetypeId != null && blueprint.archetypeId!.isNotEmpty) {
      archetype = SongArchetypeRegistry.getById(blueprint.archetypeId!);
    }
    archetype ??= dawState.songArchetype;
    if (archetype != null && dawState.songArchetype != archetype) {
      dawState.setSongArchetype(archetype);
    }

    // 1. Update DAW Global Transport & Key
    dawState.setBpm(blueprint.bpm);
    dawState.projectName = '${blueprint.title} (#$seed)';
    final rootName = ChordTheory.pitchClassNames[blueprint.rootPitchClass];
    final modeTitle = blueprint.mode.isNotEmpty
        ? '${blueprint.mode[0].toUpperCase()}${blueprint.mode.substring(1)}'
        : 'Minor';
    dawState.setSongKey('$rootName $modeTitle');

    final int totalBars = blueprint.totalBars;
    final int stepsPerBar = blueprint.stepsPerBar;

    // 2. Build Global Chord Track
    final List<ChordEvent> globalChordEvents = [];
    int runningBar = 0;
    for (final section in blueprint.sections) {
      int secBar = 0;
      int chordIdx = 0;
      while (secBar < section.lengthBars && section.chords.isNotEmpty) {
        final ch = section.chords[chordIdx % section.chords.length];
        final dur = math.min(ch.barLength, (section.lengthBars - secBar).toDouble());
        globalChordEvents.add(ChordEvent(
          id: 'ens_chord_${runningBar + secBar}_$seed',
          startBar: runningBar + secBar,
          barLength: dur,
          rootPitchClass: ch.rootPitchClass,
          quality: ch.quality,
        ));
        secBar += dur.toInt();
        chordIdx++;
      }
      runningBar += section.lengthBars;
    }
    dawState.chordTrack = globalChordEvents;

    // 3. Clear Pattern and Setup Tracks
    final pattern = dawState.activePattern;
    pattern.tracks.clear();
    pattern.lengthSteps = totalBars * stepsPerBar;

    // 4. Instantiate Track Channels for the Ensemble
    final List<TrackChannel> createdTracks = [];
    for (final trackBp in blueprint.ensemble) {
      final preset = EatScriptLibrary.getPresetById(trackBp.presetId);
      final String code = preset?.code ?? '';

      final track = TrackChannel(
        id: 'ens_track_${trackBp.trackId}',
        name: trackBp.name,
        color: Color(trackBp.colorHex),
        type: TrackType.eatScript,
        volume: trackBp.role == FunctionalRole.rhythm ? 0.90 : 0.82,
        pan: _assignDefaultPan(trackBp.role),
        eatScriptCode: code,
        eatScriptParams: Map<String, double>.from(trackBp.defaultParams),
      );
      createdTracks.add(track);
      pattern.tracks.add(track);
    }

    // 5. Render Sections Track-by-Track
    int startBar = 0;
    for (int secIdx = 0; secIdx < blueprint.sections.length; secIdx++) {
      final section = blueprint.sections[secIdx];
      final secChords = _getChordsInRange(globalChordEvents, startBar, startBar + section.lengthBars);

      for (int tIdx = 0; tIdx < blueprint.ensemble.length; tIdx++) {
        final trackBp = blueprint.ensemble[tIdx];
        final trackChannel = createdTracks[tIdx];
        final double energy = section.getTrackEnergy(trackBp.trackId);

        // If energy is 0.0, instrument rests completely during this section (no clip / tacet)
        if (energy <= 0.01) {
          continue;
        }

        final secRng = Mulberry32Rng(seed + (secIdx * 77) + (tIdx * 19));

        // Universal Role Rendering (Informed by Active Archetype / Exemplar):
        final List<Note> clipNotes = _renderRoleNotes(
          role: trackBp.role,
          textureType: trackBp.textureType,
          section: section,
          chords: secChords,
          stepsPerBar: stepsPerBar,
          meter: blueprint.meter,
          energy: energy,
          rootPitchClass: blueprint.rootPitchClass,
          isMinor: blueprint.mode.toLowerCase().contains('minor') || blueprint.mode.toLowerCase().contains('dorian'),
          swing: swing,
          humanize: humanize,
          rng: secRng,
          archetype: archetype,
          trackBlueprint: trackBp,
          barOffset: startBar,
        );

        if (clipNotes.isNotEmpty) {
          final clip = TrackClip(
            id: 'clip_${trackBp.trackId}_${section.name}_$startBar',
            name: '${section.name} (${trackBp.name})',
            trackId: trackChannel.id,
            startBar: startBar,
            barLength: section.lengthBars,
            notes: clipNotes,
          );
          trackChannel.clips.add(clip);

          // Timeline note reflection for active clip sync
          final double startOffset = startBar * stepsPerBar.toDouble();
          final timelineNotes = clipNotes.map((n) {
            return n.copyWith(
              id: 't_${trackBp.trackId}_${n.id}',
              startStep: n.startStep + startOffset,
            );
          }).toList();
          trackChannel.notes.addAll(timelineNotes);
        }
      }

      startBar += section.lengthBars;
    }

    // 6. Finalize Loop & DAW State
    dawState.setLoopPoints(0, totalBars);
    dawState.setLooping(true);
    dawState.isSongMode = true;

    int totalNotes = 0;
    for (final t in pattern.tracks) {
      for (final c in t.clips) {
        totalNotes += c.notes.length;
      }
    }

    dawState.triggerAutoSave();
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    dawState.notifyListeners();

    return ProjectScriptResult(
      isSuccess: true,
      message: 'Generated "${blueprint.title}" (${blueprint.meter}, $totalBars bars) across ${pattern.tracks.length} ensemble tracks with $totalNotes notes!',
      affectedTracksCount: pattern.tracks.length,
      affectedNotesCount: totalNotes,
      affectedChordsCount: globalChordEvents.length,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  UNIVERSAL FUNCTIONAL ROLE RENDERERS
  // ─────────────────────────────────────────────────────────────────────────

  static List<Note> _renderRoleNotes({
    required FunctionalRole role,
    required TextureType textureType,
    required EnsembleSectionBlueprint section,
    required List<ChordEvent> chords,
    required int stepsPerBar,
    required String meter,
    required double energy,
    required int rootPitchClass,
    required bool isMinor,
    required double swing,
    required double humanize,
    required Mulberry32Rng rng,
    SongArchetype? archetype,
    EnsembleTrackBlueprint? trackBlueprint,
    int barOffset = 0,
  }) {
    switch (role) {
      case FunctionalRole.rhythm:
        return _renderRhythm(
          section: section,
          stepsPerBar: stepsPerBar,
          meter: meter,
          energy: energy,
          swing: swing,
          humanize: humanize,
          rng: rng,
        );

      case FunctionalRole.foundation:
        return _renderFoundation(
          section: section,
          chords: chords,
          stepsPerBar: stepsPerBar,
          energy: energy,
          rootPitchClass: rootPitchClass,
          rng: rng,
          archetype: archetype,
          barOffset: barOffset,
        );

      case FunctionalRole.harmonicTexture:
        return _renderHarmonicTexture(
          textureType: textureType,
          section: section,
          chords: chords,
          stepsPerBar: stepsPerBar,
          energy: energy,
          rng: rng,
          archetype: archetype,
          trackBlueprint: trackBlueprint,
          barOffset: barOffset,
        );

      case FunctionalRole.primaryMelody:
        return _renderMelody(
          behavior: section.melodyBehavior,
          section: section,
          chords: chords,
          stepsPerBar: stepsPerBar,
          energy: energy,
          rootPitchClass: rootPitchClass,
          isMinor: isMinor,
          rng: rng,
          archetype: archetype,
          barOffset: barOffset,
        );

      case FunctionalRole.counterpoint:
        return _renderCounterpoint(
          section: section,
          chords: chords,
          stepsPerBar: stepsPerBar,
          energy: energy,
          rootPitchClass: rootPitchClass,
          isMinor: isMinor,
          rng: rng,
        );
    }
  }

  /// 1. Rhythm Renderer
  static List<Note> _renderRhythm({
    required EnsembleSectionBlueprint section,
    required int stepsPerBar,
    required String meter,
    required double energy,
    required double swing,
    required double humanize,
    required Mulberry32Rng rng,
  }) {
    final List<Note> notes = [];
    final int totalBars = section.lengthBars;
    final bool isTripleMeter = meter == '3/4' || meter == '6/8';

    for (int bar = 0; bar < totalBars; bar++) {
      final double barStart = bar * stepsPerBar.toDouble();
      final bool isLastBar = bar == totalBars - 1;

      if (isTripleMeter) {
        // 3/4 Waltz / Tavern Pulse: Beat 1 kick/tambourine, beats 2 and 3 soft hi-hat/snare
        // Downbeat (Beat 1)
        notes.add(Note(
          id: 'rhy_k_${bar}_0',
          pitch: 36, // Kick
          startStep: barStart + 0.0,
          durationSteps: 1.0,
          velocity: (0.75 * energy).clamp(0.2, 1.0),
        ));

        // Beat 2 (step 4) & Beat 3 (step 8)
        if (energy > 0.35) {
          notes.add(Note(
            id: 'rhy_h_${bar}_4',
            pitch: energy > 0.70 ? 38 : 42, // Snare or hat
            startStep: barStart + 4.0,
            durationSteps: 0.8,
            velocity: (0.65 * energy).clamp(0.2, 0.9),
          ));
          notes.add(Note(
            id: 'rhy_h_${bar}_8',
            pitch: energy > 0.70 ? 38 : 42,
            startStep: barStart + 8.0,
            durationSteps: 0.8,
            velocity: (0.60 * energy).clamp(0.2, 0.9),
          ));
        }
      } else {
        // 4/4 Driving Rhythm:
        // Downbeat kick on step 0
        notes.add(Note(
          id: 'rhy_k_${bar}_0',
          pitch: 36,
          startStep: barStart + 0.0,
          durationSteps: 1.0,
          velocity: (0.90 * energy).clamp(0.4, 1.0),
        ));

        // Backbeat Snare on 4 and 12 if energy > 0.4
        if (energy >= 0.40) {
          notes.add(Note(
            id: 'rhy_s_${bar}_4',
            pitch: 38,
            startStep: barStart + 4.0,
            durationSteps: 1.0,
            velocity: (0.92 * energy).clamp(0.3, 1.0),
          ));
          notes.add(Note(
            id: 'rhy_s_${bar}_12',
            pitch: 38,
            startStep: barStart + 12.0,
            durationSteps: 1.0,
            velocity: (0.92 * energy).clamp(0.3, 1.0),
          ));
        }

        // Syncopated secondary kick on step 8 or 10
        if (energy >= 0.65) {
          final kickStep = rng.chance(0.6) ? 8.0 : 10.0;
          notes.add(Note(
            id: 'rhy_k2_${bar}_$kickStep',
            pitch: 36,
            startStep: barStart + kickStep,
            durationSteps: 1.0,
            velocity: 0.85 * energy,
          ));
        }

        // Hi-Hats: 8ths or 16ths depending on energy
        final int hatStepInterval = energy > 0.70 ? 2 : 4;
        for (int s = 0; s < 16; s += hatStepInterval) {
          if (s == 4 || s == 12) continue; // let snare breathe
          final double timeOffset = (s % 2 != 0 ? swing * 0.33 : 0.0) + (rng.rand(-0.04, 0.04) * humanize);
          notes.add(Note(
            id: 'rhy_hat_${bar}_$s',
            pitch: (s == 14 && rng.chance(0.5)) ? 46 : 42,
            startStep: (barStart + s + timeOffset).clamp(barStart, barStart + 15.9),
            durationSteps: 0.5,
            velocity: (0.55 * energy).clamp(0.1, 0.85),
          ));
        }
      }

      // Transition fill on final bar if requested
      if (isLastBar && section.transitionFill == TransitionFill.snareBuild) {
        for (int s = stepsPerBar - 4; s < stepsPerBar; s++) {
          notes.add(Note(
            id: 'rhy_fill_${bar}_$s',
            pitch: 38, // Snare crescendo
            startStep: barStart + s,
            durationSteps: 0.5,
            velocity: 0.60 + (s - (stepsPerBar - 4)) * 0.12,
          ));
        }
      }
    }
    return notes;
  }

  /// 2. Foundation (Bassline / Roots) Renderer (Informed by Exemplar or Procedural Fallback)
  static List<Note> _renderFoundation({
    required EnsembleSectionBlueprint section,
    required List<ChordEvent> chords,
    required int stepsPerBar,
    required double energy,
    required int rootPitchClass,
    required Mulberry32Rng rng,
    SongArchetype? archetype,
    int barOffset = 0,
  }) {
    final List<Note> notes = [];
    final int totalBars = section.lengthBars;

    // Check if active archetype includes a foundation track with extracted phrases
    ArchetypeTrackProfile? bassProfile;
    if (archetype != null) {
      for (final t in archetype.tracks) {
        if (t.role == FunctionalRole.foundation && t.hasPhrases) {
          bassProfile = t;
          break;
        }
      }
    }

    if (bassProfile != null && bassProfile.phrases.isNotEmpty) {
      // ── EXEMPLAR-INFORMED BASSLINE PHRASING ──
      final phrases = bassProfile.phrases;
      final double stepScale = stepsPerBar / 16.0;

      // Extract intra-bar rhythmic offsets and durations from exemplar phrases
      final offsets = <double>[];
      final durs = <double>[];
      for (final p in phrases) {
        final off = (p.relativeStep % 16.0) * stepScale;
        if (!offsets.any((existing) => (existing - off).abs() < 1.0)) {
          offsets.add(off);
          durs.add((p.durationSteps * stepScale).clamp(1.0, stepsPerBar / 2.0));
        }
        if (offsets.length >= 4) break;
      }
      offsets.sort();

      for (int bar = 0; bar < totalBars; bar++) {
        final chord = _getChordAtBar(chords, bar);
        final chRoot = chord?.bassPitchClass ?? chord?.rootPitchClass ?? rootPitchClass;
        final int bassNote = 36 + chRoot;
        final double barStart = bar * stepsPerBar.toDouble();

        if (energy <= 0.35) {
          // Low energy sustained drone
          notes.add(Note(
            id: 'bass_ex_${bar}_drone',
            pitch: bassNote,
            startStep: barStart,
            durationSteps: stepsPerBar.toDouble() - 0.5,
            velocity: 0.70,
          ));
        } else {
          // Walking acoustic pulse matching exemplar rhythmic timing
          for (int oi = 0; oi < offsets.length; oi++) {
            final off = offsets[oi];
            final dur = durs.length > oi ? durs[oi] : (stepsPerBar / offsets.length);
            final bool isOctave = (energy > 0.70 && oi > 0 && rng.chance(0.35));
            notes.add(Note(
              id: 'bass_ex_${bar}_$oi',
              pitch: isOctave ? bassNote + 12 : bassNote,
              startStep: barStart + off,
              durationSteps: dur,
              velocity: (oi == 0 ? 0.90 : 0.78) * energy.clamp(0.4, 1.0),
              isAccent: oi == 0,
            ));
          }
        }
      }
      return notes;
    }

    // Default Procedural Foundation Fallback
    for (int bar = 0; bar < totalBars; bar++) {
      final chord = _getChordAtBar(chords, bar);
      final chRoot = chord?.bassPitchClass ?? chord?.rootPitchClass ?? rootPitchClass;
      final int bassNote = 36 + chRoot; // C2 (36)
      final double barStart = bar * stepsPerBar.toDouble();

      if (energy <= 0.40) {
        // Low energy: Sustained deep root pedal drone
        notes.add(Note(
          id: 'bass_${bar}_drone',
          pitch: bassNote,
          startStep: barStart,
          durationSteps: stepsPerBar.toDouble() - 0.5,
          velocity: 0.70,
        ));
      } else if (energy <= 0.75) {
        // Medium energy: Root on beat 1 + 5th bounce on upbeat
        notes.add(Note(
          id: 'bass_${bar}_0',
          pitch: bassNote,
          startStep: barStart + 0.0,
          durationSteps: (stepsPerBar / 2) - 0.5,
          velocity: 0.88,
        ));
        final fifthStep = (stepsPerBar / 2).floorToDouble();
        notes.add(Note(
          id: 'bass_${bar}_5th',
          pitch: bassNote + 7,
          startStep: barStart + fifthStep,
          durationSteps: (stepsPerBar / 2) - 1.0,
          velocity: 0.78,
        ));
      } else {
        // High energy: Driving rolling pulse with octave slap
        final pulseInterval = stepsPerBar == 12 ? 3 : 2;
        for (int s = 0; s < stepsPerBar; s += pulseInterval) {
          final isOctave = (s % (pulseInterval * 2)) != 0;
          notes.add(Note(
            id: 'bass_${bar}_$s',
            pitch: isOctave ? bassNote + 12 : bassNote,
            startStep: barStart + s,
            durationSteps: pulseInterval - 0.5,
            velocity: s == 0 ? 0.95 : 0.80,
          ));
        }
      }
    }
    return notes;
  }

  /// 3. Harmonic Texture Renderer (Sustained, Strummed, Arpeggiated, Stabs - Informed by Exemplar or Procedural Fallback)
  static List<Note> _renderHarmonicTexture({
    required TextureType textureType,
    required EnsembleSectionBlueprint section,
    required List<ChordEvent> chords,
    required int stepsPerBar,
    required double energy,
    required Mulberry32Rng rng,
    SongArchetype? archetype,
    EnsembleTrackBlueprint? trackBlueprint,
    int barOffset = 0,
  }) {
    final List<Note> notes = [];
    final int totalBars = section.lengthBars;

    // Look for matching exemplar track with extracted phrases
    ArchetypeTrackProfile? matchedTrack;
    if (archetype != null) {
      for (final t in archetype.tracks) {
        if (t.hasPhrases) {
          if (trackBlueprint != null && (t.trackId == trackBlueprint.trackId || (t.presetId.isNotEmpty && t.presetId == trackBlueprint.presetId))) {
            matchedTrack = t;
            break;
          }
          if (t.role == FunctionalRole.harmonicTexture && matchedTrack == null) {
            matchedTrack = t;
          }
        }
      }
    }

    final double stepScale = stepsPerBar / 16.0;

    for (int bar = 0; bar < totalBars; bar += 2) {
      final chord = _getChordAtBar(chords, bar) ?? chords.firstOrNull;
      final pitches = chord?.pitchClasses ?? [0, 4, 7];
      final double segStart = bar * stepsPerBar.toDouble();
      final double segDur = math.min(2.0, (totalBars - bar).toDouble()) * stepsPerBar.toDouble();

      // Form 3-to-4 note voicing in mid register (C3..C5)
      final voicing = <int>[];
      for (int i = 0; i < pitches.length; i++) {
        final octave = (i == 0) ? 48 : (i <= 2 ? 60 : 72);
        voicing.add(octave + pitches[i]);
      }
      voicing.sort();

      if (matchedTrack != null && matchedTrack.phrases.isNotEmpty) {
        // ── EXEMPLAR-INFORMED HARMONIC TEXTURE (e.g. Spanish guitar arpeggios, Grand piano sustains) ──
        final phrases = matchedTrack.phrases;
        final bool isSustainedExemplar = phrases.any((p) => p.durationSteps >= 16.0);

        if (isSustainedExemplar) {
          // Sustained piano / pad voicings matching exemplar note lengths
          for (int vi = 0; vi < voicing.length; vi++) {
            notes.add(Note(
              id: 'tex_ex_sus_${bar}_$vi',
              pitch: voicing[vi],
              startStep: segStart + (vi * 0.02),
              durationSteps: segDur - 0.5,
              velocity: (0.74 * energy).clamp(0.2, 0.88),
            ));
          }
          continue;
        } else {
          // Arpeggiated / fingerpicked strum timing from exemplar (e.g. Spanish guitar)
          final offsets = <double>[];
          for (final p in phrases) {
            final off = (p.relativeStep % (stepsPerBar * 2)) * stepScale;
            if (!offsets.any((existing) => (existing - off).abs() < 1.0)) {
              offsets.add(off);
            }
            if (offsets.length >= 8) break;
          }
          offsets.sort();

          if (offsets.isNotEmpty) {
            for (int oi = 0; oi < offsets.length; oi++) {
              final double strokeStep = segStart + offsets[oi];
              if (strokeStep >= segStart + segDur) break;
              final pIdx = oi % voicing.length;
              notes.add(Note(
                id: 'tex_ex_strum_${bar}_${oi}_$pIdx',
                pitch: voicing[pIdx],
                startStep: strokeStep,
                durationSteps: 3.2 * stepScale,
                velocity: (0.72 * energy).clamp(0.2, 0.90),
              ));
            }
            continue;
          }
        }
      }

      // Default Procedural Fallback
      switch (textureType) {
        case TextureType.sustained:
          // Smooth sustained pad/string bed
          for (int vi = 0; vi < voicing.length; vi++) {
            notes.add(Note(
              id: 'tex_sus_${bar}_$vi',
              pitch: voicing[vi],
              startStep: segStart + (vi * 0.02),
              durationSteps: segDur - 0.5,
              velocity: (0.72 * energy).clamp(0.2, 0.85),
            ));
          }
          break;

        case TextureType.strummed:
          // Acoustic lute / guitar strumming: staggered pick strokes
          final strokeCount = (segDur / (stepsPerBar == 12 ? 4.0 : 4.0)).floor();
          for (int stroke = 0; stroke < strokeCount; stroke++) {
            final double strokeStep = segStart + (stroke * 4.0);
            for (int vi = 0; vi < voicing.length; vi++) {
              final double pickDelay = vi * 0.035; // 35ms strum roll
              notes.add(Note(
                id: 'tex_strum_${bar}_${stroke}_$vi',
                pitch: voicing[vi],
                startStep: strokeStep + pickDelay,
                durationSteps: 3.2,
                velocity: ((0.75 - vi * 0.03) * energy).clamp(0.2, 0.9),
              ));
            }
          }
          break;

        case TextureType.arpeggiated:
          // Rolling harp sweep / chip arp cycling notes
          final int arpStepInterval = energy > 0.7 ? 2 : 3;
          final int stepsInSeg = segDur.toInt();
          for (int s = 0; s < stepsInSeg; s += arpStepInterval) {
            final pIdx = (s ~/ arpStepInterval) % voicing.length;
            notes.add(Note(
              id: 'tex_arp_${bar}_$s',
              pitch: voicing[pIdx],
              startStep: segStart + s,
              durationSteps: arpStepInterval - 0.4,
              velocity: (0.68 * energy).clamp(0.2, 0.85),
            ));
          }
          break;

        case TextureType.stabs:
          // Syncopated hits on offbeats (e.g. 2, 6, 10, 14)
          final hitSteps = stepsPerBar == 12 ? [3.0, 9.0] : [2.0, 6.0, 10.0, 14.0];
          for (int bInSeg = 0; bInSeg < 2 && (bar + bInSeg) < totalBars; bInSeg++) {
            final bStart = (bar + bInSeg) * stepsPerBar.toDouble();
            for (final h in hitSteps) {
              for (int vi = 0; vi < voicing.length; vi++) {
                notes.add(Note(
                  id: 'tex_stab_${bar}_${bInSeg}_${h.toInt()}_$vi',
                  pitch: voicing[vi],
                  startStep: bStart + h,
                  durationSteps: 1.5,
                  velocity: (0.80 * energy).clamp(0.3, 0.95),
                ));
              }
            }
          }
          break;
      }
    }
    return notes;
  }

  /// 4. Primary Melody Renderer (Antecedent / Consequent Phrasing, Exemplar Informed or Procedural)
  static List<Note> _renderMelody({
    required MelodyBehavior behavior,
    required EnsembleSectionBlueprint section,
    required List<ChordEvent> chords,
    required int stepsPerBar,
    required double energy,
    required int rootPitchClass,
    required bool isMinor,
    required Mulberry32Rng rng,
    SongArchetype? archetype,
    int barOffset = 0,
  }) {
    if (behavior == MelodyBehavior.tacet) {
      return []; // Complete rest for lyrical breathing
    }

    // ── STRICT LEAD OMISSION RULE ──
    // If the active archetype explicitly has NO lead track, and no custom motif was supplied
    // in the blueprint, do not generate any lead notes.
    if (archetype != null && !archetype.hasLeadTrack && (section.melodyMotif == null || section.melodyMotif!.isEmpty)) {
      return [];
    }

    // ── EXEMPLAR PHRASING & ORNAMENTATION ENGINE ──
    // When an archetype has a lead track profile with extracted phrases,
    // generate the melody from the exemplar's real phrases, intervals, grace runs, and sustains
    // rather than falling back to the generic STMN procedural piano scalar motif generator.
    if (archetype != null && archetype.hasLeadTrack) {
      final exemplarNotes = _renderMelodyFromExemplar(
        archetype: archetype,
        behavior: behavior,
        section: section,
        chords: chords,
        stepsPerBar: stepsPerBar,
        energy: energy,
        rootPitchClass: rootPitchClass,
        isMinor: isMinor,
        rng: rng,
        barOffset: barOffset,
      );
      if (exemplarNotes.isNotEmpty) {
        return exemplarNotes;
      }
    }

    final List<Note> notes = [];
    final int totalBars = section.lengthBars;

    // Resolve MelodyStyle (from blueprint or inferred by meter/energy/rng)
    MelodyStyle style = section.melodyStyle;
    if (style == MelodyStyle.auto) {
      if (stepsPerBar == 12) {
        style = rng.nextDouble() > 0.4 ? MelodyStyle.folkBallad : MelodyStyle.lyrical;
      } else if (energy > 0.8) {
        final r = rng.nextDouble();
        style = r < 0.35 ? MelodyStyle.heroicAnthem : (r < 0.70 ? MelodyStyle.syncopatedRiff : MelodyStyle.cascadingRun);
      } else if (energy < 0.4) {
        style = rng.nextDouble() > 0.5 ? MelodyStyle.atmospheric : MelodyStyle.lyrical;
      } else {
        const pool = [
          MelodyStyle.lyrical,
          MelodyStyle.heroicAnthem,
          MelodyStyle.syncopatedRiff,
          MelodyStyle.cascadingRun,
          MelodyStyle.folkBallad,
          MelodyStyle.bluesy,
        ];
        style = pool[rng.nextInt(pool.length)];
      }
    }

    // Scale interval definitions
    final diatonicIntervals = isMinor
        ? const [0, 2, 3, 5, 7, 8, 10, 12, 14, 15]
        : const [0, 2, 4, 5, 7, 9, 11, 12, 14, 16];
    final pentatonicIntervals = isMinor
        ? const [0, 3, 5, 7, 10, 12, 15, 17]
        : const [0, 2, 4, 7, 9, 12, 14, 16];
    const bluesIntervals = [0, 3, 5, 6, 7, 10, 12, 15];

    List<int> activeScale;
    switch (style) {
      case MelodyStyle.bluesy:
        activeScale = bluesIntervals;
        break;
      case MelodyStyle.folkBallad:
        activeScale = pentatonicIntervals;
        break;
      case MelodyStyle.syncopatedRiff:
        activeScale = pentatonicIntervals;
        break;
      case MelodyStyle.atmospheric:
        activeScale = pentatonicIntervals;
        break;
      case MelodyStyle.heroicAnthem:
      case MelodyStyle.lyrical:
      case MelodyStyle.cascadingRun:
      default:
        activeScale = diatonicIntervals;
        break;
    }

    // Base pitch register (60 = C4, 72 = C5)
    final int baseOctave = (style == MelodyStyle.atmospheric || behavior == MelodyBehavior.themeB) ? 72 : 60;

    // Build the core Melodic Motif (scale degree offsets)
    List<int> motifDegrees;
    if (section.melodyMotif != null && section.melodyMotif!.isNotEmpty) {
      motifDegrees = List<int>.from(section.melodyMotif!);
    } else {
      // Procedurally generate a motif suited to the style using rng
      switch (style) {
        case MelodyStyle.heroicAnthem:
          final motifs = [
            [0, 4, 2, 4],     // root -> 5th -> 3rd -> 5th
            [0, 4, 5, 4],     // root -> 5th -> 6th -> 5th
            [0, 2, 4, 7],     // triumphant ascent to octave
            [4, 2, 0, 4],     // fan-out
          ];
          motifDegrees = motifs[rng.nextInt(motifs.length)];
          break;

        case MelodyStyle.syncopatedRiff:
          final motifs = [
            [0, 2, 1, 2, 0],  // pentatonic bounce
            [0, 3, 2, 0],     // bluesy hook
            [2, 0, 3, 2],     // offbeat answer
            [0, 1, 2, 3],     // driving run
          ];
          motifDegrees = motifs[rng.nextInt(motifs.length)];
          break;

        case MelodyStyle.cascadingRun:
          final motifs = [
            [0, 1, 2, 3, 4, 3, 2, 1], // wave run
            [4, 3, 2, 1, 2, 3, 4, 5], // cascade down and up
            [0, 2, 1, 3, 2, 4, 3, 5], // alternating stairs
          ];
          motifDegrees = motifs[rng.nextInt(motifs.length)];
          break;

        case MelodyStyle.folkBallad:
          final motifs = [
            [0, 1, 2, 1, 0],
            [2, 3, 2, 1, 0],
            [0, 2, 3, 2],
            [1, 2, 4, 3],
          ];
          motifDegrees = motifs[rng.nextInt(motifs.length)];
          break;

        case MelodyStyle.bluesy:
          final motifs = [
            [0, 1, 2, 3, 2],
            [2, 3, 4, 2, 0],
            [1, 2, 1, 0],
          ];
          motifDegrees = motifs[rng.nextInt(motifs.length)];
          break;

        case MelodyStyle.atmospheric:
          final motifs = [
            [0, 3, 4],
            [2, 4, 2],
            [0, 2, 5],
          ];
          motifDegrees = motifs[rng.nextInt(motifs.length)];
          break;

        case MelodyStyle.lyrical:
        default:
          final motifs = [
            [0, 1, 2, 4],
            [2, 1, 0, 1, 2],
            [0, 2, 3, 2, 0],
            [3, 2, 1, 0],
          ];
          motifDegrees = motifs[rng.nextInt(motifs.length)];
          break;
      }
    }

    // Determine rhythmic timing template for the motif in Bar 1
    List<double> rhythmOffsets;
    if (stepsPerBar == 12) {
      // 3/4 Meter (12 steps)
      switch (style) {
        case MelodyStyle.cascadingRun:
          rhythmOffsets = [0.0, 1.0, 2.0, 3.0, 4.0, 6.0, 7.0, 8.0];
          break;
        case MelodyStyle.atmospheric:
          rhythmOffsets = [0.0, 6.0];
          break;
        case MelodyStyle.syncopatedRiff:
          rhythmOffsets = [1.5, 3.0, 6.0, 7.5, 9.0];
          break;
        case MelodyStyle.folkBallad:
        case MelodyStyle.lyrical:
        default:
          final rChoice = rng.nextInt(3);
          if (rChoice == 0) {
            rhythmOffsets = [0.0, 2.0, 4.0, 6.0, 9.0];
          } else if (rChoice == 1) {
            rhythmOffsets = [0.0, 3.0, 6.0, 9.0];
          } else {
            rhythmOffsets = [1.0, 3.0, 6.0, 8.0];
          }
          break;
      }
    } else {
      // 4/4 Meter (16 steps)
      switch (style) {
        case MelodyStyle.cascadingRun:
          rhythmOffsets = [0.0, 1.0, 2.0, 3.0, 4.0, 6.0, 8.0, 10.0];
          break;
        case MelodyStyle.atmospheric:
          rhythmOffsets = [0.0, 6.0, 12.0];
          break;
        case MelodyStyle.heroicAnthem:
          final rChoice = rng.nextInt(3);
          if (rChoice == 0) {
            rhythmOffsets = [0.0, 4.0, 6.0, 8.0, 12.0];
          } else if (rChoice == 1) {
            rhythmOffsets = [0.0, 3.0, 8.0, 11.0];
          } else {
            rhythmOffsets = [0.0, 6.0, 8.0, 10.0];
          }
          break;
        case MelodyStyle.syncopatedRiff:
          final rChoice = rng.nextInt(3);
          if (rChoice == 0) {
            rhythmOffsets = [1.5, 3.0, 6.0, 7.5, 10.0];
          } else if (rChoice == 1) {
            rhythmOffsets = [0.0, 2.5, 5.0, 8.0, 11.0];
          } else {
            rhythmOffsets = [0.0, 3.0, 4.5, 7.0, 10.5];
          }
          break;
        case MelodyStyle.bluesy:
          final rChoice = rng.nextInt(2);
          rhythmOffsets = rChoice == 0
              ? [0.0, 3.0, 6.0, 8.5, 11.0]
              : [2.0, 5.0, 7.0, 10.0, 13.0];
          break;
        case MelodyStyle.folkBallad:
        case MelodyStyle.lyrical:
        default:
          final rChoice = rng.nextInt(3);
          if (rChoice == 0) {
            rhythmOffsets = [0.0, 3.0, 6.0, 10.0];
          } else if (rChoice == 1) {
            rhythmOffsets = [2.0, 4.0, 6.0, 8.0, 12.0];
          } else {
            rhythmOffsets = [0.0, 4.0, 7.0, 11.0];
          }
          break;
      }
    }

    // Apply melodyDensity: if density < 0.5, thin out rhythm offsets
    if (section.melodyDensity < 0.5 && rhythmOffsets.length > 2) {
      final thinned = <double>[];
      for (int i = 0; i < rhythmOffsets.length; i += 2) {
        thinned.add(rhythmOffsets[i]);
      }
      rhythmOffsets = thinned;
    } else if (section.melodyDensity > 0.8 && rhythmOffsets.length < 8 && stepsPerBar == 16) {
      final last = rhythmOffsets.last;
      if (last + 2.0 < stepsPerBar) {
        rhythmOffsets.add(last + 2.0);
      }
    }

    final phraseSize = totalBars >= 4 ? 4 : 2;

    for (int bar = 0; bar < totalBars; bar += 2) {
      final chord = _getChordAtBar(chords, bar) ?? chords.firstOrNull;
      final chRoot = chord?.rootPitchClass ?? rootPitchClass;
      final double barStart = bar * stepsPerBar.toDouble();
      final int phraseBarIndex = bar % phraseSize;

      if (behavior == MelodyBehavior.callResponse) {
        // Active on even bars, rest on odd bars for counterpoint
        final callCount = math.min(3, motifDegrees.length);
        for (int mi = 0; mi < callCount; mi++) {
          final deg = motifDegrees[mi % motifDegrees.length];
          final interval = activeScale[deg % activeScale.length];
          final step = mi < rhythmOffsets.length ? rhythmOffsets[mi] : (mi * 3.0);
          final pitch = baseOctave + chRoot + interval;
          notes.add(Note(
            id: 'mel_call_${bar}_$mi',
            pitch: pitch.clamp(55, 98),
            startStep: barStart + step,
            durationSteps: 2.5,
            velocity: (0.85 * energy).clamp(0.4, 0.98),
            isAccent: mi == 0,
          ));
        }
        continue;
      }

      // Bar 1 / Even Bar: State or Develop Motif
      final int motifLen = math.min(motifDegrees.length, rhythmOffsets.length);
      final int transposition = (phraseBarIndex == 2)
          ? 2 // Bar 3 escalation: transpose up 2 scale degrees
          : (behavior == MelodyBehavior.themeB ? 4 : 0);

      for (int mi = 0; mi < motifLen; mi++) {
        int deg = motifDegrees[mi] + transposition;
        if (behavior == MelodyBehavior.themeB) {
          // Invert contour for theme B
          deg = (motifDegrees.last - motifDegrees[mi]).abs() + 2;
        }

        final interval = activeScale[deg % activeScale.length];
        int pitch = baseOctave + chRoot + interval;
        if (behavior == MelodyBehavior.themeB) {
          pitch += 12; // Theme B plays an octave higher
        }

        final step = rhythmOffsets[mi];
        final nextStep = (mi + 1 < motifLen) ? rhythmOffsets[mi + 1] : stepsPerBar.toDouble();
        final maxDur = (nextStep - step).clamp(0.8, 4.0);
        final dur = (style == MelodyStyle.syncopatedRiff)
            ? (maxDur * 0.75).clamp(0.9, 2.0)
            : (style == MelodyStyle.cascadingRun ? 1.0 : (maxDur * 0.9).clamp(1.2, 3.5));

        final bool isFirst = mi == 0;
        final bool isLast = mi == motifLen - 1;
        final bool isAccent = isFirst || (style == MelodyStyle.heroicAnthem && isLast);
        final bool isSlide = (style == MelodyStyle.bluesy && mi == 1) ||
                             (style == MelodyStyle.heroicAnthem && isLast && rng.nextDouble() > 0.4);

        final vel = ((isAccent ? 0.92 : 0.82) * energy).clamp(0.35, 0.98);

        notes.add(Note(
          id: 'mel_${bar}_$mi',
          pitch: pitch.clamp(55, 98),
          startStep: barStart + step,
          durationSteps: dur,
          velocity: vel,
          isAccent: isAccent,
          isSlide: isSlide,
        ));
      }

      // Bar 2 / Odd Bar: Consequent Answer & Resolution
      if (bar + 1 < totalBars) {
        final double answerStart = barStart + stepsPerBar.toDouble();
        final nextChord = _getChordAtBar(chords, bar + 1) ?? chord;
        final ansRoot = nextChord?.rootPitchClass ?? chRoot;

        // Choose resolving note: root, 3rd, or 5th
        final int resolutionDegree = (phraseBarIndex == 2)
            ? 7 // Half cadence to 5th
            : (behavior == MelodyBehavior.variation ? (isMinor ? 3 : 4) : 0);

        final int ansPitch = baseOctave + ansRoot + resolutionDegree + (behavior == MelodyBehavior.themeB ? 12 : 0);
        final double ansStep = (stepsPerBar == 12) ? 2.0 : (style == MelodyStyle.syncopatedRiff ? 1.5 : 2.0);
        final double ansDur = (stepsPerBar == 12)
            ? (stepsPerBar - 4.0).clamp(2.0, 8.0)
            : (style == MelodyStyle.syncopatedRiff ? 4.0 : (stepsPerBar - 5.0).clamp(3.0, 11.0));

        notes.add(Note(
          id: 'mel_ans_${bar + 1}',
          pitch: ansPitch.clamp(55, 98),
          startStep: answerStart + ansStep,
          durationSteps: ansDur,
          velocity: (0.84 * energy).clamp(0.4, 0.95),
          isAccent: true,
        ));

        // In high energy or variation, add a pick-up fill note at the end of the answering bar
        if ((energy > 0.65 || behavior == MelodyBehavior.variation) && stepsPerBar >= 16) {
          final pickupStep = stepsPerBar - 2.0;
          final pickupPitch = ansPitch + (isMinor ? 2 : 2);
          notes.add(Note(
            id: 'mel_pickup_${bar + 1}',
            pitch: pickupPitch.clamp(55, 98),
            startStep: answerStart + pickupStep,
            durationSteps: 1.5,
            velocity: (0.75 * energy).clamp(0.3, 0.88),
            isSlide: true,
          ));
        }
      }
    }
    return notes;
  }

  /// Exemplar Phrasing Renderer: structures lead melody using authentic note phrases,
  /// singing sustains, interval leaps, and cascading grace runs extracted directly from the exemplar.
  static List<Note> _renderMelodyFromExemplar({
    required SongArchetype archetype,
    required MelodyBehavior behavior,
    required EnsembleSectionBlueprint section,
    required List<ChordEvent> chords,
    required int stepsPerBar,
    required double energy,
    required int rootPitchClass,
    required bool isMinor,
    required Mulberry32Rng rng,
    int barOffset = 0,
  }) {
    final leadProfile = archetype.leadProfile;
    if (leadProfile == null || leadProfile.phrases.isEmpty) {
      return [];
    }

    final phrases = leadProfile.phrases;
    final List<Note> notes = [];
    final int totalBars = section.lengthBars;
    final hint = archetype.sectionHints[section.name];

    // Determine archetype key root
    final exemplarKeyRootName = archetype.songKey.split(' ').first;
    int exemplarKeyRoot = ChordTheory.pitchClassNames.indexOf(exemplarKeyRootName);
    if (exemplarKeyRoot < 0) {
      exemplarKeyRoot = ChordTheory.pitchClassFlatNames.indexOf(exemplarKeyRootName);
    }
    if (exemplarKeyRoot < 0) exemplarKeyRoot = 0;

    // Identify phrase groups in the exemplar:
    // Sustained singing notes (duration >= 8.0 steps in 4/4)
    final sustainedPhrases = phrases.where((p) => p.durationSteps >= 8.0).toList();
    // Fast ornamental grace runs (duration <= 2.0 steps)
    final graceRunPhrases = phrases.where((p) => p.durationSteps <= 2.0).toList();
    // Intermediate phrases
    final shortPhrases = phrases.where((p) => p.durationSteps > 2.0 && p.durationSteps < 8.0).toList();

    // Determine if section calls for a virtuosic ornamental cascade (Climax, Theme B with high energy, cascadingRun)
    final bool isClimaxOrRun = section.melodyStyle == MelodyStyle.cascadingRun ||
        (hint?.articulation?.contains('glissando_run') ?? false) ||
        (hint?.directive.toLowerCase().contains('cascade') ?? false) ||
        section.name.toLowerCase().contains('climax') ||
        section.name.toLowerCase().contains('run') ||
        (behavior == MelodyBehavior.themeB && energy >= 0.70);

    final double stepScale = stepsPerBar / 16.0;

    for (int bar = 0; bar < totalBars; bar += 2) {
      final chord = _getChordAtBar(chords, bar) ?? chords.firstOrNull;
      final chRoot = chord?.rootPitchClass ?? rootPitchClass;
      final chordPitches = chord?.pitchClasses ?? (isMinor ? [chRoot, (chRoot + 3) % 12, (chRoot + 7) % 12] : [chRoot, (chRoot + 4) % 12, (chRoot + 7) % 12]);
      final double barStart = bar * stepsPerBar.toDouble();

      if (isClimaxOrRun && graceRunPhrases.isNotEmpty) {
        // ── EXEMPLAR ORNAMENTAL GRACE CASCADE (e.g. Ultima VI 0.73-step runs) ──
        final int startIdx = (bar * 3) % graceRunPhrases.length;
        final int runLen = math.min(4, graceRunPhrases.length);
        double curStep = (stepsPerBar == 12) ? 0.0 : (rng.nextDouble() > 0.5 ? 0.0 : 2.0 * stepScale);

        for (int ri = 0; ri < runLen; ri++) {
          final gp = graceRunPhrases[(startIdx + ri) % graceRunPhrases.length];
          final int deltaFromExemplar = gp.pitch - (60 + exemplarKeyRoot);
          final int pitch = 72 + chRoot + deltaFromExemplar;
          final double dur = gp.durationSteps * stepScale;

          final bool isSlide = gp.isSlide || (archetype.leadDirectives.glissandoDensity > 0.15 && rng.nextDouble() < archetype.leadDirectives.glissandoDensity);

          notes.add(Note(
            id: 'mel_ex_run_${bar}_$ri',
            pitch: pitch.clamp(55, 102),
            startStep: barStart + curStep,
            durationSteps: dur.clamp(0.4, 2.5),
            velocity: (gp.velocity * energy).clamp(0.4, 0.98),
            isSlide: isSlide,
            isAccent: gp.isAccent,
          ));
          curStep += dur;
        }

        // Resolving held landing note on consequent bar
        if (bar + 1 < totalBars) {
          final nextChord = _getChordAtBar(chords, bar + 1) ?? chord;
          final nextPitches = nextChord?.pitchClasses ?? chordPitches;
          final int landingPitch = 72 + nextPitches[1 % nextPitches.length];
          notes.add(Note(
            id: 'mel_ex_land_${bar + 1}',
            pitch: landingPitch.clamp(55, 96),
            startStep: (bar + 1) * stepsPerBar.toDouble(),
            durationSteps: (stepsPerBar.toDouble() * 1.5).clamp(8.0, 24.0) * stepScale,
            velocity: (0.85 * energy).clamp(0.4, 0.95),
            isAccent: true,
          ));
        }
      } else if (sustainedPhrases.isNotEmpty) {
        // ── EXEMPLAR SUSTAINED SINGING VOICE (e.g. Ultima VI 24-step vibrating tones) ──
        final int pIdx = ((barOffset + bar) ~/ 2) % sustainedPhrases.length;
        final sp = sustainedPhrases[pIdx];

        final int deltaFromExemplar = sp.pitch - (60 + exemplarKeyRoot);
        int targetPitch = 60 + chRoot + deltaFromExemplar;

        // Snap sustained tones to closest chord tone for lush harmonic resonance
        int bestPitch = targetPitch;
        int minDistance = 999;
        for (final cp in chordPitches) {
          for (int oct = 60; oct <= 84; oct += 12) {
            final cand = oct + cp;
            final dist = (cand - targetPitch).abs();
            if (dist < minDistance) {
              minDistance = dist;
              bestPitch = cand;
            }
          }
        }
        targetPitch = bestPitch;

        // Duration matches exemplar sustain
        final double dur = math.min(
          sp.durationSteps * stepScale,
          (totalBars - bar) * stepsPerBar.toDouble() - 0.5,
        ).clamp(4.0, 32.0);

        final bool isSlide = sp.isSlide || (archetype.leadDirectives.glissandoDensity > 0.1 && rng.nextDouble() < archetype.leadDirectives.glissandoDensity);

        notes.add(Note(
          id: 'mel_ex_sus_$bar',
          pitch: targetPitch.clamp(55, 98),
          startStep: barStart,
          durationSteps: dur,
          velocity: (sp.velocity * energy).clamp(0.35, 0.98),
          isAccent: sp.isAccent,
          isSlide: isSlide,
        ));
      } else {
        // ── GENERAL EXEMPLAR PHRASE MAPPING ──
        final pool = shortPhrases.isNotEmpty ? shortPhrases : phrases;
        final int pIdx = (barOffset + bar) % pool.length;
        final p = pool[pIdx];
        final int delta = p.pitch - (60 + exemplarKeyRoot);
        notes.add(Note(
          id: 'mel_ex_note_$bar',
          pitch: (60 + chRoot + delta).clamp(55, 96),
          startStep: barStart,
          durationSteps: (p.durationSteps * stepScale).clamp(1.0, stepsPerBar.toDouble()),
          velocity: (p.velocity * energy).clamp(0.35, 0.95),
          isAccent: p.isAccent,
          isSlide: p.isSlide,
        ));
      }
    }

    return notes;
  }

  /// 5. Counterpoint / Answering Voice Renderer
  static List<Note> _renderCounterpoint({
    required EnsembleSectionBlueprint section,
    required List<ChordEvent> chords,
    required int stepsPerBar,
    required double energy,
    required int rootPitchClass,
    required bool isMinor,
    required Mulberry32Rng rng,
  }) {
    final List<Note> notes = [];
    final int totalBars = section.lengthBars;
    final int third = isMinor ? 3 : 4;

    for (int bar = 0; bar < totalBars; bar += 2) {
      final chord = _getChordAtBar(chords, bar) ?? chords.firstOrNull;
      final chRoot = chord?.rootPitchClass ?? rootPitchClass;
      final double barStart = bar * stepsPerBar.toDouble();

      // In Bar 1, counterpoint can play a subtle entrance
      if (energy > 0.5 && stepsPerBar == 16) {
        notes.add(Note(
          id: 'cpt_call_${bar}_0',
          pitch: 60 + chRoot + (rng.nextDouble() > 0.5 ? 7 : third),
          startStep: barStart + 8.0,
          durationSteps: 2.5,
          velocity: (0.65 * energy).clamp(0.25, 0.85),
        ));
      }

      // When melody is playing, counterpoint harmonizes or plays conversational fills on Bar 2
      if (bar + 1 < totalBars) {
        final nextChord = _getChordAtBar(chords, bar + 1) ?? chord;
        final ansRoot = nextChord?.rootPitchClass ?? chRoot;
        final double answerStart = barStart + stepsPerBar.toDouble();

        // 3rd harmony
        notes.add(Note(
          id: 'cpt_resp_${bar}_1',
          pitch: 60 + ansRoot + third,
          startStep: answerStart + (stepsPerBar == 12 ? 3.0 : 4.0),
          durationSteps: (stepsPerBar == 12 ? 2.5 : 3.5),
          velocity: (0.76 * energy).clamp(0.3, 0.9),
        ));

        // 5th resolution or octave
        final int harmInterval = rng.nextDouble() > 0.4 ? 7 : 12;
        notes.add(Note(
          id: 'cpt_resp_${bar}_2',
          pitch: 60 + ansRoot + harmInterval,
          startStep: answerStart + (stepsPerBar == 12 ? 6.0 : 8.0),
          durationSteps: (stepsPerBar == 12 ? 3.0 : 3.5),
          velocity: (0.72 * energy).clamp(0.3, 0.85),
        ));
      }
    }
    return notes;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  OFFLINE ENSEMBLE TEMPLATES
  // ─────────────────────────────────────────────────────────────────────────

  /// Generates a rich, structurally dynamic offline blueprint.
  static SongStructureBlueprint generateOfflineBlueprint(String templateName, {int seed = 42}) {
    if (templateName.contains('Fireside') || templateName.contains('Tavern')) {
      // 1. RPG Tavern Duet (Acoustic Lute & Wooden Flute, 3/4 Waltz)
      return SongStructureBlueprint(
        title: 'Fireside Tavern Tale',
        bpm: 76.0,
        meter: '3/4',
        rootPitchClass: 2, // D
        mode: 'dorian',
        ensemble: const [
          EnsembleTrackBlueprint(
            trackId: 'lute',
            name: 'Acoustic Lute',
            presetId: 'felt_piano',
            role: FunctionalRole.harmonicTexture,
            textureType: TextureType.strummed,
            colorHex: 0xFFC29B38,
          ),
          EnsembleTrackBlueprint(
            trackId: 'flute',
            name: 'Wooden Flute',
            presetId: 'snes_synth',
            role: FunctionalRole.primaryMelody,
            colorHex: 0xFF35A853,
          ),
        ],
        sections: const [
          EnsembleSectionBlueprint(
            name: 'Intro (Lute Solo)',
            lengthBars: 4,
            chords: [
              EnsembleChordEvent(rootPitchClass: 2, quality: ChordQuality.minor, barLength: 2.0),
              EnsembleChordEvent(rootPitchClass: 9, quality: ChordQuality.minor, barLength: 2.0),
            ],
            trackEnergy: {'lute': 0.85, 'flute': 0.0}, // Flute is completely silent!
            melodyBehavior: MelodyBehavior.tacet,
          ),
          EnsembleSectionBlueprint(
            name: 'Theme A (Flute Enters)',
            lengthBars: 8,
            chords: [
              EnsembleChordEvent(rootPitchClass: 2, quality: ChordQuality.minor, barLength: 2.0),
              EnsembleChordEvent(rootPitchClass: 7, quality: ChordQuality.major, barLength: 2.0),
              EnsembleChordEvent(rootPitchClass: 0, quality: ChordQuality.major, barLength: 2.0),
              EnsembleChordEvent(rootPitchClass: 2, quality: ChordQuality.minor, barLength: 2.0),
            ],
            trackEnergy: {'lute': 0.75, 'flute': 0.95},
            melodyBehavior: MelodyBehavior.themeA,
          ),
          EnsembleSectionBlueprint(
            name: 'Theme B (Lively Modulation)',
            lengthBars: 8,
            chords: [
              EnsembleChordEvent(rootPitchClass: 5, quality: ChordQuality.major, barLength: 2.0),
              EnsembleChordEvent(rootPitchClass: 0, quality: ChordQuality.major, barLength: 2.0),
              EnsembleChordEvent(rootPitchClass: 7, quality: ChordQuality.major, barLength: 2.0),
              EnsembleChordEvent(rootPitchClass: 2, quality: ChordQuality.minor, barLength: 2.0),
            ],
            trackEnergy: {'lute': 0.85, 'flute': 0.95},
            melodyBehavior: MelodyBehavior.themeB,
          ),
          EnsembleSectionBlueprint(
            name: 'Outro (Calm Fade)',
            lengthBars: 4,
            chords: [
              EnsembleChordEvent(rootPitchClass: 2, quality: ChordQuality.minor, barLength: 4.0),
            ],
            trackEnergy: {'lute': 0.60, 'flute': 0.50},
            melodyBehavior: MelodyBehavior.variation,
          ),
        ],
      );
    }

    if (templateName.contains('Evolving Action')) {
      // 2. Evolving Action: Calm atmospheric start -> Full power battle drop -> Calm outro
      return SongStructureBlueprint(
        title: 'Ascending Battle Odyssey',
        bpm: 136.0,
        meter: '4/4',
        rootPitchClass: 9, // A
        mode: 'minor',
        ensemble: const [
          EnsembleTrackBlueprint(
            trackId: 'drums',
            name: 'Battle Percussion',
            presetId: 'snes_drum_kit',
            role: FunctionalRole.rhythm,
            colorHex: 0xFFEA4335,
          ),
          EnsembleTrackBlueprint(
            trackId: 'bass',
            name: 'Driving Slap Bass',
            presetId: 'snes_synth',
            role: FunctionalRole.foundation,
            colorHex: 0xFF9C27B0,
          ),
          EnsembleTrackBlueprint(
            trackId: 'strings',
            name: 'Strings Pad Bed',
            presetId: 'snes_synth',
            role: FunctionalRole.harmonicTexture,
            textureType: TextureType.sustained,
            colorHex: 0xFF3F51B5,
          ),
          EnsembleTrackBlueprint(
            trackId: 'brass',
            name: 'Brass Fanfare',
            presetId: 'snes_synth',
            role: FunctionalRole.counterpoint,
            colorHex: 0xFFFF9800,
          ),
          EnsembleTrackBlueprint(
            trackId: 'lead',
            name: 'Heroic Flute / Synth',
            presetId: 'snes_synth',
            role: FunctionalRole.primaryMelody,
            colorHex: 0xFF4CAF50,
          ),
        ],
        sections: const [
          EnsembleSectionBlueprint(
            name: 'Calm Intro (Atmosphere)',
            lengthBars: 8,
            chords: [
              EnsembleChordEvent(rootPitchClass: 9, quality: ChordQuality.minor, barLength: 4.0),
              EnsembleChordEvent(rootPitchClass: 5, quality: ChordQuality.major, barLength: 4.0),
            ],
            trackEnergy: {
              'drums': 0.0, // Silent drums
              'bass': 0.0, // Silent bass
              'brass': 0.0, // Silent brass
              'strings': 0.70, // Soft strings pad
              'lead': 0.80, // Solo lyrical lead
            },
            melodyBehavior: MelodyBehavior.themeA,
          ),
          EnsembleSectionBlueprint(
            name: 'Build-Up (Tension Rise)',
            lengthBars: 4,
            chords: [
              EnsembleChordEvent(rootPitchClass: 5, quality: ChordQuality.major, barLength: 2.0),
              EnsembleChordEvent(rootPitchClass: 7, quality: ChordQuality.major, barLength: 2.0),
            ],
            trackEnergy: {
              'drums': 0.60,
              'bass': 0.75,
              'strings': 0.85,
              'brass': 0.0,
              'lead': 0.0, // Lead rests for dramatic drop!
            },
            melodyBehavior: MelodyBehavior.tacet,
            transitionFill: TransitionFill.snareBuild,
          ),
          EnsembleSectionBlueprint(
            name: 'Peak Drop (Full Impact Battle)',
            lengthBars: 8,
            chords: [
              EnsembleChordEvent(rootPitchClass: 9, quality: ChordQuality.minor, barLength: 2.0),
              EnsembleChordEvent(rootPitchClass: 5, quality: ChordQuality.major, barLength: 2.0),
              EnsembleChordEvent(rootPitchClass: 0, quality: ChordQuality.major, barLength: 2.0),
              EnsembleChordEvent(rootPitchClass: 7, quality: ChordQuality.major, barLength: 2.0),
            ],
            trackEnergy: {
              'drums': 1.0,
              'bass': 0.95,
              'strings': 0.85,
              'brass': 0.90, // Fanfare active!
              'lead': 0.95,
            },
            melodyBehavior: MelodyBehavior.themeB,
          ),
          EnsembleSectionBlueprint(
            name: 'Resolution (Calm Aftermath)',
            lengthBars: 4,
            chords: [
              EnsembleChordEvent(rootPitchClass: 9, quality: ChordQuality.minor, barLength: 4.0),
            ],
            trackEnergy: {
              'drums': 0.0, // Drums cut
              'bass': 0.0,
              'brass': 0.0,
              'strings': 0.50,
              'lead': 0.60,
            },
            melodyBehavior: MelodyBehavior.variation,
          ),
        ],
      );
    }

    if (templateName.contains('Ambient') || templateName.contains('Dungeon')) {
      // 3. Ambient Ethereal Dungeon (Harp, Pad, Ocarina - NO DRUMS, NO BASS!)
      return SongStructureBlueprint(
        title: 'Crystalline Cavern',
        bpm: 68.0,
        meter: '4/4',
        rootPitchClass: 0, // C
        mode: 'dorian',
        ensemble: const [
          EnsembleTrackBlueprint(
            trackId: 'harp',
            name: 'Crystal Harp Arpeggio',
            presetId: 'felt_piano',
            role: FunctionalRole.harmonicTexture,
            textureType: TextureType.arpeggiated,
            colorHex: 0xFF00BCD4,
          ),
          EnsembleTrackBlueprint(
            trackId: 'pad',
            name: 'Ethereal Warm Pad',
            presetId: 'rhodes_epiano',
            role: FunctionalRole.harmonicTexture,
            textureType: TextureType.sustained,
            colorHex: 0xFF673AB7,
          ),
          EnsembleTrackBlueprint(
            trackId: 'ocarina',
            name: 'Solo Ocarina',
            presetId: 'snes_synth',
            role: FunctionalRole.primaryMelody,
            colorHex: 0xFF4CAF50,
          ),
        ],
        sections: const [
          EnsembleSectionBlueprint(
            name: 'Murmur (Harp & Pad)',
            lengthBars: 8,
            chords: [
              EnsembleChordEvent(rootPitchClass: 0, quality: ChordQuality.minor, barLength: 4.0),
              EnsembleChordEvent(rootPitchClass: 5, quality: ChordQuality.major, barLength: 4.0),
            ],
            trackEnergy: {'harp': 0.85, 'pad': 0.70, 'ocarina': 0.0},
            melodyBehavior: MelodyBehavior.tacet,
          ),
          EnsembleSectionBlueprint(
            name: 'Echoes (Ocarina Enters)',
            lengthBars: 8,
            chords: [
              EnsembleChordEvent(rootPitchClass: 0, quality: ChordQuality.minor, barLength: 4.0),
              EnsembleChordEvent(rootPitchClass: 5, quality: ChordQuality.major, barLength: 4.0),
            ],
            trackEnergy: {'harp': 0.80, 'pad': 0.75, 'ocarina': 0.85},
            melodyBehavior: MelodyBehavior.themeA,
          ),
        ],
      );
    }

    if (templateName.contains('C64') || templateName.contains('Tracker')) {
      // 4. C64 3-Voice Classic Tracker
      return SongStructureBlueprint(
        title: 'Galway SID Odyssey (3-Voice)',
        bpm: 134.0,
        meter: '4/4',
        rootPitchClass: 0, // C
        mode: 'minor',
        ensemble: const [
          EnsembleTrackBlueprint(
            trackId: 'noise_drums',
            name: 'SID Voice 3 (Noise Drums)',
            presetId: 'c64_sid_drum_kit',
            role: FunctionalRole.rhythm,
            colorHex: 0xFF6C5EB5,
          ),
          EnsembleTrackBlueprint(
            trackId: 'pulse_bass',
            name: 'SID Voice 1 (PWM Bass)',
            presetId: 'c64_sid_synth',
            role: FunctionalRole.foundation,
            colorHex: 0xFF5C9EAD,
          ),
          EnsembleTrackBlueprint(
            trackId: 'lead_arp',
            name: 'SID Voice 2 (Hero Lead / Arp)',
            presetId: 'c64_sid_synth',
            role: FunctionalRole.primaryMelody,
            colorHex: 0xFFE08D79,
          ),
        ],
        sections: const [
          EnsembleSectionBlueprint(
            name: 'Groove A',
            lengthBars: 8,
            chords: [
              EnsembleChordEvent(rootPitchClass: 0, quality: ChordQuality.minor, barLength: 2.0),
              EnsembleChordEvent(rootPitchClass: 8, quality: ChordQuality.major, barLength: 2.0),
              EnsembleChordEvent(rootPitchClass: 3, quality: ChordQuality.major, barLength: 2.0),
              EnsembleChordEvent(rootPitchClass: 10, quality: ChordQuality.major, barLength: 2.0),
            ],
            trackEnergy: {'noise_drums': 0.90, 'pulse_bass': 0.95, 'lead_arp': 0.90},
            melodyBehavior: MelodyBehavior.themeA,
          ),
          EnsembleSectionBlueprint(
            name: 'Lead Solo B',
            lengthBars: 8,
            chords: [
              EnsembleChordEvent(rootPitchClass: 0, quality: ChordQuality.minor, barLength: 2.0),
              EnsembleChordEvent(rootPitchClass: 5, quality: ChordQuality.minor, barLength: 2.0),
              EnsembleChordEvent(rootPitchClass: 10, quality: ChordQuality.major, barLength: 2.0),
              EnsembleChordEvent(rootPitchClass: 3, quality: ChordQuality.major, barLength: 2.0),
            ],
            trackEnergy: {'noise_drums': 0.95, 'pulse_bass': 0.90, 'lead_arp': 1.0},
            melodyBehavior: MelodyBehavior.themeB,
          ),
        ],
      );
    }

    // Default: Neo-Soul / Jazz Trio
    return SongStructureBlueprint(
      title: 'Midnight Jazz Trio',
      bpm: 88.0,
      meter: '4/4',
      rootPitchClass: 5, // F
      mode: 'major',
      ensemble: const [
        EnsembleTrackBlueprint(
          trackId: 'upright',
          name: 'Upright Bass',
          presetId: 'felt_piano',
          role: FunctionalRole.foundation,
          colorHex: 0xFF795548,
        ),
        EnsembleTrackBlueprint(
          trackId: 'rhodes',
          name: 'Fender Rhodes EPiano',
          presetId: 'rhodes_epiano',
          role: FunctionalRole.harmonicTexture,
          textureType: TextureType.stabs,
          colorHex: 0xFFFFB74D,
        ),
        EnsembleTrackBlueprint(
          trackId: 'vibes',
          name: 'Vibraphone Solo',
          presetId: 'felt_piano',
          role: FunctionalRole.primaryMelody,
          colorHex: 0xFF4DD0E1,
        ),
      ],
      sections: const [
        EnsembleSectionBlueprint(
          name: 'Trio Head A',
          lengthBars: 8,
          chords: [
            EnsembleChordEvent(rootPitchClass: 5, quality: ChordQuality.major7, barLength: 2.0),
            EnsembleChordEvent(rootPitchClass: 2, quality: ChordQuality.minor7, barLength: 2.0),
            EnsembleChordEvent(rootPitchClass: 7, quality: ChordQuality.minor7, barLength: 2.0),
            EnsembleChordEvent(rootPitchClass: 0, quality: ChordQuality.dominant7, barLength: 2.0),
          ],
          trackEnergy: {'upright': 0.90, 'rhodes': 0.85, 'vibes': 0.90},
          melodyBehavior: MelodyBehavior.themeA,
        ),
        EnsembleSectionBlueprint(
          name: 'Vibes Solo B',
          lengthBars: 8,
          chords: [
            EnsembleChordEvent(rootPitchClass: 10, quality: ChordQuality.major7, barLength: 2.0),
            EnsembleChordEvent(rootPitchClass: 9, quality: ChordQuality.minor7, barLength: 2.0),
            EnsembleChordEvent(rootPitchClass: 2, quality: ChordQuality.minor7, barLength: 2.0),
            EnsembleChordEvent(rootPitchClass: 7, quality: ChordQuality.dominant7, barLength: 2.0),
          ],
          trackEnergy: {'upright': 0.85, 'rhodes': 0.70, 'vibes': 0.98},
          melodyBehavior: MelodyBehavior.themeB,
        ),
      ],
    );
  }

  /// Project script entry point mapping params from Eatscript Action runner.
  static ProjectScriptResult generateToDawState(DawState dawState, Map<String, dynamic> params) {
    final rawTemplate = params['Template'] ?? params['template'] ?? availableTemplates[0];
    String templateStr = availableTemplates[0];

    if (rawTemplate is num) {
      final idx = rawTemplate.toInt();
      if (idx >= 0 && idx < availableTemplates.length) {
        templateStr = availableTemplates[idx];
      }
    } else if (rawTemplate != null) {
      final str = rawTemplate.toString().toLowerCase();
      for (final t in availableTemplates) {
        if (t.toLowerCase().contains(str) || str.contains(t.toLowerCase())) {
          templateStr = t;
          break;
        }
      }
    }

    final int seed = ((params['Seed'] ?? params['seed'] ?? 42) as num).toInt();
    final swing = ((params['Swing'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0);
    final humanize = ((params['Humanize'] as num?)?.toDouble() ?? 0.20).clamp(0.0, 1.0);

    final blueprint = generateOfflineBlueprint(templateStr, seed: seed);
    return renderBlueprint(
      dawState,
      blueprint,
      seed: seed,
      swing: swing,
      humanize: humanize,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  static double _assignDefaultPan(FunctionalRole role) {
    switch (role) {
      case FunctionalRole.rhythm:
      case FunctionalRole.foundation:
        return 0.0;
      case FunctionalRole.harmonicTexture:
        return -0.25;
      case FunctionalRole.counterpoint:
        return 0.30;
      case FunctionalRole.primaryMelody:
        return 0.05;
    }
  }

  static List<ChordEvent> _getChordsInRange(List<ChordEvent> chords, int startBar, int endBar) {
    return chords.where((c) {
      final cEnd = c.startBar + c.barLength;
      return cEnd > startBar && c.startBar < endBar;
    }).toList();
  }

  static ChordEvent? _getChordAtBar(List<ChordEvent> chords, int bar) {
    for (final c in chords) {
      if (bar >= c.startBar && bar < (c.startBar + c.barLength)) {
        return c;
      }
    }
    return chords.isNotEmpty ? chords.last : null;
  }
}
