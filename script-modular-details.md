# Eatsbeats Modular Architecture: Scripts vs. Modular View

This document explains how **Lua Scripts** and the **Modular Rack View** work together in Eatsbeats, using **Eats-303** as a clear reference example.

---

## 1. High-Level Architecture: Single Source of Truth

In Eatsbeats, **Lua script code is the single source of truth** for all instruments, audio effects, MIDI effects, and rack layouts.

```
┌────────────────────────────────────────────────────────┐
│                   Lua Script File                      │
│                                                        │
│  1. Init & Parameters   →  Param.add(...)              │
│  2. Modular DSP Math    →  Sub-functions (.vco, .vcf)  │
│  3. Real-Time Process   →  process(time, freq, params) │
│  4. Skeuomorphic GUI    →  function .gui()             │
│  5. Modular Topology    →  function .rack()            │
└──────────────────────────┬─────────────────────────────┘
                           │
             Bi-Directional Synchronization
                           │
       ┌───────────────────┴───────────────────┐
       ▼                                       ▼
┌────────────────────────┐           ┌────────────────────────┐
│     Modular View       │           │     Faceplate GUI      │
│  • Hardware Eurorack   │           │  • Dynamic Knobs / LEDs│
│  • Patch Cables (I/O)  │           │  • 3D Space Visualizer │
│  • Visual Re-Patching  │           │  • Popout Floating Win │
└────────────────────────┘           └────────────────────────┘
```

---

## 2. What You See in the Script Section

When viewing an instrument like **Eats-303** in the Scripts pane, the code is organized into 5 distinct, modular sections:

### Section A: Parameter Declarations (`.init()`)
Defines the parameters that the engine, GUI, and automation timeline can control (e.g. Cutoff, Resonance, EnvMod, Decay, Accent, Overdrive).

### Section B: Modular DSP Sub-Functions
Rather than a giant monolithic block of math, DSP subroutines are broken down into discrete module functions that mirror analog synthesizer hardware:
1. **`Eats303.oscillator(phase, wave, slide)`**: Simulates the 303's leaky-integrator transistor core (Sawtooth & Square waveforms with portamento pitch sliding).
2. **`Eats303.envelope(time, decay, accent)`**: Generates the exponential attack/decay envelope with accent boost.
3. **`Eats303.diode_filter(sample, cutoff, reso, env)`**: 4-pole 18dB/24dB diode ladder lowpass filter with non-linear feedback and resonance self-oscillation.
4. **`Eats303.overdrive(sample, drive)`**: Asymmetric diode clipping and saturation stage.

### Section C: Real-Time Audio Process (`.process(...)`)
Combines the modular DSP sub-functions in real-time for every sample or buffer frame:
```lua
function Eats303.process(time, freq, note, params)
  local osc = Eats303.oscillator(phase, wave, isSlide)
  local env = Eats303.envelope(time, decay, accent)
  local flt = Eats303.diode_filter(osc, cutoff, reso, env)
  return Eats303.overdrive(flt, drive)
end
```

### Section D: Custom Faceplate GUI (`.gui()`)
Declares the layout, background theme, interactive knobs, switches, nixie displays, and canvas visualizers rendered on track properties and popout windows.

### Section E: Programmable 2D Canvas Graphics (`.draw()`)
Allows custom vector graphics, envelope curves, custom filter responses, XY pads, and visualizers to be rendered directly to hardware screen elements at 60 FPS:
```lua
function Eats303.draw(canvas, w, h, params, time)
  canvas:clear("#090D14")
  canvas:grid(8, 6, "#00E5FF")
  canvas:rect(10, 10, w - 20, h - 20, "#00E5FF", false, 1.5, 4.0)
  canvas:line(20, h - 30, w * 0.5, 30, "#FF3366", 2.0)
  canvas:circle(w * 0.5, 30, 6, "#00FF9D", true)
  canvas:text("303 DIODE FILTER RESPONSE", 25, 25, 10, "#FFFFFF", "left")
  canvas:waveform(1.0, 1.0, "#00E5FF", 1.8)
end
```

### Section F: Declarative Rack Definition (`.rack()`)
Declares the Eurorack hardware modules, rows, HP widths, jack categories, and default patch cables:
```lua
function Eats303.rack()
  return {
    rows = {
      -- ROW 1: Oscillators & Filter Core
      {
        { id = "vco", title = "303 SAW/SQR VCO",  hp = 12, row = 1, category = "VCO" },
        { id = "vcf", title = "18DB DIODE VCF",   hp = 14, row = 1, category = "VCF" },
        { id = "drive", title = "ANALOG OVERDRIVE", hp = 12, row = 1, category = "FX" },
      },
      -- ROW 2: Modulators & Master Output
      {
        { id = "env",    title = "ACID ACCENT ENV", hp = 14, row = 2, category = "MOD" },
        { id = "master", title = "MASTER OUT VCA",  hp = 14, row = 2, category = "OUT" },
      }
    },
    cables = {
      { from = "1:0:1", to = "1:1:0", color = "audio" },      -- VCO Out -> VCF In
      { from = "2:0:0", to = "1:1:1", color = "modulation" }, -- ENV Out -> Cutoff CV
      { from = "1:1:2", to = "1:2:0", color = "audio" },      -- VCF Out -> Drive In
      { from = "1:2:1", to = "2:1:0", color = "audio" },      -- Drive Out -> Master L
    }
  }
end
```

---

## 3. What You See in the Modular View

The Modular View provides a visual Eurorack/VCV Rack synthesizer environment:
- **Faceplate Modules**: Metal-brushed faceplates with live interactive knobs, LEDs, and toggle switches.
- **HP (Horizontal Pitch) Width**: Standard Eurorack widths (10HP, 12HP, 14HP, 16HP).
- **Subpixel I/O Jacks**: Input and output jacks categorized by signal type:
  - **Yellow / Gold**: Audio signals
  - **Green / Emerald**: Modulation CV (Control Voltage)
  - **Magenta / Purple**: 1V/Octave Pitch CV
  - **Cyan / Blue**: Gate / Trigger pulses
- **Physics Patch Cables**: Subpixel Bezier cables that sag with gravity, oscillate, and can be patched or disconnected dynamically with drag-and-drop.
- **Custom / Script Modules**: Programmable DSP modules displaying a glowing `DSP ACTIVE` badge and an `EDIT` button to jump straight to custom script code.

---

## 4. How the Script and Modular View Tie Together (Bi-Directional Sync)

1. **Script → Modular View**:
   - When you load a track or open the Modular tab, the engine parses `function <Name>.rack()` from the Lua script.
   - It instantiates the visual faceplates matching the IDs and connects the patch cables specified in the Lua table.
   - If a script doesn't contain a `.rack()` block, `ModularRackDsl.ensureRackBlock()` synthesizes a default modular rack topology automatically without modifying your DSP logic.

2. **Modular View → Script**:
   - When you click **+ ADD MODULE**, move modules, re-route a patch cable, or disconnect a jack in the Modular View, the canvas calls `ModularRackDsl.serialize(...)`.
   - This automatically regenerates the `function <Name>.rack()` block and writes it back into `track.luaScriptCode`.
   - Your custom DSP algorithms, math, and GUI declarations are completely preserved.

---

## 5. Eats-303 Component Mapping Reference

| Visual Module in Modular Rack | Script DSP Sub-Function | Input Jacks | Output Jacks |
|---|---|---|---|
| **303 SAW/SQR VCO** | `Eats303.oscillator(...)` | `Pitch CV`, `Gate In` | `Saw Out`, `Square Out` |
| **18DB DIODE VCF** | `Eats303.diode_filter(...)` | `Audio In`, `Cutoff CV` | `LP Out`, `HP Out` |
| **ACID ACCENT ENV** | `Eats303.envelope(...)` | `Gate In`, `Accent CV` | `Env Out`, `Accent Out` |
| **ANALOG OVERDRIVE** | `Eats303.overdrive(...)` | `Audio In`, `Drive CV` | `Drive Out` |
| **MASTER OUT VCA** | Volume / Pan scaling | `L In`, `R In` | `Main L`, `Main R` |

---

## 6. Tips for Creating Custom Modular Scripts

- **Add Custom Sub-Functions**: You can define any helper function (e.g. `MySynth.wavefolder()`, `MySynth.ring_mod()`) inside your Lua script.
- **Add a Script Module**: In Modular View, click **+ ADD MODULE** and choose **Custom Script Core** to drop a generic programmable DSP module into your rack.
- **Instant Code Jump**: Click the **EDIT** button on any custom module or the **Code** icon `{ }` in track properties to jump straight to the source code for that instrument.
