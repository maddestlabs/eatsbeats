import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/theme/eats_theme.dart';
import 'package:eatsbeats/ui/arranger_view.dart';
import 'package:eatsbeats/ui/mixer_view.dart';
import 'package:eatsbeats/ui/widgets/arranger_context_inspector.dart';
import 'package:eatsbeats/ui/widgets/dynamic_instrument_gui_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Track Properties Playback Accessibility Tests', () {
    testWidgets('During playback, activeClip is NOT mutated by background listeners', (WidgetTester tester) async {
      final dawState = DawState(enableMeterTimer: false);
      final track = dawState.activeTrack;
      expect(track.clips, isNotEmpty);

      // Deselect clip to start with clear track-level focus
      dawState.selectClip(null);
      expect(dawState.activeClip, isNull);

      // Start playback
      dawState.togglePlay();
      expect(dawState.isPlaying, isTrue);

      // Simulate step advancement across multiple bars
      for (int step = 0; step < 64; step += 4) {
        dawState.seekToArrangerStep(step.toDouble());
        expect(dawState.activeClip, isNull, reason: 'Playback advancement must not mutate activeClip selection');
      }

      dawState.stop();
      dawState.dispose();
    });

    testWidgets('Track Properties sidebar stays on Track Properties during active playback in ArrangerView', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dawState = DawState(enableMeterTimer: false);

      await tester.pumpWidget(
        MaterialApp(
          theme: EatsTheme.themeData,
          home: Scaffold(
            body: ArrangerView(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open the Track Properties pullout drawer by tapping the pull tab
      final pullTabFinder = find.byTooltip('Open Properties Panel');
      expect(pullTabFinder, findsOneWidget);
      await tester.tap(pullTabFinder);
      await tester.pumpAndSettle();

      // Inspector must be open and showing Track Properties
      expect(find.byType(ArrangerContextInspector), findsOneWidget);
      expect(find.text('TRACK PROPERTIES'), findsOneWidget);
      expect(find.text('SELECTED CLIP'), findsNothing);

      // Verify Instrument controls / action buttons are present in the sidebar
      expect(find.byType(DynamicInstrumentGuiWidget), findsOneWidget);
      expect(find.text('CHANGE INSTRUMENT'), findsOneWidget);

      // Start playback
      dawState.togglePlay();
      await tester.pump();
      expect(dawState.isPlaying, isTrue);

      // Advance playhead through timeline across different clips
      dawState.seekToArrangerStep(16.0); // Bar 1
      await tester.pump();
      dawState.seekToArrangerStep(32.0); // Bar 2
      await tester.pump();
      dawState.seekToArrangerStep(48.0); // Bar 3
      await tester.pump();

      // Track Properties MUST remain visible and MUST NOT have reverted to Clip Properties
      expect(find.byType(ArrangerContextInspector), findsOneWidget);
      expect(find.text('TRACK PROPERTIES'), findsOneWidget);
      expect(find.byType(DynamicInstrumentGuiWidget), findsOneWidget);
      expect(find.text('CHANGE INSTRUMENT'), findsOneWidget);
      expect(find.text('SELECTED CLIP'), findsNothing);

      dawState.stop();
      dawState.dispose();
    });

    testWidgets('Inspector allows switching between TRACK and CLIP tabs when a clip is selected', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dawState = DawState(enableMeterTimer: false);
      final track = dawState.activeTrack;
      final clip = track.clips.first;

      // Select clip explicitly
      dawState.selectClip(clip);
      expect(dawState.activeClip, equals(clip));

      await tester.pumpWidget(
        MaterialApp(
          theme: EatsTheme.themeData,
          home: Scaffold(
            body: SizedBox(
              width: 350,
              height: 800,
              child: ArrangerContextInspector(
                dawState: dawState,
                onClose: () {},
                initialTab: InspectorTab.track,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both TRACK and CLIP tabs must be rendered
      final trackTabFinder = find.text('TRACK');
      final clipTabFinder = find.textContaining('CLIP (');
      expect(trackTabFinder, findsOneWidget);
      expect(clipTabFinder, findsOneWidget);

      // Since initialTab was track, Track Properties & Instrument card are visible
      expect(find.text('TRACK PROPERTIES'), findsOneWidget);
      expect(find.byType(DynamicInstrumentGuiWidget), findsOneWidget);
      expect(find.text('CHANGE INSTRUMENT'), findsOneWidget);

      // Switch to CLIP tab
      await tester.tap(clipTabFinder);
      await tester.pumpAndSettle();

      // Clip section is now visible
      expect(find.text('SELECTED CLIP'), findsOneWidget);
      expect(find.text('TRACK PROPERTIES'), findsNothing);

      // Switch back to TRACK tab: Track Properties and Instrument card are restored immediately
      await tester.tap(trackTabFinder);
      await tester.pumpAndSettle();

      expect(find.text('TRACK PROPERTIES'), findsOneWidget);
      expect(find.byType(DynamicInstrumentGuiWidget), findsOneWidget);
      expect(find.text('CHANGE INSTRUMENT'), findsOneWidget);
      expect(find.text('SELECTED CLIP'), findsNothing);

      dawState.dispose();
    });

    testWidgets('Track Properties pullout in MixerView stays on Track Properties during playback', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dawState = DawState(enableMeterTimer: false);
      dawState.activeTabIndex = 3; // Mixer tab

      await tester.pumpWidget(
        MaterialApp(
          theme: EatsTheme.themeData,
          home: Scaffold(
            body: MixerView(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Sidebar starts expanded in MixerView
      expect(find.byType(ArrangerContextInspector), findsOneWidget);
      expect(find.text('TRACK PROPERTIES'), findsOneWidget);
      expect(find.text('SELECTED CLIP'), findsNothing);

      // Start audio playback
      dawState.togglePlay();
      await tester.pump();
      expect(dawState.isPlaying, isTrue);

      // Advance through arranger steps
      dawState.seekToArrangerStep(24.0);
      await tester.pump();
      dawState.seekToArrangerStep(40.0);
      await tester.pump();

      // Inspector remains on Track Properties with Channel EQ & Instrument
      expect(find.text('TRACK PROPERTIES'), findsOneWidget);
      expect(find.text('CHANNEL EQ'), findsOneWidget);
      expect(find.byType(DynamicInstrumentGuiWidget), findsOneWidget);
      expect(find.text('SELECTED CLIP'), findsNothing);

      dawState.stop();
      dawState.dispose();
    });
  });
}
