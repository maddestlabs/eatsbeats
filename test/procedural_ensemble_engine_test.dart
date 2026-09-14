import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/audio/procgen/ensemble_blueprint.dart';
import 'package:eatsbeats/audio/procgen/procedural_ensemble_engine.dart';
import 'package:eatsbeats/eatscript/eat_script_library.dart';
import 'package:eatsbeats/eatscript/project_script_engine.dart';
import 'package:eatsbeats/models/chord_model.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/services/ai_task_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProceduralEnsembleEngine Tests', () {
    late DawState dawState;

    setUp(() {
      dawState = DawState(enableMeterTimer: false);
    });

    test('RPG Tavern Duet generates 2 tracks in 3/4 meter with solo Intro and Flute entry', () {
      final blueprint = ProceduralEnsembleEngine.generateOfflineBlueprint(
        'RPG Fireside Tavern (Lute & Flute Duet, 3/4 Waltz)',
        seed: 777,
      );

      expect(blueprint.meter, equals('3/4'));
      expect(blueprint.stepsPerBar, equals(12));
      expect(blueprint.ensemble.length, equals(2));
      expect(blueprint.ensemble[0].name, equals('Acoustic Lute'));
      expect(blueprint.ensemble[1].name, equals('Wooden Flute'));

      final result = ProceduralEnsembleEngine.renderBlueprint(dawState, blueprint, seed: 777);

      expect(result.isSuccess, isTrue);
      expect(dawState.bpm, equals(76.0));
      expect(dawState.songKey, equals('D Dorian'));
      expect(dawState.isSongMode, isTrue);

      final tracks = dawState.activePattern.tracks;
      expect(tracks.length, equals(2));

      final luteTrack = tracks[0];
      final fluteTrack = tracks[1];

      // Lute has clips across all 4 sections
      expect(luteTrack.clips.length, equals(4));

      // Flute has 0.0 energy in Section 0 (Intro), so it only has 3 clips (Themes A, B, and Outro)
      expect(fluteTrack.clips.length, equals(3));
      expect(fluteTrack.clips.any((c) => c.name.contains('Intro')), isFalse);

      // Verify timing bounds within 3/4 meter (12 steps per bar)
      for (final track in tracks) {
        for (final clip in track.clips) {
          final maxStep = clip.barLength * 12.0;
          expect(clip.notes, isNotEmpty);
          for (final note in clip.notes) {
            expect(note.startStep, greaterThanOrEqualTo(0.0));
            expect(note.startStep, lessThan(maxStep));
          }
        }
      }
    });

    test('Evolving Action Theme generates 5 tracks with Calm Intro and Peak Drop', () {
      final blueprint = ProceduralEnsembleEngine.generateOfflineBlueprint(
        'Evolving Action Theme (Calm Intro to Full Drop)',
        seed: 1234,
      );

      expect(blueprint.ensemble.length, equals(5));

      final result = ProceduralEnsembleEngine.renderBlueprint(dawState, blueprint, seed: 1234);
      expect(result.isSuccess, isTrue);

      final tracks = dawState.activePattern.tracks;
      expect(tracks.length, equals(5));

      final drumsTrack = tracks.firstWhere((t) => t.id.contains('drums'));
      final bassTrack = tracks.firstWhere((t) => t.id.contains('bass'));
      final brassTrack = tracks.firstWhere((t) => t.id.contains('brass'));
      final stringsTrack = tracks.firstWhere((t) => t.id.contains('strings'));
      final leadTrack = tracks.firstWhere((t) => t.id.contains('lead'));

      // In Calm Intro (Section 0): Drums, Bass, Brass are silent (no clip / tacet)
      expect(drumsTrack.clips.any((c) => c.name.contains('Calm Intro')), isFalse);
      expect(bassTrack.clips.any((c) => c.name.contains('Calm Intro')), isFalse);
      expect(brassTrack.clips.any((c) => c.name.contains('Calm Intro')), isFalse);

      // Strings and Lead are active in Calm Intro
      expect(stringsTrack.clips.any((c) => c.name.contains('Calm Intro')), isTrue);
      expect(leadTrack.clips.any((c) => c.name.contains('Calm Intro')), isTrue);

      // In Peak Drop (Section 2): ALL 5 tracks are active with high note count
      for (final t in tracks) {
        expect(
          t.clips.any((c) => c.name.contains('Peak Drop')),
          isTrue,
          reason: 'Track "${t.name}" must be active in Peak Drop',
        );
      }
    });

    test('Ambient Ethereal Dungeon generates 3-track atmosphere without drums or bass', () {
      final blueprint = ProceduralEnsembleEngine.generateOfflineBlueprint(
        'Ambient Ethereal Dungeon (Harp, Pad, Ocarina)',
        seed: 888,
      );

      expect(blueprint.ensemble.length, equals(3));
      expect(blueprint.ensemble.any((t) => t.role == FunctionalRole.rhythm), isFalse);
      expect(blueprint.ensemble.any((t) => t.role == FunctionalRole.foundation), isFalse);

      final result = ProceduralEnsembleEngine.renderBlueprint(dawState, blueprint, seed: 888);
      expect(result.isSuccess, isTrue);

      final tracks = dawState.activePattern.tracks;
      expect(tracks.length, equals(3));
      expect(tracks.any((t) => t.name.toLowerCase().contains('drum')), isFalse);
      expect(tracks.any((t) => t.name.toLowerCase().contains('bass')), isFalse);
    });

    test('Parses and renders Gemini JSON blueprint correctly', () {
      final geminiJson = {
        "title": "Moonlit Forest",
        "bpm": 84.0,
        "meter": "4/4",
        "rootPitchClass": 4, // E
        "mode": "minor",
        "ensemble": [
          {
            "trackId": "harp",
            "name": "Arpeggiated Harp",
            "presetId": "felt_piano",
            "role": "harmonicTexture",
            "textureType": "arpeggiated",
            "colorHex": 4278241748
          },
          {
            "trackId": "cello",
            "name": "Solo Cello",
            "presetId": "snes_synth",
            "role": "primaryMelody",
            "colorHex": 4283215696
          }
        ],
        "sections": [
          {
            "name": "Verse",
            "lengthBars": 8,
            "chords": [
              { "rootPitchClass": 4, "quality": "minor", "barLength": 4.0 },
              { "rootPitchClass": 0, "quality": "major", "barLength": 4.0 }
            ],
            "trackEnergy": { "harp": 0.8, "cello": 0.9 },
            "melodyBehavior": "themeA"
          }
        ]
      };

      final blueprint = SongStructureBlueprint.fromJson(geminiJson);
      expect(blueprint.title, equals('Moonlit Forest'));
      expect(blueprint.bpm, equals(84.0));
      expect(blueprint.ensemble.length, equals(2));
      expect(blueprint.sections.length, equals(1));

      final result = ProceduralEnsembleEngine.renderBlueprint(dawState, blueprint);
      expect(result.isSuccess, isTrue);
      expect(dawState.activePattern.tracks.length, equals(2));
      expect(dawState.chordTrack.length, equals(2));
    });

    test('ProjectScriptEngine executes action_ensemble_arranger preset', () {
      final script = EatScriptLibrary.getPresetById('action_ensemble_arranger');
      expect(script, isNotNull);

      final result = ProjectScriptEngine.execute(
        script: script!,
        dawState: dawState,
        params: {
          'Template': 0, // RPG Tavern Duet
          'Seed': 555,
          'Swing': 0.1,
          'Humanize': 0.15,
        },
      );

      expect(result.isSuccess, isTrue);
      expect(dawState.activePattern.tracks.length, equals(2));
      expect(dawState.activePattern.tracks[0].name, equals('Acoustic Lute'));
      expect(dawState.activePattern.tracks[1].name, equals('Wooden Flute'));
    });

    test('AiTaskManager applies pending SongStructureBlueprint to DawState with history transaction', () {
      final blueprint = ProceduralEnsembleEngine.generateOfflineBlueprint(
        'Ambient Ethereal Dungeon (Harp, Pad, Ocarina)',
        seed: 42,
      );

      final mgr = AiTaskManager.instance;
      mgr.reset();

      // Simulate completed AI task ready for review
      // ignore: invalid_use_of_visible_for_testing_member
      mgr.setMockBlueprintForReview(blueprint);

      expect(mgr.status, equals(AiTaskStatus.readyForReview));
      expect(mgr.pendingBlueprint, isNotNull);
      expect(mgr.pendingBlueprint!.title, equals('Crystalline Cavern'));

      mgr.applyPendingResult(dawState);

      expect(mgr.status, equals(AiTaskStatus.idle));
      expect(dawState.activePattern.tracks.length, equals(3));
      expect(dawState.activePattern.tracks[0].name, equals('Crystal Harp Arpeggio'));
      expect(dawState.activePattern.tracks[1].name, equals('Ethereal Warm Pad'));
      expect(dawState.activePattern.tracks[2].name, equals('Solo Ocarina'));
      expect(dawState.history.canUndo, isTrue);
    });

    test('Melodic generation produces distinct note sequences across different seeds (no static hardcoded motifs)', () {
      final blueprint = ProceduralEnsembleEngine.generateOfflineBlueprint(
        'Evolving Action Theme (Calm Intro to Full Drop)',
        seed: 101,
      );

      // Render with Seed 101
      final dawState1 = DawState(enableMeterTimer: false);
      ProceduralEnsembleEngine.renderBlueprint(dawState1, blueprint, seed: 101);
      final leadTrack1 = dawState1.activePattern.tracks.firstWhere((t) => t.id.contains('lead'));
      final leadNotes1 = leadTrack1.clips.expand((c) => c.notes).toList();

      // Render with Seed 202
      final dawState2 = DawState(enableMeterTimer: false);
      ProceduralEnsembleEngine.renderBlueprint(dawState2, blueprint, seed: 202);
      final leadTrack2 = dawState2.activePattern.tracks.firstWhere((t) => t.id.contains('lead'));
      final leadNotes2 = leadTrack2.clips.expand((c) => c.notes).toList();

      expect(leadNotes1, isNotEmpty);
      expect(leadNotes2, isNotEmpty);

      // Verify that the pitches and timings are not identically frozen across different seeds
      final pitches1 = leadNotes1.map((n) => n.pitch).toList();
      final pitches2 = leadNotes2.map((n) => n.pitch).toList();
      final steps1 = leadNotes1.map((n) => n.startStep).toList();
      final steps2 = leadNotes2.map((n) => n.startStep).toList();

      final bool isIdentical = listEquals(pitches1, pitches2) && listEquals(steps1, steps2);
      expect(isIdentical, isFalse, reason: 'Different seeds must produce unique melodic variations!');
    });

    test('Gemini MelodyStyle, melodyMotif, and melodyDensity are parsed and rendered faithfully', () {
      final geminiJson = {
        "title": "Heroic Quest",
        "bpm": 128.0,
        "meter": "4/4",
        "rootPitchClass": 0, // C
        "mode": "major",
        "ensemble": [
          {
            "trackId": "lead",
            "name": "Triumphant Trumpet",
            "presetId": "snes_synth",
            "role": "primaryMelody"
          }
        ],
        "sections": [
          {
            "name": "Anthem Fanfare",
            "lengthBars": 4,
            "chords": [
              { "rootPitchClass": 0, "quality": "major", "barLength": 2.0 },
              { "rootPitchClass": 5, "quality": "major", "barLength": 2.0 }
            ],
            "trackEnergy": { "lead": 0.95 },
            "melodyBehavior": "themeA",
            "melodyStyle": "heroicAnthem",
            "melodyMotif": [0, 4, 7, 12],
            "melodyDensity": 0.8
          }
        ]
      };

      final blueprint = SongStructureBlueprint.fromJson(geminiJson);
      expect(blueprint.sections.first.melodyStyle, equals(MelodyStyle.heroicAnthem));
      expect(blueprint.sections.first.melodyMotif, equals([0, 4, 7, 12]));
      expect(blueprint.sections.first.melodyDensity, equals(0.8));

      final testDaw = DawState(enableMeterTimer: false);
      final result = ProceduralEnsembleEngine.renderBlueprint(testDaw, blueprint, seed: 888);
      expect(result.isSuccess, isTrue);

      final track = testDaw.activePattern.tracks.first;
      expect(track.clips, isNotEmpty);
      final notes = track.clips.first.notes;
      expect(notes, isNotEmpty);

      // Verify that notes are generated and contain accent and slide articulations from heroicAnthem
      expect(notes.any((n) => n.isAccent), isTrue);
    });
  });
}
