---
name: eatscript
description: Authoritative reference and cheatsheet for creating Eatscript instruments, audio effects, MIDI pipelines, and hardware GUI panels in Eatsbeats.
---

# Eatscript AI Agent Skill & DSL Reference

When generating instruments, effects, or presets for Eatsbeats, **always use Eatscript**.
Eatsbeats does NOT use Lua. Never output Lua code (`end`, `local`, `function()`, `--`, etc.).

---

## 1. Syntax & Core Templates

Eatscript uses standard Pythonic indentation (4 spaces per level), `def`, and `#` comments.

### Synth Voice Archetype
```python
# @id: unique_synth_id
# @name: Instrument Display Name
# @category: synth
# @description: Short description.

import math

def init():
    return {
        "Cutoff": eat.param("Cutoff", 20.0, 16000.0, 1800.0, unit="Hz"),
        "Resonance": eat.param("Resonance", 0.5, 12.0, 3.5),
        "EnvMod": eat.param("EnvMod", 0.0, 1.0, 0.6),
        "Decay": eat.param("Decay", 0.05, 2.5, 0.4, unit="s"),
    }

def gui():
    return {
        "panel": {
            "title": "SYNTH NAME",
            "subtitle": "Subtitle Description",
            "background": "dark", # "dark", "silver", "snes", "grunge", "wood", "carbon"
            "accent": "#00FFE0",
            "knobStyle": "chromeFluted", # "chrome", "vintageBakelite", "snes", "tb303_acid_halo", "tb303_selector"
            "layout": [
                {
                    "type": "row",
                    "children": [
                        {"type": "knob", "param": "Cutoff", "label": "CUTOFF"},
                        {"type": "knob", "param": "Resonance", "label": "RESO"},
                        {"type": "knob", "param": "EnvMod", "label": "ENV MOD"},
                        {"type": "knob", "param": "Decay", "label": "DECAY"},
                    ]
                }
            ]
        }
    }

def process(time, freq, note, params, targetNote=0, isSlide=False, isAccent=False):
    # Retrieve params
    cutoff = params.get("Cutoff", 1800.0)
    decay = params.get("Decay", 0.4)
    
    # Oscillator calculation
    phase = time * freq
    osc = 2.0 * (phase - math.floor(phase)) - 1.0
    
    # Envelope calculation
    env = math.exp(-time / max(0.01, decay))
    
    return math.tanh(osc * env * 1.2)
```

### Audio FX Archetype
```python
# @id: unique_fx_id
# @name: FX Display Name
# @category: audioFx

def init():
    return {
        "Mix": eat.param("Mix", 0.0, 1.0, 0.5),
    }

def gui():
    return {
        "panel": {
            "title": "STEREO FX",
            "layout": [{"type": "knob", "param": "Mix"}]
        }
    }

def process(input_l, input_r, params):
    mix = params.get("Mix", 0.5)
    return [input_l * mix, input_r * mix]
```

---

## 2. Parameter System (`eat.param`)

```python
eat.param(
    name,                # str: Parameter key
    min,                 # num: Minimum value
    max,                 # num: Maximum value
    default,             # num: Initial value
    step=0.0,            # num: Step interval (0.0 = continuous)
    options=[],          # list: For switches/selectors (e.g. ["SAW", "SQR"])
    allow_variance=True, # bool: Whether track variance humanizes this param
    variance_scale=1.0,  # num: Variance sensitivity
)
```

- **Variance Helpers**:
  - `eat.variance()`: Current track master variance level (0.0 to 1.0).
  - `eat.vary_param(param_name, params, scale=0.1)`: Variance-jittered value.
  - `eat.vary(val, scale=0.1)`: Micro-drift applied to a raw float.

---

## 3. High-Performance Native DSP Flags

Setting a top-level boolean flag binds the script directly to high-performance pre-compiled Dart DSP engines:

- **TB-303 Acid Bass**: `Eats303 = True`, `JC303 = True`
- **Roland 808 Drums**: `Analog808Kick = True`, `Analog808Snare = True`, `Analog808HiHat = True`, `Analog808Cowbell = True`, `Analog808Tom = True`
- **Roland 909 Drums**: `Analog909Kick = True`, `Analog909Snare = True`, `Analog909ClosedHiHat = True`, `Analog909OpenHiHat = True`, `Analog909Clap = True`, `Analog909Rimshot = True`
- **Acoustic / FM Drums**: `DualMicFmAcousticKick = True`, `DualMicFmAcousticSnare = True`, `ProceduralKick = True`, `ProceduralSnare = True`, `ProceduralHiHat = True`
- **Pianos & Keyboards**: `RhodesEPiano = True`, `ConcertGrandPiano = True`, `FeltUprightPiano = True`, `HonkyTonkPiano = True`, `DX7EPiano = True`, `ClavinetD6 = True`, `Harpsichord = True`
- **Plucked Strings**: `SpanishGuitar = True`, `FlamencoGuitar = True`, `SteelAcousticGuitar = True`, `TwelveStringGuitar = True`, `DobroResonator = True`, `SoloViolin = True`, `DoubleBass = True`
- **Chiptunes**: `SIDSynth = True` (C64 6581/8580), `snesDsp = True` (SNES SPC700), `ym2612 = True` (Sega Genesis FM)
- **Audio FX**: `Bitcrusher = True`, `StereoDelay = True`, `StereoChorus = True`, `CabDesigner = True`

---

## 4. Hardware GUI Widgets

- Containers: `row`, `column`, `group`, `divider`, `spacer`.
- Controls: `knob`, `slider`, `fader`, `switch`, `button`, `segmented_pill`, `listbox`.
- Displays & Scopes: `oscilloscope`, `spectrum`, `meter` (VU), `nixie`, `lcd`, `spacevisualizer`, `waveshaper`.
- Knob Styles: `chrome`, `chromeFluted`, `vintageBakelite`, `snes`, `minimalWhite`, `tb303_selector`, `tb303_acid_halo`, `anodizedKnurled`, `twoToneStepped`.

---

## 5. MIDI & Music Theory Functions

- `eat.add_note(pitch, start=0.0, duration=1.0, velocity=0.85)`
- `eat.get_notes()`, `eat.clear_notes()`
- `eat.scale(root="C", type="major")`
- `eat.scale_conform(pitch, root=0, is_minor=False)`
- `eat.snap_to_chord(pitch, chord="Cmaj7", mode="chord")`
- `eat.euclidean(step, steps=16, pulses=4, shift=0)`
- `eat.arpeggiate(notes, rate=1.0, octaves=2, pattern="up")`
- `eat.chord_follow(notes, mode="chord")`
- `eat.humanize(notes, timing=0.02, velocity=0.08)`
- `eat.transpose(notes, semitones=0)`
