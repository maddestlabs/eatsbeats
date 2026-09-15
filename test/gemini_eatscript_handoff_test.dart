import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatsbeats/eatscript/eats_script_engine.dart';
import 'package:eatsbeats/eatscript/eats_dsp_synthesizer.dart';
import 'package:eatsbeats/models/track_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Gemini AI Handoff Verification Tests', () {
    // ─────────────────────────────────────────────────────────────────────────
    // 1. Virtual Instrument Synthesis Handoff
    // ─────────────────────────────────────────────────────────────────────────
    test('Gemini generated Virtual Instrument compiles cleanly and renders audio', () {
      // Script generated following .agents/skills/eatscript/SKILL.md conventions:
      // - Pythonic syntax (4-space indent, def, # comments)
      // - Explicit @engine tag or Virtual Analog parameter declarations
      // - Hardware GUI panel with matching parameter bindings
      const aiGeneratedSynth = '''
# @id: cyberpunk_lead
# @name: Cyberpunk Neon Lead
# @category: synth
# @description: Dual-oscillator lead with sub-bass punch, dynamic resonant filter sweep, and overdrive.

def init():
    eat.param("waveform", 1.0, 0.0, 3.0, "") # 1.0 = Pulse/Square
    eat.param("pulse_width", 0.45, 0.1, 0.9, "")
    eat.param("sub_osc", 0.35, 0.0, 1.0, "")
    eat.param("cutoff", 2800.0, 50.0, 14000.0, "Hz")
    eat.param("resonance", 2.2, 0.1, 8.0, "")
    eat.param("env_mod", 0.45, -1.0, 1.0, "")
    eat.param("drive", 0.35, 0.0, 2.0, "")
    eat.param("attack", 0.008, 0.001, 1.0, "s")
    eat.param("decay", 0.25, 0.01, 2.0, "s")
    eat.param("sustain", 0.65, 0.0, 1.0, "")
    eat.param("release", 0.20, 0.01, 3.0, "s")

def process(time, freq, note, params):
    return eat.synth(note, time, params)

def gui():
    return {
        "panel": {
            "title": "NEON LEAD",
            "subtitle": "Cyberpunk Dual-DCO Synthesizer",
            "background": "carbon",
            "accent": "#00FFCC",
            "layout": [
                {
                    "type": "row",
                    "children": [
                        {"type": "knob", "param": "cutoff", "label": "CUTOFF", "unit": "Hz"},
                        {"type": "knob", "param": "resonance", "label": "RESO"},
                        {"type": "knob", "param": "env_mod", "label": "ENV MOD"},
                        {"type": "knob", "param": "drive", "label": "DRIVE"}
                    ]
                },
                {
                    "type": "row",
                    "children": [
                        {"type": "knob", "param": "attack", "label": "ATK", "unit": "s"},
                        {"type": "knob", "param": "decay", "label": "DEC", "unit": "s"},
                        {"type": "knob", "param": "sustain", "label": "SUS"},
                        {"type": "knob", "param": "release", "label": "REL", "unit": "s"}
                    ]
                }
            ]
        }
    }
''';

      // 1. Compile and verify static analysis diagnostics
      final comp = EatScriptEngine.compile(aiGeneratedSynth);
      expect(comp.isSuccess, isTrue);
      expect(comp.warnings, isEmpty, reason: 'AI generated script must have zero compiler warnings');
      expect(comp.guiLayout, isNotNull, reason: 'Hardware GUI layout must parse correctly');
      expect(comp.params.length, equals(11));

      // 2. Synthesize audio buffer
      final buffer = EatDspSynthesizer.synthesizeBuffer(
        code: aiGeneratedSynth,
        durationSec: 0.15,
        freq: 440.0, // A4
        note: 69,
        params: {
          'cutoff': 3200.0,
          'resonance': 3.0,
          'drive': 0.4,
          'waveform': 1.0,
          'sub_osc': 0.3,
        },
      );

      expect(buffer.length, equals((44100 * 0.15).toInt()));
      final hasAudio = buffer.any((s) => s.abs() > 0.02);
      expect(hasAudio, isTrue, reason: 'Synthesizer must produce audible audio signal');
      for (final s in buffer) {
        expect(s >= -1.0 && s <= 1.0, isTrue);
        expect(s.isNaN, isFalse);
      }
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 2. Audio Effect (Studio Sidechain Compressor) Handoff
    // ─────────────────────────────────────────────────────────────────────────
    test('Gemini generated Audio Effect compiles and configures compressor', () {
      const aiGeneratedFx = '''
# @id: punchy_bus_comp
# @name: Punchy Bus Compressor
# @category: audioFx
# @engine: compressor
# @description: Studio VCA bus compressor with auto-makeup gain and punchy attack.

def init():
    eat.use_engine("compressor")
    eat.param("Threshold", -14.0, -40.0, 0.0, "dB")
    eat.param("Ratio", 4.0, 1.0, 20.0, "")
    eat.param("Attack", 10.0, 0.5, 100.0, "ms")
    eat.param("Release", 100.0, 10.0, 1000.0, "ms")
    eat.param("Makeup", 2.5, 0.0, 24.0, "dB")
    eat.param("Mix", 1.0, 0.0, 1.0, "")

def gui():
    return {
        "panel": {
            "title": "VCA BUS COMPRESSOR",
            "subtitle": "Studio Master Dynamics & Glue",
            "background": "matteMetal",
            "accent": "#FFB300",
            "layout": [
                {
                    "type": "row",
                    "children": [
                        {"type": "knob", "param": "Threshold", "label": "THRESH", "unit": "dB"},
                        {"type": "knob", "param": "Ratio", "label": "RATIO"},
                        {"type": "knob", "param": "Attack", "label": "ATTACK", "unit": "ms"},
                        {"type": "knob", "param": "Release", "label": "RELEASE", "unit": "ms"},
                        {"type": "knob", "param": "Makeup", "label": "GAIN", "unit": "dB"},
                        {"type": "knob", "param": "Mix", "label": "MIX"}
                    ]
                }
            ]
        }
    }
''';

      final comp = EatScriptEngine.compile(aiGeneratedFx);
      expect(comp.isSuccess, isTrue);
      expect(comp.warnings, isEmpty);
      expect(comp.scriptType, equals('effect'));
      expect(comp.engineId, equals('compressor'));
      expect(comp.params.length, equals(6));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 3. Generative MIDI FX Pipeline Handoff
    // ─────────────────────────────────────────────────────────────────────────
    test('Gemini generated Generative MIDI FX creates musical notes in scale', () {
      const aiGeneratedMidiFx = '''
# @id: euclidean_acid_gen
# @name: Euclidean Acid Generator
# @category: midiFx
# @description: Generates algorithmic 16-step Euclidean bassline snapped to the song scale.

def init():
    eat.param("hits", 7, 1, 16)
    eat.param("steps", 16, 4, 32)
    eat.param("root_pitch", 36, 24, 60) # C2 default

def transform_notes(notes, params, time_ctx):
    eat.clear_notes()
    
    hits = int(params.get("hits", 7))
    steps = int(params.get("steps", 16))
    base_pitch = int(params.get("root_pitch", 36))
    
    # 1. Generate Euclidean rhythm pattern
    pattern = eat.euclidean(hits, steps)
    
    # 2. Pentatonic scale offsets
    minor_pentatonic = [0, 3, 5, 7, 10, 12]
    
    step_duration = 0.25 # 16th note
    for i in range(len(pattern)):
        if pattern[i] == 1:
            scale_degree = minor_pentatonic[i % len(minor_pentatonic)]
            pitch = base_pitch + scale_degree
            start_step = i * step_duration
            vel = 0.95 if (i % 4 == 0) else 0.80
            eat.add_note(pitch, start_step, step_duration * 0.85, vel)
    
    return eat.get_notes()
''';

      final comp = EatScriptEngine.compile(aiGeneratedMidiFx);
      expect(comp.isSuccess, isTrue, reason: comp.errorMessage);
      expect(comp.warnings, isEmpty);
      expect(comp.scriptType, equals('generator'));

      // Execute generative clip script
      final generatedNotes = EatScriptEngine.executeClipScript(
        aiGeneratedMidiFx,
        [], // Starting with empty clip
        paramValues: {'hits': 7, 'steps': 16, 'root_pitch': 36},
        tempo: 130.0,
        keyRoot: 0, // C
        isMinor: true,
      );

      expect(generatedNotes.length, equals(7), reason: 'Euclidean(7, 16) must generate exactly 7 notes');

      // Verify musical correctness
      for (final note in generatedNotes) {
        expect(note.pitch >= 36 && note.pitch <= 48, isTrue);
        expect(note.durationSteps, closeTo(0.2125, 0.01));
        expect(note.velocity >= 0.80 && note.velocity <= 0.95, isTrue);
      }
    });
  });
}
