import 'eats_script_library.dart';

/// Astral Shimmer Pad (`astral_shimmer_pad`) Preset.
///
/// 7-Unison Detuned Analog Ambient Pad Synthesizer featuring rich stereo spread,
/// slow sweeping resonant filter, and lush ADSR envelope.
class AmbientPadPreset {
  static const EatScriptDef preset = EatScriptDef(
    id: 'astral_shimmer_pad',
    name: 'Astral Shimmer Pad',
    category: EatScriptCategory.instrument,
    description: '7-unison detuned analog ambient pad with wide stereo spread, slow sweeping resonant filter, and lush ADSR envelope.',
    code: '''
# @id: astral_shimmer_pad
# @name: Astral Shimmer Pad
# @category: synth
# @engine: ambient_pad
# @description: 7-unison detuned analog ambient pad with wide stereo spread, slow sweeping resonant filter, and lush ADSR envelope.

def init():
    eat.use_engine("ambient_pad")
    eat.param("Cutoff", 2400.0, 100.0, 16000.0, "Hz")
    eat.param("Resonance", 0.55, 0.1, 5.0, "")
    eat.param("Detune", 14.0, 1.0, 35.0, "cents")
    eat.param("Warmth", 0.65, 0.0, 1.0, "")
    eat.param("Attack", 0.85, 0.05, 4.0, "s")
    eat.param("Decay", 1.5, 0.1, 6.0, "s")
    eat.param("Sustain", 0.85, 0.0, 1.0, "")
    eat.param("Release", 2.5, 0.1, 8.0, "s")

def process(time, freq, note, params):
    return eat.synth(note, time, params)

def gui():
    return {
        "panel": {
            "title": "ASTRAL SHIMMER PAD",
            "subtitle": "7-Unison Detuned Analog Ambient Synthesizer",
            "background": "carbon",
            "accent": "#00E5FF",
            "layout": [
                {
                    "type": "row",
                    "children": [
                        {"type": "knob", "param": "Cutoff", "label": "CUTOFF", "unit": "Hz", "knobStyle": "vintage"},
                        {"type": "knob", "param": "Resonance", "label": "RESO", "knobStyle": "vintage"},
                        {"type": "knob", "param": "Detune", "label": "DETUNE", "unit": "ct", "knobStyle": "vintage"},
                        {"type": "knob", "param": "Warmth", "label": "WARMTH", "knobStyle": "vintage"}
                    ]
                },
                {
                    "type": "row",
                    "children": [
                        {"type": "knob", "param": "Attack", "label": "ATTACK", "unit": "s"},
                        {"type": "knob", "param": "Decay", "label": "DECAY", "unit": "s"},
                        {"type": "knob", "param": "Sustain", "label": "SUSTAIN"},
                        {"type": "knob", "param": "Release", "label": "RELEASE", "unit": "s"}
                    ]
                }
            ]
        }
    }
''',
  );
}
