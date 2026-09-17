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

## 3. Explicit Native DSP Engine Binding

Always declare the explicit engine ID in the script header using `# @engine: <id>` or programmatically via `eat.use_engine("<id>")`:

```python
# @id: vintage_epiano
# @name: Vintage Electric Piano
# @category: synth
# @engine: rhodes_epiano
```

### Canonical Engine IDs:
- **TB-303 Acid Bass**: `tb303` (or `acid303`)
- **Roland 808 Drums**: `analog_808_kick`, `analog_808_snare`, `analog_808_hihat`, `analog_808_cowbell`, `analog_808_tom`
- **Roland 909 Drums**: `analog_909_kick`, `analog_909_snare`, `analog_909_closed_hihat`, `analog_909_open_hihat`, `analog_909_clap`, `analog_909_rimshot`
- **Acoustic / FM Drums**: `fm_acoustic_kick`, `fm_acoustic_snare`, `fm_acoustic_tom`, `fm_acoustic_hihat`, `procedural_kick`, `procedural_snare`, `procedural_hihat`, `gm_drum_kit`
- **Pianos & Keyboards**: `rhodes_epiano`, `concert_grand_piano`, `felt_upright_piano`, `honky_tonk_piano`, `toy_piano`, `dx7_epiano`, `clavinet_d6`, `harpsichord`, `glockenspiel`, `music_box`, `xylophone`, `vibraphone`
- **Plucked Strings**: `spanish_guitar`, `flamenco_guitar`, `steel_acoustic_guitar`, `twelve_string_guitar`, `dobro_resonator`, `pedal_steel_guitar`, `bluegrass_banjo`, `hawaiian_ukulele`, `solo_violin`, `solo_viola`, `solo_cello`, `double_bass`, `string_ensemble`, `sitar`
- **Bass Synthesizers**: `moog_synth_bass`, `acoustic_bass`, `fretless_bass`, `upright_bass`
- **Chiptunes**: `c64_sid` (C64 6581/8580), `snes_dsp` (SNES SPC700), `ym2612` (Sega Genesis FM)
- **Audio FX**: `stereo_delay`, `stereo_chorus`, `snes_downsample`, `bitcrusher`, `tube_distortion`, `cab_designer`

*(Legacy boolean flags like `Eats303 = True` or `RhodesEPiano = True` are still supported for backwards compatibility).*

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

---

## 6. Bi-Directional Modular Synthesis (Approach C: `def graph():`)

Eatsbeats features a real-time modular synthesis studio (VCV Rack / Eurorack style) where **Eatscript `def graph():` is the single source of truth**. Visual drag-and-drop patching in the **DESIGN > MODULAR** tab compiles directly into zero-allocation native Dart/C `GraphNode` audio trees.

### Modular Instrument Archetype
```python
# @id: modular_lead
# @name: Modular Lead
# @category: synth

def init():
    return {
        "Cutoff": eat.param("Cutoff", 40.0, 16000.0, 2200.0, unit="Hz"),
        "Resonance": eat.param("Resonance", 0.1, 10.0, 1.5),
        "Drive": eat.param("Drive", 0.0, 4.0, 1.2),
        "Attack": eat.param("Attack", 0.001, 2.0, 0.01, unit="s"),
        "Decay": eat.param("Decay", 0.01, 3.0, 0.2, unit="s"),
        "Sustain": eat.param("Sustain", 0.0, 1.0, 0.6),
        "Release": eat.param("Release", 0.01, 3.0, 0.3, unit="s"),
    }

def graph():
    vco = eat.node.osc(wave="saw", detune=2.5)
    sub = eat.node.sub(octave=-1, level=0.5)
    vcf = eat.node.svf(in_sig=vco, cutoff="Cutoff", reso="Resonance", type="lowpass")
    sat = eat.node.saturate(in_sig=vcf, drive="Drive")
    env = eat.node.adsr(attack="Attack", decay="Decay", sustain="Sustain", release="Release")
    return sat * env
```

### Modular Insert Audio FX Archetype
```python
# @id: studio_channel_strip
# @name: Studio Channel Strip
# @category: audioFx

def init():
    return {
        "Threshold": eat.param("Threshold", -60.0, 0.0, -18.0, unit="dB"),
        "Ratio": eat.param("Ratio", 1.0, 20.0, 4.0, unit=":1"),
        "Attack": eat.param("Attack", 0.001, 0.2, 0.015, unit="s"),
        "Release": eat.param("Release", 0.01, 1.0, 0.1, unit="s"),
        "Ceiling": eat.param("Ceiling", -6.0, 0.0, -0.1, unit="dB"),
    }

def graph():
    in_sig = eat.node.input()
    comp = eat.node.compressor(in_sig, threshold="Threshold", ratio="Ratio", attack="Attack", release="Release")
    lim = eat.node.limiter(comp, ceiling="Ceiling")
    return lim
```

### Complete `eat.node.*` Primitives Catalog:
- **Oscillators & Sources**: `osc(wave, pitch_cv, freq)`, `sub(octave, level)`, `noise()`, `metallic_cluster(tune)`, `midi_to_cv()`, `input()`
- **Envelopes & Modulation**: `adsr(attack, decay, sustain, release)`, `decay(decay)`, `pitch_sweep(start, end, decay)`, `multi_burst(bursts, spread, decay)`, `lfo(rate, depth)`
- **Physical Modeling**:
  - *Exciters*: `hammer(hardness, click)`, `pluck(spread, bite)`, `bow(pressure, speed)`
  - *Resonators*: `waveguide(in_sig, damping, feedback)`, `modal_bank(in_sig, structure="bell"|"vibraphone"|"membrane")`
  - *Cavity*: `acoustic_body(in_sig, profile, gain)`
- **Filters & Dynamics**: `svf(in_sig, cutoff, reso, type)`, `moog(in_sig, cutoff, reso)`, `gain(in_sig, gain_cv, gain)`, `compressor(in_sig, threshold, ratio, attack, release, makeup, mix)`, `limiter(in_sig, ceiling, release)`
- **Studio FX**: `delay(in_sig, time)`, `chorus(in_sig, rate, depth, feedback, mix)`, `tremolo(in_sig, rate, depth)`, `bitcrush(in_sig, bits, downsample, mix)`, `saturate(in_sig, drive)`, `mix(in_a, in_b)`
- **Drum Synthesis**: `tr909_kick(tune, decay, attack)`, `tr909_snare(tune, snappy, tone)`, `tr909_sample(sample, tune, decay)`, `melodic_tom(decay, coupling, pitch_bend, stick)`, `reverse_cymbal(duration, curve, shimmer, choke)`
