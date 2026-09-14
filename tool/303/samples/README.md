# TB-303 Reference Calibration Samples

Place your reference TB-303 audio recording files (`.wav`) in this folder.

## Supported Audio Formats
- **Format**: `.wav` (RIFF)
- **Sample Rates**: 44.1 kHz, 48.0 kHz, or 96.0 kHz
- **Bit Depth**: 16-bit, 24-bit PCM, or 32-bit float
- **Channels**: Mono or Stereo (stereo files are automatically summed to mono for analysis)

---

## File Naming Convention & Parameter Mapping

The calibration tool can parse synthesis parameters directly from filename tags or from an optional sidecar `.json` file.

### Option A: Filename Tags (Fastest)
Format:
```
<waveform>_<note>_[tag_value...].wav
```

Available tags:
- **`wave` / `saw` / `sqr`**: Waveform type (`saw` = sawtooth, `sqr` = square)
- **`note` / `pitch`**: MIDI note number (e.g., `36`, `48`) or note name (`C2`, `D#2`, `A1`)
- **`cut` / `cutoff`**: Cutoff position (0.0 to 1.0 or 0 to 100%)
- **`res` / `reso`**: Resonance position (0.0 to 1.0 or 0 to 100%)
- **`env` / `envmod`**: Envelope mod depth (0.0 to 1.0 or 0 to 100%)
- **`dec` / `decay`**: Decay time (0.0 to 1.0 or 0 to 100%)
- **`acc` / `accent`**: Accent flag (`1` or `0`, or `accent` present in name)
- **`slide`**: Slide portamento flag (`1` or `0`, or `slide` present in name)

#### Examples:
- `saw_C2_cut40_res80_env70_dec30_accent.wav`
  - Wave: Sawtooth
  - Note: C2 (MIDI 36)
  - Cutoff: 0.40
  - Resonance: 0.80
  - EnvMod: 0.70
  - Decay: 0.30
  - Accent: true
- `sqr_G1_cut60_res50_normal.wav`
  - Wave: Square
  - Note: G1 (MIDI 31)
  - Cutoff: 0.60
  - Resonance: 0.50
  - EnvMod: default (0.75)
  - Decay: default (0.28)
  - Accent: false

---

### Option B: Sidecar JSON Metadata
If a `.wav` file has an identical filename ending with `.json` (e.g., `sample_01.wav` and `sample_01.json`), the parameters in JSON take precedence:

```json
{
  "waveform": "saw",
  "note": "C2",
  "durationSec": 0.5,
  "params": {
    "Cutoff": 1400.0,
    "Resonance": 9.2,
    "EnvMod": 0.75,
    "Decay": 0.28,
    "Accent": 0.8,
    "Drive": 0.2
  },
  "isAccent": true,
  "isSlide": false
}
```

---

## Recommended Calibration Set (6–10 Samples)
For maximum authenticity across all operating regimes, include:
1. **Low Cutoff, Zero Resonance (Clean Sub & Wave Shape)**:
   - `saw_C2_cut20_res0.wav`
   - `sqr_C2_cut20_res0.wav`
2. **Medium Cutoff, High Resonance (Filter Q & Diode Feedback)**:
   - `saw_C2_cut50_res90.wav`
   - `sqr_C2_cut50_res90.wav`
3. **Accent Dynamics (Transient Squelch & Capacitor Decay)**:
   - `saw_C2_cut50_res80_acc1.wav`
   - `saw_C2_cut50_res80_acc0.wav`
4. **Slide Portamento (Frequency Glide & Envelope Retriggering)**:
   - `saw_C2_to_C3_slide.wav`
