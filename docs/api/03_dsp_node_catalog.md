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
| **Poly Synth / Poly Lead** | `# @engine: poly_synth`, `poly_lead` | Multi-waveform analog synth (Saw, Sine, Square, Triangle, Pulse, Noise), sub-oscillator, resonant SVF filter (LP/BP/HP), full ADSR, detune unison, and saturation. |
| **Pure Sub Bass** | `# @engine: poly_synth`, `sub_bass_synth` | Ultra-clean low-frequency anchor, 808 sub, and punchy acoustic-adjacent low-end. |
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

---

## 9. Modular Graph Node Primitives (Approach C: `def graph():`)

In Eatsbeats Approach C, modular racks compile directly from Pythonic `def graph():` definitions into zero-allocation, native C/Dart `GraphNode` trees.

| Node Primitive | Description | Key Arguments |
| :--- | :--- | :--- |
| `eat.node.osc()` | High-performance anti-aliased oscillator (sine, saw, square, noise). Supports dynamic frequency CV modulation (`pitch_cv`). | `wave="saw"`, `pitch_cv=...`, `freq=...`, `detune=...` |
| `eat.node.sub()` | Sub-octave sine oscillator. | `octave=-1`, `level=0.5` |
| `eat.node.noise()` | Fast Xorshift32 PRNG white noise generator. | `seed=...` |
| `eat.node.lfo()` | Low-frequency modulation oscillator. | `rate=...`, `depth=...` |
| `eat.node.pitch_sweep()` | Exponential transient pitch envelope generator for kick drums and punch. | `start=140.0`, `end=46.0`, `decay=0.045` |
| `eat.node.decay()` | Analog exponential decay envelope generator. | `decay=0.5` |
| `eat.node.gain()` | Voltage controlled amplifier (VCA) with signal input and CV control input. | `in_sig=...`, `gain_cv=...`, `gain=1.0` |
| `eat.node.multi_burst()` | Multi-burst micro-transient trigger envelope for 808/909 claps. | `bursts=4`, `spread=0.011`, `decay=0.28` |
| `eat.node.metallic_cluster()` | 6-oscillator inharmonic square wave cluster for cymbals, cowbells, and hats. | `tune=1.0` |
| `eat.node.midi_to_cv()` | Translates DAW MIDI events into 1V/Oct pitch CV, Gate trigger, and Velocity CV. | *none* |
| `eat.node.svf()` | 2-pole state-variable filter (lowpass, highpass, bandpass, notch, peaking, shelves). | `in_sig=...`, `cutoff=...`, `reso=...`, `type="lowpass"` |
| `eat.node.moog()` | 24dB/oct resonant transistor ladder filter. | `in_sig=...`, `cutoff=...`, `reso=...` |
| `eat.node.hammer()` | Piano/marimba felt and wooden hammer exciter. | `hardness=...`, `click=...` |
| `eat.node.pluck()` | Plectrum guitar/harp pluck exciter. | `spread=...`, `bite=...` |
| `eat.node.bow()` | Continuous bowed string physical friction exciter. | `pressure=...`, `speed=...` |
| `eat.node.waveguide()` | Dual-rail digital waveguide string delay line with damping. | `in_sig=...`, `damping=...`, `feedback=...` |
| `eat.node.modal_bank()` | High-order modal resonator bank for physical bars, bells, and membranes. | `in_sig=...`, `structure="bell"|"vibraphone"|"membrane"` |
| `eat.node.acoustic_body()` | Morphable wooden acoustic body resonator. | `in_sig=...`, `profile=...`, `gain=...` |
| `eat.node.delay()` | Modulated tape and stereo echo delay line. Normalizes milliseconds to seconds. | `in_sig=...`, `time=...` |
| `eat.node.bitcrush()` | Hardware bit-depth quantization and sample-rate decimation. | `in_sig=...`, `bits=8.0`, `downsample=1.0`, `mix=1.0` |
| `eat.node.chorus()` | Dual quadrature LFO modulated delay for stereo width and ensemble shimmer. | `in_sig=...`, `rate=0.8`, `depth=0.65`, `feedback=0.2`, `mix=0.5` |
| `eat.node.tremolo()` | Optical photocell amplitude tremolo and auto-panner. | `in_sig=...`, `rate=4.5`, `depth=0.65` |
| `eat.node.compressor()` | Studio VCA dynamic range compressor with true logarithmic dB ballistics. | `in_sig=...`, `threshold=-18.0`, `ratio=4.0`, `attack=15.0`, `release=100.0`, `makeup=0.0`, `mix=1.0` |
| `eat.node.limiter()` | Zero-overshoot brickwall peak limiter with lookahead protection. | `in_sig=...`, `ceiling=-0.1`, `release=50.0` |
| `eat.node.tr909_kick()` | Authentic André Michelle 909 analog bass drum model (274Hz->53Hz sweep & click). | `tune="Tune"`, `decay="Decay"`, `attack="Attack"` |
| `eat.node.tr909_snare()` | Dual-layer 909 snare model (tuned analog body + snappy noise wires). | `tune="Tune"`, `snappy="Snappy"`, `tone="ToneDecay"` |
| `eat.node.tr909_sample()` | Authentic 6-bit compressed PCM ROM voice with analog VCA decay (hihats, rimshot, clap). | `sample="closed_hihat"|"opened_hihat"|"rim"|"clap"`, `tune=...`, `decay=...` |
| `eat.node.melodic_tom()` | Acoustic cylindrical wooden shell with circular Bessel membrane modes & pitch drop. | `decay="TomDecay"`, `coupling="HeadCoupling"`, `pitch_bend="PitchBend"`, `stick="StickCrack"` |
| `eat.node.reverse_cymbal()` | Time-inverted bronze alloy modal plate crescendo swell with choke snap. | `duration="SwellDuration"`, `curve="CrescendoCurve"`, `shimmer="ShimmerAir"`, `choke="ChokeSnap"` |
| `eat.node.input()` | Incoming audio from DAW channel or bus for insert effects. | *none* |
| `eat.node.mix()` | Signal summer and balance mixer. | `in_a=...`, `in_b=...`, `balance=...` |
| `eat.node.saturate()` | Polynomial soft-clipping and overdrive waveshaper. | `in_sig=...`, `drive=...` |
| `eat.node.adsr()` | Polyphonic ADSR amplitude envelope applied at final output. | `attack=...`, `decay=...`, `sustain=...`, `release=...` |

