import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/ui/score/score_view.dart';
import 'package:eatsbeats/ui/widgets/compact_value_dialog.dart';

void main() {
  group('UI Improvements Verification', () {
    testWidgets('ScoreView clicking a note selects it and keeps it selected on pointer up', (WidgetTester tester) async {
      final dawState = DawState(enableMeterTimer: false);
      final track = dawState.activeTrack;
      track.name = 'Lead Synth';
      track.notes.clear();

      final note = Note(id: 'note_test_1', pitch: 60, startStep: 0.0, durationSteps: 4.0, velocity: 0.85);
      track.notes.add(note);

      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        dawState.dispose();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScoreView(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(track.selectedNoteIds.isEmpty, isTrue);

      // Find the ScoreView canvas SingleChildScrollView top-left
      final scrollFinder = find.byType(SingleChildScrollView);
      final scrollPos = tester.getTopLeft(scrollFinder);
      // Tap directly on the Middle C notehead (offset (92, 333) relative to canvas)
      final noteTapPos = scrollPos + const Offset(92, 333);

      final gesture = await tester.startGesture(noteTapPos);
      await tester.pump(const Duration(milliseconds: 30));

      // Check note was selected on pointer down
      expect(track.selectedNoteIds.contains('note_test_1'), isTrue);

      // Release pointer (pointer up)
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Verify the note REMAINS selected after pointer up (bug previously caused it to be cleared!)
      expect(track.selectedNoteIds.contains('note_test_1'), isTrue);
      expect(track.hasSelectedNotes, isTrue);
    });

    test('addClipToTrack creates a new blank clip and does not duplicate first clip notes', () {
      final dawState = DawState(enableMeterTimer: false);
      final track = dawState.activeTrack;

      // First clip with notes
      track.clips.clear();
      final clip1 = TrackClip(
        id: 'c1',
        name: 'First Clip',
        trackId: track.id,
        startBar: 0,
        barLength: 2,
        notes: [
          Note(id: 'n1', pitch: 60, startStep: 0.0, durationSteps: 4.0),
          Note(id: 'n2', pitch: 64, startStep: 4.0, durationSteps: 4.0),
        ],
      );
      track.clips.add(clip1);
      dawState.selectClip(clip1);
      expect(track.notes.length, equals(2));

      // Add new clip at bar 2 (double-click blank area equivalent)
      dawState.addClipToTrack(track, 2);

      expect(track.clips.length, equals(2));
      final newClip = track.clips.last;
      expect(newClip.startBar, equals(2));
      // Crucial: New clip must be BLANK!
      expect(newClip.notes, isEmpty);
      // Active track notes must be blank for the new clip!
      expect(track.notes, isEmpty);
      // First clip notes must remain untouched!
      expect(clip1.notes.length, equals(2));

      // Selecting first clip loads its notes back
      dawState.selectClip(clip1);
      expect(track.notes.length, equals(2));

      // Selecting second clip loads its blank notes
      dawState.selectClip(newClip);
      expect(track.notes, isEmpty);

      dawState.dispose();
    });

    test('loadFromEatsLua resets playhead and arranger position to 0', () {
      final dawState = DawState(enableMeterTimer: false);

      // Seek playhead away from 0
      dawState.seekToArrangerStep(48.0);
      expect(dawState.arrangerStep, equals(48));
      expect(dawState.continuousArrangerStepNotifier.value, equals(48.0));

      // Load a song project
      const sampleSong = '''
-- Eatsbeats Project
BPM = 120.0
SongKey = "C"
KeyMinor = false
MasterVolume = 0.8
PatternCount = 1
BarCount = 8
Swing = 0.0

-- Tracks
Track 1: "Synth Lead" [synth] Vol: 0.80 Pan: 0.00 Mute: false Solo: false Color: #00F0FF
  Clip 1: "Lead P00" Bar: 1 Len: 2 Pattern: 0
    Note: C4 0.0 2.0 0.80
''';
      dawState.loadFromEatsLua(sampleSong);

      // Verify playhead is reset to 0
      expect(dawState.arrangerStep, equals(0));
      expect(dawState.continuousArrangerStepNotifier.value, equals(0.0));
      expect(dawState.currentStep, equals(0));
      expect(dawState.currentBar, equals(0));

      dawState.dispose();
    });

    testWidgets('CompactValueEditDialog allows typing percentage directly e.g. 50%', (WidgetTester tester) async {
      String? submittedValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showCompactValueEditDialog(
                    context: context,
                    title: 'Resonance',
                    initialValue: '0.40',
                    minValue: 0.0,
                    maxValue: 2.0,
                    onSubmit: (val) => submittedValue = val,
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Enter 50% into the text field
      final textFieldFinder = find.byType(TextField);
      await tester.enterText(textFieldFinder, '50%');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // 50% of range [0.0, 2.0] is 1.0
      expect(submittedValue, equals('1'));
    });

    testWidgets('CompactValueEditDialog allows toggling % chip and entering percentage', (WidgetTester tester) async {
      String? submittedValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showCompactValueEditDialog(
                    context: context,
                    title: 'Filter Drive',
                    initialValue: '1.0',
                    minValue: 0.0,
                    maxValue: 4.0,
                    onSubmit: (val) => submittedValue = val,
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Tap '%' toggle chip
      final percentChipFinder = find.text('%');
      expect(percentChipFinder, findsOneWidget);
      await tester.tap(percentChipFinder);
      await tester.pumpAndSettle();

      // Initial 1.0 in range [0.0, 4.0] should convert to 25%
      final textFieldFinder = find.byType(TextField);
      final TextField textField = tester.widget(textFieldFinder);
      expect(textField.controller?.text, equals('25'));

      // Enter 75%
      await tester.enterText(textFieldFinder, '75');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // 75% of range [0.0, 4.0] is 3.0
      expect(submittedValue, equals('3'));
    });
  });
}
