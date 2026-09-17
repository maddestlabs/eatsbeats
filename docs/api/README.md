# Eatscript Engine API & DSP Reference

Welcome to the **Eatscript API & DSP Reference**. Eatscript is the embedded, pure-Dart, Pythonic audio domain-specific language (DSL) powering **Eatsbeats**.

The interactive web documentation is hosted at **[https://eatsbeats.app/docs/](https://eatsbeats.app/docs/)**, styled in the default **Ate Track** hardware console theme.

Eatscript runs in real time to synthesize instruments, process audio effects, generate algorithmic MIDI patterns, and dynamically declare hardware-inspired virtual instrument control panels.

---

## Key Principles & Architecture

1. **Pure Dart, Zero External Runtimes**: Eatscript is interpreted and compiled directly into pure Dart data structures and DSP evaluators. There is no Lua, Python, or C++ runtime dependency.
2. **Audio-Thread Safety**: Real-time DSP audio generation evaluates sample-by-sample or block-by-block with zero garbage collection allocations on the critical rendering path.
3. **Pythonic Simplicity**: Eatscript uses clean, readable 4-space indentation, Python-style functions (`def`), and keyword arguments.
4. **Hardware Declarative GUI**: Scripts declare their own modular, skeuomorphic hardware panels (`gui()`) complete with aluminum chassis, authentic knobs (TB-303, SNES, vintage Bakelite), nixie tubes, LCDs, oscilloscopes, and FFT analyzers.
5. **AI-Ready Grounding**: The Eatscript API is strictly structured and self-contained, enabling LLMs like Gemini to synthesize complete, working virtual instruments and audio FX from textual descriptions.

---

## Documentation Index

| Guide | Description |
| :--- | :--- |
| **[01. Syntax & Lifecycle](01_eatscript_syntax_lifecycle.md)** | Script archetypes (`synth`, `audioFx`, `midi`, `automation`), hook functions (`init`, `process`, `gui`), and runtime contexts. |
| **[02. Parameter System](02_parameter_system.md)** | Parameter definitions (`eat.param`), ranges, steps, units, and the dynamic **Variance / Humanize Engine**. |
| **[03. DSP Node Catalog](03_dsp_node_catalog.md)** | Comprehensive catalog of built-in synthesis nodes: Roland 808/909, TB-303 core, physical pianos, plucked strings, brass/reeds, chiptunes (SID, SNES, YM2612), and audio FX. |
| **[04. Declarative GUI DSL](04_declarative_gui_dsl.md)** | Full specification of the UI schema: chassis themes, 6-zone hardware knobs, sliders, nixie displays, scopes, spectrums, and vector skins. |
| **[05. MIDI & Music Theory](05_midi_and_music_theory.md)** | Note manipulation (`eat.add_note`), scale conformity, chord snapping, Euclidean rhythms, arpeggiators, and humanization. |
| **[06. DAW & Macro API](06_daw_macro_api.md)** | Host automation with `eat.daw` / `project`: track creation, pattern clip sequencing, mixer automation, and offline audio/video export. |
| **[07. Canonical Recipes](07_canonical_recipes.md)** | Golden copy-pasteable templates for virtual analog synths, acid basslines, stereo effects, and generative MIDI transformers. |

---

## Quick Example: Virtual Analog Synth Voice

```python
# --- Simple Eatscript Synth Voice ---
import math

def init():
    return {
        "Cutoff": eat.param("Cutoff", 100.0, 12000.0, 1800.0, unit="Hz"),
        "Resonance": eat.param("Resonance", 0.5, 10.0, 2.5),
        "EnvMod": eat.param("EnvMod", 0.0, 1.0, 0.6),
        "Decay": eat.param("Decay", 0.05, 2.0, 0.4, unit="s"),
    }

def gui():
    return {
        "panel": {
            "title": "ANALOG LEAD",
            "subtitle": "Virtual Analog Eatscript Synth",
            "background": "dark",
            "accent": "#FF8C00",
            "knobStyle": "chromeFluted",
            "layout": [
                {
                    "type": "row",
                    "children": [
                        {"type": "knob", "param": "Cutoff", "label": "CUTOFF"},
                        {"type": "knob", "param": "Resonance", "label": "RESO"},
                        {"type": "knob", "param": "EnvMod", "label": "ENV"},
                        {"type": "knob", "param": "Decay", "label": "DECAY"},
                    ]
                }
            ]
        }
    }

def process(time, freq, note, params, targetNote=0, isSlide=False, isAccent=False):
    cutoff = params.get("Cutoff", 1800.0)
    decay = params.get("Decay", 0.4)
    
    # Oscillator: Sawtooth wave
    phase = time * freq
    osc = 2.0 * (phase - math.floor(phase)) - 1.0
    
    # Envelope
    env = math.exp(-time / max(0.01, decay))
    
    # Output saturation
    return math.tanh(osc * env * 1.2)
```
