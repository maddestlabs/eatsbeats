# Eatscript DSP Node Catalog

Eatsbeats provides an extensive library of pre-compiled, high-performance pure-Dart DSP models. By including the corresponding identifier or dispatch flag in your Eatscript, the host will bind real-time, zero-alloc audio evaluators directly to your parameters.

---

## 1. Drum & Percussion Synthesis

### Analog 808 Series
Authentic bridged T-network and transistor simulation of vintage TR-808 percussion.

| Engine Flag / Name | Primary Parameters |
| :--- | :--- |
| `Analog808Kick = True` | `Tune`, `Tone`, `Decay`, `Punch`, `Distortion` |
| `Analog808Snare = True` | `Snappy`, `Tone`, `Decay` |
| `Analog808HiHat = True` | `Decay`, `Metallic`, `Tone` |
| `Analog808Cowbell = True`| `Tune`, `Decay`, `HighPass` |
| `Analog808Tom = True` | `Pitch`, `Decay`, `LowPass` |

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

## 6. Chiptune & FM Engines

| Engine Model | Key Flags / ID | Description |
| :--- | :--- | :--- |
| **Commodore 64 SID** | `SIDSynth = True` | MOS 6581/8580 wave generator, pulse-width modulation, ring mod, and non-linear filter distortion. |
| **SNES SPC700** | `snesDsp = True` | Authentic 32kHz downsampling, 8-tap FIR echo, and BRR interpolation. |
| **YM2612 FM Chip** | `ym2612 = True` | Sega Genesis 4-operator FM sound chip with 9-bit DAC simulation. |
| **Voltaic Plasma** | `VoltaicPlasmaSynth` | Electric arc discharge audio synthesizer. |

---

## 7. Built-in Audio Effects

| FX Identifier | Parameters | Description |
| :--- | :--- | :--- |
| `stereoDelay` | `TimeMs`, `Feedback`, `Dampening`, `Mix` | Ping-pong lookahead delay line. |
| `stereoChorus` | `RateHz`, `DepthMs`, `Mix` | Multi-phase LFO modulated delay chorus. |
| `bitcrusher` | `Bits`, `Downsample`, `Drive`, `Mix` | Hardware sample-rate and quantization bit-depth reduction. |
| `snesDownsample` | `Rate`, `EchoVolume`, `Mix` | Authentic Super Nintendo 32kHz interpolation and echo. |
| `tubeDistortion` | `Drive`, `Bias`, `Tone`, `Mix` | Asymmetric triode tube saturation. |
| `cabDesigner` | `CabSize`, `Resonance`, `MicDistance`, `Mix` | Speaker cabinet impulse and standing wave resonator. |
