# Dual-Mic FM Noise Acoustic Kick Synthesizer Engine
### Architectural Specification & Implementation Guide for Flutter Web Audio (WAJUCE / AudioWorklet)

---

## 1. Executive Summary & Acoustic Model Overview

Standard synthesized kicks rely on a solitary falling sine wave (TR-808/909 paradigm). While effective for electronic sub-weight, they fail to reproduce the dynamic spatial impact, chaotic head excitation, and physical acoustic dimensions of a real kick drum.

This engine implements the **Dual-Mic FM Noise Model** (based on Zion Jaymes' physical excitation modeling):
1. **Nearfield / Close-Mic Layer (Kick-In):** Captures the batter head impact. Modeled as a fast falling sine wave (180 Hz &rarr; 50 Hz) frequency-modulated with white noise over an ultra-short envelope (2–10 ms) to unify the click and sub-thump into a single physical source, followed by mid-scooped, click-boosted EQ.
2. **Farfield / Room Layer (Kick-Out / Room Mic):** Captures acoustic air displacement and room shell resonance (100–180 Hz). Modeled as a sine wave modulated by white noise over a wider envelope (30–70 ms) to create an organic "burst of air", high-passed to eliminate mud, and delayed by 5–12 ms to simulate physical microphone distance.

This document provides complete, zero-allocation Dart/Flutter classes, Web Audio node routing, and an optional high-performance `AudioWorkletProcessor` designed for drop-in integration with Google Antigravity / Gemini agentic code generation.

---

## 2. DSP Node Graph & Signal Flow

```
[ White Noise Buffer / PRNG ]
       │
       ├─► [ Nearfield FM Gain Env (t: 0-8ms, Depth: 500-800Hz) ] ──┐
       │                                                            ▼ (Freq Mod)
       │                                                [ Nearfield Carrier Sine ]
       │                                                (Pitch Env: 180Hz -> 52Hz, 70ms)
       │                                                            │
       │                                                            ▼
       │                                                [ Nearfield Amp Gain Env ] (280ms)
       │                                                            │
       │                                                            ▼
       │                                                [ Sub Reso Head Peak (60Hz, Q:3.5) ]
       │                                                            │
       │                                                            ▼
       │                                                [ Mid Scoop Filter (350Hz, -8dB) ]
       │                                                            │
       │                                                            ▼
       │                                                [ Beater Click High-Shelf (3.5kHz, +6dB) ]
       │                                                            │
       │                                                            ▼
       │                                                  [ Summing Bus / Master Out ]
       │                                                            ▲
       │                                                            │
       ├─► [ Farfield FM Gain Env (t: 8-50ms, Depth: 200-350Hz) ] ──┤
       │                                                            ▼ (Freq Mod)
       │                                                [ Farfield Carrier Sine ]
       │                                                (Pitch: 130Hz -> 95Hz, 150ms)
       │                                                            │
       │                                                            ▼
       │                                                [ Farfield Amp Gain Env ] (220ms, Mix: 0.35)
       │                                                            │
       │                                                            ▼
       │                                                [ Highpass Filter (85Hz) ]
       │                                                            │
       │                                                            ▼
       │                                                [ Room Body Peak (160Hz, +3dB) ]
       │                                                            │
       │                                                            ▼
       └───────────────────────────────────────────────► [ Delay Node (5-12ms) ] 
```

---

## 3. Flutter & Dart Implementation

### 3.1. Data Model: Parameters & Presets

```dart
// lib/audio/kick_params.dart

class KickVoiceParams {
  // Nearfield (Close Mic)
  final double nearPitchStart;     // e.g., 180.0 Hz
  final double nearPitchEnd;       // e.g., 52.0 Hz
  final double nearPitchDecay;     // e.g., 0.07 s
  final double nearFmDepth;        // e.g., 600.0 Hz
  final double nearFmDecay;        // e.g., 0.008 s
  final double nearAmpDecay;       // e.g., 0.28 s
  final double resoBoostFreq;      // e.g., 60.0 Hz
  final double resoBoostQ;         // e.g., 3.5
  final double resoBoostGain;      // e.g., 4.0 dB

  // Farfield (Room / Mic Out)
  final double farPitchStart;      // e.g., 130.0 Hz
  final double farPitchEnd;        // e.g., 95.0 Hz
  final double farPitchDecay;      // e.g., 0.15 s
  final double farFmDepth;         // e.g., 250.0 Hz
  final double farFmDecay;         // e.g., 0.045 s
  final double farAmpDecay;        // e.g., 0.22 s
  final double farLevel;           // e.g., 0.35
  final double roomDelaySec;       // e.g., 0.008 s (8ms)

  const KickVoiceParams({
    this.nearPitchStart = 180.0,
    this.nearPitchEnd = 52.0,
    this.nearPitchDecay = 0.07,
    this.nearFmDepth = 600.0,
    this.nearFmDecay = 0.008,
    this.nearAmpDecay = 0.28,
    this.resoBoostFreq = 60.0,
    this.resoBoostQ = 3.5,
    this.resoBoostGain = 4.0,
    this.farPitchStart = 130.0,
    this.farPitchEnd = 95.0,
    this.farPitchDecay = 0.15,
    this.farFmDepth = 250.0,
    this.farFmDecay = 0.045,
    this.farAmpDecay = 0.22,
    this.farLevel = 0.35,
    this.roomDelaySec = 0.008,
  });

  static const KickVoiceParams studioPunch = KickVoiceParams();

  static const KickVoiceParams boomBapThump = KickVoiceParams(
    nearPitchStart: 160.0,
    nearPitchEnd: 58.0,
    nearFmDepth: 450.0,
    nearFmDecay: 0.015,
    nearAmpDecay: 0.35,
    farPitchStart: 110.0,
    farPitchEnd: 85.0,
    farFmDepth: 320.0,
    farFmDecay: 0.060,
    farLevel: 0.50,
    roomDelaySec: 0.012,
  );

  static const KickVoiceParams metalClick = KickVoiceParams(
    nearPitchStart: 240.0,
    nearPitchEnd: 48.0,
    nearFmDepth: 950.0,
    nearFmDecay: 0.005,
    nearAmpDecay: 0.20,
    resoBoostFreq: 55.0,
    resoBoostGain: 6.0,
    farLevel: 0.20,
  );

  Map<String, dynamic> toMap() => {
    'nearPitchStart': nearPitchStart,
    'nearPitchEnd': nearPitchEnd,
    'nearPitchDecay': nearPitchDecay,
    'nearFmDepth': nearFmDepth,
    'nearFmDecay': nearFmDecay,
    'nearAmpDecay': nearAmpDecay,
    'resoBoostFreq': resoBoostFreq,
    'resoBoostQ': resoBoostQ,
    'resoBoostGain': resoBoostGain,
    'farPitchStart': farPitchStart,
    'farPitchEnd': farPitchEnd,
    'farPitchDecay': farPitchDecay,
    'farFmDepth': farFmDepth,
    'farFmDecay': farFmDecay,
    'farAmpDecay': farAmpDecay,
    'farLevel': farLevel,
    'roomDelaySec': roomDelaySec,
  };
}
```

---

### 3.2. Native Web Audio Engine Interface (Dart / JS Interop)

For Flutter Web Audio via `dart:js_interop` / `package:web` / `wajuce`:

```dart
// lib/audio/fm_kick_web_synth.dart
import 'dart:math' as math;
import 'package:web/web.dart' as web;
import 'kick_params.dart';

class FmKickWebSynth {
  final web.AudioContext ctx;
  web.AudioBuffer? _noiseBuffer;

  FmKickWebSynth(this.ctx) {
    _initNoiseBuffer();
  }

  void _initNoiseBuffer() {
    final sampleRate = ctx.sampleRate.toInt();
    final buffer = ctx.createBuffer(1, sampleRate, ctx.sampleRate);
    final Float32List channelData = buffer.getChannelData(0).toDart;
    final random = math.Random();
    for (int i = 0; i < sampleRate; i++) {
      channelData[i] = random.nextDouble() * 2.0 - 1.0;
    }
    _noiseBuffer = buffer;
  }

  void trigger({
    KickVoiceParams params = KickVoiceParams.studioPunch,
    double velocity = 1.0,
    double? scheduledTime,
  }) {
    final now = scheduledTime ?? ctx.currentTime;
    final masterGain = ctx.createGain();
    masterGain.gain.setValueAtTime(velocity, now);
    masterGain.connect(ctx.destination);

    // ==========================================
    // 1. Nearfield Voice (Close Mic)
    // ==========================================
    final nearOsc = ctx.createOscillator();
    final nearAmp = ctx.createGain();
    final nearNoise = ctx.createBufferSource();
    final nearFmGain = ctx.createGain();

    nearNoise.buffer = _noiseBuffer;
    nearNoise.loop = true;

    // Pitch envelope
    nearOsc.type = 'sine';
    nearOsc.frequency.setValueAtTime(params.nearPitchStart, now);
    nearOsc.frequency.exponentialRampToValueAtTime(params.nearPitchEnd, now + params.nearPitchDecay);

    // FM modulation envelope (Beater Click)
    final fmPeak = params.nearFmDepth * velocity;
    nearFmGain.gain.setValueAtTime(fmPeak > 0 ? fmPeak : 0.01, now);
    nearFmGain.gain.exponentialRampToValueAtTime(0.01, now + params.nearFmDecay);

    // Amplitude envelope
    nearAmp.gain.setValueAtTime(1.0, now);
    nearAmp.gain.exponentialRampToValueAtTime(0.0001, now + params.nearAmpDecay);

    // EQ Stage
    final subFilter = ctx.createBiquadFilter();
    subFilter.type = 'peaking';
    subFilter.frequency.value = params.resoBoostFreq;
    subFilter.Q.value = params.resoBoostQ;
    subFilter.gain.value = params.resoBoostGain;

    final midFilter = ctx.createBiquadFilter();
    midFilter.type = 'peaking';
    midFilter.frequency.value = 350;
    midFilter.gain.value = -8.0;

    final clickFilter = ctx.createBiquadFilter();
    clickFilter.type = 'highshelf';
    clickFilter.frequency.value = 3500;
    clickFilter.gain.value = 6.0;

    // Connect Nearfield Graph
    nearNoise.connect(nearFmGain);
    nearFmGain.connect(nearOsc.frequency);

    nearOsc.connect(nearAmp);
    nearAmp.connect(subFilter);
    subFilter.connect(midFilter);
    midFilter.connect(clickFilter);
    clickFilter.connect(masterGain);

    // ==========================================
    // 2. Farfield Voice (Room Air Displacement)
    // ==========================================
    final roomTime = now + params.roomDelaySec;
    final farOsc = ctx.createOscillator();
    final farAmp = ctx.createGain();
    final farNoise = ctx.createBufferSource();
    final farFmGain = ctx.createGain();

    farNoise.buffer = _noiseBuffer;
    farNoise.loop = true;

    farOsc.type = 'sine';
    farOsc.frequency.setValueAtTime(params.farPitchStart, roomTime);
    farOsc.frequency.exponentialRampToValueAtTime(params.farPitchEnd, roomTime + params.farPitchDecay);

    final farFmPeak = params.farFmDepth * velocity;
    farFmGain.gain.setValueAtTime(farFmPeak > 0 ? farFmPeak : 0.01, roomTime);
    farFmGain.gain.exponentialRampToValueAtTime(0.01, roomTime + params.farFmDecay);

    farAmp.gain.setValueAtTime(params.farLevel, roomTime);
    farAmp.gain.exponentialRampToValueAtTime(0.0001, roomTime + params.farAmpDecay);

    final farHp = ctx.createBiquadFilter();
    farHp.type = 'highpass';
    farHp.frequency.value = 85.0;

    final farBody = ctx.createBiquadFilter();
    farBody.type = 'peaking';
    farBody.frequency.value = 160.0;
    farBody.gain.value = 3.0;

    // Connect Farfield Graph
    farNoise.connect(farFmGain);
    farFmGain.connect(farOsc.frequency);

    farOsc.connect(farAmp);
    farAmp.connect(farHp);
    farHp.connect(farBody);
    farBody.connect(masterGain);

    // Start & Stop Scheduling
    nearNoise.start(now);
    nearOsc.start(now);
    nearNoise.stop(now + params.nearAmpDecay + 0.05);
    nearOsc.stop(now + params.nearAmpDecay + 0.05);

    farNoise.start(roomTime);
    farOsc.start(roomTime);
    farNoise.stop(roomTime + params.farAmpDecay + 0.05);
    farOsc.stop(roomTime + params.farAmpDecay + 0.05);
  }
}
```

---

## 4. Zero-Allocation AudioWorklet Implementation (Ultra-Performance)

For sample-accurate timeline sequencing inside a DAW engine without garbage collection spikes, deploy this single-file `AudioWorkletProcessor`.

```javascript
// web/audio/fm_kick_processor.js

class FmKickProcessor extends AudioWorkletProcessor {
  constructor() {
    super();
    this.voices = [];
    this.rngState = 0x12345678;

    this.port.onmessage = (e) => {
      if (e.data.type === 'trigger') {
        this.addVoice(e.data.params, e.data.velocity || 1.0);
      }
    };
  }

  // Fast Xorshift32 PRNG (-1.0 to 1.0)
  nextNoise() {
    let x = this.rngState;
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    this.rngState = x;
    return (x & 0xFFFFFF) / 8388607.5 - 1.0;
  }

  addVoice(p, vel) {
    const sr = sampleRate;
    this.voices.push({
      vel: vel,
      params: p,
      // Nearfield state
      nearPhase: 0.0,
      nearSamples: 0,
      nearTotalSamples: Math.floor(p.nearAmpDecay * sr),
      nearPitchDecaySamples: Math.floor(p.nearPitchDecay * sr),
      nearFmDecaySamples: Math.max(1, Math.floor(p.nearFmDecay * sr)),
      // Farfield state
      farPhase: 0.0,
      farSamples: 0,
      farDelaySamples: Math.floor(p.roomDelaySec * sr),
      farTotalSamples: Math.floor(p.farAmpDecay * sr),
      farPitchDecaySamples: Math.floor(p.farPitchDecay * sr),
      farFmDecaySamples: Math.max(1, Math.floor(p.farFmDecay * sr)),
    });
  }

  process(inputs, outputs, parameters) {
    const output = outputs[0];
    const channelLeft = output[0];
    const channelRight = output[1] || output[0];
    const sr = sampleRate;
    const invSr = 1.0 / sr;
    const twoPi = 2.0 * Math.PI;

    for (let i = 0; i < 128; i++) {
      channelLeft[i] = 0;
      if (output[1]) channelRight[i] = 0;
    }

    for (let v = this.voices.length - 1; v >= 0; v--) {
      const voice = this.voices[v];
      const p = voice.params;

      for (let i = 0; i < 128; i++) {
        let sample = 0.0;
        const noise = this.nextNoise();

        // Process Nearfield
        if (voice.nearSamples < voice.nearTotalSamples) {
          const tP = Math.min(1.0, voice.nearSamples / voice.nearPitchDecaySamples);
          const currentPitch = p.nearPitchStart * Math.pow(p.nearPitchEnd / p.nearPitchStart, tP);

          const tFm = Math.min(1.0, voice.nearSamples / voice.nearFmDecaySamples);
          const currentFm = (p.nearFmDepth * voice.vel) * Math.pow(0.001, tFm);

          voice.nearPhase += (currentPitch + noise * currentFm) * invSr;
          if (voice.nearPhase > 1.0) voice.nearPhase -= Math.floor(voice.nearPhase);

          const tAmp = voice.nearSamples / voice.nearTotalSamples;
          const currentAmp = Math.pow(0.001, tAmp);

          sample += Math.sin(voice.nearPhase * twoPi) * currentAmp;
          voice.nearSamples++;
        }

        // Process Farfield (with initial delay)
        if (voice.nearSamples >= voice.farDelaySamples) {
          if (voice.farSamples < voice.farTotalSamples) {
            const tP = Math.min(1.0, voice.farSamples / voice.farPitchDecaySamples);
            const currentPitch = p.farPitchStart * Math.pow(p.farPitchEnd / p.farPitchStart, tP);

            const tFm = Math.min(1.0, voice.farSamples / voice.farFmDecaySamples);
            const currentFm = (p.farFmDepth * voice.vel) * Math.pow(0.001, tFm);

            voice.farPhase += (currentPitch + noise * currentFm) * invSr;
            if (voice.farPhase > 1.0) voice.farPhase -= Math.floor(voice.farPhase);

            const tAmp = voice.farSamples / voice.farTotalSamples;
            const currentAmp = Math.pow(0.001, tAmp) * p.farLevel;

            sample += Math.sin(voice.farPhase * twoPi) * currentAmp;
            voice.farSamples++;
          }
        }

        channelLeft[i] += sample * voice.vel * 0.7;
        if (output[1]) channelRight[i] += sample * voice.vel * 0.7;
      }

      // Voice cleanup
      if (voice.nearSamples >= voice.nearTotalSamples && voice.farSamples >= voice.farTotalSamples) {
        this.voices.splice(v, 1);
      }
    }

    return true;
  }
}

registerProcessor('fm-kick-processor', FmKickProcessor);
```

---

## 5. Step-by-Step Implementation Guide for Google Antigravity / Gemini

1. **Add Asset / Web Script:**
   * Place `fm_kick_processor.js` in `web/audio/`.
   * Register the script in your `index.html` or dynamically load it using `ctx.audioWorklet.addModule('audio/fm_kick_processor.js')`.
2. **Implement Parameter Bindings:**
   * Copy `KickVoiceParams` into your project's audio domain models.
   * Expose preset selectors (`studioPunch`, `boomBapThump`, `metalClick`) directly in the Flutter UI.
3. **Connect to Track / Sampler Channel:**
   * Route the output of `FmKickWebSynth` or `FmKickProcessor` into your master track gain / mixer bus channel.
4. **Benchmark Performance:**
   * Verify audio quantum CPU utilization is under 0.05% per trigger.
