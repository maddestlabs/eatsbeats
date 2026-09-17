import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/eatscript/eatscript_graph_model.dart';
import 'package:eatsbeats/eatscript/eats_script_engine.dart';
import 'package:eatsbeats/audio/graph/graph_node.dart';
import 'package:eatsbeats/models/daw_state.dart';
import 'package:eatsbeats/models/track_model.dart';
import 'package:eatsbeats/ui/modular/modular_rack_dsl.dart';
import 'package:eatsbeats/ui/modular/modular_rack_canvas.dart';
import 'package:eatsbeats/eatscript/eats_builtin_presets.g.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Eatscript Bi-Directional Modular Graph System (Approach C)', () {
    const sampleEatscript = '''
# @name: Acid Bass
# @engine: poly_synth

def init():
    eat.param("Cutoff", 1200.0, 20.0, 20000.0, "Hz")
    eat.param("Resonance", 0.75, 0.1, 10.0, "")

def graph():
    vco = eat.node.osc(wave="square", detune=3.0)
    sub = eat.node.sub(octave=-1, level=0.5)
    vcf = eat.node.svf(in_sig=vco, cutoff="Cutoff", reso="Resonance")
    env = eat.node.adsr(attack=0.01, decay=0.15, sustain=0.6, release=0.25)
    sat = eat.node.saturate(in_sig=vcf, drive=2.5)
    return sat * env

def process(time, freq, note, params):
    return 0.0
''';

    test('EatscriptGraphDef parses Pythonic def graph() with zero Lua dependencies', () {
      final graph = EatscriptGraphDef.parse(sampleEatscript, trackName: 'Acid Bass');

      expect(graph.nodes.length, greaterThanOrEqualTo(5));
      expect(graph.findNode('vco')?.type, 'osc');
      expect(graph.findNode('vco')?.params['wave'], 'square');
      expect(graph.findNode('sub')?.type, 'sub');
      expect(graph.findNode('vcf')?.type, 'svf');
      expect(graph.findNode('sat')?.type, 'saturate');
      expect(graph.findNode('env')?.type, 'adsr');

      // Check cable inference from in_sig parameter
      expect(graph.cables.any((c) => c.fromNodeId == 'vco' && c.toNodeId == 'vcf'), isTrue);
      expect(graph.cables.any((c) => c.fromNodeId == 'vcf' && c.toNodeId == 'sat'), isTrue);
    });

    test('EatscriptGraphDef serializes clean Pythonic code with 4-space indentation and NO Lua keywords', () {
      final graph = EatscriptGraphDef.parse(sampleEatscript, trackName: 'Acid Bass');
      final serialized = EatscriptGraphDef.serialize(graph, existingCode: sampleEatscript, instrumentName: 'Acid Bass');

      expect(serialized, contains('def graph():'));
      expect(serialized, contains('vco = eat.node.osc('));
      expect(serialized, contains('vcf = eat.node.svf('));
      expect(serialized, contains('return sat * env'));

      // STRICT CHECK: ABSOLUTELY NO LUA KEYWORDS
      expect(serialized, isNot(contains('.rack()')));
      expect(serialized, isNot(contains('function ')));
      expect(serialized, isNot(contains('end\n')));
      expect(serialized, isNot(contains('local ')));
    });

    test('ModularRackDsl converts EatscriptGraphDef into ModularRackDefinition and back seamlessly', () {
      final graph = EatscriptGraphDef.parse(sampleEatscript, trackName: 'Acid Bass');
      final rack = ModularRackDsl.fromEatscriptGraph(graph);

      expect(rack.totalRows, greaterThanOrEqualTo(2));
      expect(rack.modulesByRow[1], isNotEmpty);
      expect(rack.modulesByRow[2], isNotEmpty);

      // Verify VCO is in row 1 and MOD/FX in row 2
      final hasVcoInRow1 = rack.modulesByRow[1]!.any((m) => m.category == 'VCO' || m.title.contains('VCO'));
      expect(hasVcoInRow1, isTrue);

      // Now serialize back through ModularRackDsl.serialize
      final reserialized = ModularRackDsl.serialize(
        totalRows: rack.totalRows,
        customModulesByRow: rack.modulesByRow,
        cables: rack.cables,
        existingScriptCode: sampleEatscript,
        instrumentName: 'Acid Bass',
      );

      expect(reserialized, contains('def graph():'));
      expect(reserialized, isNot(contains('function ')));
      expect(reserialized, isNot(contains('.rack()')));
    });

    test('EatscriptGraphDef compiles directly to native Dart/C GraphNode tree and processes audio without NaN', () {
      final graph = EatscriptGraphDef.parse(sampleEatscript, trackName: 'Acid Bass');
      final compiledNode = graph.compileToGraphNode({
        'Cutoff': 1200.0,
        'Resonance': 0.75,
        'Attack': 0.01,
        'Decay': 0.2,
        'Sustain': 0.6,
        'Release': 0.3,
        'Drive': 2.0,
      });

      expect(compiledNode, isNotNull);

      // Render 512 samples through the compiled modular graph tree
      final buffer = Float32List(512);
      final context = GraphContext(
        durationSec: 0.5,
        freq: 110.0, // A2
        midiNote: 45,
        velocity: 0.9,
      );

      compiledNode.process(context, buffer);

      // Ensure signal is active and clean
      bool hasSignal = false;
      for (int i = 0; i < buffer.length; i++) {
        expect(buffer[i].isNaN, isFalse);
        expect(buffer[i].isInfinite, isFalse);
        if (buffer[i].abs() > 0.001) hasSignal = true;
      }
      expect(hasSignal, isTrue);
    });

    test('EatScriptEngine executes eat.node.* methods without runtime exceptions', () {
      final result = EatScriptEngine.compile('''
def graph():
    osc = eat.node.osc(wave="saw", detune=2.0)
    vcf = eat.node.svf(in_sig=osc, cutoff=800, reso=0.8)
    env = eat.node.adsr(attack=0.01, decay=0.1, sustain=0.5, release=0.2)
    sat = eat.node.saturate(in_sig=vcf, drive=2.0)
    return sat * env
''');

      expect(result.isSuccess, isTrue);
    });

    testWidgets('Visual drag patching on ModularRackCanvas directly updates Eatscript def graph() in track.luaScriptCode', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dawState = DawState();
      final track = TrackChannel(
        id: 'modular_eat_track',
        name: 'Acid Bass',
        type: TrackType.eatScript,
        color: const Color(0xFF00FFE0),
        luaScriptCode: sampleEatscript,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 700,
              child: ModularRackCanvas(
                dawState: dawState,
                track: track,
              ),
            ),
          ),
        ),
      );

      // Toolbar indicates DSP SYNC: OK
      expect(find.text('DSP SYNC: OK'), findsOneWidget);

      // Add a module
      await tester.tap(find.text('+ ADD').first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'tape');
      await tester.pumpAndSettle();

      expect(find.text('TAPE DELAY FX'), findsOneWidget);
      await tester.tap(find.text('TAPE DELAY FX'));
      await tester.pumpAndSettle();

      // Verify track.luaScriptCode is updated in pure Eatscript without Lua
      expect(track.luaScriptCode, contains('def graph():'));
      expect(track.luaScriptCode, contains('eat.node.'));
      expect(track.luaScriptCode, isNot(contains('function ')));
      expect(track.luaScriptCode, isNot(contains('.rack()')));
    });

    test('Compiles and renders 3-stage Physical Modeling pipeline (Hammer -> Modal Bank -> Acoustic Body)', () {
      const physicalEatscript = '''
# @name: Concert Marimba
# @engine: poly_synth

def graph():
    strike = eat.node.hammer(hardness=0.6, velocity=0.8)
    modes = eat.node.modal_bank(in_sig=strike, structure=0.2, brightness=0.75, damping=0.4)
    body = eat.node.acoustic_body(in_sig=modes, body_type=1.0, size=1.1)
    return body

def process(time, freq, note, params):
    return 0.0
''';

      final graph = EatscriptGraphDef.parse(physicalEatscript, trackName: 'Concert Marimba');
      expect(graph.nodes.length, 3);
      expect(graph.findNode('strike')?.type, 'hammer');
      expect(graph.findNode('modes')?.type, 'modal_bank');
      expect(graph.findNode('body')?.type, 'acoustic_body');

      final compiled = graph.compileToGraphNode();
      expect(compiled, isNotNull);

      final buffer = Float32List(512);
      final context = GraphContext(
        durationSec: 1.0,
        freq: 440.0,
        midiNote: 69,
        velocity: 0.85,
      );

      compiled.process(context, buffer);

      bool hasSignal = false;
      for (int i = 0; i < buffer.length; i++) {
        expect(buffer[i].isNaN, isFalse);
        expect(buffer[i].isInfinite, isFalse);
        if (buffer[i].abs() > 0.0001) hasSignal = true;
      }
      expect(hasSignal, isTrue, reason: 'Physical modeling pipeline must produce audible acoustic output');
    });

    test('Compiles and renders Moog Ladder Filter, Noise, LFO, and Mixer nodes without NaN', () {
      const synthEatscript = '''
# @name: Vintage Moog Noise FX
# @engine: poly_synth

def graph():
    noise_gen = eat.node.noise(type=0.0)
    osc1 = eat.node.osc(wave="saw")
    lfo1 = eat.node.lfo(rate=4.0, depth=0.5)
    sum = eat.node.mix(in_a=noise_gen, in_b=osc1, gain_a=0.3, gain_b=0.7)
    vcf = eat.node.moog(in_sig=sum, cutoff=1200.0, reso=0.85)
    return vcf

def process(time, freq, note, params):
    return 0.0
''';

      final graph = EatscriptGraphDef.parse(synthEatscript, trackName: 'Vintage Moog Noise FX');
      expect(graph.nodes.length, 5);
      expect(graph.findNode('noise_gen')?.type, 'noise');
      expect(graph.findNode('lfo1')?.type, 'lfo');
      expect(graph.findNode('sum')?.type, 'mix');
      expect(graph.findNode('vcf')?.type, 'moog');

      final compiled = graph.compileToGraphNode();
      expect(compiled, isNotNull);

      final buffer = Float32List(512);
      final context = GraphContext(
        durationSec: 0.5,
        freq: 220.0,
        midiNote: 57,
        velocity: 0.8,
      );

      compiled.process(context, buffer);

      bool hasSignal = false;
      for (int i = 0; i < buffer.length; i++) {
        expect(buffer[i].isNaN, isFalse);
        expect(buffer[i].isInfinite, isFalse);
        if (buffer[i].abs() > 0.0001) hasSignal = true;
      }
      expect(hasSignal, isTrue);
    });

    test('EatScriptEngine registers and executes all new eat.node.* factories including input', () {
      const script = '''
def graph():
    inp = eat.node.input()
    h = eat.node.hammer()
    p = eat.node.pluck()
    b = eat.node.bow()
    w = eat.node.waveguide(in_sig=p)
    m = eat.node.modal_bank(in_sig=h)
    ab = eat.node.acoustic_body(in_sig=m)
    n = eat.node.noise()
    l = eat.node.lfo()
    mg = eat.node.moog(in_sig=n)
    del = eat.node.delay(in_sig=inp)
    mx = eat.node.mix(in_a=mg, in_b=del)
    return mx
''';
      final result = EatScriptEngine.compile(script);
      expect(result.isSuccess, isTrue);
    });

    test('Compiles and processes Audio FX graph with AudioInputNode', () {
      const fxScript = '''
# @name: Modular Delay FX
# @category: audioFx

def graph():
    in_sig = eat.node.input()
    fx = eat.node.delay(in_sig=in_sig, time=0.25, feedback=0.5)
    return fx
''';

      final graph = EatscriptGraphDef.parse(fxScript, trackName: 'Modular Delay FX');
      expect(graph.nodes.length, 2);
      expect(graph.findNode('in_sig')?.type, 'input');
      expect(graph.findNode('fx')?.type, 'delay');

      final compiled = graph.compileToGraphNode();
      expect(compiled, isNotNull);

      final inBuffer = Float32List(512);
      for (int i = 0; i < 512; i++) {
        inBuffer[i] = (i % 64 < 32) ? 0.5 : -0.5;
      }

      final outBuffer = Float32List(512);
      final context = GraphContext(
        durationSec: 0.1,
        freq: 440.0,
        midiNote: 69,
        inputBuffer: inBuffer,
      );

      compiled.process(context, outBuffer);

      bool hasSignal = false;
      for (int i = 0; i < outBuffer.length; i++) {
        expect(outBuffer[i].isNaN, isFalse);
        if (outBuffer[i].abs() > 0.001) hasSignal = true;
      }
      expect(hasSignal, isTrue);
    });

    test('Revamped Flagship Presets (Grand Piano, Moog Bass, Violin, Vibraphone, Guitar) parse modular def graph() and render audio', () {
      final pianoPreset = EatBuiltinPresets.presets.firstWhere((p) => p.id == 'concert_grand_piano');
      final moogPreset = EatBuiltinPresets.presets.firstWhere((p) => p.id == 'moog_synth_bass');
      final guitarPreset = EatBuiltinPresets.presets.firstWhere((p) => p.id == 'acoustic_steel_guitar');
      final violinPreset = EatBuiltinPresets.presets.firstWhere((p) => p.id == 'solo_violin');
      final vibraPreset = EatBuiltinPresets.presets.firstWhere((p) => p.id == 'vibraphone');

      for (final p in [pianoPreset, moogPreset, guitarPreset, violinPreset, vibraPreset]) {
        expect(p.code, contains('def graph():'), reason: '${p.name} must have a native def graph()');
        final graph = EatscriptGraphDef.parse(p.code, trackName: p.name);
        expect(graph.nodes, isNotEmpty, reason: '${p.name} must parse into modular nodes');

        final compiled = graph.compileToGraphNode();
        final outBuffer = Float32List(512);
        final context = GraphContext(
          durationSec: 0.5,
          freq: 440.0,
          midiNote: 69,
        );
        compiled.process(context, outBuffer);

        for (int i = 0; i < outBuffer.length; i++) {
          expect(outBuffer[i].isNaN, isFalse, reason: '${p.name} produced NaN');
        }
      }
    });
    test('Revamped Drum & Percussion Presets (808 Kick, Snare, HiHat, Cowbell, Tom, 909 Clap, Steelpan, Taiko) parse modular def graph() and render audio', () {
      final kick808 = EatBuiltinPresets.presets.firstWhere((p) => p.id == 'analog_808_kick');
      final snare808 = EatBuiltinPresets.presets.firstWhere((p) => p.id == 'analog_808_snare');
      final hihat808 = EatBuiltinPresets.presets.firstWhere((p) => p.id == 'analog_808_hihat');
      final cowbell808 = EatBuiltinPresets.presets.firstWhere((p) => p.id == 'analog_808_cowbell');
      final tom808 = EatBuiltinPresets.presets.firstWhere((p) => p.id == 'analog_808_tom');
      final clap909 = EatBuiltinPresets.presets.firstWhere((p) => p.id == 'analog_909_clap');
      final steelpan = EatBuiltinPresets.presets.firstWhere((p) => p.id == 'steel_drums');
      final taiko = EatBuiltinPresets.presets.firstWhere((p) => p.id == 'taiko_drum');

      for (final p in [kick808, snare808, hihat808, cowbell808, tom808, clap909, steelpan, taiko]) {
        expect(p.code, contains('def graph():'), reason: '${p.name} must have a native def graph()');
        final graph = EatscriptGraphDef.parse(p.code, trackName: p.name);
        expect(graph.nodes, isNotEmpty, reason: '${p.name} must parse into modular nodes');

        final compiled = graph.compileToGraphNode();
        final outBuffer = Float32List(512);
        final context = GraphContext(
          durationSec: 0.5,
          freq: 100.0,
          midiNote: 36,
          velocity: 0.9,
        );
        compiled.process(context, outBuffer);

        bool hasSignal = false;
        for (int i = 0; i < outBuffer.length; i++) {
          expect(outBuffer[i].isNaN, isFalse, reason: '${p.name} produced NaN');
          if (outBuffer[i].abs() > 0.0001) hasSignal = true;
        }
        expect(hasSignal, isTrue, reason: '${p.name} must produce audible audio signal');
      }
    });

    test('Revamped Audio FX Presets (Bitcrusher, Stereo Chorus, Parametric EQ, Multimode Filter, Delay, Saturator) process input buffers', () {
      final bitcrush = EatBuiltinPresets.presets.firstWhere((p) => p.id == 'bitcrusher');
      final chorus = EatBuiltinPresets.presets.firstWhere((p) => p.id == 'stereo_chorus');
      final peq = EatBuiltinPresets.presets.firstWhere((p) => p.id == 'parametric_eq');
      final mmf = EatBuiltinPresets.presets.firstWhere((p) => p.id == 'multimode_filter');
      final delay = EatBuiltinPresets.presets.firstWhere((p) => p.id == 'stereo_delay');
      final waveshaper = EatBuiltinPresets.presets.firstWhere((p) => p.id == 'waveshaper');

      final inBuffer = Float32List(512);
      for (int i = 0; i < 512; i++) {
        inBuffer[i] = math.sin(2.0 * math.pi * 440.0 * (i / 44100.0));
      }

      for (final p in [bitcrush, chorus, peq, mmf, delay, waveshaper]) {
        expect(p.code, contains('def graph():'), reason: '${p.name} must have a native def graph()');
        final graph = EatscriptGraphDef.parse(p.code, trackName: p.name);
        expect(graph.nodes, isNotEmpty, reason: '${p.name} must parse into modular nodes');

        final compiled = graph.compileToGraphNode();
        final outBuffer = Float32List(512);
        final context = GraphContext(
          durationSec: 0.1,
          freq: 440.0,
          midiNote: 69,
          inputBuffer: inBuffer,
        );
        compiled.process(context, outBuffer);

        bool hasSignal = false;
        for (int i = 0; i < outBuffer.length; i++) {
          expect(outBuffer[i].isNaN, isFalse, reason: '${p.name} produced NaN');
          if (outBuffer[i].abs() > 0.0001) hasSignal = true;
        }
        expect(hasSignal, isTrue, reason: '${p.name} must process and output incoming audio');
      }
    });

    test('Expanded 909 Suite & Physical Percussion (909 Kick, Snare, Closed HH, Open HH, Rimshot, Melodic Tom, Reverse Cymbal) compile and process without NaN', () {
      final kick909 = EatBuiltinPresets.presets.firstWhere((p) => p.id == 'analog_909_kick');
      final snare909 = EatBuiltinPresets.presets.firstWhere((p) => p.id == 'analog_909_snare');
      final chh909 = EatBuiltinPresets.presets.firstWhere((p) => p.id == 'analog_909_closed_hihat');
      final ohh909 = EatBuiltinPresets.presets.firstWhere((p) => p.id == 'analog_909_open_hihat');
      final rim909 = EatBuiltinPresets.presets.firstWhere((p) => p.id == 'analog_909_rimshot');
      final mTom = EatBuiltinPresets.presets.firstWhere((p) => p.id == 'melodic_tom');
      final revCymbal = EatBuiltinPresets.presets.firstWhere((p) => p.id == 'reverse_cymbal');

      for (final p in [kick909, snare909, chh909, ohh909, rim909, mTom, revCymbal]) {
        expect(p.code, contains('def graph():'), reason: '${p.name} must have a native def graph()');
        final graph = EatscriptGraphDef.parse(p.code, trackName: p.name);
        expect(graph.nodes, isNotEmpty, reason: '${p.name} must parse into modular nodes');

        final compiled = graph.compileToGraphNode();
        final outBuffer = Float32List(512);
        final context = GraphContext(
          durationSec: 0.5,
          freq: 160.0,
          midiNote: 38,
          velocity: 0.9,
        );
        compiled.process(context, outBuffer);

        bool hasSignal = false;
        for (int i = 0; i < outBuffer.length; i++) {
          expect(outBuffer[i].isNaN, isFalse, reason: '${p.name} produced NaN');
          if (outBuffer[i].abs() > 0.0001) hasSignal = true;
        }
        expect(hasSignal, isTrue, reason: '${p.name} must produce audible audio signal');
      }
    });

    test('Expanded Dynamics FX & Console Resamplers (Dynamics Compressor, Bus Comp, Limiter, SNES Downsampler) process audio buffers', () {
      final dynComp = EatBuiltinPresets.presets.firstWhere((p) => p.id == 'dynamics_compressor');
      final busComp = EatBuiltinPresets.presets.firstWhere((p) => p.id == 'punchy_bus_comp');
      final limiter = EatBuiltinPresets.presets.firstWhere((p) => p.id == 'master_limiter');
      final snesDown = EatBuiltinPresets.presets.firstWhere((p) => p.id == 'snes_downsampler');

      final inBuffer = Float32List(512);
      for (int i = 0; i < 512; i++) {
        inBuffer[i] = math.sin(2.0 * math.pi * 300.0 * (i / 44100.0)) * 0.8;
      }

      for (final p in [dynComp, busComp, limiter, snesDown]) {
        expect(p.code, contains('def graph():'), reason: '${p.name} must have a native def graph()');
        final graph = EatscriptGraphDef.parse(p.code, trackName: p.name);
        expect(graph.nodes, isNotEmpty, reason: '${p.name} must parse into modular nodes');

        final compiled = graph.compileToGraphNode();
        final outBuffer = Float32List(512);
        final context = GraphContext(
          durationSec: 0.1,
          freq: 300.0,
          midiNote: 60,
          inputBuffer: inBuffer,
        );
        compiled.process(context, outBuffer);

        bool hasSignal = false;
        for (int i = 0; i < outBuffer.length; i++) {
          expect(outBuffer[i].isNaN, isFalse, reason: '${p.name} produced NaN');
          if (outBuffer[i].abs() > 0.0001) hasSignal = true;
        }
        expect(hasSignal, isTrue, reason: '${p.name} must process and output audio');
      }
    });

    test('EatScriptEngine registers and executes all new modular eat.node.* factories (compressor, limiter, 909, toms, cymbal)', () {
      const script = '''
def graph():
    in_sig = eat.node.input()
    comp = eat.node.compressor(in_sig, threshold=-12.0, ratio=4.0)
    lim = eat.node.limiter(comp, ceiling=-0.2)
    k909 = eat.node.tr909_kick(tune=0.018, decay=0.05)
    s909 = eat.node.tr909_snare(tune=0.0, snappy=1.0)
    tom = eat.node.melodic_tom(decay=0.85)
    cym = eat.node.reverse_cymbal(duration=1.5)
    return lim
''';
      final result = EatScriptEngine.compile(script);
      expect(result.isSuccess, isTrue);
      final graph = EatscriptGraphDef.parse(script);
      expect(graph.nodes.length, greaterThanOrEqualTo(7));
      expect(graph.findNode('comp')?.type, 'compressor');
      expect(graph.findNode('lim')?.type, 'limiter');
      expect(graph.findNode('k909')?.type, 'tr909_kick');
      expect(graph.findNode('s909')?.type, 'tr909_snare');
      expect(graph.findNode('tom')?.type, 'melodic_tom');
      expect(graph.findNode('cym')?.type, 'reverse_cymbal');
    });
  });
}


