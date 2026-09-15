import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/eatscript/eats_engine_registry.dart';
import 'package:eatsbeats/eatscript/eats_script_engine.dart';
import 'package:eatsbeats/eatscript/eats_dsp_synthesizer.dart';
import 'package:eatsbeats/eatscript/eats_synth_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EatEngineRegistry Tests', () {
    test('detectEngineId detects header directive # @engine: ...', () {
      const code1 = '''
# @id: my_acid_patch
# @name: My Acid
# @engine: tb303

def init():
    eat.param("Cutoff", 100.0, 5000.0, 1200.0)
''';
      expect(EatEngineRegistry.detectEngineId(code1), equals('tb303'));
      expect(EatEngineRegistry.isRegistered('tb303'), isTrue);

      const code2 = '''
# @model: rhodes_epiano
def init():
    pass
''';
      expect(EatEngineRegistry.detectEngineId(code2), equals('rhodes_epiano'));
    });

    test('detectEngineId detects programmatic eat.use_engine(...)', () {
      const code = '''
def init():
    eat.use_engine("analog_808_kick")
    eat.param("Tune", 20.0, 100.0, 45.0)
''';
      expect(EatEngineRegistry.detectEngineId(code), equals('analog_808_kick'));
      expect(EatEngineRegistry.isRegistered('analog_808_kick'), isTrue);
    });

    test('EatScriptEngine.compile reports engineId in EatCompilationResult', () {
      const code = '''
# @engine: rhodes_epiano
def init():
    eat.param("TineBell", 0.0, 1.0, 0.5)
''';
      final comp = EatScriptEngine.compile(code);
      expect(comp.isSuccess, isTrue);
      expect(comp.engineId, equals('rhodes_epiano'));
      expect(comp.scriptType, equals('synth'));
      expect(comp.params.length, equals(1));
      expect(comp.params.first.name, equals('TineBell'));
    });

    test('EatDspSynthesizer routes explicit @engine to correct synth and model', () {
      // 1. TB-303
      const tb303Code = '''
# @engine: tb303
def init():
    eat.param("Cutoff", 200.0, 4000.0, 1000.0)
''';
      expect(EatDspSynthesizer.resolveSynthType(tb303Code), equals(EatSynthType.acid303));

      // 2. Physical Piano Model
      const rhodesCode = '''
# @engine: rhodes_epiano
def init():
    pass
''';
      expect(EatDspSynthesizer.resolveSynthType(rhodesCode), equals(EatSynthType.physicalModel));

      // 3. Audio FX
      const delayCode = '''
# @engine: stereo_delay
def init():
    eat.param("TimeMs", 50.0, 1000.0, 250.0)
''';
      expect(EatDspSynthesizer.resolveFxType(delayCode), equals(EatFxType.stereoDelay));
    });

    test('EatDspSynthesizer retains backwards-compatible heuristic fallback when no @engine declared', () {
      // Legacy code with no @engine tag, but containing traditional string keywords
      const legacy303 = '''
# --- Eats-303 Acid Bassline ---
Eats303 = True
def init():
    eat.param("Cutoff", 200.0, 4000.0, 1000.0)
''';
      expect(EatDspSynthesizer.resolveSynthType(legacy303), equals(EatSynthType.acid303));
    });

    test('compile emits warning when unknown engine ID is specified', () {
      const code = '''
# @engine: non_existent_super_synth
def init():
    eat.param("gain", 1.0, 0.0, 2.0)
''';
      final comp = EatScriptEngine.compile(code);
      expect(comp.isSuccess, isTrue);
      expect(comp.warnings, isNotEmpty);
      expect(comp.warnings.first, contains("Unknown engine ID 'non_existent_super_synth'"));
      expect(comp.errorMessage, contains("[Diagnostics / Warnings]"));
    });

    test('compile emits warning when GUI widget references undeclared parameter', () {
      const code = '''
def init():
    eat.param("cutoff", 1000.0, 20.0, 20000.0, "Hz")

def gui():
    return {
        "panel": {
            "title": "Test Synth",
            "layout": [
                {"type": "knob", "param": "cutoff"},
                {"type": "knob", "param": "resonance_typo"}
            ]
        }
    }
''';
      final comp = EatScriptEngine.compile(code);
      expect(comp.isSuccess, isTrue);
      expect(comp.warnings, isNotEmpty);
      expect(comp.warnings.any((w) => w.contains("undeclared parameter 'resonance_typo'")), isTrue);
    });

    test('compile has no warnings when GUI parameters match init() declarations', () {
      const code = '''
def init():
    eat.param("cutoff", 1000.0, 20.0, 20000.0, "Hz")
    eat.param("resonance", 0.7, 0.1, 10.0, "")

def gui():
    return {
        "panel": {
            "title": "Test Synth",
            "layout": [
                {"type": "knob", "param": "cutoff"},
                {"type": "knob", "param": "resonance"}
            ]
        }
    }
''';
      final comp = EatScriptEngine.compile(code);
      expect(comp.isSuccess, isTrue);
      expect(comp.warnings, isEmpty);
    });

    test('EatDspSynthesizer synthesizes virtual analog buffer with user parameters', () {
      const code = '''
def init():
    eat.param("waveform", 0, 0, 3, "")
    eat.param("cutoff", 1500.0, 50.0, 10000.0, "Hz")
    eat.param("resonance", 1.5, 0.1, 8.0, "")
    eat.param("sub_osc", 0.3, 0.0, 1.0, "")
    eat.param("drive", 0.2, 0.0, 2.0, "")
''';
      final buffer = EatDspSynthesizer.synthesizeBuffer(
        code: code,
        durationSec: 0.1,
        freq: 220.0,
        note: 57,
        params: {
          'waveform': 1.0, // Square
          'cutoff': 1200.0,
          'resonance': 2.0,
          'sub_osc': 0.4,
          'drive': 0.3,
        },
      );

      expect(buffer.length, equals(4410)); // 0.1s * 44100
      // Ensure audio was generated and non-zero
      final hasSignal = buffer.any((sample) => sample.abs() > 0.01);
      expect(hasSignal, isTrue);
      // Ensure values are safely bounded
      for (final s in buffer) {
        expect(s >= -1.0 && s <= 1.0, isTrue);
      }
    });
  });
}

