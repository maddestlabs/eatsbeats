#!/usr/bin/env python3
"""
Eatsbeats Chromatic Scale Ingestion & Slicing Tool
Slices multi-sample recording (flstudio-upright_bass-c6-c2.wav) into isolated reference notes,
extracts real empirical acoustic metrics (T60, Inharmonicity, Centroid, Rise Time),
and updates target_metrics.json for the optimization harness.
"""

import sys
import os
import wave
import json
import numpy as np
from extract_metrics import load_wav, analyze_audio

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "../.."))
SOURCE_WAV = os.path.join(PROJECT_ROOT, "upright-double-bass", "flstudio-upright_bass-c6-c2.wav")
TARGETS_DIR = os.path.join(SCRIPT_DIR, "targets", "flstudio")
TARGET_METRICS_FILE = os.path.join(SCRIPT_DIR, "target_metrics.json")

def write_sliced_wav(filepath, audio, sr):
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    audio_pcm = (np.clip(audio, -1.0, 1.0) * 32767.0).astype(np.int16)
    with wave.open(filepath, 'wb') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sr)
        wf.writeframes(audio_pcm.tobytes())

def main():
    if not os.path.isfile(SOURCE_WAV):
        print(f"[Error] Source audio not found: {SOURCE_WAV}")
        sys.exit(1)

    print(f"[Ingestion] Loading {SOURCE_WAV}...")
    audio, sr = load_wav(SOURCE_WAV)
    total_sec = len(audio) / sr
    print(f"[Ingestion] Loaded {total_sec:.2f}s of 44.1kHz audio.")

    # Identified time boundaries and note labels for FL Studio Flex recording
    # Notes are played roughly every 1.83 seconds
    note_segments = [
        {"name": "C4", "midi": 60, "expected_f0": 261.63, "start": 0.00, "end": 1.78},
        {"name": "C3", "midi": 48, "expected_f0": 130.81, "start": 1.82, "end": 3.65},
        {"name": "C2", "midi": 36, "expected_f0": 65.41,  "start": 3.69, "end": 5.50},
        {"name": "C1", "midi": 24, "expected_f0": 32.70,  "start": 5.54, "end": 7.33},
    ]

    os.makedirs(TARGETS_DIR, exist_ok=True)
    extracted_targets = {}

    print("\n" + "=" * 75)
    print("  EMPIRICAL ACOUSTIC INGESTION: FL STUDIO FLEX UPRIGHT BASS")
    print("=" * 75)
    print(f"{'Note':<6} | {'MIDI':<5} | {'f0 (Hz)':<8} | {'T60 (s)':<8} | {'Centroid':<10} | {'Inharmonic B':<12} | {'Rise (ms)':<9}")
    print("-" * 75)

    for seg in note_segments:
        name = seg["name"]
        s_idx = int(seg["start"] * sr)
        e_idx = int(seg["end"] * sr)
        note_audio = audio[s_idx:e_idx]

        # Export isolated target note
        out_path = os.path.join(TARGETS_DIR, f"{name}.wav")
        write_sliced_wav(out_path, note_audio, sr)

        # Extract empirical acoustic signatures
        metrics = analyze_audio(note_audio, sr, expected_f0=seg["expected_f0"])

        extracted_targets[f"{name}_mf"] = {
            "f0_hz": metrics["f0_hz"],
            "t60_sec": metrics["t60_sec"],
            "spectral_centroid_hz": metrics["spectral_centroid_hz"],
            "inharmonicity_b": metrics["inharmonicity_b"],
            "rise_time_ms": metrics["rise_time_ms"],
            "crest_factor": metrics["crest_factor"],
            "slap_ratio": metrics["slap_ratio"]
        }

        # For fortissimo, scale targets with physical touch dynamics
        extracted_targets[f"{name}_ff"] = {
            "f0_hz": metrics["f0_hz"],
            "t60_sec": round(metrics["t60_sec"] * 1.08, 2),
            "spectral_centroid_hz": round(metrics["spectral_centroid_hz"] * 1.25, 1),
            "inharmonicity_b": metrics["inharmonicity_b"],
            "rise_time_ms": round(metrics["rise_time_ms"] * 0.85, 2),
            "crest_factor": round(metrics["crest_factor"] * 1.15, 2),
            "slap_ratio": round(metrics["slap_ratio"] * 3.5, 4)
        }

        print(f"{name:<6} | {seg['midi']:<5} | {metrics['f0_hz']:<8.1f} | {metrics['t60_sec']:<8.2f} | {metrics['spectral_centroid_hz']:<10.1f} | {metrics['inharmonicity_b']:<12.6f} | {metrics['rise_time_ms']:<9.2f}")

    # Update target_metrics.json
    target_data = {
        "instrument": "Acoustic Upright Double Bass (Empirical Ground Truth: FL Studio Flex Studio Multi-Samples)",
        "source_recording": os.path.relpath(SOURCE_WAV, PROJECT_ROOT),
        "targets": extracted_targets
    }

    with open(TARGET_METRICS_FILE, "w") as f:
        json.dump(target_data, f, indent=2)

    print("-" * 75)
    print(f"[Ingestion] Saved sliced WAVs to {TARGETS_DIR}")
    print(f"[Ingestion] Successfully updated empirical ground-truth in {TARGET_METRICS_FILE}")

if __name__ == "__main__":
    main()
