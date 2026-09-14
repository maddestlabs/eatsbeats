import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/audio/procgen/ensemble_blueprint.dart';
import 'package:eatsbeats/audio/procgen/procedural_ensemble_engine.dart';
import 'package:eatsbeats/audio/procgen/song_archetype.dart';
import 'package:eatsbeats/audio/procgen/song_archetype_registry.dart';
import 'package:eatsbeats/models/chord_model.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Exemplar-Driven Lead & Ensemble Rendering Tests', () {
    late String exemplarContent;

    setUpAll(() {
      final file = File('assets/archetypes/fantasy_rpg_midnight_bites.eat');
      expect(file.existsSync(), isTrue);
      exemplarContent = file.readAsStringSync();
    });

    setUp(() {
      SongArchetypeRegistry.clear();
      SongArchetypeRegistry.registerFromEatString(exemplarContent);
    });

    test('Exemplar parses vibraphone with primaryMelody and real note phrases', () {
      final archetype = SongArchetypeRegistry.getById('fantasy_rpg_midnight_bites');
      expect(archetype, isNotNull);
      expect(archetype!.hasLeadTrack, isTrue);

      final lead = archetype.leadProfile;
      expect(lead, isNotNull);
      expect(lead!.name, contains('Vibraphone'));
      expect(lead.role, equals(FunctionalRole.primaryMelody));
      expect(lead.phrases.isNotEmpty, isTrue);

      // Verify authentic exemplar phrases: singing sustained notes & grace runs
      final sustained = lead.phrases.where((p) => p.durationSteps >= 16.0).toList();
      expect(sustained.isNotEmpty, isTrue, reason: 'Exemplar must feature long singing tones');

      final graceRuns = lead.phrases.where((p) => p.durationSteps <= 1.0).toList();
      expect(graceRuns.isNotEmpty, isTrue, reason: 'Exemplar must feature rapid cascading grace notes');
    });

    test('Renders lead melody from exemplar phrasing instead of STMN procedural scalar motif', () {
      final dawState = DawState(enableMeterTimer: false);

      final blueprint = SongStructureBlueprint(
        archetypeId: 'fantasy_rpg_midnight_bites',
        title: 'Midnight Adventure',
        bpm: 120.0,
        meter: '4/4',
        rootPitchClass: 0, // C
        mode: 'major',
        ensemble: [
          const EnsembleTrackBlueprint(
            trackId: 'lead_vibe',
            name: 'Orchestral Vibraphone',
            presetId: 'vibraphone',
            role: FunctionalRole.primaryMelody,
            colorHex: 0xff21f4e8,
          ),
          const EnsembleTrackBlueprint(
            trackId: 'gtr_spanish',
            name: 'Spanish Classical Guitar',
            presetId: 'spanish_guitar',
            role: FunctionalRole.harmonicTexture,
            colorHex: 0xffff8c00,
          ),
          const EnsembleTrackBlueprint(
            trackId: 'bass_acoustic',
            name: 'Acoustic Bass Guitar',
            presetId: 'acoustic_bass',
            role: FunctionalRole.foundation,
            colorHex: 0xffff8c00,
          ),
        ],
        sections: [
          EnsembleSectionBlueprint(
            name: 'Theme A',
            lengthBars: 4,
            melodyBehavior: MelodyBehavior.themeA,
            melodyStyle: MelodyStyle.lyrical,
            trackEnergy: {'lead_vibe': 0.85, 'gtr_spanish': 0.80, 'bass_acoustic': 0.85},
            chords: const [
              EnsembleChordEvent(rootPitchClass: 0, quality: ChordQuality.major, barLength: 2.0),
              EnsembleChordEvent(rootPitchClass: 7, quality: ChordQuality.major, barLength: 2.0),
            ],
          ),
          EnsembleSectionBlueprint(
            name: 'Climax / Run',
            lengthBars: 4,
            melodyBehavior: MelodyBehavior.themeB,
            melodyStyle: MelodyStyle.cascadingRun,
            trackEnergy: {'lead_vibe': 0.95, 'gtr_spanish': 0.80, 'bass_acoustic': 0.90},
            chords: const [
              EnsembleChordEvent(rootPitchClass: 9, quality: ChordQuality.minor, barLength: 2.0),
              EnsembleChordEvent(rootPitchClass: 5, quality: ChordQuality.major, barLength: 2.0),
            ],
          ),
        ],
      );

      final result = ProceduralEnsembleEngine.renderBlueprint(dawState, blueprint, seed: 12345);
      expect(result.isSuccess, isTrue);

      final leadTrack = dawState.activePattern.tracks.firstWhere((t) => t.name.contains('Vibraphone'));
      expect(leadTrack.notes.isNotEmpty, isTrue);

      // Verify Theme A contains singing sustained notes from exemplar (> 12 steps)
      final sustainedNotes = leadTrack.notes.where((n) => n.durationSteps >= 12.0).toList();
      expect(sustainedNotes.isNotEmpty, isTrue, reason: 'Exemplar lead must adopt sustained singing tones');

      // Verify Climax section contains rapid cascading grace runs (duration <= 2.0 steps)
      final graceNotes = leadTrack.notes.where((n) => n.durationSteps <= 2.0).toList();
      expect(graceNotes.isNotEmpty, isTrue, reason: 'Exemplar lead must adopt cascading grace notes in climax');
    });

    test('Strict Lead Omission: Omits lead track if archetype has no lead and no custom motif requested', () {
      // Register an ambient soundscape archetype with NO primaryMelody lead track
      final ambientNoLead = SongArchetype(
        archetypeId: 'ambient_soundscape_no_lead',
        category: 'Ambient',
        title: 'Deep Ethereal Caves',
        tags: ['ambient', 'drone'],
        tracks: [
          const ArchetypeTrackProfile(
            trackId: 't_pad',
            name: 'Crystal Pad',
            presetId: 'felt_piano',
            role: FunctionalRole.harmonicTexture,
            phrases: [
              ArchetypeNotePhrase(relativeStep: 0, durationSteps: 32, pitch: 60, pitchInterval: 0),
            ],
          ),
          const ArchetypeTrackProfile(
            trackId: 't_drone',
            name: 'Sub Drone',
            presetId: 'acoustic_bass',
            role: FunctionalRole.foundation,
            phrases: [
              ArchetypeNotePhrase(relativeStep: 0, durationSteps: 32, pitch: 36, pitchInterval: 0),
            ],
          ),
        ],
      );
      SongArchetypeRegistry.registerArchetype(ambientNoLead);
      expect(ambientNoLead.hasLeadTrack, isFalse);

      final dawState = DawState(enableMeterTimer: false);

      // Blueprint attempting to include a primaryMelody track without custom motif
      final blueprint = SongStructureBlueprint(
        archetypeId: 'ambient_soundscape_no_lead',
        title: 'Cave Exploration',
        bpm: 80.0,
        meter: '4/4',
        rootPitchClass: 0,
        mode: 'minor',
        ensemble: [
          const EnsembleTrackBlueprint(
            trackId: 'unwanted_lead',
            name: 'Solo Lead',
            presetId: 'flute',
            role: FunctionalRole.primaryMelody,
            colorHex: 0xff00ffff,
          ),
          const EnsembleTrackBlueprint(
            trackId: 'pad_track',
            name: 'Crystal Pad',
            presetId: 'felt_piano',
            role: FunctionalRole.harmonicTexture,
            colorHex: 0xff8888ff,
          ),
        ],
        sections: [
          EnsembleSectionBlueprint(
            name: 'Drone Section',
            lengthBars: 4,
            melodyBehavior: MelodyBehavior.themeA,
            melodyMotif: null, // No explicit user custom motif requested
            trackEnergy: {'unwanted_lead': 0.8, 'pad_track': 0.8},
            chords: const [
              EnsembleChordEvent(rootPitchClass: 0, quality: ChordQuality.minor, barLength: 4.0),
            ],
          ),
        ],
      );

      ProceduralEnsembleEngine.renderBlueprint(dawState, blueprint, seed: 999);

      final leadTrack = dawState.activePattern.tracks.firstWhere((t) => t.name == 'Solo Lead');
      // Lead track notes must be completely omitted/empty!
      expect(leadTrack.notes.isEmpty, isTrue, reason: 'When archetype has no lead, lead track notes must be omitted');
    });

    test('Foundation and harmonic texture tracks adopt exemplar phrasing timings', () {
      final dawState = DawState(enableMeterTimer: false);

      final blueprint = SongStructureBlueprint(
        archetypeId: 'fantasy_rpg_midnight_bites',
        title: 'Tavern Arrival',
        bpm: 120.0,
        meter: '4/4',
        rootPitchClass: 0,
        mode: 'major',
        ensemble: [
          const EnsembleTrackBlueprint(
            trackId: 'gtr_spanish',
            name: 'Spanish Classical Guitar',
            presetId: 'spanish_guitar',
            role: FunctionalRole.harmonicTexture,
            colorHex: 0xffff8c00,
          ),
          const EnsembleTrackBlueprint(
            trackId: 'bass_acoustic',
            name: 'Acoustic Bass Guitar',
            presetId: 'acoustic_bass',
            role: FunctionalRole.foundation,
            colorHex: 0xffff8c00,
          ),
        ],
        sections: [
          EnsembleSectionBlueprint(
            name: 'Theme A',
            lengthBars: 4,
            melodyBehavior: MelodyBehavior.tacet,
            trackEnergy: {'gtr_spanish': 0.85, 'bass_acoustic': 0.85},
            chords: const [
              EnsembleChordEvent(rootPitchClass: 0, quality: ChordQuality.major, barLength: 2.0),
              EnsembleChordEvent(rootPitchClass: 7, quality: ChordQuality.major, barLength: 2.0),
            ],
          ),
        ],
      );

      ProceduralEnsembleEngine.renderBlueprint(dawState, blueprint, seed: 777);

      final bassTrack = dawState.activePattern.tracks.firstWhere((t) => t.name.contains('Acoustic Bass'));
      expect(bassTrack.notes.isNotEmpty, isTrue);

      final guitarTrack = dawState.activePattern.tracks.firstWhere((t) => t.name.contains('Spanish Classical Guitar'));
      expect(guitarTrack.notes.isNotEmpty, isTrue);
    });
  });
}
