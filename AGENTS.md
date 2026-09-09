# Eatscript Architecture & AI Agent Instructions

## CRITICAL RULE: NO LUA
**Eatsbeats does NOT use Lua and has NO Lua runtime.**
Eatsbeats uses **Eatscript**, a custom, pure-Dart, Pythonic audio scripting language and DSP engine.

Under no circumstances should you:
1. Propose, write, or generate Lua code (`function()`, `end`, `local`, `..`, etc.).
2. Add dependencies, files, or variables prefixed with `lua_` or mentioning `lua`.
3. Assume any audio/scripting execution in Eatsbeats is handled by Lua.

---

## What is Eatscript?
Eatscript is an embedded domain-specific language (DSL) written entirely in Dart for real-time DSP synthesis, audio processing, MIDI transformation, and dynamic UI panel generation.

### Eatscript Syntax & Conventions
Eatscript uses Python-like indentation and syntax:
- Indentation is 4 spaces.
- Defining functions: `def init():`, `def process():`, `def gui():`, `def note_on(pitch, velocity):`.
- Comments use `#`.
- Defining parameters:
  ```python
  def init():
      eat.param("cutoff", 1000.0, 20.0, 20000.0, "Hz")
      eat.param("resonance", 0.7, 0.1, 10.0, "")
  ```
- Audio signal processing:
  ```python
  def process():
      # Eatscript DSP primitives
      freq = eat.mtof(eat.note)
      sig = eat.saw(freq)
      return eat.moog(sig, eat.cutoff, eat.resonance)
  ```
- GUI declarative panel definition:
  ```python
  def gui():
      panel(title="Synthesizer", width=320, height=200):
          row:
              knob("cutoff", label="Cutoff")
              knob("resonance", label="Reso")
  ```

---

## Directory Organization
- `lib/eatscript/`: Core Eatscript engines, parsers, serializers, GUI models, canvas drawing engines, and script libraries.
- All files in `lib/eatscript/` use `eat_` prefixes (e.g., `eat_script_library.dart`, `eat_engine.dart`, `eat_gui_model.dart`, `eat_project_parser.dart`).
- Never introduce a `lib/lua/` directory or files with `lua_` prefixes.

---

## Project Serialization Compatibility
When reading project files:
- The standard project file extension is `.eat`.
- Legacy `.eats.lua` files and JSON with `"type": "luaScript"` or `"luaScriptCode"` are retained strictly for backward compatibility when deserializing older projects.
- New serialization always produces `"type": "eatScript"` and `"eatScriptCode"`.
