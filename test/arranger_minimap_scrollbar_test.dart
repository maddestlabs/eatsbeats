import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/models/chord_model.dart';
import 'package:eatsbeats/ui/arranger_view.dart';
import 'package:eatsbeats/ui/widgets/arranger_minimap_scrollbar.dart';

void main() {
  group('Arranger Refinements & Minimap Scrollbar Tests', () {
    late DawState dawState;

    setUp(() {
      dawState = DawState();
      dawState.setLoopPoints(4, 12);
    });

    testWidgets('Chord track header no longer contains "Takes" button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArrangerView(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // "Chords" button should be present
      expect(find.text('Chords'), findsOneWidget);

      // "Takes" button should NOT be present in Chord track header
      expect(find.text('Takes'), findsNothing);

      // The overview corner should be present
      expect(find.text('OVERVIEW'), findsOneWidget);
      expect(find.text('${dawState.totalTimelineBars} BARS'), findsOneWidget);

      // ArrangerMinimapScrollbar should be mounted
      expect(find.byType(ArrangerMinimapScrollbar), findsOneWidget);
    });

    testWidgets('ArrangerMinimapScrollbar renders clips, chords, and responds to tap & drag', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));

      final scrollController = ScrollController();

      // Add a test track with clip
      if (dawState.visibleTracks.isNotEmpty) {
        final track = dawState.visibleTracks.first;
        track.clips.add(TrackClip(
          id: 'test_clip_1',
          name: 'Beat A',
          trackId: track.id,
          startBar: 2,
          barLength: 4,
          patternIndex: 0,
          notes: [
            Note(id: 'n1', pitch: 60, startStep: 0, durationSteps: 2),
          ],
          lyrics: [],
          eatScriptCode: '',
          eatScriptParams: {},
          automationLanes: [],
          isAudioClip: false,
          embeddedTranscribedNotes: [],
        ));
      }

      // Add a test chord
      dawState.chordTrack.add(ChordEvent(
        id: 'chord_1',
        rootPitchClass: 0,
        quality: ChordQuality.major,
        startBar: 0,
        barLength: 4.0,
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: dawState.totalTimelineBars * 60.0,
                      height: 400,
                    ),
                  ),
                ),
                ArrangerMinimapScrollbar(
                  dawState: dawState,
                  horizontalScroll: scrollController,
                  barWidth: 60.0,
                  totalBars: dawState.totalTimelineBars,
                  height: 26.0,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ArrangerMinimapScrollbar), findsOneWidget);
      expect(scrollController.hasClients, isTrue);
      expect(scrollController.offset, equals(0.0));

      // Tap near the right side of the minimap (e.g. x = 600)
      final minimapFinder = find.byType(ArrangerMinimapScrollbar);
      final minimapTopLeft = tester.getTopLeft(minimapFinder);

      await tester.tapAt(Offset(minimapTopLeft.dx + 600, minimapTopLeft.dy + 13));
      await tester.pump();

      // The scroll offset should have jumped forward
      expect(scrollController.offset, greaterThan(0.0));

      // Drag on the minimap
      final currentOffset = scrollController.offset;
      await tester.timedDragFrom(
        Offset(minimapTopLeft.dx + 400, minimapTopLeft.dy + 13),
        const Offset(-100, 0),
        const Duration(milliseconds: 100),
      );
      await tester.pump();

      // Offset should have shifted left (smaller than before drag)
      expect(scrollController.offset, lessThan(currentOffset));
    });

    testWidgets('ArrangerMinimapScrollbar updates scrollOffset in real-time as pointer moves before release', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));

      final scrollController = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: dawState.totalTimelineBars * 60.0,
                      height: 400,
                    ),
                  ),
                ),
                ArrangerMinimapScrollbar(
                  dawState: dawState,
                  horizontalScroll: scrollController,
                  barWidth: 60.0,
                  totalBars: dawState.totalTimelineBars,
                  height: 26.0,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final minimapFinder = find.byType(ArrangerMinimapScrollbar);
      final minimapTopLeft = tester.getTopLeft(minimapFinder);

      final gesture = await tester.startGesture(Offset(minimapTopLeft.dx + 20, minimapTopLeft.dy + 13));
      await tester.pump();

      final initialOffset = scrollController.offset;

      // Move by +50 pixels without releasing the mouse button
      await gesture.moveBy(const Offset(50, 0));
      await tester.pump();

      // Verify that offset shifted DURING the move before pointer up!
      expect(scrollController.offset, greaterThan(initialOffset));

      // Move further by +50 pixels
      final midOffset = scrollController.offset;
      await gesture.moveBy(const Offset(50, 0));
      await tester.pump();
      expect(scrollController.offset, greaterThan(midOffset));

      // Finally release pointer
      await gesture.up();
      await tester.pump();
    });
  });
}

