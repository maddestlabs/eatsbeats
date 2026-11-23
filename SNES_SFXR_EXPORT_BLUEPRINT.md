# SNES SFXR Ultra-Light Single-Header Export Blueprint

This document details how to extract the core components proven in `c:\git\snessfxr` into a small corpus of **single-header C/C-ABI libraries** (`stb`/`clay`/`miniaudio` style), hone them in a clean standalone sandbox (`c:\git\eatsfxr`), and then use that exact corpus as the **ultra-light (`--backend=gl`) export target** for Eatscript.

---

## 1. Why This Exists: WebGPU vs. OpenGL/WebGL

Eatsbeats' main host renderer (`src/ui/dawn_bridge.cpp`) uses **`wgpu_native.dll`** on native Windows and **`--use-port=emdawnwebgpu`** on Emscripten. That gives full WebGPU capability (custom WGSL shaders, heavy 2D/3D batching) at the cost of a ~10 MB+ runtime footprint.

By contrast, `c:\git\snessfxr` achieves **< 600 KB on desktop** and **< 300 KB on web** by:
1. Using **Clay** (`clay.h`) as the renderer-agnostic UI layout layer.
2. Using **OpenGL (`opengl32` / system GL + GLFW)** on desktop and **WebGL (`-sUSE_GLFW=3 -sFULL_ES2=1`)** on Emscripten.
3. Replacing FreeType + HarfBuzz with a **4 KB `8x16` bitmap font table**.
4. Replacing the full Eatsbeats host runtime with focused, zero-bloat headers.

Because Clay already sits above the renderer (`Clay_RenderCommandArray`), Eatsbeats does **not** need WebGPU-to-OpenGL translation glue. Both backends simply consume Clay render commands:

```
  Eatscript UI / Standalone App
               │
               ▼
     Clay_RenderCommandArray
       ├──► Full Path:  clay_batch_bridge ──► dawn_bridge (wgpu_native / emdawnwebgpu)
       └──► Light Path: eats_clay_gl.h    ──► OpenGL / WebGL (< 600 KB)
```

---

## 2. The Single-Header Corpus

Each library follows the `miniaudio.h` / `clay.h` convention:
- **Flat C-compatible public API** (POD structs + functions, `extern "C"` safe) so it is trivial to bind to both Eatscript's VM (`host_abi.cpp`) and the AOT transpiler (`transpiler.cpp`).
- **Single-header split** via `#ifdef EATS_<NAME>_IMPLEMENTATION` so only one translation unit compiles the implementation.
- **Zero dynamic heap allocations** inside audio or render hot paths.

### Library 1: `eats_snes_dsp.h`
*Conceived from `snes_dsp_core.hpp`, `snes_sfxr_generator.hpp`, and `prng.hpp` in `c:\git\snessfxr`.*

- **Implementation Guard:** `#define EATS_SNES_DSP_IMPLEMENTATION`
- **Contents:**
  - `EatsPrng` (Mulberry32 deterministic PRNG)
  - `EatsSnesVoice` / `EatsSnesDsp` (8-voice SPC700/S-DSP emulation, 4-point Gaussian interpolation, 12 BRR wavetables, 15-bit Galois LFSR noise, PMOD pitch modulation, 8-tap programmable stereo FIR echo)
  - `EatsSfxrParams` & `EatsSfxrArchetype` (`LASER`, `EXPLOSION`, `POWERUP`, `COIN`, `JUMP`, `HURT`, `LOSE`, `BUTTON`, `WARP`, `MUTATE`, `CUSTOM`)
- **Core API:**
  - `void eats_snes_init(EatsSnesDsp* dsp, uint32_t sample_rate);`
  - `void eats_snes_generate_preset(EatsSfxrParams* out, EatsSfxrArchetype arch, uint32_t seed);`
  - `void eats_snes_mutate(EatsSfxrParams* params, uint32_t seed, float jitter_pct);`
  - `void eats_snes_trigger(EatsSnesDsp* dsp, const EatsSfxrParams* params, float pitch_mult);`
  - `void eats_snes_render(EatsSnesDsp* dsp, float* interleaved_stereo, uint32_t frame_count);`

### Library 2: `eats_audio.h`
*Conceived from `audio_engine.hpp` / `audio_engine.cpp` and `wav_exporter.hpp` in `c:\git\snessfxr`.*

- **Implementation Guard:** `#define EATS_AUDIO_IMPLEMENTATION`
- **Dependencies:** `miniaudio.h` (included or assumed included prior)
- **Contents:**
  - `EatsScopeRingBuffer` (lock-free 1024-frame ring buffer with optional zero-crossing trigger search for stable oscilloscope rendering)
  - `EatsAudioDevice` (minimal `ma_device` lifecycle for WASAPI / CoreAudio / ALSA / WebAudio)
  - `eats_wav_write_pcm16(...)` (16-bit PCM RIFF WAV writer supporting 32,000 Hz SNES native and 44,100 Hz)
- **Core API:**
  - `bool eats_audio_start(EatsAudioDevice* dev, uint32_t sample_rate, EatsAudioCallback cb, void* user_data);`
  - `void eats_audio_stop(EatsAudioDevice* dev);`
  - `void eats_scope_push(EatsScopeRingBuffer* rb, const float* samples, uint32_t count);`
  - `uint32_t eats_scope_copy_latest(const EatsScopeRingBuffer* rb, float* out, uint32_t count, bool zero_cross_trigger);`

### Library 3: `eats_clay_gl.h`
*Conceived from `SimpleGLRenderer`, `monospace_font_8x16.hpp`, and `snes_sfxr_ui.cpp` in `c:\git\snessfxr`.*

- **Implementation Guard:** `#define EATS_CLAY_GL_IMPLEMENTATION`
- **Dependencies:** `clay.h`, GLFW3 + system OpenGL (desktop) or WebGL/ES2 (Emscripten)
- **Contents:**
  - Static 4 KB `8x16` monospace bitmap font table + Clay text measurement callback (`eats_clay_measure_text`)
  - Minimal OpenGL 2.1 / GLES 2.0 / WebGL shader & vertex batcher (colored quads, borders, textured glyph quads, lines)
  - `eats_clay_gl_render(Clay_RenderCommandArray cmds, EatsClayGlCustomFn custom_cb, void* user_data)`:
    - Handles `CLAY_RENDER_COMMAND_TYPE_RECTANGLE`
    - Handles `CLAY_RENDER_COMMAND_TYPE_BORDER`
    - Handles `CLAY_RENDER_COMMAND_TYPE_TEXT`
    - Handles `CLAY_RENDER_COMMAND_TYPE_SCISSOR_START` / `SCISSOR_END`
    - Dispatches `CLAY_RENDER_COMMAND_TYPE_CUSTOM` to `custom_cb` (for the CRT oscilloscope trace, pitch-sweep curve, etc.)

---

## 3. Sandbox Layout (`c:\git\eatsfxr`)

Before modifying Eatscript's transpiler, stand up `c:\git\eatsfxr` as a clean, self-contained proving ground. Keep `src/main.cpp` as thin glue—just like the code Eatscript's AOT transpiler will eventually emit:

```text
c:\git\eatsfxr\
├── CMakeLists.txt
├── build.ps1
├── include\
│   └── eats\
│       ├── eats_snes_dsp.h
│       ├── eats_audio.h
│       └── eats_clay_gl.h
├── third_party\
│   ├── clay\clay.h
│   └── miniaudio\miniaudio.h
├── src\
│   └── main.cpp          # Defines *_IMPLEMENTATION once; wires AppState + Clay UI + callbacks
└── web\
    └── index.html        # Minimal Emscripten shell (canvas + audio unlock + WAV download hook)
```

### Why Keeping `main.cpp` Thin Matters
If `src/main.cpp` is only ~150–300 lines of:
1. `#define EATS_*_IMPLEMENTATION` + `#include`s
2. Struct state (`AppState`)
3. A Clay UI layout function (`build_ui()`)
4. An audio callback (`on_audio()`)

...then `main.cpp` **is** the exact template that `src/eatscript/transpiler.cpp` needs to generate when exporting an Eatscript project with `--backend=gl`.

---

## 4. Step-by-Step Execution Plan

1. **Extract `eats_snes_dsp.h`:**
   Port `snes_dsp_core.hpp`, `snes_sfxr_generator.hpp`, and `prng.hpp` into a single C-ABI header with `#ifdef EATS_SNES_DSP_IMPLEMENTATION`. Verify zero STL containers in the render path.
2. **Extract `eats_audio.h`:**
   Wrap `miniaudio.h`, `ScopeRingBuffer`, and `wav_exporter.hpp` behind `#ifdef EATS_AUDIO_IMPLEMENTATION`.
3. **Extract `eats_clay_gl.h`:**
   Combine `monospace_font_8x16`, the GL/ES2 quad+line batcher, and the `Clay_RenderCommandArray` loop into one header. Expose a `CUSTOM` command callback for the oscilloscope and pitch-sweep graph.
4. **Stand Up `c:\git\eatsfxr`:**
   Create the minimal `CMakeLists.txt` (desktop GLFW+OpenGL, Emscripten `-sUSE_GLFW=3 -sFULL_ES2=1`) and `src/main.cpp` recreating the 3-column ChipTone-style UI, drag sliders, 1-octave audition keyboard, and WAV export.
5. **Verify Footprint & Parity (Verified in `c:\git\eatsfxr`):**
   - Desktop Release binary (`eatsfxr.exe`): **663,040 bytes (647.5 KB)** with zero external DLL dependencies.
   - **Critical `.data` vs `.bss` rule:** Keep large static DSP buffers (like the 1 MB `EatsSnesEchoUnit` delay arrays) zero-initialized (`static AppCtx g_app;` with non-zero fields initialized in `main()`), or allocate them at init time. Non-zero default member initializers in C++ force MSVC to emit the entire struct into `.data` on disk (+1 MB bloat: `1,676.5 KB` vs `647.5 KB`).
6. **Promote Headers Back to Eatsbeats:**
   Once honed in `c:\git\eatsfxr`, copy `eats_snes_dsp.h`, `eats_audio.h`, and `eats_clay_gl.h` into Eatsbeats (e.g. `include/eatsbeats/single_header/`), bind them in `host_abi.cpp`, and add the `--backend=gl` codegen path in `src/eatscript/transpiler.cpp`.

---

## 5. Automating Standalone Instrument GUI Export (Eliminating Manual UI Rebuilds)

In `c:\git\snessfxr`, the UI was manually ported away from Eatsbeats' host GUI (`gui_window.cpp`, `floating_window_manager.cpp`, `theme.cpp`, `dawn_bridge.cpp`). To **automate** standalone instrument exports from Eatsbeats without dragging in the DAW host runtime:

### Principle: Separate *DAW Chrome* from *Instrument UI*
Standalone instruments do not need Eatsbeats' arranger, mixer, docking, or WebGPU host chrome. They only need:
1. **A thin declarative UI layer (`eats_ui.h`)** built directly on `clay.h`
2. **A parameter & state contract** (`EatsParamDesc[]` + scope/meter ring buffer)
3. **A minimal standalone host shim** (audio device, keyboard audition, clipboard/WAV export)

### The 3-Part Automated Pipeline

1. **Target a Single `eats_ui.h` API in Both Eatsbeats and the Transpiler**
   - Eatsbeats already exposes declarative layout primitives to Eatscript in `src/ui/clay/eatscript_clay_bridge.cpp` (`ui_begin_column`, `ui_begin_row`, `ui_spacer`, `ui_push_id`, etc.).
   - Extract those primitives + core instrument widgets (`ui_slider`, `ui_knob`, `ui_button`, `ui_scope`, `ui_keyboard`) into a single-header **`eats_ui.h`** backed by `clay.h`.
   - **Inside Eatsbeats:** `Clay_RenderCommandArray` renders through `clay_batch_bridge.cpp` -> WebGPU.
   - **Inside Standalone Export:** `src/eatscript/transpiler.cpp` emits direct C calls to `eats_ui.h`, rendered through `eats_clay_gl.h` -> OpenGL/WebGL.
   - Any Eatscript instrument with a `render_ui()` function exports **1:1 without manual UI rewriting**.

2. **Fallback Auto-Faceplate from Parameter Descriptors (`EatsParamDesc`)**
   - For instruments that only define DSP + parameters (or native C++ instruments), expose a flat `EatsParamDesc` table (`name`, `min`, `max`, `default`, `unit`, `group`, `widget_type`).
   - A small `eats_ui_auto_faceplate()` helper in `eats_ui.h` can automatically generate the 3-column layout (Presets | Scope + Sliders | Waveforms/Export) directly from that table.

3. **Standalone Host Shim (`eats_standalone_host.h`)**
   - Maps Eatscript host calls (note audition, WAV export, clipboard/preset sharing) to `eats_audio.h` + GLFW instead of Eatsbeats' project/sequencer runtime.

