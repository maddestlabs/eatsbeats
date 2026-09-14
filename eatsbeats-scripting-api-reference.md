# Eatsbeats Engine API — Audio & Scripting Specification Reference

**Version:** 2.0.0 (Eatscript Pure-Dart Audio Engine)  
**Target Runtimes:** WebAudio API (Browser / Flutter Web), Native C++ / Wajuce (Windows 64-bit, macOS, Linux, Mobile)  
**Scripting Engine:** Eatscript (Pythonic DSL embedded in pure Dart)  
**Governing Rule:** No Lua runtime. All audio scripting and DSP are pure Dart Eatscript.

---

## 1. Governing Principle

**Scripts execute deterministically without blocking the real-time audio thread.**

Everything a script does is compiled into Dart ASTs or delegates to native pre-compiled DSP nodes ([EatDspSynthesizer](file:///c:/git/eatsbeats/lib/eatscript/eats_dsp_synthesizer.dart) and [GraphEvaluator](file:///c:/git/eatsbeats/lib/audio/graph/graph_evaluator.dart)). Parameter values are synchronized lock-free via double-buffered state contexts.

### Execution Isolation Architecture
```
+-----------------------------------------------------------------------+
|                         Track Execution Layer                         |
|                     [Eatscript Interpreter / AST]                     |
|                                 |                                     |
|                       Command & Event Queue                           |
|                                 v                                     |
+-----------------------------------------------------------------------+
|                         Audio Engine Context                          |
|         [Lookahead Scheduler] -> [EatDspSynthesizer / Graph]          |
|                                 |                                     |
|                         Feedback Snapshot Buffer                      |
|                                 v                                     |
|  [VU Meters] [Playhead Position] [Oscilloscopes] [FFT Visualizers]    |
+-----------------------------------------------------------------------+
```

---

## 2. Core API Surface & Scripting Syntax

Eatscript uses Pythonic syntax (4-space indentation, `def`, `#` comments).

### 2.1 Hook Lifecycle
- `def init():`: Parameter registration via `eat.param(...)`.
- `def gui():`: Hardware instrument chassis and control layout declaration.
- `def process(...):`: Real-time audio or MIDI processing.
  - **Synth Voice**: `def process(time, freq, note, params, targetNote=0, isSlide=False, isAccent=False):`
  - **Audio FX**: `def process(input_l, input_r, params):`
  - **MIDI Transformer**: `def process(notes, time_ctx):`
  - **Automation Script**: `def process(time, value, params):`

### 2.2 Host Modules & Globals
- `eat`: Core host namespace containing DSP helpers, note functions, scale conformity, and variance tools.
- `params`: Current active track parameter values dictionary.
- `eat.daw` / `project`: Macro orchestration object for creating tracks, clips, automation curves, and triggering audio/video exports.

---

## 3. High-Performance Native DSP Dispatch

Scripts can invoke pre-compiled, SIMD-accelerated native DSP synthesis and physical modeling nodes by declaring top-level flags:

- **Roland TB-303 Acid Core**: `Eats303 = True`, `JC303 = True`
- **Drum Machines**: `Analog808Kick = True`, `Analog909Snare = True`, `ProceduralKick = True`, `ProceduralSnare = True`, `ProceduralHiHat = True`
- **Keyboards & Physical Pianos**: `RhodesEPiano = True`, `ConcertGrandPiano = True`, `DX7EPiano = True`, `ClavinetD6 = True`
- **Plucked Guitars & Strings**: `SpanishGuitar = True`, `SteelAcousticGuitar = True`, `SoloViolin = True`, `DoubleBass = True`
- **Chiptunes**: `SIDSynth = True` (C64), `snesDsp = True` (SPC700), `ym2612 = True` (Genesis)
- **Audio FX**: `Bitcrusher = True`, `StereoDelay = True`, `StereoChorus = True`, `CabDesigner = True`

---

## 4. Complete Documentation Suite

For comprehensive, in-depth documentation and code references, refer to the modular documentation suite in [`docs/api/`](docs/api/):

1. **[`docs/api/01_eatscript_syntax_lifecycle.md`](docs/api/01_eatscript_syntax_lifecycle.md)**: Lifecycle hooks and runtime contexts.
2. **[`docs/api/02_parameter_system.md`](docs/api/02_parameter_system.md)**: Parameters and the Analog Variance Engine.
3. **[`docs/api/03_dsp_node_catalog.md`](docs/api/03_dsp_node_catalog.md)**: Exhaustive catalog of built-in DSP nodes and physical models.
4. **[`docs/api/04_declarative_gui_dsl.md`](docs/api/04_declarative_gui_dsl.md)**: Skeuomorphic GUI layout schema, hardware knobs, and scopes.
5. **[`docs/api/05_midi_and_music_theory.md`](docs/api/05_midi_and_music_theory.md)**: Scales, chord follow, Euclidean rhythms, and MIDI tools.
6. **[`docs/api/06_daw_macro_api.md`](docs/api/06_daw_macro_api.md)**: Project management, automation lanes, and offline export.
7. **[`docs/api/07_canonical_recipes.md`](docs/api/07_canonical_recipes.md)**: Verified starting templates for synthesizers, effects, and generators.
