# DAW & Macro Orchestration API

Eatscript scripts can automate and manipulate the host DAW directly using the `eat.daw` object (also globally aliased as `project`).

This allows scripts to generate whole multi-track arrangements, manage clips, program automation curves, and automate offline audio or video rendering.

---

## 1. Global Project Controls

### Tempo & Song Key
```python
# Read current song tempo and key
currentBpm = eat.daw.tempo
currentKey = eat.daw.key

# Set tempo and key
eat.daw.set_tempo(138.0)
eat.daw.set_key("F# Minor")
```

### History Checkpoints & Logging
```python
# Create an undo checkpoint in the DAW history stack
eat.daw.checkpoint(label="Generated Techno Bassline")

# Log messages to the DAW script console
eat.daw.log("Pattern generation complete.")
```

---

## 2. Track Management

### `eat.daw.get_tracks()`
Returns a list of all active track channel wrappers in the current pattern.

### `eat.daw.get_track(name_or_id)`
Finds and returns a specific track by name or ID.

### `eat.daw.add_track(name="New Track", type="synth")`
Creates a new track in the active pattern.
- **Types**: `"synth"`, `"sampler"` (drum kit), `"bass"`, `"tts"` (speech synthesis), `"script"`.

```python
bassTrack = eat.daw.add_track("Acid 303", type="bass")
```

### `eat.daw.delete_track(name_or_id)`
Removes the specified track from the project.

---

## 3. Track Channel Manipulation

Each track object returned by `eat.daw.get_track()` or `add_track()` provides control methods:

```python
track = eat.daw.get_track("Acid 303")

# Adjust mixer parameters
track.set_volume(0.85)     # 0.0 to 2.0 (1.0 = unity gain)
track.set_pan(-0.2)        # -1.0 (left) to 1.0 (right)
track.mute(False)          # Mute toggle
track.solo(False)          # Solo toggle

# Update track script parameters directly
track.set_param("Cutoff", 2400.0)
track.set_param("Resonance", 8.5)
```

---

## 4. Clip Creation & Automation Lanes

### Creating Clips
```python
# Create a 4-bar clip starting at bar 8
clip = track.create_clip(start_bar=8, length_bars=4, name="Chorus Bass")
```

### Adding Automation Points
Program precision automation envelopes on any track parameter:

```python
# Parameters: target_param, step_position, target_value, easing_curve
track.add_automation_point(
    target="Cutoff",
    step=0.0,
    val=400.0,
    easing="exponential"   # "linear", "exponential", "ease_in_out", "smooth"
)

track.add_automation_point(
    target="Cutoff",
    step=64.0,             # End of 4 bars (16 steps * 4)
    val=4500.0,
    easing="linear"
)
```

---

## 5. Offline Render Triggers

Scripts can orchestrate headless, batch, or background audio/video rendering:

### Audio Export (`.wav`)
```python
# Export the entire song or specified number of timeline bars to WAV
eat.daw.render_audio(filename="master_track.wav", bars=32)
```

### Video Rendering (`.mp4`)
Render video visualizations of the project:
```python
eat.daw.render_video(
    filename="synthwave_demo.mp4",
    fps=60,
    width=1920,
    height=1080,
    bars=16
)
```
