import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/ui/edit_view.dart';
import 'package:eatsbeats/ui/piano_roll_view.dart';
import 'package:eatsbeats/ui/score/score_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Ghost Notes (Background Tracks) State & Behavior', () {
    test('DawState handles ghost notes opacity and enable state', () {
      final dawState = DawState();
      expect(dawState.ghostNotesOpacity, equals(0.0));
      expect(dawState.isGhostNotesEnabled, isFalse);

      bool notified = false;
      dawState.addListener(() {
        notified = true;
      });

      dawState.setGhostNotesOpacity(0.35);
      expect(notified, isTrue);
      expect(dawState.ghostNotesOpacity, closeTo(0.35, 0.001));
      expect(dawState.isGhostNotesEnabled, isTrue);

      // Clamping test
      dawState.setGhostNotesOpacity(1.5);
      expect(dawState.ghostNotesOpacity, equals(1.0));

      dawState.setGhostNotesOpacity(-0.5);
      expect(dawState.ghostNotesOpacity, equals(0.0));
      expect(dawState.isGhostNotesEnabled, isFalse);
    });

    testWidgets('EditView displays Ghost Notes control in Piano Roll and Score views', (tester) async {
      final dawState = DawState();
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditView(dawState: dawState),
          ),
        ),
      );
      await tester.pump();

      // By default in EditView, if active view is Piano Roll, GHOST control is visible
      expect(find.text('GHOST'), findsOneWidget);
      expect(find.text('OFF'), findsOneWidget);

      // Set opacity via DawState
      dawState.setGhostNotesOpacity(0.40);
      await tester.pump();
      expect(find.text('40%'), findsOneWidget);

      // Tap the GHOST toggle button to turn OFF
      await tester.tap(find.text('GHOST'));
      await tester.pump();
      expect(dawState.ghostNotesOpacity, equals(0.0));
      expect(find.text('OFF'), findsOneWidget);

      // Tap again to toggle back to last opacity (40%)
      await tester.tap(find.text('GHOST'));
      await tester.pump();
      expect(dawState.ghostNotesOpacity, closeTo(0.40, 0.01));
      expect(find.text('40%'), findsOneWidget);

      // Switch to Tracker View: GHOST control should disappear
      dawState.setTrackActiveView(dawState.activeTrack, MusicViewType.tracker);
      await tester.pump();
      expect(find.text('GHOST'), findsNothing);

      // Switch to Score View: GHOST control should reappear
      dawState.setTrackActiveView(dawState.activeTrack, MusicViewType.score);
      await tester.pump();
      expect(find.text('GHOST'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('PianoRollView and ScoreView render smoothly with ghost notes enabled', (tester) async {
      final dawState = DawState();
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      // Add a second track with some notes to serve as background ghost notes
      if (dawState.tracks.length < 2) {
        final newTrack = TrackChannel(
          id: 'bg_track_1',
          name: 'Background Strings',
          color: Colors.amber,
          type: TrackType.synth,
        );
        dawState.activePattern.tracks.add(newTrack);
      }
      final bgTrack = dawState.tracks.firstWhere((t) => t.id != dawState.activeTrack.id);
      bgTrack.notes.add(Note(
        id: 'bg_note_1',
        pitch: 64,
        startStep: 0,
        durationSteps: 4,
      ));
      bgTrack.notes.add(Note(
        id: 'bg_note_2',
        pitch: 67,
        startStep: 4,
        durationSteps: 4,
      ));

      // Enable ghost notes
      dawState.setGhostNotesOpacity(0.5);

      // Render PianoRollView
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PianoRollView(dawState: dawState),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(PianoRollView), findsOneWidget);

      // Render ScoreView
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScoreView(dawState: dawState),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(ScoreView), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });
  });
}
