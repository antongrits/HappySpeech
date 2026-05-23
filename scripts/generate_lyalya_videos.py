#!/usr/bin/env python3
"""
generate_lyalya_videos.py
Generates 20 Lyalya cartoon bee video clips via Veo 2.0 for HappySpeech.
Budget guard: stops if accumulated cost > $95.
"""

import os
import sys
import time
import json
import subprocess
from pathlib import Path

from google import genai
from google.genai.types import GenerateVideosConfig

# ── Config ──────────────────────────────────────────────────────────────────
GCP_PROJECT = os.environ.get("GCP_PROJECT", "happyspeech-illustrations")
GCP_REGION  = os.environ.get("GCP_REGION", "us-central1")

OUTPUT_DIR = Path(
    "/Users/antongric/Yandex.Disk.localized/xcode_projects/Диплом/"
    "HappySpeech/HappySpeech/Resources/Videos/Lyalya"
)
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

MANIFEST_PATH = OUTPUT_DIR / "videos_manifest.json"

COST_PER_SEC    = 0.50
DURATION_SEC    = 8
VIDEO_COST      = DURATION_SEC * COST_PER_SEC   # $4.00
BUDGET_HARD_CAP = 95.0                          # stop before $95
MAX_RETRIES     = 2                             # attempts per slug on filter

# ── Character base ───────────────────────────────────────────────────────────
# "Safe" pattern: describe ONLY the cartoon bee, no human/therapy references.
CHARACTER_BASE = (
    "A cute cartoon bee character with cream-yellow round plush body, "
    "large shiny black eyes with white highlights, tiny yellow antennae, "
    "small black and yellow striped belly, semi-transparent iridescent wings, "
)

STYLE_SUFFIX = (
    "Kawaii animation style, soft 3D plush toy aesthetic, "
    "smooth gentle looping motion, bright cheerful colors, "
    "no text, no watermarks."
)

# ── 20 video definitions ────────────────────────────────────────────────────
# (slug, category, action_phrase, background_description)
VIDEOS = [
    # A. Greetings
    ("wave_hello",    "greetings",
     "raising both paws in a warm friendly greeting wave",
     "soft pastel mint green gradient background"),
    ("excited_jump",  "greetings",
     "jumping joyfully upward with arms raised high, expression of delight",
     "warm cream-yellow pastel background"),
    ("clapping",      "greetings",
     "enthusiastically clapping both small paws together, smiling broadly",
     "soft pastel sky-blue background"),
    ("flying",        "greetings",
     "flying gracefully through the air with wings buzzing, gentle arc motion",
     "airy pale lavender gradient background"),
    ("bouncing",      "greetings",
     "bouncing playfully on the ground with springy repeated hops",
     "soft pastel peach background"),

    # B. Emotions
    ("happy_dance",   "emotions",
     "dancing happily in a small circle, spinning with joy, arms out wide",
     "warm golden-yellow soft background"),
    ("thinking_pose", "emotions",
     "placing one paw on chin in a thoughtful pose, eyes looking upward curiously",
     "soft pastel lilac background"),
    ("surprised",     "emotions",
     "eyes wide open in surprise, mouth forming a small O shape, paws raised",
     "soft pastel mint background"),
    ("proud_stand",   "emotions",
     "standing tall with chest out and tiny paws on hips, confident proud expression",
     "soft pastel coral background"),
    ("sleepy_yawn",   "emotions",
     "yawning gently with eyes half-closed, stretching arms out slowly",
     "soft deep-blue twilight gradient background"),

    # C. With objects
    ("pointing_right",  "objects",
     "extending one paw to point enthusiastically to the right",
     "soft pastel green background"),
    ("holding_star",    "objects",
     "holding a glowing yellow five-pointed star up proudly in both paws",
     "soft pastel night-blue background with tiny sparkles"),
    ("playing_drum",    "objects",
     "tapping a small round toy drum with tiny drumsticks, rhythmic motion",
     "warm pastel orange background"),
    ("reading_book",    "objects",
     "holding a tiny colorful book and carefully turning its pages",
     "cozy warm cream background"),
    ("painting",        "objects",
     "holding a small paintbrush and making gentle brushstrokes in the air",
     "soft pastel teal background"),

    # D. Scenes
    ("forest_path",    "scenes",
     "walking along a bright green grass path surrounded by rounded cartoon trees",
     "soft sunny forest clearing background"),
    ("night_stars",    "scenes",
     "looking upward with wonder at twinkling cartoon stars filling the sky",
     "deep soft midnight-blue sky background with glowing stars"),
    ("rainbow_fly",    "scenes",
     "flying joyfully past a large vibrant rainbow arc",
     "bright clear sky-blue background with white puffy clouds"),
    ("flower_garden",  "scenes",
     "standing among large colorful cartoon flowers, petals swaying gently",
     "soft green garden background with pastel flowers"),
    ("sunny_day",      "scenes",
     "basking happily under a large bright cartoon sun with rays",
     "bright pastel sky-blue background with fluffy white clouds"),
]

# ── Helpers ──────────────────────────────────────────────────────────────────

def build_prompt(action: str, bg: str) -> str:
    return f"{CHARACTER_BASE}{action}, against {bg}. {STYLE_SUFFIX}"


def save_video(video_obj, out_path: Path) -> bool:
    """Save video bytes or GCS URI to out_path. Returns True on success."""
    if hasattr(video_obj, "video_bytes") and video_obj.video_bytes:
        out_path.write_bytes(video_obj.video_bytes)
        return True
    uri = getattr(video_obj, "uri", None)
    if uri:
        result = subprocess.run(
            ["gsutil", "cp", uri, str(out_path)],
            capture_output=True, text=True
        )
        if result.returncode == 0:
            return True
        print(f"    gsutil error: {result.stderr.strip()}")
    return False


def poll_operation(client, op, slug: str, timeout_sec: int = 600):
    """Poll until done or timeout. Returns final op."""
    deadline = time.time() + timeout_sec
    dots = 0
    while not op.done and time.time() < deadline:
        time.sleep(10)
        op = client.operations.get(op)
        dots += 1
        print(f"\r    Polling {slug}{'.' * (dots % 4 + 1)}    ", end="", flush=True)
    print()
    return op


def generate_one(client, slug: str, category: str, action: str, bg: str,
                 accumulated_cost: float) -> tuple[bool, float, dict | None]:
    """
    Generate one video.
    Returns (success, cost_incurred, manifest_entry_or_None).
    cost_incurred is 0 if filtered (not charged), VIDEO_COST if generated.
    """
    out = OUTPUT_DIR / f"{slug}.mp4"
    if out.exists() and out.stat().st_size > 100_000:
        print(f"  SKIP {slug} (already exists, {out.stat().st_size // 1024} KB)")
        entry = {
            "slug": slug, "category": category,
            "duration_seconds": DURATION_SEC,
            "file_size_bytes": out.stat().st_size,
            "prompt": build_prompt(action, bg),
            "status": "skipped_existing",
        }
        return True, 0.0, entry

    prompt = build_prompt(action, bg)
    print(f"\n  [{slug}] category={category}")
    print(f"    Prompt: {prompt[:120]}...")
    print(f"    Generating {DURATION_SEC}s video (~${VIDEO_COST:.2f})...")

    for attempt in range(1, MAX_RETRIES + 1):
        if attempt > 1:
            print(f"    Retry attempt {attempt}/{MAX_RETRIES}...")

        try:
            op = client.models.generate_videos(
                model="veo-2.0-generate-001",
                prompt=prompt,
                config=GenerateVideosConfig(
                    aspect_ratio="16:9",
                    duration_seconds=DURATION_SEC,
                    number_of_videos=1,
                    person_generation="dont_allow",
                ),
            )
        except Exception as exc:
            print(f"    API error: {exc}")
            return False, 0.0, None

        op = poll_operation(client, op, slug)

        if not op.done:
            print(f"    TIMEOUT after polling")
            return False, 0.0, None

        # Check for filter
        if op.response and op.response.generated_videos:
            video_obj = op.response.generated_videos[0].video
            if save_video(video_obj, out):
                size_kb = out.stat().st_size // 1024
                print(f"    SAVED {out.name} ({size_kb} KB)")
                entry = {
                    "slug": slug, "category": category,
                    "duration_seconds": DURATION_SEC,
                    "file_size_bytes": out.stat().st_size,
                    "prompt": prompt,
                    "status": "generated",
                    "attempts": attempt,
                }
                return True, VIDEO_COST, entry
            else:
                print(f"    ERROR: could not save video bytes")
                return False, VIDEO_COST, None

        # Filtered
        reasons = []
        if op.response:
            reasons = getattr(op.response, "rai_media_filtered_reasons", []) or []
            filtered_count = getattr(op.response, "rai_media_filtered_count", 0)
        else:
            filtered_count = 0

        print(f"    FILTERED (attempt {attempt}): reasons={reasons}, count={filtered_count}")
        # Not charged for filtered — no cost increment

        if attempt < MAX_RETRIES:
            # Slightly soften the prompt for retry
            prompt = (
                f"{CHARACTER_BASE}{action}, against {bg}. "
                f"Cute cartoon animation, plush toy style, smooth motion, "
                f"bright colors, looping animation, no people, no text."
            )
            print(f"    Softened prompt for retry.")

    print(f"    GAVE UP after {MAX_RETRIES} attempts (all filtered, $0 charged)")
    return False, 0.0, None


# ── Main ─────────────────────────────────────────────────────────────────────

def main():
    print("=" * 60)
    print("HappySpeech — Lyalya Video Generator (Veo 2.0)")
    print(f"Project: {GCP_PROJECT} / Region: {GCP_REGION}")
    print(f"Output:  {OUTPUT_DIR}")
    print(f"Budget:  ${BUDGET_HARD_CAP} hard cap")
    print("=" * 60)

    client = genai.Client(
        vertexai=True,
        project=GCP_PROJECT,
        location=GCP_REGION,
    )

    # Load existing manifest
    manifest: list[dict] = []
    done_slugs: set[str] = set()
    if MANIFEST_PATH.exists():
        with open(MANIFEST_PATH) as f:
            manifest = json.load(f)
        done_slugs = {e["slug"] for e in manifest if e.get("status") == "generated"}
        print(f"Existing manifest: {len(manifest)} entries, {len(done_slugs)} generated")

    total_cost    = 0.0
    generated_ok  = 0
    filtered_total = 0
    failed_total   = 0

    for slug, category, action, bg in VIDEOS:
        # Budget guard
        if total_cost >= BUDGET_HARD_CAP:
            print(f"\nBUDGET CAP REACHED (${total_cost:.2f}). Stopping.")
            break

        remaining_budget = BUDGET_HARD_CAP - total_cost
        if remaining_budget < VIDEO_COST:
            print(f"\nInsufficient budget remaining (${remaining_budget:.2f} < ${VIDEO_COST:.2f}). Stopping.")
            break

        success, cost, entry = generate_one(
            client, slug, category, action, bg, total_cost
        )

        total_cost += cost

        if entry:
            # Remove old entry for this slug if exists
            manifest = [e for e in manifest if e["slug"] != slug]
            manifest.append(entry)
            # Save manifest after every video
            with open(MANIFEST_PATH, "w") as f:
                json.dump(manifest, f, indent=2, ensure_ascii=False)

        if success:
            if entry and entry.get("status") == "generated":
                generated_ok += 1
            elif entry and entry.get("status") == "skipped_existing":
                generated_ok += 1
        else:
            if cost == 0.0:
                filtered_total += 1
            else:
                failed_total += 1

        print(f"  Running cost: ${total_cost:.2f} / ${BUDGET_HARD_CAP:.2f}")

    # ── Summary ──────────────────────────────────────────────────────────────
    print("\n" + "=" * 60)
    print("GENERATION COMPLETE")
    print(f"  Videos OK:       {generated_ok} / {len(VIDEOS)}")
    print(f"  Filtered (free): {filtered_total}")
    print(f"  Failed (paid):   {failed_total}")
    print(f"  Total cost:      ~${total_cost:.2f}")

    total_size = sum(
        (OUTPUT_DIR / f"{e['slug']}.mp4").stat().st_size
        for e in manifest
        if e.get("status") in ("generated", "skipped_existing")
        and (OUTPUT_DIR / f"{e['slug']}.mp4").exists()
    )
    print(f"  Total file size: {total_size / (1024*1024):.1f} MB")
    print(f"  Manifest:        {MANIFEST_PATH}")
    print("=" * 60)

    return 0 if generated_ok > 0 else 1


if __name__ == "__main__":
    sys.exit(main())
