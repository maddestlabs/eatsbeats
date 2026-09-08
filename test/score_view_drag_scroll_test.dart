import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/ui/score/score_view.dart';

void main() {
  testWidgets('ScoreView horizontal drag navigation does not reset or glitch when follow playback is enabled', (WidgetTester tester) async {
    final dawState = DawState(enableMeterTimer: false);
    final track = dawState.activeTrack;
    track.name = 'SNES Synth';

    // Clear existing notes and add user's exact 7-event sequence
    track.notes.clear();
    final sampleNotes = [
      Note(id: 's1', pitch: 60, startStep: 0.0, durationSteps: 16.0, velocity: 0.85), // C4
      Note(id: 's2', pitch: 65, startStep: 0.0, durationSteps: 16.0, velocity: 0.85), // F4
      Note(id: 's3', pitch: 69, startStep: 0.0, durationSteps: 16.0, velocity: 0.85), // A4
      Note(id: 's4', pitch: 62, startStep: 16.0, durationSteps: 16.0, velocity: 0.85), // D4
      Note(id: 's5', pitch: 69, startStep: 16.0, durationSteps: 16.0, velocity: 0.85), // A4
      Note(id: 's6', pitch: 71, startStep: 16.0, durationSteps: 16.0, velocity: 0.85), // B4
      Note(id: 's7', pitch: 72, startStep: 26.0, durationSteps: 4.0, velocity: 0.85), // C5
    ];
    for (final n in sampleNotes) {
      track.notes.add(n);
    }

    // Default follow playback is enabled, and playback is stopped
    expect(dawState.isFollowPlayback, isTrue);
    expect(dawState.isPlaying, isFalse);

    // Set a defined test viewport size
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

    // Verify ScoreView is rendered
    expect(find.byType(ScoreView), findsOneWidget);
    final scrollableFinder = find.byType(SingleChildScrollView);
    expect(scrollableFinder, findsOneWidget);

    final SingleChildScrollView scrollWidget = tester.widget(scrollableFinder);
    final scrollController = scrollWidget.controller!;
    expect(scrollController.offset, equals(0.0));

    // Drag horizontally on empty canvas area (start at x: 400, y: 150 which is above the notes)
    // Drag to the left by 200px (from 400 to 200) -> should pan scroll forward by 200px
    final gesture = await tester.startGesture(const Offset(400, 150));
    await tester.pump(const Duration(milliseconds: 20));

    // Move pointer beyond 5px threshold to engage canvas panning mode
    await gesture.moveTo(const Offset(350, 150));
    await tester.pump(const Duration(milliseconds: 16));

    await gesture.moveTo(const Offset(200, 150));
    await tester.pump(const Duration(milliseconds: 16));

    // Offset should have scrolled forward to around 200.0
    expect(scrollController.offset, closeTo(200.0, 5.0));

    // Release gesture
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Crucial check: Before the fix, the postFrameCallback would reset the scroll back to 0.0!
    // After our fix, the scroll offset MUST remain at 200.0 without snapping back or oscillating.
    expect(scrollController.offset, closeTo(200.0, 5.0));

    // Pump further frames to ensure no deferred callbacks reset it
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(scrollController.offset, closeTo(200.0, 5.0));
  });

  testWidgets('ScoreView trackpad / pointer signal horizontal scroll works', (WidgetTester tester) async {
    final dawState = DawState(enableMeterTimer: false);
    final track = dawState.activeTrack;
    track.notes.add(Note(id: 's1', pitch: 60, startStep: 0.0, durationSteps: 16.0));

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

    final scrollableFinder = find.byType(SingleChildScrollView);
    final SingleChildScrollView scrollWidget = tester.widget(scrollableFinder);
    final scrollController = scrollWidget.controller!;
    expect(scrollController.offset, equals(0.0));

    // Send horizontal pointer scroll event
    await tester.sendEventToBinding(
      const PointerScrollEvent(
        position: Offset(400, 300),
        scrollDelta: Offset(120, 0),
      ),
    );
    await tester.pumpAndSettle();

    expect(scrollController.offset, closeTo(120.0, 2.0));
  });
}
