import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/ui/widgets/floating_instrument_window.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Floating In-App VSTi Window State & Interaction Tests', () {
    test('State management for floating instrument window', () {
      final state = DawState();
      final track = state.activeTrack;

      expect(state.isFloatingWindowVisible, isFalse);

      // Open window for track
      state.openFloatingInstrumentWindow(track);
      expect(state.isFloatingWindowVisible, isTrue);
      expect(state.floatingInstrumentTrackId, equals(track.id));
      expect(state.floatingInstrumentTrack?.id, equals(track.id));

      // Move window position
      final initialPos = state.floatingWindowPosition;
      state.updateFloatingWindowPosition(const Offset(20, 30));
      expect(state.floatingWindowPosition.dx, equals(initialPos.dx + 20));
      expect(state.floatingWindowPosition.dy, equals(initialPos.dy + 30));

      // Resize window
      final initialSize = state.floatingWindowSize;
      state.updateFloatingWindowSize(const Offset(40, 50));
      expect(state.floatingWindowSize.width, equals(initialSize.width + 40));
      expect(state.floatingWindowSize.height, equals(initialSize.height + 50));

      // Scale window
      state.setFloatingWindowScale(1.25);
      expect(state.floatingWindowScale, equals(1.25));

      // Close window
      state.closeFloatingInstrumentWindow();
      expect(state.isFloatingWindowVisible, isFalse);

      // Toggle window
      state.toggleFloatingInstrumentWindow(track);
      expect(state.isFloatingWindowVisible, isTrue);
      state.toggleFloatingInstrumentWindow(track);
      expect(state.isFloatingWindowVisible, isFalse);
    });

    test('Accurate natural GUI height calculation for zero-padding fit', () {
      final state = DawState();
      final track = state.activeTrack;

      final height = state.getTrackNaturalGuiHeight(track);
      expect(height, greaterThanOrEqualTo(120.0));
      expect(height, lessThanOrEqualTo(600.0));

      // Auto-fit calculates exact aspect ratio without excess height
      state.fitFloatingWindowToWorkspace(const Size(800, 600), track);
      final winH = state.floatingWindowSize.height;
      // Window height should equal (content natural height * scale) + 38 titlebar
      expect(winH, lessThan(600));
    });

    test('Auto-fit and fullscreen maximization state logic', () {
      final state = DawState();
      final track = state.activeTrack;
      state.openFloatingInstrumentWindow(track);

      // Mobile screen fit: 380x720
      state.fitFloatingWindowToWorkspace(const Size(380, 720));
      expect(state.isFloatingWindowMaximized, isFalse);
      expect(state.floatingWindowSize.width, lessThanOrEqualTo(380));
      expect(state.floatingWindowSize.height, lessThanOrEqualTo(720));
      expect(state.floatingWindowPosition.dx, greaterThanOrEqualTo(0));

      // Toggle Fullscreen / Maximize
      state.toggleMaximizeFloatingWindow(const Size(800, 600));
      expect(state.isFloatingWindowMaximized, isTrue);
      expect(state.floatingWindowSize.width, equals(792)); // 800 - (4*2)
      expect(state.floatingWindowSize.height, equals(592)); // 600 - (4*2)
      expect(state.floatingWindowPosition, equals(const Offset(4, 4)));

      // Toggle back / Restore
      state.toggleMaximizeFloatingWindow(const Size(800, 600));
      expect(state.isFloatingWindowMaximized, isFalse);
    });

    testWidgets('Renders FloatingInstrumentWindow when visible and handles user interactions', (tester) async {
      final state = DawState();
      final track = state.activeTrack;
      track.name = 'Acid Synth 303';
      state.openFloatingInstrumentWindow(track);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: state,
              builder: (context, _) => Stack(
                children: [
                  Positioned.fill(child: Container(color: Colors.black)),
                  if (state.isFloatingWindowVisible)
                    Positioned(
                      left: state.floatingWindowPosition.dx,
                      top: state.floatingWindowPosition.dy,
                      width: state.floatingWindowSize.width,
                      height: state.floatingWindowSize.height,
                      child: FloatingInstrumentWindow(
                        dawState: state,
                        workspaceBounds: const Size(800, 600),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify script-driven title bar and actions
      expect(find.text('ACID SYNTH 303'), findsOneWidget);
      expect(find.byIcon(Icons.developer_board), findsOneWidget);
      expect(find.byIcon(Icons.fit_screen), findsOneWidget);
      expect(find.byIcon(Icons.fullscreen), findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);

      // Verify 1:1 FittedBox scaling container is rendered
      expect(find.byType(FittedBox), findsWidgets);

      // Tap Fit to Screen button
      await tester.tap(find.byIcon(Icons.fit_screen));
      await tester.pumpAndSettle();
      expect(state.isFloatingWindowMaximized, isFalse);

      // Tap Fullscreen / Maximize button
      await tester.tap(find.byIcon(Icons.fullscreen));
      await tester.pumpAndSettle();
      expect(state.isFloatingWindowMaximized, isTrue);
      expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);

      // Tap Close Screw to Close Panel
      await tester.tap(find.byTooltip('Close'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(state.isFloatingWindowVisible, isFalse);
    });

    testWidgets('Popout GUI controls (buttons, switches, segmented pills) respond immediately without double-tap delay', (tester) async {
      final state = DawState();
      final track = state.activeTrack;
      track.name = 'TTS Voice Synth';
      track.luaScriptCode = '''
-- @name: TTS Voice Synth
TTSVoiceSynth = {}
function TTSVoiceSynth.init()
  return { voice_mode = 0, adv = 0, bypass_engine = 0 }
end
function TTSVoiceSynth.gui()
  return {
    panel = {
      title = "TTS VOICE SYNTH",
      layout = {
        { type = "button", action = "bypass", param = "bypass_engine", label = "BYPASS" },
        { type = "segmented_pill", param = "voice_mode", label = "VOICE PROFILE", options = { "Natural", "Robot", "Whisper" } },
        { type = "switch", param = "adv", label = "ADV" },
      }
    }
  }
end
''';
      track.luaParams['bypass_engine'] = 0.0;
      track.luaParams['voice_mode'] = 0.0;
      track.luaParams['adv'] = 0.0;

      state.openFloatingInstrumentWindow(track);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: state,
              builder: (context, _) => Stack(
                children: [
                  if (state.isFloatingWindowVisible)
                    Positioned(
                      left: state.floatingWindowPosition.dx,
                      top: state.floatingWindowPosition.dy,
                      width: state.floatingWindowSize.width,
                      height: state.floatingWindowSize.height,
                      child: FloatingInstrumentWindow(
                        dawState: state,
                        workspaceBounds: const Size(800, 600),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Single tap on "Robot" segmented pill option
      final robotOption = find.text('Robot');
      expect(robotOption, findsOneWidget);
      await tester.tap(robotOption);
      await tester.pump();
      // Should respond immediately without needing double tap delay
      expect(track.luaParams['voice_mode'], equals(1.0));

      // 2. Single tap on "Whisper"
      final whisperOption = find.text('Whisper');
      await tester.tap(whisperOption);
      await tester.pump();
      expect(track.luaParams['voice_mode'], equals(2.0));

      // 3. Single tap on ADV switch
      final advSwitch = find.text('ADV');
      expect(advSwitch, findsOneWidget);
      await tester.tap(advSwitch);
      await tester.pump();
      expect(track.luaParams['adv'], equals(1.0));

      // 4. Single tap on Bypass button
      final bypassBtn = find.text('BYPASS');
      expect(bypassBtn, findsOneWidget);
      await tester.tap(bypassBtn);
      await tester.pump();
      expect(track.luaParams['bypass_engine'], equals(1.0));
      await tester.pumpAndSettle();
    });

    test('Accurate natural GUI height for nested multi-column TTS Voice Synth layout', () {
      final state = DawState();
      final track = state.activeTrack;
      track.name = 'TTS Voice Synth';
      track.luaScriptCode = '''
-- @name: TTS Voice Synth
TTSVoiceSynth = {}
function TTSVoiceSynth.init()
  return { voice_mode = 0, speech_speed = 1, pitch = 1.0, tone = 0.5, volume = 0.85, space = 0.35, air = 0.30, adv = 1.0 }
end
function TTSVoiceSynth.gui()
  return {
    panel = {
      title = "TTS VOICE SYNTH",
      subtitle = "Vocal Speech & Formant Synthesizer",
      background = "minimal_white",
      accent = "#D9603B",
      knobStyle = "minimal_white",
      layout = {
        {
          type = "row",
          children = {
            {
              type = "column",
              children = {
                { type = "spectrum", width = 210, height = 96 },
                { type = "segmented_pill", param = "voice_mode", label = "VOICE PROFILE", options = { "Natural", "Robot", "Whisper" } },
                { type = "segmented_pill", param = "speech_speed", label = "SPEED", options = { "Slow", "Normal", "Fast" } },
                {
                  type = "row",
                  children = {
                    { type = "knob", param = "pitch", label = "PITCH", size = 48, knobStyle = "minimal_white" },
                    { type = "knob", param = "tone", label = "TONE", size = 48, knobStyle = "minimal_white" },
                  }
                },
              }
            },
            {
              type = "column",
              children = {
                { type = "knob", param = "volume", label = "LEVEL", size = 72, knobStyle = "minimal_white" },
                { type = "knob", param = "space", label = "SPACE", size = 52, knobStyle = "minimal_white" },
                { type = "knob", param = "air", label = "AIR", size = 46, knobStyle = "minimal_white" },
                { type = "switch", param = "adv", label = "ADV", orientation = "vertical" },
              }
            },
          }
        },
      }
    }
  }
end
''';
      final height = state.getTrackNaturalGuiHeight(track);
      // Height should accurately reflect the taller column (~340-420px), not be squished down to 120px
      expect(height, greaterThanOrEqualTo(300.0));
      expect(height, lessThanOrEqualTo(500.0));

      state.fitFloatingWindowToWorkspace(const Size(1000, 700), track);
      expect(state.floatingWindowSize.height, greaterThan(350.0));
      expect(state.floatingWindowSize.width, greaterThan(450.0));
    });
  });
}

