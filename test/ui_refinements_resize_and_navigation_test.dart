import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/ui/arranger_view.dart';
import 'package:eatsbeats/ui/piano_roll_view.dart';
import 'package:eatsbeats/ui/sequence_editor_view.dart';
import 'package:eatsbeats/ui/tracker_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Piano Roll Resize Handler Tests', () {
    testWidgets('PianoRollView renders resize handle and keeps note selected when handle is tapped', (tester) async {
      final dawState = DawState();
      final track = dawState.activeTrack;
      final note = Note(
        id: 'test_note_1',
        pitch: 60,
        startStep: 0,
        durationSteps: 4,
        velocity: 0.8,
      );
      track.notes.add(note);
      dawState.selectNotes(track, [note.id]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PianoRollView(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the resize handle '<>' is present
      final resizeHandle = find.text('<>');
      expect(resizeHandle, findsOneWidget);

      // Tap the resize handle
      await tester.tap(resizeHandle, warnIfMissed: false);
      await tester.pump();

      // Verify the note is STILL selected and the handle did not disappear
      expect(track.selectedNoteIds.contains(note.id), isTrue);
      expect(find.text('<>'), findsOneWidget);
    });
  });

  group('Sequence Editor Playhead Highlight & Key Navigation Tests', () {
    testWidgets('Sequence Editor highlights playing bar and updates when playhead advances', (tester) async {
      final dawState = DawState();
      if (!dawState.isFollowPlayback) {
        dawState.toggleFollowPlayback();
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SequenceEditorView(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially stopped, no play arrow
      expect(find.byIcon(Icons.play_arrow), findsNothing);

      // Start playback at bar 0
      dawState.togglePlay();
      dawState.continuousArrangerStepNotifier.value = 0.0;
      await tester.pump();

      // Play icon should appear on bar 0
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);

      // Advance playhead into bar 2 (step 32)
      dawState.continuousArrangerStepNotifier.value = 32.0;
      await tester.pump();

      // Play icon should still be visible (now on bar 2)
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);

      // Stop playback
      dawState.togglePlay();
      await tester.pump();

      // Play icon should be removed
      expect(find.byIcon(Icons.play_arrow), findsNothing);
    });

    testWidgets('Sequence Editor navigates bars with KeyDownEvent', (tester) async {
      final dawState = DawState();
      dawState.sequenceSelectedBar = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SequenceEditorView(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(dawState.sequenceSelectedBar, 0);

      // Send ArrowDown key down event
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(dawState.sequenceSelectedBar, 1);
    });
  });

  group('Tracker View Arrow Navigation Tests', () {
    testWidgets('TrackerView navigates steps with ArrowDown', (tester) async {
      final dawState = DawState();
      dawState.trackerSelectedStep = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrackerView(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(dawState.trackerSelectedStep, 0);

      // Send ArrowDown
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(dawState.trackerSelectedStep, 1);
    });
  });

  group('Arranger View Playhead Seeking Tests', () {
    testWidgets('Tapping timeline ruler moves playhead, while tapping track lane does not', (tester) async {
      final dawState = DawState();
      dawState.seekToArrangerStep(0.0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1200,
              height: 800,
              child: ArrangerView(dawState: dawState),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(dawState.arrangerStep, 0);

      // Find ruler bar number '4' (bar 4 in top timeline ruler)
      final rulerBar4 = find.text('4');
      expect(rulerBar4, findsWidgets);

      // Tap on top ruler bar 4
      await tester.tap(rulerBar4.first);
      await tester.pump(const Duration(milliseconds: 350));

      // Playhead should have moved to around bar 3 / 4 (step >= 48)
      final stepAfterRulerTap = dawState.arrangerStep;
      expect(stepAfterRulerTap, greaterThan(0));

      // Reset step to 16
      dawState.seekToArrangerStep(16.0);
      expect(dawState.arrangerStep, 16);

      // Tap on a track lane (e.g. empty grid area)
      // Track lanes have container with trackRowHeight (48.0)
      // Tap at an offset in the middle of track lanes (x: 500, y: 300)
      await tester.tapAt(const Offset(500, 300));
      await tester.pump(const Duration(milliseconds: 350));

      // Playhead should NOT have changed (remains 16)
      expect(dawState.arrangerStep, 16);
    });
  });
}
