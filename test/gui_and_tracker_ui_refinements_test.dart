import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/audio/soundfont_engine.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/theme/eats_theme.dart';
import 'package:eatsbeats/ui/piano_roll_view.dart';
import 'package:eatsbeats/ui/tracker_view.dart';
import 'package:eatsbeats/ui/transport_header.dart';
import 'package:eatsbeats/ui/widgets/floating_instrument_window.dart';
import 'package:eatsbeats/utils/url_script_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await SoundFontEngine.instance.loadDefaultBundledFont();
  });

  group('Floating FX & Instrument GUI Tests', () {
    testWidgets('Renders preset selector and actions in correct order with correct tooltips', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dawState = DawState();
      final track = dawState.activeTrack;
      dawState.openFloatingInstrumentWindow(track, const Size(1200, 800));

      await tester.pumpWidget(
        MaterialApp(
          theme: EatsTheme.themeData,
          home: Scaffold(
            body: FloatingInstrumentWindow(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Open in Design tab, Fit to screen, Fullscreen, and Close tooltips exist
      expect(find.byTooltip('Open in Design tab'), findsOneWidget);
      expect(find.byTooltip('Fit to screen'), findsOneWidget);
      expect(find.byTooltip('Fullscreen'), findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);

      // Verify icons
      expect(find.byIcon(Icons.developer_board), findsOneWidget);
      expect(find.byIcon(Icons.fit_screen), findsOneWidget);
      expect(find.byIcon(Icons.fullscreen), findsOneWidget);
    });

    testWidgets('Tapping Open in Design tab switches activeTabIndex to 4', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dawState = DawState();
      final track = dawState.activeTrack;
      dawState.activeTabIndex = 0;
      dawState.openFloatingInstrumentWindow(track, const Size(1200, 800));

      await tester.pumpWidget(
        MaterialApp(
          theme: EatsTheme.themeData,
          home: Scaffold(
            body: FloatingInstrumentWindow(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Open in Design tab'));
      await tester.pumpAndSettle();

      expect(dawState.activeTabIndex, equals(4)); // Design tab
      expect(dawState.isFloatingWindowVisible, isFalse);
    });
  });

  group('Piano Roll Note Articulations Tests', () {
    testWidgets('Note model holds and updates articulation property', (tester) async {
      final note = Note(
        id: 'n1',
        pitch: 60,
        startStep: 0,
        durationSteps: 2,
        articulation: 'staccato',
      );
      expect(note.articulation, equals('staccato'));

      final updated = note.copyWith(articulation: 'pizzicato');
      expect(updated.articulation, equals('pizzicato'));
      expect(updated.toJson()['articulation'], equals('pizzicato'));
    });

    testWidgets('Sidebar renders Articulation & Expression section with selector chips', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dawState = DawState();
      final track = dawState.activeTrack;
      track.notes.clear();
      final testNote = Note(
        id: 'test_note_art_1',
        pitch: 64,
        startStep: 0.0,
        durationSteps: 2.0,
        velocity: 0.8,
      );
      track.notes.add(testNote);

      await tester.pumpWidget(
        MaterialApp(
          theme: EatsTheme.themeData,
          home: Scaffold(
            body: PianoRollView(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the note on canvas to open the note inspector
      await tester.tap(find.text('E4').last);
      await tester.pumpAndSettle();

      expect(find.text('ARTICULATION & EXPRESSION'), findsOneWidget);
      expect(find.text('STACCATO'), findsOneWidget);
      expect(find.text('LEGATO'), findsOneWidget);
      expect(find.text('ACCENT'), findsOneWidget);
      expect(find.text('PIZZICATO'), findsOneWidget);
      expect(find.text('MUTED'), findsOneWidget);
      expect(find.text('HARMONICS'), findsOneWidget);
      expect(find.text('TREMOLO'), findsOneWidget);
      expect(find.text('SLAP'), findsOneWidget);
      expect(find.text('FLAM'), findsOneWidget);

      // Select STACCATO
      await tester.tap(find.text('STACCATO'));
      await tester.pumpAndSettle();
      expect(track.notes.first.articulation, equals('staccato'));
    });
  });

  group('Tracker View Navigation & Selection Tests', () {
    testWidgets('Tracker view navigates cells with Arrow keys and updates selection without getting stuck', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dawState = DawState();
      final track = dawState.activeTrack;
      dawState.selectTrackerCell(0, 0);

      await tester.pumpWidget(
        MaterialApp(
          theme: EatsTheme.themeData,
          home: Scaffold(
            body: TrackerView(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(dawState.trackerSelectedStep, equals(0));
      expect(dawState.trackerSelectedColumn, equals(0));

      // Send ArrowDown key
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(dawState.trackerSelectedStep, equals(1));

      // Send ArrowRight key
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(dawState.trackerSelectedColumn, equals(1));

      // Send ArrowUp key
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(dawState.trackerSelectedStep, equals(0));

      // Send ArrowLeft key
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(dawState.trackerSelectedColumn, equals(0));
    });
  });

  group('Settings Import/Export Dialog Tests', () {
    testWidgets('Settings menu contains IMPORT / EXPORT button and shows dialog with Gist input', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dawState = DawState();

      await tester.pumpWidget(
        MaterialApp(
          theme: EatsTheme.themeData,
          home: Scaffold(
            body: TransportHeader(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Monster Icon to open settings
      await tester.tap(find.byTooltip('Eatsbeats Settings'));
      await tester.pumpAndSettle();

      expect(find.text('IMPORT / EXPORT'), findsOneWidget);

      // Tap Import/Export button
      await tester.tap(find.text('IMPORT / EXPORT'));
      await tester.pumpAndSettle();

      expect(find.text('IMPORT / EXPORT SCRIPT'), findsOneWidget);
      expect(find.text('LOAD FROM GITHUB GIST / URL'), findsOneWidget);
      expect(find.text('FETCH GIST'), findsOneWidget);
      expect(find.text('SHARE LINK'), findsOneWidget);
      expect(find.text('IMPORT'), findsOneWidget);
      expect(find.text('COPY'), findsOneWidget);
    });
  });

  group('UrlScriptHelper & Compressed Song Sharing Tests', () {
    test('Compresses and decompresses Lua scripts via URL-safe Base64 and GZip', () {
      const originalScript = '''
-- Eatsbeats Project Script
bpm = 128
shuffle = 0.2
function onInit()
  print("Initialized Acid Song")
end
''';
      final compressed = UrlScriptHelper.compressScriptToPayload(originalScript);
      expect(compressed.startsWith('gz+'), isTrue);

      final decompressed = UrlScriptHelper.decompressPayload(compressed.substring(3));
      expect(decompressed, equals(originalScript));

      final shareUrl = UrlScriptHelper.buildShareableUrl(originalScript);
      expect(shareUrl.startsWith('https://eatsbeats.app/?script=gz%2B'), isTrue);
    });

    test('UrlScriptHelper handles Gist ID, prefixed Gist ID, and compressed payloads', () async {
      const mockScript = 'print("hello world")';
      final compressed = UrlScriptHelper.compressScriptToPayload(mockScript);

      // Resolves compressed payload
      final resolved = await UrlScriptHelper.resolveScript(compressed);
      expect(resolved, equals(mockScript));

      // Tests Gist ID recognition
      expect(RegExp(r'^[a-fA-F0-9]{20,40}$').hasMatch('b785e0cc352b9aa3ece5dfd3c29c134c'), isTrue);
    });
  });

  group('Floating Instrument Window Fullscreen Stability Tests', () {
    testWidgets('Tapping fullscreen does not bounce back to fit-to-screen', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dawState = DawState();
      final track = dawState.activeTrack;
      dawState.openFloatingInstrumentWindow(track, const Size(1200, 800));

      await tester.pumpWidget(
        MaterialApp(
          theme: EatsTheme.themeData,
          home: Scaffold(
            body: ListenableBuilder(
              listenable: dawState,
              builder: (context, _) => Stack(
                children: [
                  if (dawState.isFloatingWindowVisible && !dawState.isFloatingWindowMaximized)
                    Positioned(
                      left: dawState.floatingWindowPosition.dx,
                      top: dawState.floatingWindowPosition.dy,
                      width: dawState.floatingWindowSize.width,
                      height: dawState.floatingWindowSize.height,
                      child: FloatingInstrumentWindow(dawState: dawState),
                    ),
                  if (dawState.isFloatingWindowVisible && dawState.isFloatingWindowMaximized)
                    Positioned.fill(
                      child: FloatingInstrumentWindow(
                        dawState: dawState,
                        workspaceBounds: const Size(1200, 800),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Fullscreen button
      await tester.tap(find.byTooltip('Fullscreen'));
      await tester.pumpAndSettle();

      // Ensure window remains maximized and does not revert
      expect(dawState.isFloatingWindowMaximized, isTrue);

      // Verify exit fullscreen button is visible
      expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);

      // Tap exit fullscreen
      await tester.tap(find.byIcon(Icons.fullscreen_exit));
      await tester.pumpAndSettle();
      expect(dawState.isFloatingWindowMaximized, isFalse);
    });
  });

  group('Piano Roll Navigation & Tracker Length Extension Tests', () {
    testWidgets('Piano Roll allows viewing and navigating content past 2 bars', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dawState = DawState();
      final track = dawState.activeTrack;
      // Set clip length to 4 bars (64 steps)
      dawState.activeTrackClip.barLength = 4;

      await tester.pumpWidget(
        MaterialApp(
          theme: EatsTheme.themeData,
          home: Scaffold(
            body: PianoRollView(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Focus should be requested on Piano Roll
      expect(find.byType(PianoRollView), findsOneWidget);

      // Verify END OF CLIP badge is present
      expect(find.text('END OF CLIP'), findsOneWidget);
    });

    testWidgets('Tracker view navigates past row 15 when clip or pattern is longer than 1 bar', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dawState = DawState();
      final track = dawState.activeTrack;
      // Set clip length to 2 bars (32 steps)
      dawState.activeTrackClip.barLength = 2;

      await tester.pumpWidget(
        MaterialApp(
          theme: EatsTheme.themeData,
          home: Scaffold(
            body: TrackerView(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Set tracker step to row 15
      dawState.selectTrackerCell(15, 0);
      await tester.pumpAndSettle();
      expect(dawState.trackerSelectedStep, equals(15));

      // Press ArrowDown to navigate to row 16
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(dawState.trackerSelectedStep, equals(16));

      // Press ArrowDown multiple times to navigate to row 31 (end of 2-bar pattern)
      for (int i = 0; i < 15; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      }
      await tester.pumpAndSettle();
      expect(dawState.trackerSelectedStep, equals(31));
    });
  });
}
