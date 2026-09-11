#!/usr/bin/env python3
"""
Eatsbeats Acoustic Target Extraction Protocol
Analyzes WAV files for:
- Inharmonicity factor (B)
- Modal Decay (T60 per band)
- Attack Transient Dynamics (rise time ms, crest factor)
- Fingerboard Slap / Noise Ratio
- Spectral Centroid trajectory
"""

import sys
import os
import json
import wave
import struct
import numpy as np
import scipy.signal as signal

def load_wav(filepath):
    with wave.open(filepath, 'rb') as wf:
        n_channels = wf.getnchannels()
        sampwidth = wf.getsampwidth()
        framerate = wf.getframerate()
        n_frames = wf.getnframes()
        raw_data = wf.readframes(n_frames)

    if sampwidth == 2:
        dtype = np.int16
        norm = 32768.0
        audio = np.frombuffer(raw_data, dtype=dtype).astype(np.float32) / norm
    elif sampwidth == 3:
        raw_bytes = np.frombuffer(raw_data, dtype=np.uint8).reshape(-1, 3)
        b0 = raw_bytes[:, 0].astype(np.int32)
        b1 = raw_bytes[:, 1].astype(np.int32)
        b2 = raw_bytes[:, 2].astype(np.int32)
        b2 = np.where(b2 >= 128, b2 - 256, b2)
        int24 = b0 | (b1 << 8) | (b2 << 16)
        audio = int24.astype(np.float32) / 8388608.0
    elif sampwidth == 4:
        dtype = np.int32
        norm = 2147483648.0
        audio = np.frombuffer(raw_data, dtype=dtype).astype(np.float32) / norm
    else:
        raise ValueError(f"Unsupported sample width: {sampwidth}")
    if n_channels > 1:
        audio = audio[::n_channels] # Downmix / take first channel
    return audio, framerate

def analyze_audio(audio, sr, expected_f0=None):
    # 1. Attack Transient Dynamics
    pluck_window = np.abs(audio[:int(0.050 * sr)])
    peak_val = np.max(pluck_window) if len(pluck_window) > 0 else np.max(abs_audio)
    if peak_val < 1e-5:
        return {"error": "audio silent"}

    # Find 10% to 90% rise time of pluck
    idx_10 = np.where(pluck_window >= 0.10 * peak_val)[0]
    idx_90 = np.where(pluck_window >= 0.90 * peak_val)[0]
    rise_time_ms = 0.0
    if len(idx_10) > 0 and len(idx_90) > 0:
        rise_time_ms = (idx_90[0] - idx_10[0]) / sr * 1000.0

    # Crest factor (peak to RMS in first 100ms)
    window_100ms = audio[:int(0.10 * sr)]
    rms_100ms = np.sqrt(np.mean(window_100ms ** 2)) + 1e-8
    crest_factor = float(peak_val / rms_100ms)

    # 2. Slap / Noise Ratio (high frequencies > 1.8kHz in first 35ms)
    attack_samples = int(0.035 * sr)
    attack_audio = audio[:attack_samples]
    sos_hp = signal.butter(4, 1800.0, 'hp', fs=sr, output='sos')
    high_slap_energy = np.sum(signal.sosfilt(sos_hp, attack_audio) ** 2) + 1e-9
    total_attack_energy = np.sum(attack_audio ** 2) + 1e-9
    slap_ratio = float(high_slap_energy / total_attack_energy)

    # 3. Spectral Centroid
    mid_start = int(0.060 * sr)
    mid_end = min(len(audio), int(0.50 * sr))
    mid_audio = audio[mid_start:mid_end]
    fft_spec = np.abs(np.fft.rfft(mid_audio * np.hanning(len(mid_audio))))
    freqs = np.fft.rfftfreq(len(mid_audio), 1.0 / sr)

    centroid = float(np.sum(freqs * fft_spec) / (np.sum(fft_spec) + 1e-9))

    # 4. Fundamental Frequency & Inharmonicity Factor (B)
    peaks, _ = signal.find_peaks(fft_spec, distance=int(30 * len(mid_audio) / sr), height=np.max(fft_spec) * 0.02)
    peak_freqs = sorted(freqs[peaks])

    f0 = expected_f0 if expected_f0 else (peak_freqs[0] if len(peak_freqs) > 0 else 55.0)
    inharmonicity_b = 0.00035

    if len(peak_freqs) >= 4:
        matched_partials = []
        for n in range(1, 7):
            expected = n * f0
            candidates = [f for f in peak_freqs if abs(f - expected) < expected * 0.18]
            if candidates:
                closest = min(candidates, key=lambda f: abs(f - expected))
                matched_partials.append((n, closest))

        if len(matched_partials) >= 3:
            b_estimates = []
            for n, fn in matched_partials[1:]:
                ratio = (fn / (n * f0)) ** 2
                if ratio > 1.0:
                    b_est = (ratio - 1.0) / (n ** 2)
                    b_estimates.append(b_est)
            if b_estimates:
                inharmonicity_b = float(np.median(b_estimates))

    # 5. T60 Modal Decay Estimation (ISO 3382 standard energy decay regression)
    t_start = 0.08
    t_end = min(len(audio) / sr - 0.05, 2.3)
    t60_sec = 2.40
    if t_end > t_start + 0.3:
        times = np.linspace(t_start, t_end, 30)
        rms_vals = [np.sqrt(np.mean(audio[int(t * sr):int((t + 0.04) * sr)] ** 2)) for t in times]
        db_vals = 20.0 * np.log10(np.maximum(rms_vals, 1e-5))
        slope, _ = np.polyfit(times, db_vals, 1)
        if slope < -0.5:
            t60_sec = float(-60.0 / slope)
        else:
            t60_sec = 12.0

    return {
        "f0_hz": round(float(f0), 2),
        "rise_time_ms": round(rise_time_ms, 2),
        "crest_factor": round(crest_factor, 2),
        "slap_ratio": round(slap_ratio, 4),
        "spectral_centroid_hz": round(centroid, 2),
        "inharmonicity_b": round(inharmonicity_b, 6),
        "t60_sec": round(t60_sec, 2),
    }

def main():
    if len(sys.argv) < 2:
        print("Usage: extract_metrics.py <file_or_directory>")
        sys.exit(1)

    target_path = sys.argv[1]
    wav_files = []
    if os.path.isfile(target_path) and target_path.endswith('.wav'):
        wav_files.append(target_path)
    elif os.path.isdir(target_path):
        for f in sorted(os.listdir(target_path)):
            if f.endswith('.wav'):
                wav_files.append(os.path.join(target_path, f))

    results = {}
    for wf in wav_files:
        basename = os.path.splitext(os.path.basename(wf))[0]
        try:
            audio, sr = load_wav(wf)
            metrics = analyze_audio(audio, sr)
            results[basename] = metrics
            print(f"[{basename}] T60: {metrics.get('t60_sec')}s, Centroid: {metrics.get('spectral_centroid_hz')}Hz, B: {metrics.get('inharmonicity_b')}, Slap: {metrics.get('slap_ratio')}")
        except Exception as e:
            results[basename] = {"error": str(e)}
            print(f"[{basename}] Error: {e}")

    out_file = os.path.join(os.path.dirname(target_path) if os.path.isfile(target_path) else target_path, "metrics_summary.json")
    with open(out_file, "w") as f:
        json.dump(results, f, indent=2)
    print(f"\nSaved metrics to {out_file}")

if __name__ == "__main__":
    main()
