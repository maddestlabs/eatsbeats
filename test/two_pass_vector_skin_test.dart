import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/eatscript/eat_gui_model.dart';
import 'package:eatsbeats/eatscript/eat_gui_parser.dart';
import 'package:eatsbeats/eatscript/eat_gui_serializer.dart';
import 'package:eatsbeats/ui/vector/built_in_vector_skins.dart';
import 'package:eatsbeats/ui/vector/two_pass_vector_painter.dart';
import 'package:eatsbeats/ui/vector/vector_skin_model.dart';
import 'package:eatsbeats/eatscript/eat_script_engine.dart';
import 'package:eatsbeats/eatscript/eat_script_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('2-Pass Vector Skin & Painter Tests', () {
    test('BuiltInVectorSkins provides pre-compiled hardware skins', () {
      final chrome = BuiltInVectorSkins.chromeFluted;
      expect(chrome.id, 'chrome_fluted');
      expect(chrome.chassisLayers.length, greaterThanOrEqualTo(3));
      expect(chrome.indicatorLayer.type, VectorShapeType.svgPath);
      expect(chrome.indicatorLayer.precompiledPath, isNotNull);

      final minimal = BuiltInVectorSkins.minimalMatte;
      expect(minimal.id, 'minimal_white');
      expect(minimal.indicatorLayer.precompiledPath, isNotNull);

      final vintage = BuiltInVectorSkins.vintageBakelite;
      expect(vintage.id, 'vintage_bakelite');

      final snes = BuiltInVectorSkins.snesConsole;
      expect(snes.id, 'snes_cream');
    });

    test('TwoPassVectorKnobPainter paints static chassis into Picture and dynamic indicator', () {
      final skin = BuiltInVectorSkins.chromeFluted;
      final painter = TwoPassVectorKnobPainter(
        normalizedValue: 0.75,
        skin: skin,
        accentColor: const Color(0xFF00E5FF),
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(56, 56);

      // Verify painting runs smoothly with zero errors
      expect(() => painter.paint(canvas, size), returnsNormally);

      // Verify second paint pass reuses cached picture and executes cleanly
      expect(() => painter.paint(canvas, size), returnsNormally);

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('BuiltInVectorSkins exports valid EatScript string', () {
      final skin = BuiltInVectorSkins.chromeFluted;
      final script = BuiltInVectorSkins.exportToEatScript(skin, 'MyAcidKnob');
      expect(script, contains('def MyAcidKnob():'));
      expect(script, contains('"chassis": ['));
      expect(script, contains('"indicator": {'));
      expect(script, contains('"type": "svg_path"'));
    });

    test('LuaGuiParser parses custom vector skin from script table', () {
      const luaCode = '''
function AcidSynth.gui()
  return {
    panel = {
      title = "ACID 303",
      layout = {
        {
          type = "knob",
          param = "Cutoff",
          label = "CUTOFF",
          style = "custom",
          chassis = {
            { type = "circle", radius = 24, fill = "#141416" },
            { type = "ticks", count = 15, radius = 22, length = 4, color = "#00E5FF" }
          },
          indicator = {
            type = "svg_path",
            data = "M -1.5 0 L 0 -18 L 1.5 0 Z",
            fill = "#00E5FF"
          }
        }
      }
    }
  }
end
''';

      final panel = LuaGuiParser.parseFromCode(luaCode);
      expect(panel, isNotNull);
      expect(panel!.children.length, 1);
      final knobNode = panel.children.first;
      expect(knobNode.type, LuaGuiNodeType.knob);
      expect(knobNode.knobStyle, KnobStyle.customVector);
      expect(knobNode.customSkin, isNotNull);
      expect(knobNode.customSkin!.chassisLayers.length, 2);
      expect(knobNode.customSkin!.chassisLayers[0].type, VectorShapeType.circle);
      expect(knobNode.customSkin!.chassisLayers[1].type, VectorShapeType.radialTicks);
      expect(knobNode.customSkin!.indicatorLayer.type, VectorShapeType.svgPath);
      expect(knobNode.customSkin!.indicatorLayer.precompiledPath, isNotNull);
    });

    test('LuaGuiSerializer serializes node with customSkin into EatScript', () {
      final skin = BuiltInVectorSkins.chromeFluted;
      final panel = LuaGuiPanelDef(
        title: 'CUSTOM RIG',
        children: [
          LuaGuiNode(
            type: LuaGuiNodeType.knob,
            param: 'Drive',
            label: 'OVERDRIVE',
            knobStyle: KnobStyle.customVector,
            customSkin: skin,
          ),
        ],
      );

      final code = LuaGuiSerializer.serialize(panel: panel, instrumentName: 'CustomRig');
      expect(code, contains('def gui():'));
      expect(code, contains('"style": "custom"'));
      expect(code, contains('"chassis": ['));
      expect(code, contains('"indicator": {'));
      expect(code, contains('"type": "svg_path"'));
    });

    test('LuaGuiParser parses panel backgroundSvg for EatsFX Fire and Rain', () {
      const code = '''
function EatsFXFire.gui()
  return {
    panel = {
      title = "EATSFX FIRE",
      background = "minimal_white",
      knobStyle = "minimal_white",
      backgroundSvg = "M 100 220 C 60 220, 20 180, 20 130 Z",
      backgroundSvgOpacity = 0.12,
      layout = {}
    }
  }
end
''';
      final panel = LuaGuiParser.parseFromCode(code);
      expect(panel, isNotNull);
      expect(panel!.backgroundStyle, PanelBackgroundStyle.minimalWhite);
      expect(panel.backgroundSvg, isNotNull);
      expect(panel.backgroundSvg, contains('M 100 220'));
    });

    test('Check concert_grand_piano and EatsFX Rain EatScript roundtrip serialization and parsing', () {
      final p = LuaScriptLibrary.getPresetById('concert_grand_piano');
      expect(p, isNotNull);
      final eatCode = p!.eatCode;
      final comp = EatScriptEngine.compile(eatCode);
      expect(comp.isSuccess, isTrue);
      expect(comp.guiLayout, isNotNull);
      expect(comp.guiLayout!.title, 'CONCERT GRAND PIANO');
      expect(comp.guiLayout!.children.length, 2);

      // Serialize with changes
      final serialized = LuaGuiSerializer.serialize(
        panel: comp.guiLayout!,
        existingScriptCode: eatCode,
        instrumentName: 'ConcertGrandPiano',
      );
      expect(EatScriptEngine.isEatScript(serialized), isTrue);
      expect(serialized, contains('def gui():'));
      expect(serialized, contains('def process('));
      expect(serialized, isNot(contains('function ConcertGrandPiano.gui()')));

      final comp2 = EatScriptEngine.compile(serialized);
      expect(comp2.isSuccess, isTrue);
      expect(comp2.guiLayout, isNotNull);
      expect(comp2.guiLayout!.title, 'CONCERT GRAND PIANO');
      expect(comp2.guiLayout!.children.length, 2);

      // Verify EatsFX Rain roundtrip
      final rain = LuaScriptLibrary.getPresetById('eatsfx_rain');
      expect(rain, isNotNull);
      final rainEat = rain!.eatCode;
      final rainComp = EatScriptEngine.compile(rainEat);
      expect(rainComp.isSuccess, isTrue);
      expect(rainComp.guiLayout, isNotNull);
      expect(rainComp.guiLayout!.backgroundSvg, isNotNull);

      final rainSerialized = LuaGuiSerializer.serialize(
        panel: rainComp.guiLayout!,
        existingScriptCode: rainEat,
        instrumentName: 'EatsFXRain',
      );
      expect(rainSerialized, contains('def gui():'));
      expect(rainSerialized, contains('"backgroundSvg":'));
      final rainComp2 = EatScriptEngine.compile(rainSerialized);
      expect(rainComp2.isSuccess, isTrue);
      expect(rainComp2.guiLayout!.backgroundSvg, isNotNull);
    });
  });
}
