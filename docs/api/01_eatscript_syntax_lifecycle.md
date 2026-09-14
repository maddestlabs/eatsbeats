# Eatscript Syntax & Lifecycle

Eatscript scripts execute inside an isolated [EatScriptContext](file:///c:/git/eatsbeats/lib/eatscript/eats_api.dart) managed by the DAW engine. Each track channel, insert effect, or pipeline step can host an Eatscript.

---

## 1. Syntax Conventions

- **Language Style**: Pythonic indentation (4 spaces per level).
- **Functions**: Declared with `def name(args):`.
- **Comments**: Prefixed with `#`. Single-line metadata headers use `# @key: value`.
- **Math Library**: `import math` exposes standard functions: `math.sin`, `math.cos`, `math.exp`, `math.floor`, `math.pi`, `math.tanh`, `math.random()`.
- **Module Namespace**: Host functions are provided via the global `eat` dictionary, host parameters via `params`, and DAW orchestration via `eat.daw` or `project`.

---

## 2. Script Archetypes & Hook Signatures

Depending on where an Eatscript is deployed in Eatsbeats, it implements specific lifecycle hooks.

### Archetype A: Instrument / Synth Voice
Used on instrument tracks to render audio samples from MIDI notes.

```python
# 1. Parameter Declaration Hook
def init():
    return {
        "Cutoff": eat.param("Cutoff", 20.0, 20000.0, 1500.0),
    }

# 2. Hardware GUI Declaration Hook
def gui():
    return {
        "panel": {
            "title": "MY SYNTH",
            "layout": [{"type": "knob", "param": "Cutoff"}]
        }
    }

# 3. DSP Evaluation Hook (Sample-by-sample or block)
def process(time, freq, note, params, targetNote=0, isSlide=False, isAccent=False):
    """
    Called for each sample or DSP block.
    :param time: Current note playback elapsed time in seconds (resets on note-on)
    :param freq: Fundamental frequency in Hz (e.g. 440.0 for A4)
    :param note: MIDI note number (0..127)
    :param params: Current dictionary of active track parameter values
    :param targetNote: Target MIDI note for portamento/glissando slides
    :param isSlide: Boolean flag indicating 303-style slide legato
    :param isAccent: Boolean flag indicating velocity/accent boost
    :return: Float sample value in range [-1.0, 1.0] (clamped/saturated)
    """
    return math.sin(2.0 * math.pi * freq * time)
```

---

### Archetype B: Audio Effect (Insert or Master Bus)
Used in effect slots to process incoming audio streams.

```python
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
    """
    Called for incoming stereo audio blocks/samples.
    :param input_l: Left channel float audio signal
    :param input_r: Right channel float audio signal
    :param params: Active parameter values
    :return: List of two floats: [output_l, output_r]
    """
    mix = params.get("Mix", 0.5)
    return [input_l * mix, input_r * mix]
```

---

### Archetype C: MIDI Pipeline & Generative Pattern
Used in track MIDI pre-processors, arpeggiators, and pattern generators.

```python
def init():
    return {
        "Rate": eat.param("Rate", 0.25, 4.0, 1.0, step=0.25),
    }

def process(notes, time_ctx):
    """
    Called when generating or transforming track MIDI notes.
    :param notes: List of Note objects or Note dictionaries
    :param time_ctx: Host TimeContext (bpm, currentBar, currentBeat, songKeyRoot, isSongKeyMinor)
    :return: List of transformed notes
    """
    # Example: Snap all notes to current song chord
    return eat.chord_follow(notes, mode="chord")
```

---

### Archetype D: Parameter Automation Curve
Used for procedural LFOs and envelope generators bound to mixer lanes.

```python
def init():
    return {
        "Speed": eat.param("Speed", 0.1, 20.0, 1.0, unit="Hz"),
    }

def process(time, value, params):
    """
    Called to compute dynamic parameter modulation.
    :param time: Timeline position in seconds or fractional bars
    :param value: Base lane parameter value
    :param params: Parameter dictionary
    :return: Modulated float parameter value
    """
    speed = params.get("Speed", 1.0)
    return value + 0.2 * math.sin(2.0 * math.pi * speed * time)
```

---

## 3. High-Performance Native DSP Dispatch Flags

When an Eatscript defines standard parameters and GUI layouts, it can optionally delegate its heavy mathematical rendering directly to pre-compiled native Dart DSP engines. Setting a top-level boolean flag activates direct dispatch:

```python
# Enables Roland TB-303 analog transistor ladder DSP
Eats303 = True
JC303 = True

# Enables 8-bit hardware downsampler and bit-reduction
Bitcrusher = True

# Enables cabinet physical impulse resonator
CabDesigner = True

# Enables procedural Roland 808 / 909 drums
Analog808Kick = True
Analog909Snare = True
```

See **[03. DSP Node Catalog](03_dsp_node_catalog.md)** for the complete list of dispatch targets.
