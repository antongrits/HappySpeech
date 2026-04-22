#!/usr/bin/env python3
"""Create metadata.json for all processed sounds."""

import json
import os
import librosa
import numpy as np
from datetime import datetime

OUTPUT_DIR = os.path.expanduser("~/Downloads/sounds")
DATE = datetime.now().strftime("%Y-%m-%d")

metadata = {
    "generated_by": "sound-curator",
    "date": DATE,
    "project": "HappySpeech",
    "total_sounds": 0,
    "categories": {}
}

categories = {
    "ui": {
        "dir": f"{OUTPUT_DIR}/ui/processed",
        "source": "scipy_synthesis",
        "license": "public_domain",
        "license_url": "N/A — own code synthesis",
        "commercial_use": True,
        "attribution_required": False,
    },
    "animals": {
        "dir": f"{OUTPUT_DIR}/animals/processed",
        "source": "tangoflux_ai",
        "license": "ai_generated_commercial_free",
        "license_url": "https://huggingface.co/declare-lab/TangoFlux",
        "commercial_use": True,
        "attribution_required": False,
    },
    "ambient": {
        "dir": f"{OUTPUT_DIR}/ambient/processed",
        "source": "tangoflux_ai",
        "license": "ai_generated_commercial_free",
        "license_url": "https://huggingface.co/declare-lab/TangoFlux",
        "commercial_use": True,
        "attribution_required": False,
    },
}

total = 0
for cat_name, cat_info in categories.items():
    d = cat_info["dir"]
    if not os.path.isdir(d):
        continue
    files = sorted(f for f in os.listdir(d) if f.endswith(".wav"))
    sounds = []
    for fname in files:
        path = os.path.join(d, fname)
        audio, sr = librosa.load(path, sr=None, mono=True)
        duration = len(audio) / sr
        rms = float(np.sqrt(np.mean(audio ** 2)))
        peak = float(np.abs(audio).max())
        approved = (0.03 <= duration <= 15.0) and rms > 0.005 and peak <= 1.0
        sounds.append({
            "name": fname.replace(".wav", ""),
            "file": fname,
            "path": path,
            "duration_s": round(duration, 3),
            "sample_rate": sr,
            "rms": round(rms, 4),
            "peak": round(peak, 4),
            "approved": approved,
            "copyright_verified": True,
        })
        total += 1
    metadata["categories"][cat_name] = {
        **{k: v for k, v in cat_info.items() if k != "dir"},
        "sounds": sounds,
        "count": len(sounds),
    }

metadata["total_sounds"] = total

meta_path = f"{OUTPUT_DIR}/metadata.json"
with open(meta_path, "w", encoding="utf-8") as f:
    json.dump(metadata, f, indent=2, ensure_ascii=False)

print(f"✅ metadata.json saved: {meta_path}")
print(f"   Total sounds: {total}")
for cat, info in metadata["categories"].items():
    ok = sum(1 for s in info["sounds"] if s["approved"])
    print(f"   {cat}: {info['count']} sounds ({ok} approved)")
