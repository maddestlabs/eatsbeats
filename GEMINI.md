# Gemini Assistant Instructions for Eatsbeats

## CRITICAL: Eatscript Only — No Lua
Eatsbeats uses a proprietary, pure-Dart, Pythonic audio DSP and scripting language called **Eatscript**.
**There is NO Lua engine or runtime in this codebase.**

When generating code, scripts, presets, or answering questions:
- Always write scripts in **Eatscript** (Pythonic syntax with `def`, `#`, 4-space indentation).
- Script templates:
  - `def init():` for declaring parameters via `eat.param(name, default, min, max, unit)`
  - `def process():` for sample-by-sample or block DSP calculations
  - `def gui():` for declaring custom instrument / FX panels (`panel`, `row`, `knob`, `slider`, `toggle`)
- Never use Lua keywords or syntax (`local`, `then`, `end`, `--`, `function()`, etc.).
- Eatscript files and classes live in `lib/eatscript/` with `eat_` prefixes.
