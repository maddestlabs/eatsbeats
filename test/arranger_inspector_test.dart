import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_wren_daw/models/chord_model.dart';
import 'package:mobile_wren_daw/models/daw_state.dart';
import 'package:mobile_wren_daw/models/track_model.dart';
import 'package:mobile_wren_daw/ui/arranger_view.dart';
import 'package:mobile_wren_daw/ui/widgets/arranger_context_inspector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ArrangerContextInspector & Track Selection Tests', () {
    test('Deselects clip when switching active track', () {
      final dawState = DawState(enableMeterTimer: false);
      final track1 = dawState.activePattern.tracks[0];
      final track2 = dawState.activePattern.tracks.length > 1
          ? dawState.activePattern.tracks[1]
          : TrackChannel(id: 't2', name: 'Bass', color: Colors.amber, type: TrackType.synth);
      if (!dawState.activePattern.tracks.contains(track2)) {
        dawState.activePattern.tracks.add(track2);
      }

      // Select clip on track 1
      dawState.activeTrackIndex = 0;
      dawState.selectClip(track1.clips.first);
      expect(dawState.activeClip, isNotNull);
      expect(dawState.activeClip!.id, equals(track1.clips.first.id));

      // Switch active track index to track 2
      dawState.activeTrackIndex = 1;
      expect(dawState.activeClip, isNull);

      dawState.dispose();
    });

    testWidgets('Renders unified Track and streamlined Clip properties without tabs or timing/note sections', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dawState = DawState(enableMeterTimer: false);
      final track = dawState.activeTrack;
      final clip = track.clips.first;
      dawState.selectClip(clip);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 900,
              child: ArrangerContextInspector(
                dawState: dawState,
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      // Verify unified header title
      expect(find.text('PROPERTIES'), findsOneWidget);

      // Verify track properties are rendered
      expect(find.text('TRACK PROPERTIES'), findsOneWidget);
      expect(find.text('TRACK NAME'), findsOneWidget);
      expect(find.text('TRACK COLOR'), findsOneWidget);
      expect(find.text(track.name), findsOneWidget);

      // Verify clip properties are rendered below track properties
      expect(find.text('SELECTED CLIP'), findsOneWidget);
      expect(find.text('CLIP TITLE'), findsOneWidget);
      expect(find.text(clip.name), findsOneWidget);

      // Verify TIMING & POSITION and NOTE CONTENT sections have been removed
      expect(find.text('TIMING & POSITION'), findsNothing);
      expect(find.text('NOTE CONTENT'), findsNothing);

      dawState.dispose();
    });

    testWidgets('Renames track and clip through editable title fields', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dawState = DawState(enableMeterTimer: false);
      final track = dawState.activeTrack;
      final clip = track.clips.first;
      dawState.selectClip(clip);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 900,
              child: ArrangerContextInspector(
                dawState: dawState,
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      // Tap Rename track button (first edit icon)
      final editIcons = find.byIcon(Icons.edit);
      expect(editIcons, findsNWidgets(2)); // Track edit and Clip edit
      await tester.tap(editIcons.first);
      await tester.pumpAndSettle();

      // Enter new track name
      final trackTextField = find.byType(TextField).first;
      await tester.enterText(trackTextField, 'Lead Arp 80s');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(track.name, equals('Lead Arp 80s'));

      // Tap Rename clip button
      final clipEditIcon = find.byTooltip('Rename Clip');
      await tester.tap(clipEditIcon);
      await tester.pumpAndSettle();

      final clipTextField = find.byType(TextField).first;
      await tester.enterText(clipTextField, 'Chorus Synth Pattern');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(clip.name, equals('Chorus Synth Pattern'));

      dawState.dispose();
    });

    testWidgets('Duplicates clip through inspector button', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dawState = DawState(enableMeterTimer: false);
      final track = dawState.activeTrack;
      final initialClipCount = track.clips.length;
      final clip = track.clips.first;
      dawState.selectClip(clip);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 900,
              child: ArrangerContextInspector(
                dawState: dawState,
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      // Scroll to DUPLICATE button and tap
      final duplicateBtn = find.widgetWithText(OutlinedButton, 'DUPLICATE');
      await tester.ensureVisible(duplicateBtn);
      await tester.pumpAndSettle();
      await tester.tap(duplicateBtn);
      await tester.pumpAndSettle();

      // Verify track has one more clip
      expect(track.clips.length, equals(initialClipCount + 1));

      dawState.dispose();
    });

    testWidgets('Deletes clip through inspector button', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dawState = DawState(enableMeterTimer: false);
      final track = dawState.activeTrack;
      final clip = track.clips.first;
      dawState.selectClip(clip);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 900,
              child: ArrangerContextInspector(
                dawState: dawState,
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      // Scroll to DELETE button and tap
      final deleteBtn = find.widgetWithText(OutlinedButton, 'DELETE');
      await tester.ensureVisible(deleteBtn);
      await tester.pumpAndSettle();
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      // Verify clip was removed from track
      expect(track.clips.any((c) => c.id == clip.id), isFalse);

      dawState.dispose();
    });

    testWidgets('ArrangerView renders chord blocks with drag indicators and resize handles', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dawState = DawState(enableMeterTimer: false);
      dawState.addOrUpdateChord(ChordEvent(
        id: 'c1',
        startBar: 0,
        barLength: 2.0,
        rootPitchClass: 0, // C
        quality: ChordQuality.major,
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArrangerView(dawState: dawState),
          ),
        ),
      );

      expect(find.text('C'), findsWidgets);
      expect(find.byIcon(Icons.drag_indicator), findsWidgets);

      dawState.dispose();
    });

    test('DawState moveTrackUp and moveTrackDown reorders tracks and updates activeTrackIndex', () {
      final dawState = DawState(enableMeterTimer: false);
      final track1 = dawState.activePattern.tracks[0];
      final track2 = TrackChannel(id: 't2', name: 'Bass Line', color: Colors.purple, type: TrackType.synth);
      final track3 = TrackChannel(id: 't3', name: 'Drum Kit', color: Colors.orange, type: TrackType.sampler);
      dawState.activePattern.tracks.add(track2);
      dawState.activePattern.tracks.add(track3);

      final t2Index = dawState.activePattern.tracks.indexOf(track2);
      expect(t2Index, greaterThan(0));

      // Move track 2 down
      dawState.moveTrackDown(track2);
      expect(dawState.activePattern.tracks.indexOf(track2), equals(t2Index + 1));
      expect(dawState.activeTrackIndex, equals(t2Index + 1));

      // Move track 2 up
      dawState.moveTrackUp(track2);
      expect(dawState.activePattern.tracks.indexOf(track2), equals(t2Index));
      expect(dawState.activeTrackIndex, equals(t2Index));

      dawState.dispose();
    });

    testWidgets('ArrangerContextInspector renders track order up and down buttons', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dawState = DawState(enableMeterTimer: false);
      final track2 = TrackChannel(id: 't2', name: 'Bass Line', color: Colors.purple, type: TrackType.synth);
      dawState.activePattern.tracks.add(track2);
      dawState.activeTrackIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 900,
              child: ArrangerContextInspector(
                dawState: dawState,
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      // Verify track order header and icons in TRACK ACTIONS card
      expect(find.text('ORDER'), findsOneWidget);
      expect(find.byTooltip('Move Track Up'), findsOneWidget);
      expect(find.byTooltip('Move Track Down'), findsOneWidget);

      // Tap Move Track Down button
      final moveDownBtn = find.byTooltip('Move Track Down');
      await tester.tap(moveDownBtn);
      await tester.pumpAndSettle();

      expect(dawState.activePattern.tracks[1].name, equals(dawState.activeTrack.name));

      dawState.dispose();
    });

    testWidgets('ArrangerView allows Track Properties to be toggled independently when Project Browser is open', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dawState = DawState(enableMeterTimer: false);
      expect(dawState.isBrowserOpen, isFalse);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArrangerView(dawState: dawState),
          ),
        ),
      );

      // Open project browser
      dawState.toggleBrowser();
      await tester.pumpAndSettle();
      expect(dawState.isBrowserOpen, isTrue);

      // Inspector should NOT be forced open simply because browser is open
      expect(find.byType(ArrangerContextInspector), findsNothing);

      // Toggle INFO inspector button on
      final infoBtn = find.text('INFO');
      expect(infoBtn, findsOneWidget);
      await tester.tap(infoBtn);
      await tester.pumpAndSettle();

      // Now inspector is open alongside the open browser
      expect(find.byType(ArrangerContextInspector), findsOneWidget);
      expect(find.text('TRACK PROPERTIES'), findsOneWidget);

      // Close inspector via close button on ArrangerContextInspector
      final closeBtn = find.byTooltip('Close Inspector');
      expect(closeBtn, findsOneWidget);
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();

      // Inspector closes while browser remains open
      expect(find.byType(ArrangerContextInspector), findsNothing);
      expect(dawState.isBrowserOpen, isTrue);

      dawState.dispose();
    });
  });
}
