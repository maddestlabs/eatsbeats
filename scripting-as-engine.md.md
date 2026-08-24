# Scripting Engine & Clip Architecture (Eatsbeats)

## Core Architectural Principle: Code as Source of Truth
Every clip in the DAW is driven by a script (Lua). The Piano Roll visual UI acts as a bi-directional parser over the underlying Lua script state.

## Data & Logic Layering (Approach 2)
To keep performance high and allow seamless bi-directional editing between UI and code:
1. **Declarative Data Table:** The visual Piano Roll updates a standard Lua array of note definitions (`notes = { {pitch=60, start=0, length=1, vel=100} }`).
2. **Algorithmic Hooks:** Users/AI can write optional `process(notes)` functions to transform, quantize, or generate notes dynamically over the base data.

## Implementation Priorities
1. Pre-render note evaluations into a look-ahead queue to prevent Lua GC pauses on the real-time audio thread.
2. WebAssembly/WASM Lua execution on Web targets vs. C/FFI on iOS/Android.
3. Expose custom UI parameters via `clip:register_param()`.