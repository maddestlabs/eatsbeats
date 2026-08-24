import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/lua/eats_lua_parser.dart';
import 'package:eatsbeats/lua/eats_lua_serializer.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/theme/eats_theme.dart';
import 'package:eatsbeats/ui/mixer_view.dart';
import 'package:eatsbeats/ui/widgets/fx_rack_dialog.dart';
import 'package:eatsbeats/ui/widgets/modular_fx_rack_widget.dart';
import 'package:eatsbeats/ui/widgets/arranger_context_inspector.dart';
import 'package:eatsbeats/ui/widgets/skeuomorphic_hardware_button.dart';
import 'package:eatsbeats/ui/widgets/skeuomorphic_hardware_switch.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Master Track FX Chain & Limiter/Compressor Tests', () {
    test('DawState initializes masterTrack with dedicated fxRack', () {
      final state = DawState();
      expect(state.masterTrack, isNotNull);
      expect(state.masterTrack.id, equals('master_bus'));
      expect(state.masterTrack.name, equals('Master'));
      expect(state.masterTrack.fxRack, isEmpty);

      // Add Master Limiter
      state.addFXInsert(state.masterTrack, FXType.limiter);
      expect(state.masterTrack.fxRack.length, equals(1));
      final limiter = state.masterTrack.fxRack.first;
      expect(limiter.type, equals(FXType.limiter));
      expect(limiter.params['Threshold'], equals(-1.0));
      expect(limiter.params['Ceiling'], equals(-0.1));

      // Add Dynamics Compressor
      state.addFXInsert(state.masterTrack, FXType.compressor);
      expect(state.masterTrack.fxRack.length, equals(2));
      final comp = state.masterTrack.fxRack.last;
      expect(comp.type, equals(FXType.compressor));
      expect(comp.params['Threshold'], equals(-18.0));
      expect(comp.params['Ratio'], equals(4.0));

      state.dispose();
    });

    test('EatsLuaSerializer and EatsLuaParser preserve masterFx with Limiter & Compressor', () {
      final state = DawState();
      state.projectName = 'Mastered Anthem';
      state.addFXInsert(state.masterTrack, FXType.compressor);
      state.addFXInsert(state.masterTrack, FXType.limiter);

      state.updateFXParam(state.masterTrack, state.masterTrack.fxRack[0].id, 'Threshold', -14.0);
      state.updateFXParam(state.masterTrack, state.masterTrack.fxRack[1].id, 'Ceiling', -0.5);

      final luaString = EatsLuaSerializer.serialize(state, projectName: state.projectName);

      expect(luaString, contains('masterFx = {'));
      expect(luaString, contains('Dynamics Compressor'));
      expect(luaString, contains('Master Limiter'));
      expect(luaString, contains('-14.0000'));
      expect(luaString, contains('-0.5000'));

      // Test parsing back
      final newState = DawState();
      EatsLuaParser.populateDawState(newState, luaString);

      expect(newState.masterTrack.fxRack.length, equals(2));
      expect(newState.masterTrack.fxRack[0].type, equals(FXType.compressor));
      expect(newState.masterTrack.fxRack[0].params['Threshold'], equals(-14.0));
      expect(newState.masterTrack.fxRack[1].type, equals(FXType.limiter));
      expect(newState.masterTrack.fxRack[1].params['Ceiling'], equals(-0.5));

      state.dispose();
      newState.dispose();
    });
  });

  group('Arranger / Dialog Reactive FX Updates Tests', () {
    testWidgets('showFxRackDialog updates UI live when FX inserts are added or removed', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final state = DawState(enableMeterTimer: false);
      final track = state.activeTrack;

      await tester.pumpWidget(
        MaterialApp(
          theme: EatsTheme.themeData,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showFxRackDialog(ctx, state, track),
                child: const Text('OPEN DIALOG'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Open Dialog
      await tester.tap(find.text('OPEN DIALOG'));
      await tester.pumpAndSettle();

      expect(find.byType(ModularFxRackWidget), findsOneWidget);
      final initialFxCount = track.fxRack.length;

      // Programmatically add an FX (simulating background action, drag & drop, or command palette)
      state.addFXInsert(track, FXType.limiter);
      await tester.pump();

      // Verify the dialog rebuilt reactively and shows the new insert
      expect(find.text('MASTER LIMITER'), findsOneWidget);
      expect(track.fxRack.length, equals(initialFxCount + 1));

      // Toggle bypass switch inside dialog
      final switchFinder = find.byType(SkeuomorphicHardwareSwitch).first;
      await tester.tap(switchFinder);
      await tester.pump();

      // Remove FX
      final deleteBtnFinder = find.byTooltip('Remove FX').last;
      await tester.tap(deleteBtnFinder);
      await tester.pump();

      expect(track.fxRack.length, equals(initialFxCount));

      state.stop();
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    });
  });

  group('Mixer Master Strip FX Button Tests', () {
    testWidgets('MixerView Master channel strip renders FX button and opens Master FX Rack', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final state = DawState(enableMeterTimer: false);

      await tester.pumpWidget(
        MaterialApp(
          theme: EatsTheme.themeData,
          home: Scaffold(
            body: MixerView(dawState: state),
          ),
        ),
      );
      await tester.pump();

      // Master Strip should have an FX button
      final masterFxBtnFinder = find.byWidgetPredicate(
        (w) => w is Tooltip && w.message == 'Master Bus FX Rack (Limiter, Compressor, Reverb, etc.)',
      );
      expect(masterFxBtnFinder, findsOneWidget);

      // Tap Master FX button to open dialog
      await tester.tap(masterFxBtnFinder);
      await tester.pumpAndSettle();

      // Verify Dialog is open for Master
      expect(find.text('FX INSERT RACK: MASTER'), findsOneWidget);
      expect(find.byType(ModularFxRackWidget), findsOneWidget);

      state.stop();
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    });
  });

  group('Stop / Panic Button Execution Tests', () {
    test('stop() executes full Panic audio kill and cache reset', () {
      final state = DawState();
      state.togglePlay();
      expect(state.isPlaying, isTrue);

      // Single call to stop() now executes panic
      state.stop();

      expect(state.isPlaying, isFalse);
      expect(state.currentStep, equals(0));
      expect(state.audioEngine.leftPeak, equals(0.0));
      expect(state.audioEngine.rightPeak, equals(0.0));

      state.dispose();
    });
  });

  group('Arranger Track Properties & Color Picker Dialog Tests', () {
    testWidgets('ArrangerContextInspector renders Track Color, Actions, MIDI FX, and Audio FX in exact order without empty text padding', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final state = DawState(enableMeterTimer: false);
      state.selectClip(null);

      await tester.pumpWidget(
        MaterialApp(
          theme: EatsTheme.themeData,
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 1000,
              child: ArrangerContextInspector(
                dawState: state,
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Track Color section is rendered
      expect(find.text('TRACK COLOR'), findsOneWidget);
      expect(find.text('PALETTE...'), findsOneWidget);

      // Verify Track Actions section is rendered
      expect(find.text('TRACK ACTIONS'), findsOneWidget);

      // Verify MIDI FX and Modular FX Rack widgets are both rendered in Track Properties
      expect(find.textContaining('MIDI FX RACK'), findsOneWidget);
      expect(find.textContaining('AUDIO FX RACK'), findsOneWidget);

      // Verify empty state placeholder texts are removed
      expect(find.textContaining('No MIDI FX on this track'), findsNothing);
      expect(find.textContaining('No FX Inserts on this track'), findsNothing);

      // Tap PALETTE... to open EatsColorPickerDialog
      await tester.tap(find.text('PALETTE...'));
      await tester.pumpAndSettle();

      expect(find.text('SELECT TRACK COLOR'), findsOneWidget);
      expect(find.text('NEON & CYBERPUNK'), findsOneWidget);
      expect(find.text('CLASSIC SYNTH & STUDIO'), findsOneWidget);
      expect(find.text('APPLY COLOR'), findsOneWidget);

      // Apply a color
      await tester.tap(find.text('APPLY COLOR'));
      await tester.pumpAndSettle();

      state.dispose();
    });
  });
}
