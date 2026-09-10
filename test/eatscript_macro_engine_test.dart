import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/chord_model.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/eatscript/eat_script_library.dart';
import 'package:eatsbeats/eatscript/eat_script_engine.dart';
import 'package:eatsbeats/eatscript/project_script_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Eatscript Macro & DAW Automation API Tests', () {
    late DawState dawState;

    setUp(() {
      dawState = DawState(enableMeterTimer: false);
      for (final p in dawState.patterns) {
        p.tracks.clear();
      }
      dawState.chordTrack.clear();
    });

    test('Category consolidation: EatScriptCategory.macro returns all macros and legacy scripts', () {
      final macros = LuaScriptLibrary.getScriptsByCategory(LuaScriptCategory.macro);
      expect(macros, isNotEmpty);
      expect(macros.any((m) => m.id == 'action_global_transpose'), isTrue);
      expect(macros.any((m) => m.id == 'action_procedural_song'), isTrue);
      expect(macros.any((m) => m.id == 'action_stmn_procedural_piano'), isTrue);

      final transpose = macros.firstWhere((m) => m.id == 'action_global_transpose');
      expect(transpose.isMacro, isTrue);
      expect(transpose.isProjectAction, isTrue);
    });

    test('Eatscript Macro can inspect and alter DAW transport (tempo and key)', () {
      final script = LuaScriptDef(
        id: 'test_macro_transport',
        name: 'Transport Macro',
        category: LuaScriptCategory.macro,
        description: 'Sets tempo and key',
        code: '''
def init():
    return {
        "TargetBpm": eat.param("TargetBpm", 60, 200, 142, step=1),
    }

def run(project, params):
    project.set_tempo(params.get("TargetBpm", 142))
    project.set_key("F# Minor")
    project.log("Transport updated successfully")
''',
      );

      final result = dawState.runProjectScript(script, params: {'TargetBpm': 148});
      expect(result.isSuccess, isTrue);
      expect(dawState.bpm, equals(148.0));
      expect(dawState.songKey, equals('F# Minor'));
    });

    test('Eatscript Macro can add tracks, create clips, and populate notes via project API', () {
      final script = LuaScriptDef(
        id: 'test_macro_track_builder',
        name: 'Track & Clip Builder Macro',
        category: LuaScriptCategory.macro,
        description: 'Creates tracks and populates clips with notes',
        code: '''
def run(project, params):
    # Add a new synth track
    lead = project.add_track("Cyber Lead", "synth")
    lead.set_volume(0.80)
    lead.set_pan(-0.25)
    
    # Create an 8-bar clip
    clip = lead.create_clip(0, 8, "Intro Riff")
    
    # Add notes
    clip.add_note(60, 0.0, 1.0, 0.9)
    clip.add_note(63, 1.0, 1.0, 0.85)
    clip.add_note(67, 2.0, 2.0, 0.95)
    
    # Add chord progression to song
    project.add_chord(0, 4, "C", "minor")
    project.add_chord(4, 4, "G", "minor")
    
    project.checkpoint("Generated Cyber Lead & Chords")
''',
      );

      final result = dawState.runProjectScript(script);
      expect(result.isSuccess, isTrue);

      expect(dawState.activePattern.tracks.length, equals(1));
      final track = dawState.activePattern.tracks.first;
      expect(track.name, equals('Cyber Lead'));
      expect(track.volume, closeTo(0.80, 0.001));
      expect(track.pan, closeTo(-0.25, 0.001));

      expect(track.clips.length, equals(1));
      final clip = track.clips.first;
      expect(clip.name, equals('Intro Riff'));
      expect(clip.barLength, equals(8));
      expect(clip.notes.length, equals(3));
      expect(clip.notes[0].pitch, equals(60));
      expect(clip.notes[1].pitch, equals(63));
      expect(clip.notes[2].pitch, equals(67));

      expect(dawState.chordTrack.length, equals(2));
      expect(dawState.chordTrack[0].rootPitchClass, equals(0)); // C
      expect(dawState.chordTrack[1].rootPitchClass, equals(7)); // G
    });

    test('Forward-compatible automation authoring from Eatscript Macro', () {
      final script = LuaScriptDef(
        id: 'test_macro_automation',
        name: 'Automation Lane Generator Macro',
        category: LuaScriptCategory.macro,
        description: 'Creates automation points on tracks and clips',
        code: '''
def run(project, params):
    tr = project.add_track("Pad", "synth")
    
    # 1. Track-level volume automation (fade in over 16 steps)
    tr.add_automation_point("track.volume", 0.0, 0.1, "exponential")
    tr.add_automation_point("track.volume", 16.0, 0.9, "linear")
    
    # 2. Clip-level cutoff filter sweep
    clip = tr.create_clip(0, 4, "Atmosphere")
    clip.add_automation_point("filter.cutoff", 0.0, 400.0, "linear")
    clip.add_automation_point("filter.cutoff", 32.0, 12000.0, "exponential")
''',
      );

      final result = dawState.runProjectScript(script);
      expect(result.isSuccess, isTrue);

      final track = dawState.activePattern.tracks.first;
      expect(track.automationLanes.isNotEmpty, isTrue);
      final volLane = track.automationLanes.firstWhere((l) => l.target.id == 'track.volume');
      expect(volLane.points.length, equals(2));
      expect(volLane.points[0].step, equals(0.0));
      expect(volLane.points[0].value, closeTo(0.1, 0.001));
      expect(volLane.points[1].step, equals(16.0));
      expect(volLane.points[1].value, closeTo(0.9, 0.001));

      final clip = track.clips.first;
      expect(clip.automationLanes.isNotEmpty, isTrue);
      final cutoffLane = clip.automationLanes.firstWhere((l) => l.target.id == 'filter.cutoff');
      expect(cutoffLane.points.length, equals(2));
      expect(cutoffLane.points[0].value, closeTo(400.0, 0.001));
      expect(cutoffLane.points[1].value, closeTo(12000.0, 0.001));
    });

    test('Undo history properly rolls back macro modifications', () {
      dawState.setSongKey('C Major');
      dawState.setBpm(120.0);

      final script = LuaScriptDef(
        id: 'test_macro_rollback',
        name: 'Rollback Test Macro',
        category: LuaScriptCategory.macro,
        description: 'Tests undo rollback',
        code: '''
def run(project, params):
    project.set_tempo(160)
    project.set_key("E Minor")
    project.add_track("Temp Track", "synth")
''',
      );

      dawState.runProjectScript(script);
      expect(dawState.bpm, equals(160.0));
      expect(dawState.songKey, equals('E Minor'));
      expect(dawState.activePattern.tracks.length, equals(1));

      // Undo
      expect(dawState.undo(), isTrue);
      expect(dawState.bpm, equals(120.0));
      expect(dawState.songKey, equals('C Major'));
      expect(dawState.activePattern.tracks.length, equals(0));
    });
  });
}
