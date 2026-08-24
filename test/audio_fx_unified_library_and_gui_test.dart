import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_wren_daw/lua/lua_engine.dart';
import 'package:mobile_wren_daw/lua/lua_preset_library.dart';
import 'package:mobile_wren_daw/models/daw_state.dart';
import 'package:mobile_wren_daw/models/track_model.dart';
import 'package:mobile_wren_daw/ui/widgets/dynamic_instrument_gui_widget.dart';
import 'package:mobile_wren_daw/ui/widgets/floating_instrument_window.dart';
import 'package:mobile_wren_daw/ui/widgets/fx_rack_dialog.dart';
import 'package:mobile_wren_daw/ui/widgets/interactive_game_canvas_widget.dart';
import 'package:mobile_wren_daw/ui/widgets/modular_fx_rack_widget.dart';
import 'package:mobile_wren_daw/ui/widgets/skeuomorphic_hardware_switch.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Unified Audio FX Preset Library Tests', () {
    test('All Audio FX presets in LuaPresetLibrary compile cleanly', () {
      final audioPresets = LuaPresetLibrary.presets.where((p) => p.isAudioFx).toList();
      expect(audioPresets.length, greaterThanOrEqualTo(8));

      for (final preset in audioPresets) {
        final compilation = LuaEngine.compile(preset.code);
        expect(
          compilation.isSuccess,
          isTrue,
          reason: 'Preset "${preset.name}" (${preset.id}) failed to compile: ${compilation.errorMessage}',
        );
      }
    });

    test('addAudioFXFromPreset adds FXInsert with proper parameters and Lua code', () {
      final dawState = DawState();
      final track = dawState.activeTrack;
      final initialCount = track.fxRack.length;

      final scopePreset = LuaPresetLibrary.getPresetById('eats_scope')!;
      dawState.addAudioFXFromPreset(track, scopePreset);

      expect(track.fxRack.length, initialCount + 1);
      final addedFx = track.fxRack.last;
      expect(addedFx.name, 'Eats-Scope');
      expect(addedFx.luaScriptCode, scopePreset.code);
      expect(addedFx.presetId, 'eats_scope');
      expect(addedFx.isLuaFX, isTrue);
      expect(addedFx.luaParams.containsKey('Gain'), isTrue);
      expect(addedFx.luaParams.containsKey('Timebase'), isTrue);
    });

    test('Audio FX presets are serialized and deserialized with Lua data', () {
      final fx = FXInsert.create(
        FXType.luaFX,
        name: 'Eats-Spectrum',
        luaScriptCode: '-- code',
        presetId: 'eats_spectrum',
        luaParams: {'Gain': 2.0, 'Decay': 0.8},
      );

      final json = fx.toJson();
      expect(json['presetId'], 'eats_spectrum');
      expect(json['luaParams']['Gain'], 2.0);

      final restored = FXInsert.fromJson(json);
      expect(restored.name, 'Eats-Spectrum');
      expect(restored.presetId, 'eats_spectrum');
      expect(restored.luaParams['Gain'], 2.0);
      expect(restored.isLuaFX, isTrue);
    });
  });

  group('Modern Circle Pill Switch & Vintage Bat Handle Switch Tests', () {
    testWidgets('SkeuomorphicHardwareSwitch renders modernPill horizontally and vertically', (tester) async {
      bool horizontalVal = false;
      bool verticalVal = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SkeuomorphicHardwareSwitch(
                  value: horizontalVal,
                  style: SwitchStyle.modernPill,
                  orientation: Axis.horizontal,
                  showText: true,
                  onChanged: (v) => horizontalVal = v,
                ),
                SkeuomorphicHardwareSwitch(
                  value: verticalVal,
                  style: SwitchStyle.modernPill,
                  orientation: Axis.vertical,
                  width: 16.0,
                  height: 28.0,
                  onChanged: (v) => verticalVal = v,
                ),
                SkeuomorphicHardwareSwitch(
                  value: true,
                  style: SwitchStyle.vintageBat,
                  onChanged: (v) {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SkeuomorphicHardwareSwitch), findsNWidgets(3));

      // Tap horizontal switch to toggle
      await tester.tap(find.byType(SkeuomorphicHardwareSwitch).first);
      await tester.pumpAndSettle();
      expect(horizontalVal, isTrue);

      // Tap vertical switch to toggle
      await tester.tap(find.byType(SkeuomorphicHardwareSwitch).at(1));
      await tester.pumpAndSettle();
      expect(verticalVal, isFalse);
    });
  });

  group('Floating Audio FX Window Tests', () {
    testWidgets('DawState.openFloatingFxWindow opens and FloatingInstrumentWindow renders FX faceplate', (tester) async {
      final dawState = DawState();
      final track = dawState.activeTrack;
      final spectrumPreset = LuaPresetLibrary.getPresetById('eats_spectrum')!;

      dawState.addAudioFXFromPreset(track, spectrumPreset);
      final fx = track.fxRack.last;

      dawState.openFloatingFxWindow(track, fx);
      expect(dawState.isFloatingWindowVisible, isTrue);
      expect(dawState.floatingFxInsertId, fx.id);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FloatingInstrumentWindow(
              dawState: dawState,
              workspaceBounds: const Size(1200, 800),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(FloatingInstrumentWindow), findsOneWidget);
      expect(find.byType(DynamicInstrumentGuiWidget), findsOneWidget);
      expect(find.byType(InteractiveGameCanvasWidget), findsOneWidget);
      expect(find.text('GAIN'), findsWidgets);
      expect(find.text('DECAY'), findsWidgets);
    });
  });

  group('Modular FX Rack & Faceplate GUI Tests', () {
    testWidgets('ModularFxRackWidget displays all added FX and opens GUI expansion', (tester) async {
      final dawState = DawState();
      final track = dawState.activeTrack;

      final scopePreset = LuaPresetLibrary.getPresetById('eats_scope')!;
      final limiterPreset = LuaPresetLibrary.getPresetById('master_limiter')!;

      dawState.addAudioFXFromPreset(track, scopePreset);
      dawState.addAudioFXFromPreset(track, limiterPreset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ModularFxRackWidget(
                dawState: dawState,
                track: track,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(ModularFxRackWidget), findsOneWidget);
      expect(find.text('+ ADD FX'), findsOneWidget);
      expect(find.text('EATS-SCOPE'), findsOneWidget);
      expect(find.text('MASTER LIMITER'), findsOneWidget);

      // Tap on EATS-SCOPE to expand its custom faceplate GUI
      await tester.tap(find.text('EATS-SCOPE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Verifies that expanding renders DynamicInstrumentGuiWidget & InteractiveGameCanvasWidget
      expect(find.byType(DynamicInstrumentGuiWidget), findsWidgets);
      expect(find.byType(InteractiveGameCanvasWidget), findsWidgets);
      expect(find.text('TIMEBASE'), findsWidgets);
    });
  });
}
