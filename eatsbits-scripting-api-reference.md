# Eatsbits Engine API — Audio & Scripting Specification Reference

**Version:** 1.0.0-draft  
**Target Runtimes:** WebAudio API (Browser / Flutter Web), Native C++ / Soundpipe / AudioUnit / VST Core  
**Scripting Engine:** Lua 5.4 / LuaJIT (Isolated Isolate / Thread per track)

---

## 1. Governing Principle

**Scripts never touch the real-time audio thread, directly or indirectly.**

Everything a script does becomes a message on a one-directional command queue into the native audio engine. Everything a script learns about engine state comes back through a separate read-only double-buffered feedback channel.

### Execution Isolation Architecture
```
+-----------------------------------------------------------------------+
|                         Track Execution Layer                         |
|  [Lua 5.4 / LuaJIT VM] <--->  [Dart Isolate / Web Worker]             |
|                                 |                                     |
|                       Command Queue (JSON / Struct)                   |
|                                 v                                     |
+-----------------------------------------------------------------------+
|                         Audio Engine Context                          |
|  [Lookahead Scheduler] -> [WebAudio Graph / Native DSP Nodes]          |
|                                 |                                     |
|                         Feedback Snapshot Buffer                      |
|                                 v                                     |
|  [Peak / RMS Meters] [Playhead Position] [FFT Visualizer Data]        |
+-----------------------------------------------------------------------+
```

---

## 2. Core API Surface (`eatsbits.v1`)

### 2.1 Opaque Handles (`NodeHandle`, `ParamHandle`, `BusHandle`)
Scripts never hold pointers or direct JS/C++ object references into the audio graph. All references are lightweight numeric/string identifiers wrapped in Lua opaque handle tables.

#### Lua Table Definitions:
```lua
-- NodeHandle Table Structure
local NodeHandle = {}
NodeHandle.__index = NodeHandle

function NodeHandle.new(id, nodeType)
  return setmetatable({ id = id, type = nodeType }, NodeHandle)
end

function NodeHandle:getParam(paramName)
  return ParamHandle.new(self.id, paramName)
end

function NodeHandle:connect(targetNode)
  eatsbits.v1.connect(self.id, targetNode.id)
end

function NodeHandle:connectToParam(targetParamHandle)
  eatsbits.v1.connectToParam(self.id, targetParamHandle.nodeId, targetParamHandle.paramName)
end

function NodeHandle:disconnect()
  eatsbits.v1.disconnect(self.id)
end

-- ParamHandle Table Structure
local ParamHandle = {}
ParamHandle.__index = ParamHandle

function ParamHandle.new(nodeId, paramName)
  return setmetatable({ nodeId = nodeId, paramName = paramName }, ParamHandle)
end

function ParamHandle:setValueAtTime(value, time)
  eatsbits.v1.scheduleParamOp(self.nodeId, self.paramName, "setValue", value, time)
end

function ParamHandle:exponentialRampToValueAtTime(value, time)
  eatsbits.v1.scheduleParamOp(self.nodeId, self.paramName, "exponentialRamp", value, time)
end
```

---

## 2.2 Node Factory & Registry

Scripts request audio processing nodes via `eatsbits.v1.createNode(nodeType, configTable)`. The native WebAudio graph instantiates corresponding nodes.

#### Standard Native Node Registry:
| Category | Node Name | Config Keys & Defaults | Exposed `ParamHandle`s |
| :--- | :--- | :--- | :--- |
| **Instrument** | `"TB303"` | `{waveform = 0, oversample = 2}` | `Cutoff`, `Resonance`, `EnvMod`, `Decay`, `Accent`, `Slide`, `Overdrive` |
| **Instrument** | `"Sampler"` | `{sampleBuffer = "snare"}` | `Pitch`, `Gain`, `StartOffset` |
| **Instrument** | `"ProceduralKick"` | `{startFreq = 160, endFreq = 42}` | `StartFreq`, `EndFreq`, `PitchDecay`, `AmpDecay`, `Click` |
| **Instrument** | `"ProceduralSnare"`| `{toneFreq = 185}` | `ToneFreq`, `Snappy`, `Decay`, `Variation` |
| **Instrument** | `"ProceduralHiHat"`| `{cutoff = 7500}` | `Cutoff`, `Decay`, `Metallic`, `Variation` |
| **Instrument** | `"ProceduralClap"` | `{roomDecay = 0.18}` | `Tone`, `RoomDecay` |
| **Instrument** | `"FMSynth"` | `{modRatio = 2.0}` | `ModRatio`, `ModIndex`, `Attack`, `Release` |
| **Effect** | `"StereoDelayFX"` | `{timeMs = 250}` | `TimeMs`, `Feedback`, `Dampening`, `Mix` |
| **Effect** | `"StereoChorusFX"`| `{rateHz = 1.2}` | `RateHz`, `DepthMs`, `Mix` |
| **Effect** | `"Bitcrusher"` | `{bits = 6}` | `Bits`, `Downsample`, `Mix` |
| **Effect** | `"TubeDistortion"` | `{drive = 6.0}` | `Drive`, `Tone`, `OutGain` |
| **Modulator** | `"LFO"` | `{shape = "sine", rateHz = 2.0}` | `Frequency`, `Gain` |

---

### 2.3 Audio Routing as First-Class Primitive

Scripts dynamically alter signal chains at runtime without recreating nodes or destroying parameter state:

```lua
-- Route Synth -> Delay -> Master Bus
local synth = eatsbits.v1.createNode("TB303", {})
local delay = eatsbits.v1.createNode("StereoDelayFX", { timeMs = 250 })
local master = eatsbits.v1.getMasterBus()

synth:connect(delay)
delay:connect(master)

-- Bypass delay dynamically:
synth:disconnect()
synth:connect(master)
```

---

### 2.4 Sample-Accurate Parameter Automation

Parameter automation maps directly onto WebAudio `AudioParam` timeline methods. Automation is interpolated at audio-rate by the native thread.

```lua
-- Sweep filter cutoff over 2 bars
local cutoff = synth:getParam("Cutoff")
local now = Scheduler.currentTime()

cutoff:setValueAtTime(200.0, now)
cutoff:exponentialRampToValueAtTime(8000.0, now + Scheduler.beatsToSeconds(8.0))
```

#### Automation Command Format:
```json
{
  "type": "PARAM_AUTOMATE",
  "nodeId": "node_tb303_01",
  "paramName": "Cutoff",
  "method": "exponentialRampToValueAtTime",
  "targetValue": 8000.0,
  "scheduledTime": 1.45200
}
```

---

### 2.5 Curve Easing & Automation Engine (`eatsbits.easing` & `eatsbits.automation`)

Scripts have full access to continuous and discrete curve evaluation for parameter automation, LFOs, and YMFM hardware chip registers.

#### Supported Easing Modes:
- `"step"`: Immediate value jump/hold (vital for discrete chip registers, FM algorithms, waveforms)
- `"linear"`: Linear interpolation
- `"exponential"`: Perceptually uniform frequency/gain curves
- `"sineInOut"`, `"sineIn"`, `"sineOut"`: Harmonic trigonometric curves
- `"cubicInOut"`, `"cubicIn"`, `"cubicOut"`: Polynomial transitions with tension
- `"smoothstep"`: $3t^2 - 2t^3$ polynomial curve
- `"cubicBezier"`: Arbitrary 2D Cubic Bezier curve handles `(cx1, cy1, cx2, cy2)`

```lua
-- Example: Custom Lua Automation Lane
function evaluate(step, timeCtx)
  local sweep = eatsbits.easing.cubicInOut(0.0, 1.0, (step % 16) / 16)
  return 200 + sweep * 4000
end
```

---

### 2.5 Musical-Time Lookahead Scheduler

Scripts schedule events using musical time (bars, beats, sub-ticks) relative to transport state. The engine translates musical time to audio clock timestamps:

$$\text{Time}_{\text{seconds}} = \text{Clock}_{\text{start}} + \left( \text{Beat} \times \frac{60.0}{\text{BPM}} \right)$$

```lua
local Scheduler = {}

function Scheduler.bpm()
  return eatsbits.v1.getBpm()
end

function Scheduler.currentTime()
  return eatsbits.v1.getAudioTime()
end

function Scheduler.beatsToSeconds(beats)
  return (beats * 60.0) / Scheduler.bpm()
end

function Scheduler.scheduleNote(pitch, velocity, beatOffset, durationBeats)
  local startTime = Scheduler.currentTime() + Scheduler.beatsToSeconds(beatOffset)
  local durationSec = Scheduler.beatsToSeconds(durationBeats)
  eatsbits.v1.sendNoteOn(pitch, velocity, startTime, durationSec)
end
```

---

### 2.6 Discrete Event Queue (`noteOn`, `noteOff`, `sendEvent`)

Events flow into a timestamped queue processed by native instrument engines ahead of playhead arrival (50ms - 150ms lookahead horizon).

```lua
eatsbits.v1.sendNoteOn(60, 0.9, startTime, durationSeconds)
eatsbits.v1.sendNoteOff(60, stopTime)
eatsbits.v1.sendEvent("triggerAccent", { accentLevel = 1.0 }, startTime)
```

---

### 2.7 Read-Only Feedback & Metering Channel

Scripts and UI poll double-buffered feedback snapshots without blocking audio execution:

```lua
local Meter = {}

function Meter.getSnapshot()
  return eatsbits.v1.getMeterSnapshot()
end
```

---

### 2.8 Lifecycle Hooks

```lua
local MyTrackScript = {}

-- Initialization off-thread when loaded
function MyTrackScript.onInit(config)
  print("Initializing Track Script in Lua...")
end

-- Called when transport starts or pattern loops
function MyTrackScript.onTransportStart(bar, beat)
  -- Schedule sequence
end

-- Cleanup on track deletion or preset unload
function MyTrackScript.onDispose()
  print("Disposing track resources...")
end

return MyTrackScript
```

---

### 2.9 Watchdog & Execution Budget

- **CPU Time Limit:** Max **5ms** wall-clock per message invocation per script isolate turn.
- **Hook Protection:** Uses native `lua_sethook` instruction cycle limiters.
- **Fault Recovery:** If a script throws an exception or times out, its isolate is paused, track output is soft-muted via gain ramp down, and an error diagnostic is dispatched to the DAW UI.

---

### 2.10 Versioned API Namespace (`eatsbits.v1`)

All track scripts target explicitly versioned namespaces (`eatsbits.v1`), guaranteeing backwards compatibility across engine upgrades.
