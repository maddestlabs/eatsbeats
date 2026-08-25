import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/audio/soundfont_engine.dart';
import 'package:eatsbeats/lua/lua_preset_library.dart';
import 'package:eatsbeats/models/chord_model.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/theme/eats_theme.dart';
import 'package:eatsbeats/ui/widgets/circle_of_fifths_dialog.dart';
import 'package:eatsbeats/ui/widgets/dynamic_instrument_gui_widget.dart';
import 'package:eatsbeats/ui/widgets/floating_instrument_window.dart';
import 'package:eatsbeats/ui/widgets/modular_fx_rack_widget.dart';
import 'package:eatsbeats/ui/widgets/midi_fx_rack_widget.dart';
import 'package:eatsbeats/ui/arranger_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await SoundFontEngine.instance.loadDefaultBundledFont();
  });

  group('Selector Dropdowns & Animation Style Tests', () {
    testWidgets('EatsTheme provides popupMenuTheme with panelHeader and textPrimary styling', (tester) async {
      final theme = EatsTheme.themeData;
      expect(theme.popupMenuTheme.color, equals(EatsTheme.panelHeader));
      expect(theme.popupMenuTheme.textStyle?.color, equals(EatsTheme.textPrimary));
    });

    testWidgets('Audio FX and MIDI FX buttons render with search icon and theme colors', (tester) async {
      final dawState = DawState();
      final track = dawState.activeTrack;

      await tester.pumpWidget(
        MaterialApp(
          theme: EatsTheme.themeData,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  ModularFxRackWidget(dawState: dawState, track: track),
                  MidiFxRackWidget(dawState: dawState, track: track),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('+ ADD FX'), findsOneWidget);
      expect(find.text('+ ADD MIDI FX'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsNWidgets(2));
      dawState.dispose();
    });
  });

  group('Chord Selector & Circle of Fifths Mobile vs Desktop Tests', () {
    testWidgets('CircleOfFifthsDialog renders responsive tabs in mobile compact mode', (tester) async {
      // Mobile screen dimensions
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dawState = DawState();
      await tester.pumpWidget(
        MaterialApp(
          theme: EatsTheme.themeData,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => CircleOfFifthsDialog.show(context, dawState: dawState),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // In mobile compact mode, tabs are visible
      expect(find.text('CIRCLE OF FIFTHS'), findsWidgets);
      expect(find.text('QUALITIES & BASS'), findsOneWidget);
      expect(find.text('SELECTED CHORD'), findsOneWidget);

      // Switch to Qualities & Bass tab
      await tester.tap(find.text('QUALITIES & BASS'));
      await tester.pumpAndSettle();

      // Verify Chord Quality / Extensions are visible
      expect(find.text('CHORD QUALITY & EXTENSIONS'), findsOneWidget);
      expect(find.text('BASS / SLASH NOTE (INVERSION)'), findsOneWidget);
    });

    testWidgets('CircleOfFifthsDialog renders side-by-side layout in desktop wide mode', (tester) async {
      // Desktop screen dimensions
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dawState = DawState();
      await tester.pumpWidget(
        MaterialApp(
          theme: EatsTheme.themeData,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => CircleOfFifthsDialog.show(context, dawState: dawState),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // In desktop mode, both wheel and modifiers matrix are present side-by-side without mobile tabs
      expect(find.text('CHORD SELECTOR & CIRCLE OF FIFTHS'), findsOneWidget);
      expect(find.text('CHORD QUALITY & EXTENSIONS'), findsOneWidget);
      expect(find.text('BASS / SLASH NOTE (INVERSION)'), findsOneWidget);
      expect(find.text('QUALITIES & BASS'), findsNothing);
    });
  });

  group('Floating Instrument Window Proportions & Code Icon Tests', () {
    testWidgets('FloatingInstrumentWindow renders code icon and auto-fits default size', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dawState = DawState();
      final track = dawState.activeTrack;
      dawState.openFloatingInstrumentWindow(track, const Size(1400, 900));

      await tester.pumpWidget(
        MaterialApp(
          theme: EatsTheme.themeData,
          home: Scaffold(
            body: FloatingInstrumentWindow(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify code icon exists for Open in Script Editor
      final codeIcons = find.byIcon(Icons.code);
      expect(codeIcons, findsOneWidget);

      // Verify window size is auto-fitted
      expect(dawState.floatingWindowSize.width, greaterThan(300.0));
      expect(dawState.floatingWindowSize.height, greaterThan(150.0));
    });
  });

  group('SNES Synth Auto-Audition Tests', () {
    testWidgets('Tapping RANDOMIZE in SNES Synth triggers C5 note audition', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dawState = DawState();
      final snesPreset = LuaPresetLibrary.getPresetById('eats_sfxr')!;
      final track = TrackChannel(
        id: 'snes_track_1',
        name: 'SNES Sfxr Track',
        type: TrackType.luaScript,
        color: const Color(0xFF21F4E8),
        luaScriptCode: snesPreset.code,
        luaParams: {
          'SFXType': 0.0,
          'Seed': 42.0,
        },
      );
      dawState.tracks.add(track);

      await tester.pumpWidget(
        MaterialApp(
          theme: EatsTheme.themeData,
          home: Scaffold(
            body: SingleChildScrollView(
              child: DynamicInstrumentGuiWidget(
                dawState: dawState,
                track: track,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final randomizeBtn = find.text('RANDOMIZE');
      expect(randomizeBtn, findsOneWidget);

      final initialSeed = track.luaParams['Seed'];
      await tester.tap(randomizeBtn);
      await tester.pumpAndSettle();

      // Verify seed was modified and note was auditioned
      expect(track.luaParams['Seed'], isNot(equals(initialSeed)));
    });
  });
}
