import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_wren_daw/main.dart';
import 'package:mobile_wren_daw/models/daw_state.dart';
import 'package:mobile_wren_daw/models/track_model.dart';
import 'package:mobile_wren_daw/ui/arranger_view.dart';

void main() {
  testWidgets('DAW smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const WrenDawApp());
    expect(find.byType(WrenDawApp), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Pattern Clip Selection & Note Preview Test', (WidgetTester tester) async {
    final dawState = DawState(enableMeterTimer: false);
    final track = dawState.activeTrack;
    expect(track.clips, isNotEmpty);

    final clip = track.clips.first;
    dawState.selectClip(clip);
    expect(dawState.activeClip?.id, equals(clip.id));

    // Add a note to track
    dawState.addNote(
      track,
      Note(
        id: 'test_n1',
        pitch: 64,
        startStep: 2.0,
        durationSteps: 2.0,
      ),
    );
    expect(clip.notes.any((n) => n.id == 'test_n1'), isTrue);

    // Pump ArrangerView widget
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArrangerView(dawState: dawState),
        ),
      ),
    );

    expect(find.byType(ArrangerView), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);

    dawState.dispose();
    await tester.pumpWidget(const SizedBox());
  });
}
