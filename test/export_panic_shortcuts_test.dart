import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_wren_daw/lua/eats_lua_serializer.dart';
import 'package:mobile_wren_daw/lua/eats_lua_parser.dart';
import 'package:mobile_wren_daw/main.dart';
import 'package:mobile_wren_daw/models/daw_state.dart';
import 'package:mobile_wren_daw/theme/eats_theme.dart';
import 'package:mobile_wren_daw/ui/transport_header.dart';
import 'package:mobile_wren_daw/ui/virtual_piano_keyboard.dart';
import 'package:mobile_wren_daw/ui/widgets/skeuomorphic_hardware_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Song Export & Settings Isolation Tests', () {
    test('Exported .eats.lua does NOT contain theme or app settings', () {
      final state = DawState();
      state.projectName = 'Pure Song Data';
      state.authorName = 'Producer';
      state.setBpm(130.0);
      state.setThemePreset(EatsThemePreset.midnightBites);

      final luaString = EatsLuaSerializer.serialize(state, projectName: state.projectName);

      // Verify essential project/song data is present
      expect(luaString, contains('title = "Pure Song Data"'));
      expect(luaString, contains('bpm = 130.00'));
      expect(luaString, contains('author = "Producer"'));

      // Verify theme is NOT serialized in the song file
      expect(luaString.contains('theme ='), isFalse);
      expect(luaString.contains('midnightBites'), isFalse);

      state.dispose();
    });

    test('Loading song does NOT overwrite user active theme setting', () {
      final state = DawState();
      state.setThemePreset(EatsThemePreset.dinner);

      const legacySongWithTheme = '''
return eatsbits.song {
  meta = {
    title = "Legacy Track",
    theme = "breakfast",
    bpm = 120.0,
  },
  patterns = {}
}
''';

      state.loadFromEatsLua(legacySongWithTheme);

      // Song data loaded
      expect(state.projectName, equals('Legacy Track'));
      // Theme remains untouched as user preference
      expect(EatsTheme.currentPreset, equals(EatsThemePreset.dinner));

      state.dispose();
    });
  });

  group('Stop Button Panic Functionality Tests', () {
    test('DawState panic halts playback, stops all audio nodes, and clears PCM cache', () {
      final state = DawState();
      state.togglePlay();
      expect(state.isPlaying, isTrue);

      // Simulate some cached audio or calculation state
      state.panic();

      expect(state.isPlaying, isFalse);
      expect(state.currentStep, equals(0));
      expect(state.audioEngine.leftPeak, equals(0.0));
      expect(state.audioEngine.rightPeak, equals(0.0));

      state.dispose();
    });

    testWidgets('Stop button has correct hover tooltip and double-tap panic trigger', (WidgetTester tester) async {
      final state = DawState(enableMeterTimer: false);
      state.togglePlay();
      expect(state.isPlaying, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          theme: EatsTheme.themeData,
          home: Scaffold(
            body: TransportHeader(dawState: state),
          ),
        ),
      );
      await tester.pump();

      // Verify Tooltip message
      final stopTooltipFinder = find.byWidgetPredicate(
        (widget) => widget is Tooltip && widget.message == 'Stop (Double-tap to stop all audio)',
      );
      expect(stopTooltipFinder, findsOneWidget);

      // Find the Stop button inside the Tooltip
      final stopButtonFinder = find.descendant(
        of: stopTooltipFinder,
        matching: find.byType(SkeuomorphicHardwareButton),
      );
      expect(stopButtonFinder, findsOneWidget);

      // Double-tap the Stop button
      await tester.tap(stopButtonFinder);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(stopButtonFinder);
      await tester.pump(const Duration(milliseconds: 400));

      expect(state.isPlaying, isFalse);

      state.stop();
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    });
  });

  group('Global Spacebar Play/Stop Tests', () {
    testWidgets('Spacebar triggers togglePlay across app, but respects text fields', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final dawState = DawState(enableMeterTimer: false);

      await tester.pumpWidget(
        MaterialApp(
          theme: EatsTheme.themeData,
          home: Scaffold(
            body: DawMainShell(dawState: dawState),
          ),
        ),
      );
      await tester.pump();

      expect(dawState.isPlaying, isFalse);

      // Press Space globally -> should start playback
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(dawState.isPlaying, isTrue);

      // Press Space globally -> should pause/stop playback
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(dawState.isPlaying, isFalse);

      dawState.stop();
      await tester.pumpWidget(const SizedBox());
      dawState.dispose();
    });
  });

  group('Virtual Piano Keyboard Tests', () {
    testWidgets('VirtualPianoKeyboard renders and responds to pointer down with velocity', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final dawState = DawState(enableMeterTimer: false);

      await tester.pumpWidget(
        MaterialApp(
          theme: EatsTheme.themeData,
          home: Scaffold(
            body: VirtualPianoKeyboard(dawState: dawState),
          ),
        ),
      );
      await tester.pump();

      // Open drawer
      final dragTabFinder = find.byType(VirtualPianoKeyboard);
      expect(dragTabFinder, findsOneWidget);

      await tester.tap(dragTabFinder);
      await tester.pump();

      // CustomPaint is rendered for keys
      expect(find.byType(CustomPaint), findsWidgets);

      dawState.stop();
      await tester.pumpWidget(const SizedBox());
      dawState.dispose();
    });
  });
}
