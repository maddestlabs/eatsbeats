#!/usr/bin/env python3
"""
Eatsbeats Acoustic Optimization Loop Orchestrator
Runs Dart candidate audio synthesis, extracts acoustic telemetry, computes loss
against target_metrics.json, and prints diagnostic physical feedback for Gemini.
"""

import sys
import os
import json
import subprocess
from extract_metrics import analyze_audio, load_wav

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "../.."))
OUTPUT_DIR = os.path.join(SCRIPT_DIR, "output")
TARGETS_FILE = os.path.join(SCRIPT_DIR, "target_metrics.json")
REPORT_FILE = os.path.join(SCRIPT_DIR, "iteration_report.json")

def run_candidate_synthesis(params_json=None):
    cmd = ["dart", "run", "tools/acoustic_optimizer/candidate_runner.dart"]
    if params_json:
        cmd.extend(["--params", params_json])
    
    print(f"[Optimizer] Running: {' '.join(cmd)}")
    res = subprocess.run(cmd, cwd=PROJECT_ROOT, capture_output=True, text=True, shell=True)
    if res.returncode != 0:
        print("[Error] Candidate runner failed:")
        print(res.stderr)
        sys.exit(1)
    print(res.stdout.strip())

def evaluate_iteration():
    if not os.path.isfile(TARGETS_FILE):
        print(f"[Error] Target file not found: {TARGETS_FILE}")
        sys.exit(1)

    with open(TARGETS_FILE, "r") as f:
        targets_data = json.load(f)
    targets = targets_data.get("targets", {})

    wav_files = [f for f in sorted(os.listdir(OUTPUT_DIR)) if f.endswith(".wav")]
    if not wav_files:
        print(f"[Error] No WAV files generated in {OUTPUT_DIR}")
        sys.exit(1)

    eval_results = {}
    total_loss_terms = []

    print("\n" + "=" * 80)
    print("  ACOUSTIC PHYSICAL MODELING EVALUATION REPORT: 3/4 UPRIGHT DOUBLE BASS")
    print("=" * 80)
    print(f"{'Note/Vel':<10} | {'Metric':<14} | {'Candidate':<10} | {'Target':<10} | {'Error %':<10}")
    print("-" * 80)

    discrepancies = []

    for wf_name in wav_files:
        base_key = os.path.splitext(wf_name)[0]
        if base_key not in targets:
            continue

        tgt = targets[base_key]
        wf_path = os.path.join(OUTPUT_DIR, wf_name)
        audio, sr = load_wav(wf_path)
        cand = analyze_audio(audio, sr, expected_f0=tgt.get("f0_hz"))

        # Calculate relative errors
        t60_err = abs(cand["t60_sec"] - tgt["t60_sec"]) / (tgt["t60_sec"] + 1e-6)
        cent_err = abs(cand["spectral_centroid_hz"] - tgt["spectral_centroid_hz"]) / (tgt["spectral_centroid_hz"] + 1e-6)
        inharm_err = abs(cand["inharmonicity_b"] - tgt["inharmonicity_b"]) / (tgt["inharmonicity_b"] + 1e-6)
        rise_err = abs(cand["rise_time_ms"] - tgt["rise_time_ms"]) / (tgt["rise_time_ms"] + 1e-6)
        slap_err = abs(cand["slap_ratio"] - tgt["slap_ratio"]) / (tgt["slap_ratio"] + 1e-4)

        composite_error = (t60_err * 0.35 + cent_err * 0.25 + inharm_err * 0.20 + rise_err * 0.10 + slap_err * 0.10) * 100.0
        total_loss_terms.append(composite_error)

        eval_results[base_key] = {
            "candidate": cand,
            "target": tgt,
            "error_percent": round(composite_error, 2),
            "errors": {
                "t60": round(t60_err * 100.0, 2),
                "centroid": round(cent_err * 100.0, 2),
                "inharmonicity": round(inharm_err * 100.0, 2),
                "rise_time": round(rise_err * 100.0, 2),
                "slap_ratio": round(slap_err * 100.0, 2),
            }
        }

        print(f"{base_key:<10} | {'T60 (sec)':<14} | {cand['t60_sec']:<10.2f} | {tgt['t60_sec']:<10.2f} | {t60_err*100.0:<9.1f}%")
        print(f"{'':<10} | {'Centroid (Hz)':<14} | {cand['spectral_centroid_hz']:<10.1f} | {tgt['spectral_centroid_hz']:<10.1f} | {cent_err*100.0:<9.1f}%")
        print(f"{'':<10} | {'Inharmonicity':<14} | {cand['inharmonicity_b']:<10.6f} | {tgt['inharmonicity_b']:<10.6f} | {inharm_err*100.0:<9.1f}%")
        print(f"{'':<10} | {'Rise Time (ms)':<14} | {cand['rise_time_ms']:<10.2f} | {tgt['rise_time_ms']:<10.2f} | {rise_err*100.0:<9.1f}%")
        print(f"{'':<10} | {'Slap Ratio':<14} | {cand['slap_ratio']:<10.4f} | {tgt['slap_ratio']:<10.4f} | {slap_err*100.0:<9.1f}%")
        print(f"{'':<10} | {'[TOTAL ERROR]':<14} | {'':<10} | {'':<10} | {composite_error:<9.1f}%")
        print("-" * 80)

        # Physical diagnostic reasoning
        if t60_err > 0.20:
            direction = "short" if cand["t60_sec"] < tgt["t60_sec"] else "long"
            param_sugg = "Increase Sustain or decrease StringDamp" if direction == "short" else "Decrease Sustain or increase StringDamp"
            discrepancies.append(f"[{base_key}] String decay is too {direction} ({cand['t60_sec']}s vs {tgt['t60_sec']}s). Recommendation: {param_sugg}.")

        if cent_err > 0.25:
            direction = "dark" if cand["spectral_centroid_hz"] < tgt["spectral_centroid_hz"] else "bright"
            param_sugg = "Increase BodyPunch/WoodTone or increase FingerMass" if direction == "dark" else "Decrease WoodTone or increase StringDamp"
            discrepancies.append(f"[{base_key}] Timbre is too {direction} ({cand['spectral_centroid_hz']}Hz vs {tgt['spectral_centroid_hz']}Hz). Recommendation: {param_sugg}.")

        if inharm_err > 0.30:
            param_sugg = "Increase Dispersion allpass parameter" if cand["inharmonicity_b"] < tgt["inharmonicity_b"] else "Decrease Dispersion parameter"
            discrepancies.append(f"[{base_key}] Partial spreading / inharmonicity is off. Recommendation: {param_sugg}.")

    avg_loss = sum(total_loss_terms) / len(total_loss_terms) if total_loss_terms else 0.0
    print(f"\n>> MEAN OVERALL ACOUSTIC LOSS: {avg_loss:.2f}% <<\n")

    if discrepancies:
        print("DIAGNOSTIC ACOUSTIC FEEDBACK FOR AGENT:")
        for d in discrepancies[:6]:
            print(f"  * {d}")
    else:
        print("CONVERGENCE ACHIEVED: All physical signatures closely match ground-truth acoustic targets!")

    report = {
        "mean_loss_percent": round(avg_loss, 2),
        "converged": bool(avg_loss < 15.0),
        "results": eval_results,
        "diagnostics": discrepancies
    }

    with open(REPORT_FILE, "w") as f:
        json.dump(report, f, indent=2)
    print(f"\nReport written to {REPORT_FILE}")

def main():
    params_arg = None
    for i, arg in enumerate(sys.argv):
        if arg == "--params" and i + 1 < sys.argv.__len__():
            params_arg = sys.argv[i + 1]

    run_candidate_synthesis(params_arg)
    evaluate_iteration()

if __name__ == "__main__":
    main()
