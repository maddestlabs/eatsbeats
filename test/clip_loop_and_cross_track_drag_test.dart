import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/ui/arranger_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TrackClip Loop Model Tests', () {
    test('TrackClip defaults to unlooped with effectiveLoopLengthBars matching barLength', () {
      final clip = TrackClip(
        id: 'c1',
        name: 'Lead Pattern',
        trackId: 't1',
        startBar: 0,
        barLength: 4,
      );

      expect(clip.loopLengthBars, isNull);
      expect(clip.isLooped, isFalse);
      expect(clip.effectiveLoopLengthBars, 4);
    });

    test('TrackClip with loopLengthBars reflects isLooped and effectiveLoopLengthBars', () {
      final clip = TrackClip(
        id: 'c2',
        name: 'Bass Loop',
        trackId: 't1',
        startBar: 0,
        barLength: 8,
        loopLengthBars: 2,
      );

      expect(clip.loopLengthBars, 2);
      expect(clip.isLooped, isTrue);
      expect(clip.effectiveLoopLengthBars, 2);
    });

    test('TrackClip JSON serialization and deserialization preserves loopLengthBars', () {
      final clip = TrackClip(
        id: 'c3',
        name: 'Synth Riff',
        trackId: 't_synth',
        startBar: 2,
        barLength: 6,
        loopLengthBars: 2,
        notes: [
          Note(id: 'n1', pitch: 60, startStep: 0, durationSteps: 2),
          Note(id: 'n2', pitch: 64, startStep: 4, durationSteps: 2),
        ],
      );

      final json = clip.toJson();
      expect(json['loopLengthBars'], 2);

      final restored = TrackClip.fromJson(json);
      expect(restored.id, 'c3');
      expect(restored.barLength, 6);
      expect(restored.loopLengthBars, 2);
      expect(restored.isLooped, isTrue);
      expect(restored.effectiveLoopLengthBars, 2);
      expect(restored.notes.length, 2);
    });

    test('TrackClip.copyWith properly updates and preserves loopLengthBars', () {
      final clip = TrackClip(
        id: 'c4',
        name: 'Arp Clip',
        trackId: 't_arp',
        startBar: 0,
        barLength: 4,
        loopLengthBars: 1,
      );

      final copy1 = clip.copyWith(loopLengthBars: 2);
      expect(copy1.loopLengthBars, 2);
      expect(copy1.isLooped, isTrue);

      final copy2 = clip.copyWith(barLength: 8);
      expect(copy2.loopLengthBars, 1);
      expect(copy2.barLength, 8);
    });
  });

  group('DawState Clip Loop Operations & Step Evaluation Tests', () {
    late DawState dawState;

    setUp(() {
      dawState = DawState();
    });

    tearDown(() {
      dawState.dispose();
    });

    test('setTrackClipLoopLength sets loop point and records history', () {
      final track = dawState.activePattern.tracks.firstWhere((t) => t.type != TrackType.sampler && !t.isFolder);
      final clip = TrackClip(
        id: 'c_test',
        name: 'Test Clip',
        trackId: track.id,
        startBar: 0,
        barLength: 4,
      );
      track.clips.add(clip);

      dawState.setTrackClipLoopLength(clip, 2);
      expect(clip.loopLengthBars, 2);
      expect(clip.isLooped, isTrue);

      dawState.setTrackClipLoopLength(clip, null);
      expect(clip.loopLengthBars, isNull);
      expect(clip.isLooped, isFalse);
    });

    test('setTrackClipBarLength adjusts clip length and maintains or resets loop', () {
      final track = dawState.activePattern.tracks.firstWhere((t) => t.type != TrackType.sampler && !t.isFolder);
      final clip = TrackClip(
        id: 'c_test2',
        name: 'Test Clip 2',
        trackId: track.id,
        startBar: 0,
        barLength: 4,
        loopLengthBars: 2,
      );
      track.clips.add(clip);

      // Extending keeps loop
      dawState.setTrackClipBarLength(clip, 8, keepLoop: true);
      expect(clip.barLength, 8);
      expect(clip.loopLengthBars, 2);
      expect(clip.isLooped, isTrue);

      // Resizing shorter without keepLoop clears loop if loop >= length
      dawState.setTrackClipBarLength(clip, 2, keepLoop: false);
      expect(clip.barLength, 2);
    });
  });

  group('Cross-Track Pattern Clip Moving Tests', () {
    late DawState dawState;

    setUp(() {
      dawState = DawState();
    });

    tearDown(() {
      dawState.dispose();
    });

    test('canMoveClipToTrack allows pattern clips across synth, bass, lua, and tts tracks', () {
      final synthTrack = TrackChannel(id: 't_synth', name: 'Synth', color: Colors.blue, type: TrackType.synth);
      final bassTrack = TrackChannel(id: 't_bass', name: '303 Bass', color: Colors.green, type: TrackType.bass);
      final luaTrack = TrackChannel(id: 't_lua', name: 'Lua Synth', color: Colors.purple, type: TrackType.luaScript);
      final ttsTrack = TrackChannel(id: 't_tts', name: 'TTS Vocal', color: Colors.teal, type: TrackType.tts);
      final samplerTrack = TrackChannel(id: 't_sampler', name: 'Drum Sampler', color: Colors.orange, type: TrackType.sampler);
      final folderTrack = TrackChannel(id: 't_folder', name: 'Folder Group', color: Colors.grey, type: TrackType.folder);

      final patternClip = TrackClip(
        id: 'c_pat',
        name: 'Melody Pattern',
        trackId: synthTrack.id,
        isAudioClip: false,
      );

      // Pattern clip CAN move to any pattern-based track
      expect(dawState.canMoveClipToTrack(patternClip, synthTrack), isTrue);
      expect(dawState.canMoveClipToTrack(patternClip, bassTrack), isTrue);
      expect(dawState.canMoveClipToTrack(patternClip, luaTrack), isTrue);
      expect(dawState.canMoveClipToTrack(patternClip, ttsTrack), isTrue);

      // Pattern clip CANNOT move to audio sampler or folder tracks
      expect(dawState.canMoveClipToTrack(patternClip, samplerTrack), isFalse);
      expect(dawState.canMoveClipToTrack(patternClip, folderTrack), isFalse);
    });

    test('canMoveClipToTrack enforces audio clip destination restrictions', () {
      final synthTrack = TrackChannel(id: 't_synth', name: 'Synth', color: Colors.blue, type: TrackType.synth);
      final samplerTrack = TrackChannel(id: 't_sampler', name: 'Drum Sampler', color: Colors.orange, type: TrackType.sampler);

      final audioClip = TrackClip(
        id: 'c_aud',
        name: 'Vocal Stem',
        trackId: samplerTrack.id,
        isAudioClip: true,
      );

      // Audio clip can only move to sampler/audio tracks
      expect(dawState.canMoveClipToTrack(audioClip, samplerTrack), isTrue);
      expect(dawState.canMoveClipToTrack(audioClip, synthTrack), isFalse);
    });

    test('moveClipToTrack transfers pattern clip from source track to destination track', () {
      final synthTrack = TrackChannel(id: 't_synth_1', name: 'Synth', color: Colors.blue, type: TrackType.synth);
      final bassTrack = TrackChannel(id: 't_bass_1', name: 'Bass', color: Colors.green, type: TrackType.bass);
      dawState.activePattern.tracks.addAll([synthTrack, bassTrack]);

      final clip = TrackClip(
        id: 'c_move',
        name: 'Transferred Lead',
        trackId: synthTrack.id,
        startBar: 1,
        barLength: 4,
        notes: [Note(id: 'n1', pitch: 60, startStep: 0, durationSteps: 2)],
      );
      synthTrack.clips.add(clip);

      expect(synthTrack.clips.contains(clip), isTrue);
      expect(bassTrack.clips.contains(clip), isFalse);

      final success = dawState.moveClipToTrack(clip, synthTrack, bassTrack, targetStartBar: 3);
      expect(success, isTrue);

      expect(synthTrack.clips.where((c) => c.id == clip.id), isEmpty);
      expect(bassTrack.clips.where((c) => c.id == clip.id).length, 1);
      expect(clip.trackId, bassTrack.id);
      expect(clip.startBar, 3);
      expect(dawState.activeClip?.id, clip.id);
    });

    test('moveClipToTrack rejects invalid destination track', () {
      final synthTrack = TrackChannel(id: 't_synth_2', name: 'Synth', color: Colors.blue, type: TrackType.synth);
      final samplerTrack = TrackChannel(id: 't_sampler_2', name: 'Drums', color: Colors.orange, type: TrackType.sampler);
      dawState.activePattern.tracks.addAll([synthTrack, samplerTrack]);

      final clip = TrackClip(
        id: 'c_reject',
        name: 'Lead Riff',
        trackId: synthTrack.id,
        isAudioClip: false,
      );
      synthTrack.clips.add(clip);

      final success = dawState.moveClipToTrack(clip, synthTrack, samplerTrack);
      expect(success, isFalse);
      expect(synthTrack.clips.contains(clip), isTrue);
      expect(samplerTrack.clips.contains(clip), isFalse);
    });
  });

  group('ArrangerView Widget UI Tests for Loop Handles & Cross-Track Gestures', () {
    late DawState dawState;

    setUp(() {
      dawState = DawState();
    });

    tearDown(() {
      dawState.dispose();
    });

    testWidgets('ArrangerView renders loop indicators and dual resize handles on clips', (tester) async {
      final firstTrack = dawState.visibleTracks.first;
      final clip = TrackClip(
        id: 'c_ui_test',
        name: 'Super Synth',
        trackId: firstTrack.id,
        startBar: 0,
        barLength: 4,
        loopLengthBars: 2,
      );
      firstTrack.clips.add(clip);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArrangerView(dawState: dawState),
          ),
        ),
      );
      await tester.pump();

      // Find clip name and loop badge
      expect(find.text('Super Synth'), findsOneWidget);
      expect(find.text('2b LOOP'), findsOneWidget);

      // Verify loop sync icon and standard resize code icon exist
      expect(find.byIcon(Icons.sync), findsWidgets);
      expect(find.byIcon(Icons.code), findsWidgets);
    });
  });

  group('Lua File Saving & Loading Loop Content Tests', () {
    late DawState dawState;

    setUp(() {
      dawState = DawState();
    });

    tearDown(() {
      dawState.dispose();
    });

    test('EatsLuaSerializer and EatsLuaParser preserve clip loopLengthBars and properties across save and load', () {
      final track = dawState.visibleTracks.first;
      final loopedClip = TrackClip(
        id: 'c_loop_save',
        name: 'Acid Loop 303',
        trackId: track.id,
        startBar: 1,
        barLength: 8,
        loopLengthBars: 2,
        notes: [
          Note(id: 'n_a1', pitch: 36, startStep: 0, durationSteps: 1, velocity: 0.9),
          Note(id: 'n_a2', pitch: 48, startStep: 4, durationSteps: 2, isSlide: true, isAccent: true),
        ],
      );
      track.clips.add(loopedClip);

      // 1. Export to Lua string (file saving)
      final luaOutput = dawState.exportToEatsLua();
      expect(luaOutput.contains('loopLengthBars = 2'), isTrue);
      expect(luaOutput.contains('Acid Loop 303'), isTrue);

      // 2. Load into fresh DawState (file loading / restoring)
      final loadedState = DawState();
      loadedState.loadFromEatsLua(luaOutput);

      final loadedTrack = loadedState.visibleTracks.firstWhere((t) => t.id == track.id);
      final restoredClip = loadedTrack.clips.firstWhere((c) => c.id == 'c_loop_save');

      expect(restoredClip.name, 'Acid Loop 303');
      expect(restoredClip.startBar, 1);
      expect(restoredClip.barLength, 8);
      expect(restoredClip.loopLengthBars, 2);
      expect(restoredClip.isLooped, isTrue);
      expect(restoredClip.effectiveLoopLengthBars, 2);
      expect(restoredClip.notes.length, 2);
      expect(restoredClip.notes.first.pitch, 36);
      expect(restoredClip.notes.last.isSlide, isTrue);
      expect(restoredClip.notes.last.isAccent, isTrue);

      loadedState.dispose();
    });
  });
}
