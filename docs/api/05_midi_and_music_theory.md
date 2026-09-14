# MIDI Pipeline & Music Theory API

Eatscript provides an extensive set of host functions inside the `eat` module for generating note sequences, enforcing musical scales, following chord progressions, and applying rhythmic transforms.

---

## 1. Note Data Structures

A MIDI note in Eatscript can be either an internal `Note` object or a standard dictionary:

```python
{
    "id": "note_1001",
    "pitch": 60,          # MIDI pitch (0..127, 60 = Middle C)
    "start": 0.0,         # Start position in 16th-step divisions (0.0 = bar 1 beat 1)
    "duration": 1.0,      # Duration in 16th-step divisions (1.0 = one 16th note, 4.0 = one beat)
    "velocity": 0.85      # Note velocity in range [0.0, 1.0]
}
```

---

## 2. Note Generation & Modification

### `eat.add_note(pitch, start=0.0, duration=1.0, velocity=0.85)`
Appends a new note to the active track/pattern buffer.
```python
# Add a C3 note on the 4th step with 0.9 velocity
eat.add_note(pitch=48, start=4.0, duration=2.0, velocity=0.9)
```

### `eat.get_notes()`
Returns a list of all active notes in the current context as dictionaries.

### `eat.clear_notes()`
Clears all notes from the current track buffer.

---

## 3. Musical Scales & Chords

### `eat.scale(root="C", type="major")`
Returns a list of valid MIDI note numbers across the keyboard belonging to the specified scale.
- **Root**: String like `"C"`, `"F#"`, `"Bb"`, or an integer MIDI pitch.
- **Type**: `"major"`, `"minor"`, `"dorian"`, `"mixolydian"`, `"blues"`, `"pentatonic"`, `"pentatonic_minor"`.

```python
scaleNotes = eat.scale("A", "minor")
```

### `eat.scale_conform(pitch, root=0, is_minor=False)`
Quantizes a MIDI pitch to the nearest in-scale note based on key and mode.
```python
snappedPitch = eat.scale_conform(61, root=0, is_minor=False) # 61 (C#) -> 62 (D) in C Major
```

### `eat.snap_to_chord(pitch, chord="Cmaj7", mode="chord")`
Snaps a pitch to the notes of a specific chord.
- **Modes**: `"chord"` (strictly chord tones), `"scale"` (chord scale), `"bass"` (root or slash-bass tone).

```python
chordPitch = eat.snap_to_chord(62, chord="Am7", mode="chord")
```

---

## 4. Algorithmic Generators & Transformers

### `eat.euclidean(step, steps=16, pulses=4, shift=0)`
Evaluates Bjorklund's Euclidean rhythm algorithm. Returns `True` if a trigger falls on the specified step.

```python
# Generate a classic 4-pulse over 16-step pattern:
for step in range(16):
    if eat.euclidean(step, steps=16, pulses=4):
        eat.add_note(pitch=36, start=step, duration=1.0)
```

### `eat.arpeggiate(notes, rate=1.0, octaves=2, pattern="up", gate=0.85, swing=0.0)`
Generates an arpeggio from a chord or input note list.
- **Patterns**: `"up"`, `"down"`, `"updown"`, `"random"`, `"converge"`, `"diverge"`.
- **Rate**: Step division rate (1.0 = 16th note, 0.5 = 32nd note, 2.0 = 8th note).

### `eat.chord_follow(notes, mode="chord")`
Dynamically transforms a list of notes to follow the active song's chord track progression in real time.
- **Modes**: `"chord"`, `"bass"`, `"scale"`, `"colorLead"`.

### `eat.humanize(notes, timing=0.02, velocity=0.08)`
Applies subtle human micro-timing jitter and velocity variations across a list of notes.

### `eat.transpose(notes, semitones=0)`
Transposes all notes by the specified semitone offset.

---

## 5. Randomness Utilities

- `eat.random_int(min=0, max=10)`: Returns a random integer in `[min, max]`.
- `eat.random_float(min=0.0, max=1.0)`: Returns a random floating-point number.
- `eat.random_choice(list)`: Selects and returns a random element from a list.
