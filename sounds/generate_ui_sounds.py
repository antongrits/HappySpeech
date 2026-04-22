#!/usr/bin/env python3
"""Generate UI sounds for HappySpeech via scipy synthesis.
All sounds are copyright-free (own code, no license restrictions).
"""

import numpy as np
import soundfile as sf
import os

SR = 44100
OUTPUT_DIR = os.path.expanduser("~/Downloads/sounds/ui/processed")
os.makedirs(OUTPUT_DIR, exist_ok=True)


def sine_wave(freq: float, duration: float, amplitude: float = 0.7, fade: float = 0.02) -> np.ndarray:
    t = np.linspace(0, duration, int(SR * duration), endpoint=False)
    wave = (amplitude * np.sin(2 * np.pi * freq * t)).astype(np.float32)
    f = int(fade * SR)
    if f > 0 and len(wave) > 2 * f:
        wave[:f] *= np.linspace(0, 1, f)
        wave[-f:] *= np.linspace(1, 0, f)
    return wave


def silence(duration: float) -> np.ndarray:
    return np.zeros(int(SR * duration), dtype=np.float32)


def click_envelope(freq: float, duration: float, decay: float = 60.0) -> np.ndarray:
    t = np.linspace(0, duration, int(SR * duration), endpoint=False)
    wave = (np.exp(-t * decay) * np.sin(2 * np.pi * freq * t)).astype(np.float32)
    return wave * 0.6


def noise_burst(duration: float, amplitude: float = 0.3) -> np.ndarray:
    rng = np.random.default_rng(42)
    noise = rng.standard_normal(int(SR * duration)).astype(np.float32)
    t = np.linspace(0, duration, int(SR * duration), endpoint=False)
    envelope = np.exp(-t * 40)
    return (noise * envelope * amplitude).astype(np.float32)


def save(name: str, audio: np.ndarray):
    path = os.path.join(OUTPUT_DIR, f"{name}.wav")
    # Normalize to -16 LUFS equivalent (RMS normalization)
    rms = np.sqrt(np.mean(audio ** 2))
    target_rms = 10 ** (-16.0 / 20)
    if rms > 1e-6:
        audio = audio * (target_rms / rms)
    # Prevent clipping
    peak = np.abs(audio).max()
    if peak > 0.99:
        audio = audio / peak * 0.95
    sf.write(path, audio, SR)
    duration = len(audio) / SR
    print(f"✅ {name}.wav — {duration*1000:.0f}ms, rms={np.sqrt(np.mean(audio**2)):.4f}")
    return path


sounds = {}

# tap_soft — gentle button press click (~50ms)
tap_soft = click_envelope(1200, 0.05, decay=80)
tap_soft += click_envelope(600, 0.05, decay=120) * 0.3
sounds["tap_soft"] = tap_soft

# tap_correct — two-tone rising chime C5→E5 (~300ms)
tap_correct = np.concatenate([
    sine_wave(523.25, 0.12, amplitude=0.65),
    silence(0.02),
    sine_wave(659.25, 0.18, amplitude=0.55),
])
sounds["tap_correct"] = tap_correct

# tap_almost — gentle "almost" sound: soft descend with tail (~300ms)
tap_almost = np.concatenate([
    sine_wave(440, 0.10, amplitude=0.45),
    sine_wave(392, 0.08, amplitude=0.35),
    silence(0.05),
    sine_wave(440, 0.07, amplitude=0.25),
])
sounds["tap_almost"] = tap_almost

# card_flip — brief whoosh/click (~150ms)
t_cf = np.linspace(0, 0.15, int(SR * 0.15), endpoint=False)
card_flip = (np.exp(-t_cf * 30) * np.sin(2 * np.pi * (200 + 800 * t_cf) * t_cf)).astype(np.float32)
card_flip *= 0.5
sounds["card_flip"] = card_flip

# drag_drop — soft thud with small pop (~200ms)
drag_drop = np.concatenate([
    click_envelope(300, 0.05, decay=50),
    silence(0.02),
    sine_wave(800, 0.08, amplitude=0.3, fade=0.01),
    silence(0.05),
])
sounds["drag_drop"] = drag_drop

# session_complete — ascending arpeggio C5 E5 G5 C6 (~1.5s)
session_complete = np.concatenate([
    sine_wave(523.25, 0.15, amplitude=0.6),
    silence(0.03),
    sine_wave(659.25, 0.15, amplitude=0.6),
    silence(0.03),
    sine_wave(783.99, 0.15, amplitude=0.6),
    silence(0.03),
    sine_wave(1046.50, 0.40, amplitude=0.65),
    silence(0.05),
    sine_wave(1318.51, 0.20, amplitude=0.45),
    silence(0.10),
    sine_wave(1046.50, 0.30, amplitude=0.35),
])
sounds["session_complete"] = session_complete

# sticker_unlock — bubbly pop + rising tone (~500ms)
sticker_unlock = np.concatenate([
    noise_burst(0.04, amplitude=0.4),
    silence(0.02),
    sine_wave(659.25, 0.10, amplitude=0.5),
    sine_wave(880, 0.10, amplitude=0.5),
    sine_wave(1047, 0.20, amplitude=0.45),
    silence(0.08),
])
sounds["sticker_unlock"] = sticker_unlock

# star_earn — sparkle: three quick high pings (~400ms)
star_earn = np.concatenate([
    sine_wave(1318.51, 0.08, amplitude=0.55, fade=0.01),
    silence(0.03),
    sine_wave(1568, 0.08, amplitude=0.50, fade=0.01),
    silence(0.03),
    sine_wave(2093, 0.18, amplitude=0.55),
    silence(0.05),
])
sounds["star_earn"] = star_earn

# timer_tick — soft mechanical tick (~50ms)
timer_tick = click_envelope(1000, 0.05, decay=100)
timer_tick += click_envelope(500, 0.05, decay=150) * 0.2
sounds["timer_tick"] = timer_tick

# error_gentle — soft descending "try again" (NOT harsh, child-friendly) (~300ms)
error_gentle = np.concatenate([
    sine_wave(392, 0.10, amplitude=0.40),
    silence(0.02),
    sine_wave(349.23, 0.10, amplitude=0.35),
    silence(0.02),
    sine_wave(311.13, 0.12, amplitude=0.30),
])
sounds["error_gentle"] = error_gentle

# app_startup — warm welcome chime (~1s)
app_startup = np.concatenate([
    silence(0.05),
    sine_wave(261.63, 0.12, amplitude=0.45),
    silence(0.02),
    sine_wave(329.63, 0.12, amplitude=0.48),
    silence(0.02),
    sine_wave(392, 0.12, amplitude=0.50),
    silence(0.02),
    sine_wave(523.25, 0.35, amplitude=0.55),
    silence(0.05),
])
sounds["app_startup"] = app_startup

# Save all
print(f"\nGenerating {len(sounds)} UI sounds → {OUTPUT_DIR}\n")
results = {}
for name, audio in sounds.items():
    path = save(name, audio)
    results[name] = {
        "path": path,
        "duration_ms": round(len(audio) / SR * 1000),
        "source": "scipy_synthesis",
        "license": "public_domain",
        "approved": True,
    }

print(f"\n✅ All {len(results)} UI sounds generated successfully!")

# Save sounds_index.csv
import csv
csv_path = os.path.expanduser("~/Downloads/sounds/sounds_index.csv")
rows = []
for name, info in results.items():
    rows.append({
        "name": name,
        "category": "ui",
        "source": info["source"],
        "license": info["license"],
        "duration_ms": info["duration_ms"],
        "path": info["path"],
        "approved": info["approved"],
    })

# Append or create
existing = []
if os.path.exists(csv_path):
    with open(csv_path, "r", newline="") as f:
        reader = csv.DictReader(f)
        existing = [r for r in reader if r.get("name") not in results]

with open(csv_path, "w", newline="") as f:
    fieldnames = ["name", "category", "source", "license", "duration_ms", "path", "approved"]
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(existing)
    writer.writerows(rows)

print(f"\n📋 Index saved: {csv_path}")
print(f"   Total entries: {len(existing) + len(rows)}")
