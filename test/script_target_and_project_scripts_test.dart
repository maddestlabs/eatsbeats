import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/models/script_target_model.dart';
import 'package:eatsbeats/lua/lua_preset_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScriptTarget & Project-Wide Script Management Tests', () {
    late DawState dawState;

    setUp(() {
      dawState = DawState(enableMeterTimer: false);
    });

    test('getAllScriptTargets gathers all Track DSPs, MIDI FX, and Clip Scripts', () {
      final targets = dawState.getAllScriptTargets();
      expect(targets, isNotEmpty);

      // Verify track DSP targets exist for each track
      for (final track in dawState.activePattern.tracks) {
        final dspTarget = targets.where((t) => t.trackId == track.id && t.type == ScriptTargetType.trackDsp).firstOrNull;
        expect(dspTarget, isNotNull);
        expect(dspTarget!.typeBadge, equals('SYNTH DSP'));
      }

      // Add a MIDI FX to active track and verify it appears in script targets
      final track = dawState.activeTrack;
      dawState.addMidiFXInsert(track, name: 'Acid Arpeggiator', luaScriptCode: '-- Arp script\nfunction process() end');

      final updatedTargets = dawState.getAllScriptTargets();
      final mfxTarget = updatedTargets.where((t) => t.type == ScriptTargetType.midiFx && t.title.contains('Acid Arpeggiator')).firstOrNull;
      expect(mfxTarget, isNotNull);
      expect(mfxTarget!.typeBadge, equals('MIDI FX'));

      // Add a Clip with script and verify it appears in script targets
      if (track.clips.isNotEmpty) {
        final clip = track.clips.first;
        clip.luaScriptCode = '-- Clip generator\nclip:registerParam("rate", 0.1, 1.0, 0.25)\nfunction process() end';
        final clipTargets = dawState.getAllScriptTargets();
        final clipTarget = clipTargets.where((t) => t.type == ScriptTargetType.clipScript && t.secondaryId == clip.id).firstOrNull;
        expect(clipTarget, isNotNull);
        expect(clipTarget!.typeBadge, equals('CLIP SCRIPT'));
      }
    });

    test('compileScriptTarget saves snapshot in HistoryManager BEFORE compiling', () {
      final initialHistoryDepth = dawState.history.past.length;

      final track = dawState.activeTrack;
      dawState.addMidiFXInsert(track, name: 'Scale Snapper', luaScriptCode: '-- Initial code');

      final mfxTarget = dawState.getAllScriptTargets().firstWhere((t) => t.type == ScriptTargetType.midiFx && t.title.contains('Scale Snapper'));
      
      const newMfxCode = '''
-- Updated Scale Snapper Script
function process(notes, time_ctx)
  return scale_snap(notes, 0)
end
''';

      dawState.compileScriptTarget(mfxTarget, newMfxCode);

      // Verify history recorded the compile action
      expect(dawState.history.past.length, greaterThan(initialHistoryDepth));
      final lastHistory = dawState.history.current;
      expect(lastHistory, isNotNull);
      expect(lastHistory!.description, contains('Compile MIDI FX'));

      // Verify code was applied to target
      final codeInTarget = dawState.getScriptCodeForTarget(mfxTarget);
      expect(codeInTarget, equals(newMfxCode));

      // Test Undo restores state
      final undoSuccess = dawState.undo();
      expect(undoSuccess, isTrue);
    });

    test('Compiling Clip Script parses notes and updates clip parameters', () {
      final track = dawState.activeTrack;
      final clip = track.clips.isNotEmpty
          ? track.clips.first
          : TrackClip(id: 'c1', name: 'Test Clip', trackId: track.id);
      if (track.clips.isEmpty) track.clips.add(clip);

      final clipTarget = ScriptTarget(
        id: 'clip_${track.id}_${clip.id}',
        type: ScriptTargetType.clipScript,
        title: '${clip.name} (${track.name})',
        subtitle: 'Generative Clip Script',
        trackId: track.id,
        trackName: track.name,
        trackColor: track.color,
        secondaryId: clip.id,
        clipName: clip.name,
      );

      const generativeLuaCode = '''
-- Generative Clip Script
clip:registerParam("steps", 4, 16, 8)
notes = {
  { pitch = 60, start = 0.0, duration = 1.0, vel = 0.9 },
  { pitch = 64, start = 2.0, duration = 1.0, vel = 0.8 },
  { pitch = 67, start = 4.0, duration = 1.0, vel = 0.85 }
}
''';

      dawState.compileScriptTarget(clipTarget, generativeLuaCode);

      expect(dawState.compilationResult.isSuccess, isTrue);
      expect(clip.luaParams.containsKey('steps'), isTrue);
      expect(clip.notes.length, equals(3));
      expect(clip.notes.first.pitch, equals(60));
    });

    test('openScriptInEditor sets activeScriptTarget and switches activeTabIndex to 4', () {
      final targets = dawState.getAllScriptTargets();
      final target = targets.last;

      dawState.openScriptInEditor(target);

      expect(dawState.activeTabIndex, equals(4)); // Tab 4 is SCRIPTS
      expect(dawState.activeScriptTarget.id, equals(target.id));
    });
  });
}
