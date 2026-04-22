#!/usr/bin/env python3
"""Validate generated sounds for children's app quality."""

import librosa
import numpy as np
import os
import csv

def validate_sound(audio_path: str) -> dict:
    audio, sr = librosa.load(audio_path, sr=None, mono=True)
    duration = len(audio) / sr
    rms = float(np.sqrt(np.mean(audio ** 2)))
    peak = float(np.abs(audio).max())

    checks = {
        "duration_ok": 0.03 <= duration <= 15.0,
        "not_silent": rms > 0.005,
        "no_clipping": peak <= 1.0,
    }
    report = {
        "file": os.path.basename(audio_path),
        "duration_s": round(duration, 3),
        "sample_rate": sr,
        "rms": round(rms, 4),
        "peak": round(peak, 4),
        "checks": checks,
        "approved": all(checks.values()),
    }
    status = "✅ OK" if report["approved"] else "❌ FAIL"
    print(f"{status}  {report['file']:30s}  {duration*1000:6.0f}ms  rms={rms:.4f}  peak={peak:.4f}")
    return report


processed_dir = os.path.expanduser("~/Downloads/sounds/ui/processed")
print(f"Validating sounds in: {processed_dir}\n")

files = sorted(f for f in os.listdir(processed_dir) if f.endswith(".wav"))
reports = []
for fname in files:
    path = os.path.join(processed_dir, fname)
    reports.append(validate_sound(path))

approved = sum(1 for r in reports if r["approved"])
print(f"\n{'='*60}")
print(f"RESULT: {approved}/{len(reports)} sounds approved")
if approved == len(reports):
    print("✅ All UI sounds pass quality validation!")
else:
    print("⚠️  Some sounds failed — review above")
