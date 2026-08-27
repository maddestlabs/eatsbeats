import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/lua/lua_gui_model.dart';
import 'package:eatsbeats/lua/lua_canvas_drawing_engine.dart';
import 'package:eatsbeats/ui/widgets/lua_programmable_canvas_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Lua 2D Canvas Drawing Engine Tests', () {
    test('LuaCanvasDrawingContext records primitives and parses colors correctly', () {
      final ctx = LuaCanvasDrawingContext(
        width: 320,
        height: 180,
        defaultAccent: const Color(0xFF00E5FF),
      );

      ctx.clear('#111520');
      ctx.grid(8, 6, '#00FF9D');
      ctx.line(10, 20, 100, 120, '#FF8C00', 2.5);
      ctx.rect(30, 40, 60, 80, '#E040FB', true, 1.0, 4.0);
      ctx.circle(160, 90, 25, '#00E5FF', false, 2.0);
      ctx.text('FILTER FREQ', 15, 25, 12, '#FFFFFF', 'left');
      ctx.waveform(1.2, 0.8, '#00FF9D', 2.0);
      ctx.spectrum(16, 1.0, 0.5, '#00E5FF');

      expect(ctx.ops.length, equals(8));
      expect(ctx.ops[0], isA<LuaCanvasClearOp>());
      expect((ctx.ops[0] as LuaCanvasClearOp).color, equals(const Color(0xFF111520)));

      expect(ctx.ops[1], isA<LuaCanvasGridOp>());
      expect((ctx.ops[1] as LuaCanvasGridOp).cols, equals(8));

      expect(ctx.ops[2], isA<LuaCanvasLineOp>());
      expect((ctx.ops[2] as LuaCanvasLineOp).strokeWidth, equals(2.5));

      expect(ctx.ops[3], isA<LuaCanvasRectOp>());
      expect((ctx.ops[3] as LuaCanvasRectOp).filled, isTrue);
      expect((ctx.ops[3] as LuaCanvasRectOp).cornerRadius, equals(4.0));

      expect(ctx.ops[4], isA<LuaCanvasCircleOp>());
      expect((ctx.ops[4] as LuaCanvasCircleOp).radius, equals(25.0));

      expect(ctx.ops[5], isA<LuaCanvasTextOp>());
      expect((ctx.ops[5] as LuaCanvasTextOp).text, equals('FILTER FREQ'));

      expect(ctx.ops[6], isA<LuaCanvasWaveformOp>());
      expect(ctx.ops[7], isA<LuaCanvasSpectrumOp>());
    });

    test('LuaCanvasDrawingEngine parses and evaluates custom Lua draw routine', () {
      const scriptCode = '''
local CustomSynth = {}

function CustomSynth.draw(canvas, w, h, params, time)
  canvas:clear("#0A0E18")
  canvas:grid(8, 6, "#00E5FF")
  canvas:rect(10, 10, w - 20, h - 20, "#00E5FF", false, 1.5, 4)
  canvas:line(20, h - 30, w * 0.5, 30, "#FF3366", 2.0)
  canvas:circle(w * 0.5, 30, 6, "#00FF9D", true)
  canvas:text("CUTOFF GRAPH", 25, 25, 10, "#FFFFFF", "left")
  canvas:waveform(1.0, 1.0, "#00E5FF", 1.5)
end

return CustomSynth
''';

      final ops = LuaCanvasDrawingEngine.evaluate(
        scriptCode: scriptCode,
        width: 320,
        height: 180,
        params: {'Cutoff': 2400.0, 'Resonance': 4.5},
        time: 1.25,
        accentColor: const Color(0xFF00E5FF),
      );

      expect(ops.length, equals(7));
      expect(ops[0], isA<LuaCanvasClearOp>());
      expect(ops[1], isA<LuaCanvasGridOp>());
      expect(ops[2], isA<LuaCanvasRectOp>());
      expect(ops[3], isA<LuaCanvasLineOp>());
      expect(ops[4], isA<LuaCanvasCircleOp>());
      expect(ops[5], isA<LuaCanvasTextOp>());
      expect(ops[6], isA<LuaCanvasWaveformOp>());
    });

    test('LuaCanvasDrawingEngine generates responsive fallback vector display when no draw() exists', () {
      const emptyScript = '''
local SimpleSynth = {}
return SimpleSynth
''';

      final ops = LuaCanvasDrawingEngine.evaluate(
        scriptCode: emptyScript,
        width: 340,
        height: 180,
        params: {'Cutoff': 1200.0, 'Resonance': 2.0},
        time: 0.0,
        accentColor: const Color(0xFF00FF9D),
        touchPos: const Offset(120, 80),
        isTouchDown: true,
      );

      expect(ops.isNotEmpty, isTrue);
      expect(ops.any((op) => op is LuaCanvasClearOp), isTrue);
      expect(ops.any((op) => op is LuaCanvasGridOp), isTrue);
      expect(ops.any((op) => op is LuaCanvasWaveformOp), isTrue);
      expect(ops.any((op) => op is LuaCanvasTextOp), isTrue);
    });

    testWidgets('LuaProgrammableCanvasWidget renders custom 2D canvas at 60fps', (tester) async {
      final dawState = DawState();
      final track = TrackChannel(
        id: 'canvas_synth_1',
        name: 'Acid Vector Synth',
        type: TrackType.luaScript,
        color: const Color(0xFF00E5FF),
        luaScriptCode: '''
local VectorSynth = {}
function VectorSynth.draw(canvas, w, h, params, time)
  canvas:clear("#080B12")
  canvas:grid(6, 4, "#00E5FF")
  canvas:line(10, 10, 200, 100, "#00FF9D", 2.0)
  canvas:text("VECTOR CORE", 12, 14, 9, "#FFFFFF")
end
return VectorSynth
''',
      );

      const node = LuaGuiNode(
        type: LuaGuiNodeType.canvas,
        width: 320,
        height: 160,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: LuaProgrammableCanvasWidget(
                dawState: dawState,
                track: track,
                node: node,
                accentColor: const Color(0xFF00E5FF),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(LuaProgrammableCanvasWidget), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}
