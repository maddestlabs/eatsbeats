# Declarative GUI DSL

Eatscript allows developers and AI agents to design hardware-quality instrument and FX control panels using the declarative `def gui():` function.

---

## 1. The Panel Definition

The top-level structure returned by `gui()` configures the chassis:

```python
def gui():
    return {
        "panel": {
            "title": "EATS-303",                  # Main header text
            "subtitle": "Acid Bass Synthesizer",  # Sub-header text
            "background": "silver",               # Theme texture: silver, dark, grunge, snes, wood, carbon
            "accent": "#00FFE0",                  # Primary UI highlight color (hex)
            "knobStyle": "chrome",                # Default knob appearance for all children
            "sideCheeks": "wood",                 # Optional side panel cheeks: wood, metal, none
            "cornerRadius": 8.0,                  # Chassis corner rounding in pixels
            "layout": [                           # Array of layout rows, columns, and widgets
                ...
            ]
        }
    }
```

---

## 2. Layout Containers

Widgets are positioned using hierarchical layout nodes:

### Row Container
Aligns child widgets horizontally:
```python
{
    "type": "row",
    "align": "space_around",  # "start", "center", "end", "space_between", "space_around", "space_evenly"
    "crossAlign": "center",   # "start", "center", "end"
    "children": [
        {"type": "knob", "param": "Cutoff", "label": "CUTOFF"},
        {"type": "knob", "param": "Resonance", "label": "RESO"}
    ]
}
```

### Column Container
Aligns child widgets vertically:
```python
{
    "type": "column",
    "align": "center",
    "children": [...]
}
```

### Group Box
Surrounds child elements with a labeled bordered chassis compartment:
```python
{
    "type": "group",
    "title": "FILTER SECTION",
    "children": [...]
}
```

### Dividers & Spacers
- **Horizontal Divider**: `{"type": "divider", "orientation": "horizontal"}`
- **Vertical Divider**: `{"type": "divider", "orientation": "vertical", "height": 60}`
- **Spacer**: `{"type": "spacer", "size": 16}`

---

## 3. Interactive Control Widgets

### Knobs (`type: "knob"`)
The core rotary control in Eatsbeats.

```python
{
    "type": "knob",
    "param": "Cutoff",         # Target parameter key
    "label": "CUTOFF",         # Display label
    "unit": "Hz",              # Measurement unit
    "size": 56,                # Diameter in pixels (default: 52)
    "knobStyle": "chrome",     # "standard", "chrome", "vintage", "snes", "minimalWhite", "hardwareKnob"
}
```

#### 6-Zone Physical Hardware Knob Styles
Set `knobStyle: "hardwareKnob"` or provide a specialized hardware token:
- `"tb303_selector"`: Roland stepped rotary waveform/pattern selector.
- `"tb303_acid_halo"`: Glowing LED indicator ring with silver spun center cap.
- `"tb303_potentiometer"`: Fluted silver skirted knob with top indicator notch.
- `"vintageBakelite"`: Heavy fluted black/brown bakelite with white pointers.
- `"chromeFluted"`: Machined aluminum audio console knob.
- `"anodizedKnurled"`: Diamond-knurled industrial metal knob.
- `"twoToneStepped"`: Dual-color stepped studio knob.
- `"illuminatedEncoder"`: Modern optical endless encoder with neon ring.

### Sliders & Faders (`type: "slider"`, `type: "fader"`)
```python
{
    "type": "slider",
    "param": "Volume",
    "label": "LEVEL",
    "orientation": "vertical",  # "vertical" or "horizontal"
    "sliderStyle": "capsule",   # "console", "capsule", "minimalPill"
    "size": 120                 # Length in pixels
}
```

### Switches & Toggles (`type: "switch"`)
```python
{
    "type": "switch",
    "param": "Waveform",
    "label": "WAVE",
    "options": ["SAW", "SQR"]   # Switch state options
}
```

### Segmented Pill Selectors (`type: "segmented_pill"`)
Modern horizontal multi-choice selector:
```python
{
    "type": "segmented_pill",
    "param": "FilterMode",
    "label": "MODE",
    "options": ["LP", "BP", "HP", "NOTCH"]
}
```

---

## 4. Visualizers & Displays

Eatscript instruments can embed real-time visualizers into their panels:

| Widget Type | Description |
| :--- | :--- |
| `oscilloscope` | Real-time audio waveform trace display with persistence. |
| `spectrum` | 64-band FFT frequency analyzer. |
| `nixie` | Glowing vacuum tube numerical readout for parameters and tempos. |
| `lcd` | 16x2 backlit dot-matrix LCD panel displaying patch info. |
| `meter` | Analog VU meter with needle ballistic physics. |
| `spacevisualizer` | 3D wireframe room/cabinet acoustic response display. |
| `waveshaper` | Interactive transfer curve graph showing distortion clipping profiles. |

### Visualizer Example: Embedded Scope & Nixie Readout
```python
{
    "type": "row",
    "children": [
        {"type": "nixie", "param": "Cutoff", "label": "FREQ"},
        {"type": "oscilloscope", "width": 140, "height": 60, "accent": "#00FFCC"}
    ]
}
```
