#!/usr/bin/env python3
"""Generate animal and nature sounds for HappySpeech via TangoFlux AI.
License: AI-generated sounds — commercial use permitted, no attribution required.
"""

import os
import shutil
import librosa
import numpy as np
import soundfile as sf
import csv
import time

OUTPUT_DIR = os.path.expanduser("~/Downloads/sounds")
SR = 44100

ANIMAL_PROMPTS = {
    "dog_bark":    ("dog barking once, short, clear, single bark", 2),
    "cat_meow":    ("cat meowing softly, single meow, gentle", 2),
    "cow_moo":     ("cow mooing, farm, clear, single moo", 3),
    "frog_croak":  ("frog croaking, pond, single croak, clear", 2),
    "bird_chirp":  ("bird chirping, short tweet, cheerful", 2),
    "lion_roar":   ("lion roaring, loud, majestic, single roar", 3),
    "horse_neigh": ("horse neighing, stable, single neigh", 3),
}

AMBIENT_PROMPTS = {
    "rain_light":  ("light rain drops, gentle, no thunder, peaceful", 5),
    "wind_gentle": ("gentle breeze, soft wind, outdoor", 4),
}


def try_tangoflux(prompt: str, output_path: str, duration: int) -> bool:
    try:
        from gradio_client import Client
        print(f"  → TangoFlux: '{prompt[:50]}...' ({duration}s)")
        client = Client("declare-lab/TangoFlux", verbose=False)
        result = client.predict(
            prompt=prompt,
            steps=25,
            guidance=4.5,
            duration=duration,
            api_name="/predict"
        )
        shutil.copy(result, output_path)
        print(f"  ✅ TangoFlux success")
        return True
    except Exception as e:
        print(f"  ⚠️  TangoFlux failed: {e}")
        return False


def try_mmaudio(prompt: str, output_path: str, duration: float) -> bool:
    try:
        from gradio_client import Client
        print(f"  → MMAudio fallback: '{prompt[:50]}...'")
        client = Client("hkchengrex/MMAudio", verbose=False)
        result = client.predict(
            prompt=prompt,
            negative_prompt="music, speech, talking",
            seed=-1,
            num_steps=25,
            cfg_strength=4.5,
            duration=duration,
            api_name="/text_to_audio"
        )
        # MMAudio returns FLAC, convert to WAV
        audio_data, sr = sf.read(result)
        sf.write(output_path, audio_data, sr)
        print(f"  ✅ MMAudio success")
        return True
    except Exception as e:
        print(f"  ⚠️  MMAudio failed: {e}")
        return False


def normalize_sound(input_path: str, output_path: str, target_lufs: float = -16.0):
    audio, sr = librosa.load(input_path, sr=44100, mono=False)
    rms = np.sqrt(np.mean(audio ** 2))
    target_rms = 10 ** (target_lufs / 20)
    if rms > 1e-6:
        audio = audio * (target_rms / rms)
    peak = np.abs(audio).max()
    if peak > 0.99:
        audio = audio / peak * 0.95
    if audio.ndim > 1:
        sf.write(output_path, audio.T, sr)
    else:
        sf.write(output_path, audio, sr)
    return output_path


def validate_sound(path: str) -> dict:
    audio, sr = librosa.load(path, sr=None, mono=True)
    duration = len(audio) / sr
    rms = float(np.sqrt(np.mean(audio ** 2)))
    peak = float(np.abs(audio).max())
    approved = (0.3 <= duration <= 15.0) and (rms > 0.005) and (peak <= 1.0)
    return {"duration_s": round(duration, 2), "rms": round(rms, 4), "approved": approved}


results = []

all_prompts = list(ANIMAL_PROMPTS.items()) + list(AMBIENT_PROMPTS.items())
category_map = {k: "animals" for k in ANIMAL_PROMPTS} | {k: "ambient" for k in AMBIENT_PROMPTS}

for name, (prompt, duration) in all_prompts:
    category = category_map[name]
    raw_dir = f"{OUTPUT_DIR}/{category}/raw"
    proc_dir = f"{OUTPUT_DIR}/{category}/processed"
    os.makedirs(raw_dir, exist_ok=True)
    os.makedirs(proc_dir, exist_ok=True)

    raw_path = f"{raw_dir}/{name}_raw.wav"
    final_path = f"{proc_dir}/{name}.wav"

    print(f"\n[{name}] ({category})")

    # Try TangoFlux first, then MMAudio
    success = try_tangoflux(prompt, raw_path, duration)
    if not success:
        success = try_mmaudio(prompt, raw_path, float(duration))

    if success and os.path.exists(raw_path):
        # Validate raw
        report = validate_sound(raw_path)
        if report["approved"]:
            normalize_sound(raw_path, final_path)
            final_report = validate_sound(final_path)
            status = "approved" if final_report["approved"] else "failed_validation"
            print(f"  ✅ Normalized: {final_path} ({final_report['duration_s']}s)")
        else:
            status = "failed_validation"
            print(f"  ❌ Failed validation: duration={report['duration_s']}s, rms={report['rms']}")
    else:
        status = "generation_failed"
        print(f"  ❌ Generation failed for {name}")

    results.append({
        "name": name,
        "category": category,
        "source": "tangoflux_ai" if success else "failed",
        "license": "ai_generated_commercial_free",
        "duration_ms": int(validate_sound(final_path)["duration_s"] * 1000) if status == "approved" and os.path.exists(final_path) else 0,
        "path": final_path if status == "approved" else "",
        "approved": status == "approved",
    })

    # Small delay between API calls
    time.sleep(2)

# Update sounds_index.csv
csv_path = f"{OUTPUT_DIR}/sounds_index.csv"
existing = []
if os.path.exists(csv_path):
    with open(csv_path, "r", newline="") as f:
        reader = csv.DictReader(f)
        new_names = {r["name"] for r in results}
        existing = [row for row in reader if row.get("name") not in new_names]

with open(csv_path, "w", newline="") as f:
    fieldnames = ["name", "category", "source", "license", "duration_ms", "path", "approved"]
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(existing)
    writer.writerows(results)

approved_count = sum(1 for r in results if r["approved"])
print(f"\n{'='*60}")
print(f"ANIMAL/AMBIENT SOUNDS: {approved_count}/{len(results)} generated successfully")
print(f"CSV updated: {csv_path}")
