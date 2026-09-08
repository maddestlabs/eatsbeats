import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/ui/edit_view.dart';
import 'package:eatsbeats/ui/piano_roll_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Track Switching in Follow Mode & Multi-Clip Stability', () {
    test('DawState switches tracks during playback and syncs clips/notes without breaking follow', () {
      final dawState = DawState();
      dawState.setFollowPlayback(true);

      // Ensure at least 2 tracks exist
      expect(dawState.activePattern.tracks.length, greaterThanOrEqualTo(2));
      final track0 = dawState.activePattern.tracks[0];
      final track1 = dawState.activePattern.tracks[1];

      // Give track 0 a clip at bar 0
      final clip0 = TrackClip(
        id: 'clip_t0',
        name: 'Track 0 Clip',
        trackId: track0.id,
        startBar: 0,
        barLength: 4,
        notes: [Note(id: 'n0', pitch: 60, startStep: 0, durationSteps: 2)],
        luaScriptCode: '',
        luaParams: {},
      );
      track0.clips = [clip0];

      // Give track 1 a clip at bar 4
      final clip1 = TrackClip(
        id: 'clip_t1',
        name: 'Track 1 Clip',
        trackId: track1.id,
        startBar: 4,
        barLength: 4,
        notes: [Note(id: 'n1', pitch: 64, startStep: 0, durationSteps: 2)],
        luaScriptCode: '',
        luaParams: {},
      );
      track1.clips = [clip1];

      // Select track 0 and sync clip0
      dawState.activeTrackIndex = 1;
      dawState.activeTrackIndex = 0;
      expect(dawState.activeTrackClip.id, equals('clip_t0'));

      // Simulate live playback past bar 4 (step 70, which is bar 4, step 6)
      dawState.seekToArrangerStep(70.0);

      // Switch to track 1 while playing
      dawState.activeTrackIndex = 1;
      expect(dawState.activeTrackIndex, equals(1));
      // activeTrackClip must automatically pick clip1 spanning bar 4
      expect(dawState.activeTrackClip.id, equals('clip_t1'));

      // Modify activeTrack.notes on track 1
      dawState.activeTrack.notes.add(Note(id: 'n1_added', pitch: 67, startStep: 4, durationSteps: 1));

      // Switch back to track 0: changes to track 1 notes must have been persisted to clip1
      dawState.activeTrackIndex = 0;
      expect(clip1.notes.any((n) => n.id == 'n1_added'), isTrue);
    });

    testWidgets('PianoRollView remains stable during track switch with follow playback and automation drawer', (tester) async {
      final dawState = DawState();
      dawState.setFollowPlayback(true);
      dawState.activeTabIndex = 1; // Edit tab

      await tester.binding.setSurfaceSize(const Size(1200, 800));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditView(dawState: dawState),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(PianoRollView), findsOneWidget);

      // Simulate active playback
      dawState.togglePlay();
      expect(dawState.isPlaying, isTrue);

      // Advance playhead smoothly
      dawState.continuousArrangerStepNotifier.value = 16.0;
      await tester.pump(const Duration(milliseconds: 50));

      // Switch active track index while playing in follow mode
      dawState.activeTrackIndex = 1;
      await tester.pump(const Duration(milliseconds: 50));

      // Ensure PianoRollView is still mounted and rendered without exceptions
      expect(find.byType(PianoRollView), findsOneWidget);

      // Advance playhead further
      dawState.continuousArrangerStepNotifier.value = 32.0;
      await tester.pump(const Duration(milliseconds: 50));

      // Switch back to track 0
      dawState.activeTrackIndex = 0;
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(PianoRollView), findsOneWidget);

      dawState.stop();
      await tester.pump();
    });
  });
}
