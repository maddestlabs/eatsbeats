import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/lua/lua_engine.dart';
import 'package:eatsbeats/lua/lua_preset_library.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/ui/arranger_view.dart';
import 'package:eatsbeats/ui/transport_header.dart';
import 'package:eatsbeats/ui/widgets/dynamic_instrument_gui_widget.dart';
import 'package:eatsbeats/ui/widgets/glowing_nixie_display.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Arranger View UI Refinements', () {
    testWidgets('Arranger track list header does not contain FX button', (tester) async {
      final dawState = DawState();
      final track = TrackChannel(
        id: 'test_track',
        name: 'Lead Synth',
        type: TrackType.synth,
        color: const Color(0xFF00E5FF),
      );
      dawState.tracks.add(track);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: ArrangerView(dawState: dawState),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Track header should have Mute ('M'), Solo ('S'), Follow Mode ('--'), but NOT 'FX' button
      expect(find.text('M'), findsWidgets);
      expect(find.text('S'), findsWidgets);
      expect(find.text('FX'), findsNothing);
    });
  });

  group('Transport Header Refinements', () {
    testWidgets('Right-click (secondary tap) on Tempo opens BPM edit dialog', (tester) async {
      final dawState = DawState();
      dawState.setBpm(128.0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransportHeader(dawState: dawState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the BPM nixie display
      final bpmDisplay = find.byType(GlowingNixieDisplay).first;
      expect(bpmDisplay, findsOneWidget);

      // Perform secondary tap (right-click)
      await tester.tap(bpmDisplay, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      // Compact value dialog should be visible
      expect(find.text('TEMPO (BPM)'), findsOneWidget);
      expect(find.text('128'), findsOneWidget);
    });

    testWidgets('Single-click on L/R master peak meter toggles DSP CPU meter', (tester) async {
      final dawState = DawState();
      expect(dawState.showCpuMeter, isFalse);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: dawState,
              builder: (context, _) => TransportHeader(dawState: dawState),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial state is L/R Master Peak Meter
      expect(find.text('L'), findsWidgets);
      expect(find.text('CPU'), findsNothing);

      // Single tap on the meter
      await tester.tap(find.text('L').first);
      await tester.pumpAndSettle();

      // Should now show CPU meter
      expect(dawState.showCpuMeter, isTrue);
      expect(find.text('CPU'), findsOneWidget);

      // Single tap again toggles back to L/R
      await tester.tap(find.text('CPU'));
      await tester.pumpAndSettle();

      expect(dawState.showCpuMeter, isFalse);
      expect(find.text('L'), findsWidgets);
    });
  });

  group('SNES Sfxr RNG SEED & Nixie Interactions', () {
    test('SNES Sfxr preset has 100px width for RNG SEED nixie matching Randomize button', () {
      final sfxr = LuaPresetLibrary.getPresetById('eats_sfxr')!;
      final compilation = LuaEngine.compile(sfxr.code);
      expect(compilation.guiLayout, isNotNull);

      final row1 = compilation.guiLayout!.children.first;
      final col = row1.children.firstWhere((c) => c.param == null && c.children.isNotEmpty);
      final seedNode = col.children.firstWhere((c) => c.param == 'Seed');
      final randomButtonNode = col.children.firstWhere((c) => c.action == 'randomize');

      expect(seedNode.width, equals(100.0));
      expect(randomButtonNode.width, equals(100.0));
    });

    testWidgets('RNG SEED in DynamicInstrumentGuiWidget renders with centered label, width, and tooltip', (tester) async {
      final dawState = DawState();
      final sfxr = LuaPresetLibrary.getPresetById('eats_sfxr')!;
      final track = TrackChannel(
        id: 'sfxr_track',
        name: 'SNES Sfxr',
        type: TrackType.synth,
        color: const Color(0xFFE52521),
        luaScriptCode: sfxr.code,
        luaParams: {
          'SFXType': 0.0, // Laser
          'Seed': 42.0,
        },
      );
      dawState.tracks.add(track);

      await tester.pumpWidget(
        MaterialApp(
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

      expect(find.text('RNG SEED'), findsOneWidget);
      expect(find.text('42'), findsWidgets);

      // Verify Tooltip exists with editing information
      expect(find.byType(Tooltip), findsWidgets);
      final nixieDisplays = find.byType(GlowingNixieDisplay);
      expect(nixieDisplays, findsOneWidget);

      final nixieWidget = tester.widget<GlowingNixieDisplay>(nixieDisplays.first);
      expect(nixieWidget.width, equals(100.0));
      expect(nixieWidget.centerLabel, isTrue);
      expect(nixieWidget.tooltip, contains('Scroll or Hold/Right-click to edit'));
    });

    testWidgets('Right-click / long-press edit dialog validates input and reverts on unusable string', (tester) async {
      final dawState = DawState();
      final sfxr = LuaPresetLibrary.getPresetById('eats_sfxr')!;
      final track = TrackChannel(
        id: 'sfxr_track',
        name: 'SNES Sfxr',
        type: TrackType.synth,
        color: const Color(0xFFE52521),
        luaScriptCode: sfxr.code,
        luaParams: {
          'SFXType': 0.0, // Laser
          'Seed': 42.0,
        },
      );
      dawState.tracks.add(track);

      await tester.pumpWidget(
        MaterialApp(
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

      // Long press RNG SEED nixie display
      await tester.longPress(find.byType(GlowingNixieDisplay).first);
      await tester.pumpAndSettle();

      // Value edit dialog is shown
      expect(find.text('RNG SEED'), findsWidgets);
      expect(find.byType(TextField), findsOneWidget);

      // Enter invalid / unusable string
      await tester.enterText(find.byType(TextField), 'garbage_value');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Seed should revert / remain 42.0
      expect(track.luaParams['Seed'], equals(42.0));

      // Now open edit dialog again and enter valid seed
      await tester.longPress(find.byType(GlowingNixieDisplay).first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '777');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Seed should now be updated to 777.0 and archetype params regenerated
      expect(track.luaParams['Seed'], equals(777.0));
    });

    testWidgets('Mouse scroll on RNG SEED increments and decrements value', (tester) async {
      final dawState = DawState();
      final sfxr = LuaPresetLibrary.getPresetById('eats_sfxr')!;
      final track = TrackChannel(
        id: 'sfxr_track',
        name: 'SNES Sfxr',
        type: TrackType.synth,
        color: const Color(0xFFE52521),
        luaScriptCode: sfxr.code,
        luaParams: {
          'SFXType': 0.0, // Laser
          'Seed': 100.0,
        },
      );
      dawState.tracks.add(track);

      await tester.pumpWidget(
        MaterialApp(
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

      final nixieCenter = tester.getCenter(find.byType(GlowingNixieDisplay).first);

      // Simulate mouse scroll up (delta dy < 0 -> increment)
      final scrollUpEvent = PointerScrollEvent(
        position: nixieCenter,
        scrollDelta: const Offset(0, -100),
      );
      await tester.sendEventToBinding(scrollUpEvent);
      await tester.pumpAndSettle();

      expect(track.luaParams['Seed'], equals(101.0));

      // Simulate mouse scroll down (delta dy > 0 -> decrement)
      final scrollDownEvent = PointerScrollEvent(
        position: nixieCenter,
        scrollDelta: const Offset(0, 100),
      );
      await tester.sendEventToBinding(scrollDownEvent);
      await tester.pumpAndSettle();

      expect(track.luaParams['Seed'], equals(100.0));
    });
  });

  group('YM2612 & OPL3 Retro Chiptune GUI Tests', () {
    test('YM2612 Genesis 4-Op FM compiles with Nixie controls and 110px widths', () {
      final ym2612 = LuaPresetLibrary.getPresetById('ym2612_synth')!;
      final compilation = LuaEngine.compile(ym2612.code);

      expect(compilation.guiLayout, isNotNull);
      final panel = compilation.guiLayout!;
      expect(panel.title, contains('YM2612'));

      final row1 = panel.children.first;
      final algoNode = row1.children.firstWhere((c) => c.param == 'Algorithm');
      final fbNode = row1.children.firstWhere((c) => c.param == 'Feedback');

      expect(algoNode.width, equals(110.0));
      expect(fbNode.width, equals(110.0));
    });

    test('OPL3 Retro Chiptune compiles with hardware rack GUI layout', () {
      final opl3 = LuaPresetLibrary.getPresetById('opl3_retro')!;
      final compilation = LuaEngine.compile(opl3.code);

      expect(compilation.guiLayout, isNotNull);
      final panel = compilation.guiLayout!;
      expect(panel.title, contains('OPL3'));
      expect(panel.subtitle, contains('Retro DOS FM Hardware'));

      final row1 = panel.children.first;
      expect(row1.children.any((c) => c.param == 'Algorithm'), isTrue);
      expect(row1.children.any((c) => c.param == 'Feedback'), isTrue);

      final row2 = panel.children[1];
      expect(row2.children.any((c) => c.param == 'Op1_Mult'), isTrue);
      expect(row2.children.any((c) => c.param == 'Op1_TL'), isTrue);
      expect(row2.children.any((c) => c.param == 'Op2_Mult'), isTrue);
      expect(row2.children.any((c) => c.param == 'Op2_TL'), isTrue);
    });

    testWidgets('DynamicInstrumentGuiWidget renders OPL3 sleek GUI and edits Algorithm with validation', (tester) async {
      final dawState = DawState();
      final opl3 = LuaPresetLibrary.getPresetById('opl3_retro')!;
      final track = TrackChannel(
        id: 'opl3_track',
        name: 'OPL3 Chiptune',
        type: TrackType.synth,
        color: const Color(0xFF39FF14),
        luaScriptCode: opl3.code,
        luaParams: {
          'Algorithm': 4.0,
          'Feedback': 3.0,
          'Op1_Mult': 1.0,
          'Op1_TL': 12.0,
          'Op2_Mult': 2.0,
          'Op2_TL': 0.0,
        },
      );
      dawState.tracks.add(track);

      await tester.pumpWidget(
        MaterialApp(
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

      expect(find.text('YMF262 / OPL3 FM SYNTH'), findsOneWidget);
      expect(find.text('ALGORITHM'), findsOneWidget);
      expect(find.text('FEEDBACK'), findsOneWidget);
      expect(find.text('OP1 MULT'), findsOneWidget);
      expect(find.text('OP2 MULT'), findsOneWidget);

      // Long press ALGORITHM nixie to edit
      await tester.longPress(find.byType(GlowingNixieDisplay).first);
      await tester.pumpAndSettle();

      expect(find.text('ALGORITHM'), findsWidgets);
      // Type unusable input
      await tester.enterText(find.byType(TextField), 'not_a_number');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Algorithm value should remain 4.0
      expect(track.luaParams['Algorithm'], equals(4.0));

      // Long press again and enter 6.0
      await tester.longPress(find.byType(GlowingNixieDisplay).first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '6');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(track.luaParams['Algorithm'], equals(6.0));
    });
  });
}
