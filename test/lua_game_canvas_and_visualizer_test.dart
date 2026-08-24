import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_wren_daw/lua/lua_engine.dart';
import 'package:mobile_wren_daw/lua/lua_gui_model.dart';
import 'package:mobile_wren_daw/lua/lua_gui_parser.dart';
import 'package:mobile_wren_daw/lua/lua_preset_library.dart';
import 'package:mobile_wren_daw/models/daw_state.dart';
import 'package:mobile_wren_daw/models/track_model.dart';
import 'package:mobile_wren_daw/ui/widgets/dynamic_instrument_gui_widget.dart';
import 'package:mobile_wren_daw/ui/widgets/interactive_game_canvas_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Lua GUI Model & Parser Canvas Extensions', () {
    test('LuaGuiNodeType.parseType recognizes canvas, dpad, and gamepad variants', () {
      expect(LuaGuiNode.parseType('canvas'), LuaGuiNodeType.canvas);
      expect(LuaGuiNode.parseType('gamecanvas'), LuaGuiNodeType.canvas);
      expect(LuaGuiNode.parseType('screen'), LuaGuiNodeType.canvas);
      expect(LuaGuiNode.parseType('viewport'), LuaGuiNodeType.canvas);
      expect(LuaGuiNode.parseType('display'), LuaGuiNodeType.canvas);
      expect(LuaGuiNode.parseType('framebuffer'), LuaGuiNodeType.canvas);

      expect(LuaGuiNode.parseType('dpad'), LuaGuiNodeType.dpad);
      expect(LuaGuiNode.parseType('joystick'), LuaGuiNodeType.dpad);
      expect(LuaGuiNode.parseType('directional'), LuaGuiNodeType.dpad);

      expect(LuaGuiNode.parseType('gamepad'), LuaGuiNodeType.gamepad);
      expect(LuaGuiNode.parseType('arcadebuttons'), LuaGuiNodeType.gamepad);
      expect(LuaGuiNode.parseType('actionbuttons'), LuaGuiNodeType.gamepad);
    });

    test('LuaGuiParser correctly parses canvas properties from Lua GUI tables', () {
      const luaScript = '''
function Nibbles.gui()
  return {
    panel = {
      title = "FT2 Nibbles",
      background = "dark",
      accent = "#00FF9D",
      layout = {
        {
          type = "canvas",
          mode = "grid",
          cols = 32,
          rows = 24,
          width = 320,
          height = 200,
          showDpad = true,
          showActionButtons = true
        }
      }
    }
  }
end
''';

      final panel = LuaGuiParser.parseFromCode(luaScript);
      expect(panel, isNotNull);
      expect(panel!.title, 'FT2 Nibbles');
      expect(panel.children.length, 1);

      final canvasNode = panel.children.first;
      expect(canvasNode.type, LuaGuiNodeType.canvas);
      expect(canvasNode.canvasMode, 'grid');
      expect(canvasNode.cols, 32);
      expect(canvasNode.rows, 24);
      expect(canvasNode.width, 320.0);
      expect(canvasNode.height, 200.0);
      expect(canvasNode.showDpad, isTrue);
      expect(canvasNode.showActionButtons, isTrue);
    });
  });

  group('Built-in Throwback Presets', () {
    test('Eats-Nibbles preset compiles and has valid GUI layout', () {
      final preset = LuaPresetLibrary.getPresetById('eats_nibbles');
      expect(preset, isNotNull);
      expect(preset!.name, 'Eats-Nibbles');

      final compilation = LuaEngine.compile(preset.code);
      expect(compilation.isSuccess, isTrue);
      expect(compilation.params.any((p) => p.name == 'Speed'), isTrue);
      expect(compilation.params.any((p) => p.name == 'SFXType'), isTrue);
      expect(compilation.guiLayout, isNotNull);

      final gui = compilation.guiLayout!;
      expect(gui.title, 'Eats-Nibbles');
      expect(gui.children.any((n) => n.type == LuaGuiNodeType.canvas), isTrue);
    });

    test('Eats-Runner preset compiles and has valid GUI layout', () {
      final preset = LuaPresetLibrary.getPresetById('eats_runner');
      expect(preset, isNotNull);
      expect(preset!.name, 'Eats-Runner');

      final compilation = LuaEngine.compile(preset.code);
      expect(compilation.isSuccess, isTrue);
      expect(compilation.params.any((p) => p.name == 'Jump'), isTrue);
      expect(compilation.params.any((p) => p.name == 'Speed'), isTrue);
      expect(compilation.guiLayout, isNotNull);

      final gui = compilation.guiLayout!;
      expect(gui.title, 'Eats-Runner');
      expect(gui.children.any((n) => n.type == LuaGuiNodeType.canvas), isTrue);
    });

    test('Eats-Scope & Eats-Spectrum visualizer FX compile and have valid GUI layout', () {
      final scope = LuaPresetLibrary.getPresetById('eats_scope');
      expect(scope, isNotNull);
      expect(scope!.name, 'Eats-Scope');
      expect(scope.isAudioFx, isTrue);

      final scopeCompilation = LuaEngine.compile(scope.code);
      expect(scopeCompilation.isSuccess, isTrue);
      expect(scopeCompilation.guiLayout!.title, 'Eats-Scope');
      expect(scopeCompilation.guiLayout!.children.first.canvasMode, 'vector');

      final spectrum = LuaPresetLibrary.getPresetById('eats_spectrum');
      expect(spectrum, isNotNull);
      expect(spectrum!.name, 'Eats-Spectrum');
      expect(spectrum.isAudioFx, isTrue);

      final spectrumCompilation = LuaEngine.compile(spectrum.code);
      expect(spectrumCompilation.isSuccess, isTrue);
      expect(spectrumCompilation.guiLayout!.title, 'Eats-Spectrum');
      expect(spectrumCompilation.guiLayout!.children.first.canvasMode, 'spectrum');
    });

    test('findMatchingPreset identifies Eats-Nibbles, Eats-Runner, Eats-Scope, and Eats-Spectrum', () {
      final nibbles = LuaPresetLibrary.findMatchingPreset("local Nibbles = {}\nfunction Nibbles.init() end");
      expect(nibbles, isNotNull);
      expect(nibbles!.id, 'eats_nibbles');

      final runner = LuaPresetLibrary.findMatchingPreset("local CyberRunner = {}\nfunction CyberRunner.init() end");
      expect(runner, isNotNull);
      expect(runner!.id, 'eats_runner');

      final scope = LuaPresetLibrary.findMatchingPreset("local Scope = {}\n-- @name: Eats-Scope");
      expect(scope, isNotNull);
      expect(scope!.id, 'eats_scope');

      final spectrum = LuaPresetLibrary.findMatchingPreset("local Spectrum = {}\n-- @name: Eats-Spectrum");
      expect(spectrum, isNotNull);
      expect(spectrum!.id, 'eats_spectrum');
    });
  });

  group('Interactive Game Canvas Widget Tests', () {
    testWidgets('Renders Eats-Nibbles canvas and virtual D-Pad controls in DynamicInstrumentGuiWidget', (tester) async {
      final dawState = DawState();
      final nibblesPreset = LuaPresetLibrary.getPresetById('eats_nibbles')!;
      final track = TrackChannel(
        id: 'track_1',
        name: 'Eats-Nibbles',
        type: TrackType.synth,
        color: const Color(0xFF00FF9D),
        luaScriptCode: nibblesPreset.code,
      );

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Verify canvas widget is rendered
      expect(find.byType(InteractiveGameCanvasWidget), findsOneWidget);

      // Verify D-Pad buttons are rendered
      expect(find.byIcon(Icons.keyboard_arrow_up), findsWidgets);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsWidgets);
      expect(find.byIcon(Icons.keyboard_arrow_left), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_right), findsOneWidget);

      // Verify action buttons
      expect(find.text('RESET'), findsOneWidget);
      expect(find.text('JUMP'), findsOneWidget);

      // Tap D-Pad Up
      await tester.tap(find.byIcon(Icons.keyboard_arrow_up).first);
      await tester.pump(const Duration(milliseconds: 50));

      // Tap Reset
      await tester.tap(find.text('RESET'));
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('Renders Eats-Runner canvas and Jump controls', (tester) async {
      final dawState = DawState();
      final runnerPreset = LuaPresetLibrary.getPresetById('eats_runner')!;
      final track = TrackChannel(
        id: 'track_2',
        name: 'Eats-Runner',
        type: TrackType.synth,
        color: const Color(0xFF00E5FF),
        luaScriptCode: runnerPreset.code,
      );

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(InteractiveGameCanvasWidget), findsOneWidget);
      expect(find.textContaining('EATS-RUNNER'), findsWidgets);
      expect(find.text('JUMP'), findsWidgets);

      // Tap canvas to trigger jump
      await tester.tap(find.byType(InteractiveGameCanvasWidget));
      await tester.pump(const Duration(milliseconds: 50));
    });
  });
}
