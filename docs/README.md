# Eatsbeats Documentation

Welcome to the **Eatsbeats** developer and musician documentation. Eatsbeats is a skeuomorphic, high-performance, open-source digital audio workstation (DAW) built with Flutter and pure-Dart DSP synthesis.

---

## 1. Documentation Index

### 🎹 [Eatscript API & Audio DSP Suite](api/README.md)
The authoritative technical specification and reference manual for Eatscript, the embedded audio DSL:
- **[01. Syntax & Lifecycle](api/01_eatscript_syntax_lifecycle.md)**: Hook conventions (`init`, `process`, `gui`), script archetypes.
- **[02. Parameter System & Variance Engine](api/02_parameter_system.md)**: Parameter registration, units, steps, and thermal analog drift.
- **[03. DSP Node Catalog](api/03_dsp_node_catalog.md)**: Roland 808/909, TB-303, physical pianos, acoustic guitars, brass, reeds, and chiptune nodes.
- **[04. Declarative GUI DSL](api/04_declarative_gui_dsl.md)**: Custom hardware racks, 6-zone knobs, nixie tubes, LCDs, oscilloscopes, and FFT analyzers.
- **[05. MIDI & Music Theory](api/05_midi_and_music_theory.md)**: Note buffers, scale conformity, chord snapping, and Euclidean rhythm generators.
- **[06. DAW & Macro API](api/06_daw_macro_api.md)**: Headless project automation, clip sequencing, and offline audio/video export.
- **[07. Canonical Recipes](api/07_canonical_recipes.md)**: Production-ready templates for synths, audio FX, and generative transformers.

---

## 2. Eatsbeats Architecture Overview

```
+-------------------------------------------------------------------------+
|                           Eatsbeats Studio                              |
+--------------------+---------------------+------------------------------+
|   Arranger & Clips |  Piano Roll Editor  |  Tracker & Step Sequencer    |
+--------------------+---------------------+------------------------------+
|                 Modular Rack & Eatscript Workbench                      |
|      [Hardware GUI View]  <---->  [Real-Time Dart Code Editor]          |
+-------------------------------------------------------------------------+
|                           Audio Engine Core                             |
|   [Lookahead Scheduler] -> [EatDspSynthesizer] -> [GraphEvaluator]      |
|                                  |                                      |
|            +---------------------+---------------------+                |
|            |                                           |                |
|     [WebAudio Worklet] (Browser)               [Wajuce / Native C++]    |
|                                                (Win64, macOS, Linux)    |
+-------------------------------------------------------------------------+
```

### Key Subsystems:
1. **Eatscript Engine (`lib/eatscript/`)**: Pure-Dart lexer, parser, interpreter, and AST evaluator executing at 44.1kHz / 48kHz audio rates.
2. **DSP Synthesizer & Audio Graph (`lib/audio/graph/` & `lib/eatscript/eats_dsp_synthesizer.dart`)**: Zero-alloc real-time synthesis models covering subtractive, FM, wavetable, chiptune (SID, SNES, YM2612), and physical waveguide models.
3. **Hardware UI Framework (`lib/ui/hardware/` & `lib/ui/widgets/`)**: Fully vector-rendered skeuomorphic audio hardware components that respond to automation, mouse drag, and touch gestures.
4. **Multi-Platform Audio Backends (`lib/audio/`)**:
   - **Browser**: High-performance WebAudio buffer streaming.
   - **Native Desktop**: `wajuce.dll` high-fidelity native audio pipeline.
