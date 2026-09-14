# Eatscript Parameter System & Variance Engine

The Eatscript parameter system declares controllable synth and FX variables, exposes them to DAW automation lanes, registers them with the hardware GUI, and integrates with the **Eatscript Variance Engine** for analog humanization.

---

## 1. Registering Parameters: `eat.param`

Parameters are defined inside the `def init():` hook using `eat.param()`:

```python
def init():
    return {
        "Cutoff": eat.param(
            "Cutoff",             # Parameter name (unique key)
            min=20.0,             # Minimum numeric value
            max=20000.0,          # Maximum numeric value
            default=1500.0,       # Initial default value
            step=1.0,             # Granularity / snap increment (0.0 for continuous)
            options=[],           # List of string options for discrete switches/selectors
            allow_variance=True,  # Whether the global variance engine modulates this param
            variance_scale=1.0,   # Sensitivity multiplier for variance drift
        )
    }
```

### Positional vs Keyword Arguments
Both positional and keyword formats are supported:
- Positional: `eat.param(name, min, max, default, step)`
- Keyword: `eat.param("Pitch", min=-24.0, max=24.0, default=0.0, step=1.0)`

### Discrete Switch / Dropdown Parameters
For parameters that select between enumerated options (e.g. Waveform types, Filter slopes):

```python
eat.param("Waveform", 0.0, 3.0, 0.0, step=1.0, options=["SAW", "SQR", "TRI", "SIN"], allow_variance=False)
```

---

## 2. Accessing Parameters in `process()`

During evaluation, parameters are passed into the `params` dictionary:

```python
def process(time, freq, note, params, **kwargs):
    # Safe retrieval with fallback defaults:
    cutoff = params.get("Cutoff", 1500.0)
    resonance = params.get("Resonance", 1.0)
    ...
```

---

## 3. The Variance Engine (Analog Drift & Humanization)

Eatsbeats features a dedicated **Variance Engine** that simulates thermal drift, component tolerances, and physical performance fluctuations across synthesizer parameters.

### How Variance Works
1. Every track channel features a master **Variance** slider (0.0 = sterile digital precision, 1.0 = heavy vintage analog drift).
2. Continuous parameters (cutoff, decay, drive, resonance, pitch detune) drift subtly on note-on events based on `variance_scale`.
3. Discrete or structural parameters (octave switches, waveforms, bank presets) are **variance-exempt** by default.

### Variance API Methods

| Method | Description |
| :--- | :--- |
| `eat.variance()` | Returns current master track variance level (0.0 to 1.0). |
| `eat.vary(val, scale=0.1, min=None, max=None)` | Adds randomized micro-drift to any raw value: `val ± (val * scale * random)`. |
| `eat.vary_param(param_name, params, scale=0.1, min=None, max=None)` | Returns the variance-adjusted value of a named parameter, honoring track variance and exemptions. |
| `eat.apply_variance(params_map)` | Returns a cloned dictionary where all non-exempt parameters have drift applied. |
| `eat.ignore_variance(param_name)` | Dynamically exempts a parameter from variance modulation. |
| `eat.is_variance_exempt(param_name)` | Returns `True` if a parameter is exempt (e.g. contains `octave`, `waveform`, `mode`, or has `allow_variance=False`). |

### Example: Using Variance in a Custom Synth

```python
def process(time, freq, note, params, **kwargs):
    # Apply variance directly to cutoff to simulate analog component tolerance
    liveCutoff = eat.vary_param("Cutoff", params, scale=0.08)
    
    # Manually jitter attack time slightly per note
    rawAttack = params.get("Attack", 0.02)
    liveAttack = eat.vary(rawAttack, scale=0.05, min=0.001)
    
    ...
```
