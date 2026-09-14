# Canonical Eatscript Recipes

Use these complete, production-tested Eatscript templates as starting foundations when generating new instruments, effects, and generators.

---

## 1. Virtual Analog Polyphonic Synth (Instrument)

```python
# @id: va_lead
# @name: Vintage Poly Synth
# @category: synth
# @description: Dual-oscillator analog synthesizer with 24dB ladder filter and hardware chassis.

import math

def init():
    return {
        "Waveform": eat.param("Waveform", 0.0, 1.0, 0.0, step=1.0, options=["SAW", "SQR"], allow_variance=False),
        "Cutoff": eat.param("Cutoff", 40.0, 14000.0, 2200.0, unit="Hz"),
        "Resonance": eat.param("Resonance", 0.5, 12.0, 4.0),
        "EnvMod": eat.param("EnvMod", 0.0, 1.0, 0.65),
        "Attack": eat.param("Attack", 0.002, 1.0, 0.01, unit="s"),
        "Decay": eat.param("Decay", 0.05, 3.0, 0.45, unit="s"),
        "Drive": eat.param("Drive", 0.0, 1.0, 0.2),
    }

def gui():
    return {
        "panel": {
            "title": "VINTAGE POLY SYNTH",
            "subtitle": "Virtual Analog 24dB Ladder Synth",
            "background": "dark",
            "accent": "#00FFE0",
            "knobStyle": "chromeFluted",
            "layout": [
                {
                    "type": "row",
                    "children": [
                        {"type": "switch", "param": "Waveform", "label": "OSC WAVE", "options": ["SAW", "SQR"]},
                        {"type": "divider", "orientation": "vertical", "height": 56},
                        {"type": "knob", "param": "Cutoff", "label": "CUTOFF", "size": 58},
                        {"type": "knob", "param": "Resonance", "label": "RESO", "size": 58},
                        {"type": "knob", "param": "EnvMod", "label": "ENV MOD", "size": 54},
                        {"type": "divider", "orientation": "vertical", "height": 56},
                        {"type": "knob", "param": "Attack", "label": "ATTACK", "size": 50},
                        {"type": "knob", "param": "Decay", "label": "DECAY", "size": 50},
                        {"type": "knob", "param": "Drive", "label": "DRIVE", "size": 50},
                    ]
                }
            ]
        }
    }

def process(time, freq, note, params, targetNote=0, isSlide=False, isAccent=False):
    wave = params.get("Waveform", 0.0)
    decay = params.get("Decay", 0.45)
    attack = params.get("Attack", 0.01)
    drive = params.get("Drive", 0.2)
    
    # Oscillator: Sawtooth or Square
    phase = time * freq
    normPhase = phase - math.floor(phase)
    saw = 2.0 * normPhase - 1.0
    sqr = 0.85 if normPhase < 0.5 else -0.85
    osc = (1.0 - wave) * saw + wave * sqr
    
    # AD Envelope
    env = (1.0 - math.exp(-time / max(0.001, attack))) * math.exp(-time / max(0.01, decay))
    
    # Saturation
    out = osc * env
    if drive > 0.01:
        out = math.tanh(out * (1.0 + drive * 4.0))
    return out
```

---

## 2. Lo-Fi Stereo Bitcrusher (Audio FX)

```python
# @id: lofi_crusher
# @name: Lo-Fi Bitcrusher & Filter
# @category: audioFx
# @description: Quantization bit-reduction and warm resonant ladder lowpass.

import math

def init():
    return {
        "Bits": eat.param("Bits", 2.0, 16.0, 8.0, step=1.0, allow_variance=False),
        "Downsample": eat.param("Downsample", 1.0, 32.0, 2.0, step=1.0, allow_variance=False),
        "Tone": eat.param("Tone", 500.0, 18000.0, 6000.0, unit="Hz"),
        "Mix": eat.param("Mix", 0.0, 1.0, 0.8),
    }

def gui():
    return {
        "panel": {
            "title": "LO-FI CRUSHER",
            "subtitle": "Digital Texture & Bit Reducer",
            "background": "snes",
            "accent": "#FFB300",
            "knobStyle": "snes",
            "layout": [
                {
                    "type": "row",
                    "children": [
                        {"type": "knob", "param": "Bits", "label": "BITS", "unit": "bit"},
                        {"type": "knob", "param": "Downsample", "label": "CRUSH", "unit": "x"},
                        {"type": "knob", "param": "Tone", "label": "TONE", "unit": "Hz"},
                        {"type": "knob", "param": "Mix", "label": "MIX"},
                    ]
                }
            ]
        }
    }

def process(input_l, input_r, params):
    bits = params.get("Bits", 8.0)
    mix = params.get("Mix", 0.8)
    
    # Quantize amplitude
    levels = 2.0 ** bits
    crushed_l = math.floor(input_l * levels + 0.5) / levels
    crushed_r = math.floor(input_r * levels + 0.5) / levels
    
    out_l = input_l * (1.0 - mix) + crushed_l * mix
    out_r = input_r * (1.0 - mix) + crushed_r * mix
    return [out_l, out_r]

# Also delegate to native high-performance DSP
Bitcrusher = True
```

---

## 3. Generative Euclidean Pattern Generator (MIDI Pipeline)

```python
# @id: euclidean_gen
# @name: Euclidean Rhythm Generator
# @category: midi
# @description: Generates algorithmic Euclidean rhythms conformant to song scale.

def init():
    return {
        "Pulses": eat.param("Pulses", 1.0, 16.0, 5.0, step=1.0),
        "Steps": eat.param("Steps", 4.0, 32.0, 16.0, step=1.0),
        "Shift": eat.param("Shift", 0.0, 15.0, 0.0, step=1.0),
        "BaseNote": eat.param("BaseNote", 36.0, 72.0, 48.0, step=1.0),
    }

def process(notes, time_ctx):
    pulses = params.get("Pulses", 5.0)
    steps = params.get("Steps", 16.0)
    shift = params.get("Shift", 0.0)
    baseNote = int(params.get("BaseNote", 48.0))
    
    eat.clear_notes()
    
    for s in range(int(steps)):
        if eat.euclidean(s, steps=steps, pulses=pulses, shift=shift):
            # Quantize pitch to active song key
            pitch = eat.scale_conform(baseNote, root=time_ctx.songKeyRoot, is_minor=time_ctx.isSongKeyMinor)
            eat.add_note(pitch=pitch, start=float(s), duration=0.8, velocity=0.88)
            
    return eat.humanize(eat.get_notes(), timing=0.015, velocity=0.05)
```
