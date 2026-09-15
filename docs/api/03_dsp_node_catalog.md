# Eatscript DSP Node Catalog

Eatsbeats provides an extensive library of pre-compiled, high-performance pure-Dart DSP models. 

### Explicit Engine Binding (Recommended)
You can deterministically bind any native DSP engine using either:
1. **Header Directive**: `# @engine: <id>`
2. **Programmatic Binding**: `eat.use_engine("<id>")` in `def init():`

*(Legacy scripts without `@engine` are also supported via backwards-compatible heuristic fallback).*

---

## 1. Drum & Percussion Synthesis

### Analog 808 Series
Authentic bridged T-network and transistor simulation of vintage TR-808 percussion.

| Engine ID (`# @engine: ...`) | Legacy Flag | Primary Parameters |
| :--- | :--- | :--- |
| `analog_808_kick` | `Analog808Kick = True` | `Tune`, `Tone`, `Decay`, `Punch`, `Distortion` |
| `analog_808_snare` | `Analog808Snare = True` | `Snappy`, `Tone`, `Decay` |
| `analog_808_hihat` | `Analog808HiHat = True` | `Decay`, `Metallic`, `Tone` |
| `analog_808_cowbell` | `Analog808Cowbell = True`| `Tune`, `Decay`, `HighPass` |
| `analog_808_tom` | `Analog808Tom = True` | `Pitch`, `Decay`, `LowPass` |

### Analog 909 Series
State-variable filter (SVF) oscillators, pulse punch generators, and authentic 6-bit / 8-bit ROM hi-hat playback.

| Engine Flag / Name | Primary Parameters |
| :--- | :--- |
| `Analog909Kick = True` | `Tune`, `Attack`, `Decay`, `Drive` |
| `Analog909Snare = True` | `Tune`, `Snappy`, `Decay`, `Tone` |
| `Analog909ClosedHiHat = True` | `Decay`, `Tune`, `Choke` |
| `Analog909OpenHiHat = True` | `Decay`, `Tune` |
| `Analog909Clap = True` | `Reverb`, `Spread`, `Decay` |
| `Analog909Rimshot = True` | `Pitch`, `Snap` |

### Dual-Mic FM Acoustic Drums
Physically-inspired modal FM drums with near/far microphone crossfading.

- `DualMicFmAcousticKick`
- `DualMicFmAcousticSnare`
- `DualMicFmAcousticTom`
- `DualMicFmAcousticHiHat`

---

## 2. Keyboard & Physical Piano Models

These nodes employ waveguide synthesis, modal resonance matrices, and non-linear hammer velocity maps.

| Engine Model | Style & Description |
| :--- | :--- |
| `ConcertGrandPiano` | Multi-velocity acoustic grand with sympathetic string resonance. |
| `FeltUprightPiano` | Muted felt hammers, warm mechanical damper sound. |
| `HonkyTonkPiano` | Detuned triple-string chorus and bright tack hammers. |
| `ToyPiano` | Bell-like metallic rod physical model. |
| `RhodesEPiano` | Tine and pickup physical emulation with dynamic bell bark. |
| `ClavinetD6` | Plucked reed with dual single-coil magnetic pickups. |
| `Harpsichord` | Bright plectrum-plucked string mechanism. |
| `DX7EPiano` | Authentic 6-operator FM electric piano. |
| `Glockenspiel` | Tuned steel bars with high-frequency transient ring. |
| `MusicBox` | Steel comb tine plucks. |
| `Xylophone` / `Vibraphone` | Resonated rosewood and motor tremolo vibrato. |

---

## 3. Plucked Strings & Guitars

Waveguide physical models implementing Karplus-Strong string equations with body formants.

| Engine Model | Description |
| :--- | :--- |
| `SpanishGuitar` | Warm nylon strings with classical body impulse. |
| `FlamencoGuitar` | Aggressive attack with bright cypress body resonance. |
| `SteelAcousticGuitar` | Bright bronze wound strings with dreadnought resonance. |
| `TwelveStringGuitar` | Octave-paired dual string chorus. |
| `DobroResonator` | Spun aluminum cone resonator guitar. |
| `PedalSteelGuitar` | Continuous pitch glissando and sustain bar dynamics. |
| `BluegrassBanjo` | Stretched mylar head body resonance with quick decay. |
| `HawaiianUkulele` | High-register koa wood chamber pluck. |
| `SoloViolin` / `SoloViola` / `SoloCello` / `DoubleBass` | Continuous bowed string physical friction models. |
| `StringEnsemble` | Multi-voice detuned orchestral string wash. |
| `Sitar` | Sympathetic resonant strings and curved jawari bridge buzz. |

---

## 4. Bass Synthesizers

| Engine Model | Key Flags | Description |
| :--- | :--- | :--- |
| **Eats-303 Acid Bass** | `Eats303 = True`, `JC303 = True` | Authentic Roland TB-303 transistor ladder filter, accent capacitor discharge, and portamento slide. |
| **Moog Synth Bass** | `MoogSynthBass = True` | 24dB/oct resonant transistor ladder with saturated overdrive. |
| **Acoustic & Upright Bass** | `AcousticBass`, `UprightBass` | Large double bass body cavity model with fingerboard clack. |
| **Fretless Bass** | `FretlessBass` | Mwah-sound finger slides and warm harmonic swell. |

---

## 5. Brass & Woodwind Physical Models

Non-linear exciter coupled with cylindrical/conical acoustic bore delay lines.

- **Brass**: `OrchestralTrumpet`, `TenorTrombone`, `Tuba`, `FrenchHorn`, `BrassSection`, `MutedTrumpet`.
- **Woodwinds**: `ConcertPiccolo`, `ConcertFlute`, `WoodenRecorder`, `PanFlute`, `TinWhistle`, `SweetOcarina`, `Shakuhachi`, `BlownBottle`.
- **Reeds**: `SopranoSax`, `AltoSax`, `TenorSax`, `BaritoneSax`, `Oboe`, `EnglishHorn`, `Bassoon`, `Clarinet`.

---

## 6. Ambient & Pad Synthesizers

| Engine Model | Key Flags / ID | Primary Parameters | Description |
| :--- | :--- | :--- | :--- |
| **Astral Shimmer Pad** | `ambient_pad`, `super_pad` | `Cutoff`, `Resonance`, `Detune`, `Warmth`, `Attack`, `Decay`, `Sustain`, `Release` | 7-unison detuned analog supersaw pad with wide stereo spread, slow sweeping resonant filter, and lush ADSR envelope. |

---

## 7. Chiptune & FM Engines

| Engine Model | Key Flags / ID | Description |
| :--- | :--- | :--- |
| **Commodore 64 SID** | `SIDSynth = True`, `c64_sid` | MOS 6581/8580 wave generator, pulse-width modulation, ring mod, and non-linear filter distortion. |
| **SNES SPC700** | `snesDsp = True`, `snes_dsp` | Authentic 32kHz downsampling, 8-tap FIR echo, and BRR interpolation. |
| **YM2612 FM Chip** | `ym2612 = True`, `ym2612` | Sega Genesis 4-operator FM sound chip with 9-bit DAC simulation. |
| **Voltaic Plasma** | `VoltaicPlasmaSynth` | Electric arc discharge audio synthesizer. |

---

## 8. Built-in Audio Effects

| FX Identifier | Primary Parameters | Description |
| :--- | :--- | :--- |
| `compressor` | `Threshold`, `Ratio`, `Attack`, `Release`, `Makeup`, `Mix` | Studio dynamic range compressor with true logarithmic decibel ballistics and external sidechain input. |
| `limiter` | `Ceiling`, `Threshold`, `Release` | Zero-overshoot brickwall peak limiter with 2ms lookahead buffer. |
| `multimode_filter` | `Cutoff`, `Resonance`, `GainDb`, `Type` | 2-pole RBJ biquad filter (Lowpass, Highpass, Bandpass, Notch, Peaking, Shelves). |
| `parametric_eq` | `Band1_Freq`..`Band5_Freq`, `Gain`, `Q` | 5-band studio parametric EQ with real-time composite magnitude response. |
| `stereo_delay` | `TimeMs`, `Feedback`, `Damping`, `Mix` | Stereo ping-pong tape delay line with analog feedback saturation. |
| `stereo_chorus` | `RateHz`, `DepthMs`, `BaseDelayMs`, `Mix` | Dual quadrature LFO multi-voice stereo chorus & flanger. |
| `bitcrusher` | `Bits`, `Downsample`, `Drive`, `Mix` | Hardware sample-rate and quantization bit-depth reduction. |
| `snes_downsample` | `Rate`, `EchoVolume`, `Mix` | Authentic Super Nintendo 32kHz interpolation and echo. |
| `tube_distortion` | `Drive`, `Bias`, `Tone`, `Mix` | Asymmetric triode tube saturation. |
| `cab_designer` | `CabSize`, `Resonance`, `MicDistance`, `Mix` | Speaker cabinet impulse and standing wave resonator. |

