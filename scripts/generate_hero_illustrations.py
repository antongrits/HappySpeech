#!/usr/bin/env python3
"""
Task #65 — Generate Imagen 3 HERO illustrations for HappySpeech
Model: imagen-3.0-generate-001 via google-genai SDK (REST, no grpc)
Hard cap: $10 = 500 images @ $0.02 each
"""

import os
import json
import subprocess
import datetime
import time
import random
from pathlib import Path

from google import genai
from google.genai import types
from google.auth import default as gauth_default
from google.auth.transport.requests import Request as GRequest

# ── Config ────────────────────────────────────────────────────────────────────
GCP_PROJECT    = os.environ.get("GCP_PROJECT", "happyspeech-illustrations")
GCP_REGION     = os.environ.get("GCP_REGION",  "us-central1")
COST_PER_IMAGE = 0.02
HARD_CAP       = 10.00
BASE_DIR       = Path(
    "/Users/antongric/Yandex.Disk.localized/xcode_projects/Диплом/HappySpeech"
    "/HappySpeech/Resources/Assets.xcassets/Hero"
)
MANIFEST_PATH  = BASE_DIR / "hero_manifest.json"

NEGATIVE = (
    "text, words, letters, logo, watermark, realistic photo, scary, dark, "
    "human face, person, people, medical, clinical"
)
BASE_PROMPT_SUFFIX = (
    ", soft pastel cream-yellow palette, warm friendly kawaii cartoon style, "
    "white or very soft gradient background, no text in image, no logos, "
    "centered composition, gentle warm lighting, hand-drawn feel, "
    "soft 3D rounded shapes, pastel coral peach teal lilac mint colors."
)

# ── Init google-genai client (Vertex AI backend, REST) ────────────────────────
client = genai.Client(
    vertexai=True,
    project=GCP_PROJECT,
    location=GCP_REGION,
)

# ── Tracking ───────────────────────────────────────────────────────────────────
total_cost       = 0.0
total_gen        = 0
total_skip       = 0
total_fail       = 0
manifest_entries = []

# ── Helpers ────────────────────────────────────────────────────────────────────

def contents_json(slug: str) -> dict:
    return {
        "images": [
            {"idiom": "universal", "filename": f"{slug}.png",    "scale": "1x"},
            {"idiom": "universal", "filename": f"{slug}@2x.png", "scale": "2x"},
            {"idiom": "universal", "filename": f"{slug}@3x.png", "scale": "3x"},
        ],
        "info": {"author": "xcode", "version": 1},
    }


def sips_resize(src: Path, dst: Path, width: int, height: int):
    subprocess.run(
        ["sips", "-z", str(height), str(width), str(src), "--out", str(dst)],
        check=True, capture_output=True,
    )


def generate(slug: str, scene: str, aspect: str, tier: str) -> str:
    """Returns 'skip', 'ok', or 'fail:<reason>'."""
    global total_cost, total_gen, total_skip, total_fail

    out_dir   = BASE_DIR / f"{slug}.imageset"
    target_3x = out_dir / f"{slug}@3x.png"

    # Idempotent check
    if target_3x.exists() and target_3x.stat().st_size > 50_000:
        total_skip += 1
        return "skip"

    # Budget guard
    if total_cost + COST_PER_IMAGE > HARD_CAP:
        return "fail:budget_exhausted"

    prompt = scene + BASE_PROMPT_SUFFIX

    # Retry with exponential backoff
    max_retries = 7
    base_delay  = 20.0
    response    = None
    for attempt in range(max_retries):
        try:
            response = client.models.generate_images(
                model="imagen-3.0-generate-001",
                prompt=prompt,
                config=types.GenerateImagesConfig(
                    number_of_images=1,
                    aspect_ratio=aspect,
                    negative_prompt=NEGATIVE,
                    person_generation="DONT_ALLOW",
                    safety_filter_level="BLOCK_SOME",
                    output_mime_type="image/png",
                ),
            )
            break
        except Exception as exc:
            exc_str = str(exc)
            is_quota = "429" in exc_str or "quota" in exc_str.lower() or "RESOURCE_EXHAUSTED" in exc_str
            if is_quota and attempt < max_retries - 1:
                delay = base_delay * (2 ** attempt) + random.uniform(1, 10)
                print(f"  [429]  {slug} — throttled, retry {attempt+1}/{max_retries} in {delay:.0f}s")
                time.sleep(delay)
                continue
            total_fail += 1
            print(f"  [FAIL] {slug}: {exc}")
            return f"fail:{exc_str[:120]}"
    else:
        total_fail += 1
        return "fail:max_retries_exceeded"

    if not response or not response.generated_images:
        total_fail += 1
        print(f"  [FAIL] {slug}: empty response")
        return "fail:empty_response"

    out_dir.mkdir(parents=True, exist_ok=True)
    img_data = response.generated_images[0].image.image_bytes
    target_3x.write_bytes(img_data)

    # Derive @2x and @1x dimensions from aspect ratio
    if aspect == "16:9":
        w2, h2 = 960, 540
        w1, h1 = 480, 270
    elif aspect == "9:16":
        w2, h2 = 540, 960
        w1, h1 = 270, 480
    else:  # 1:1
        w2, h2 = 512, 512
        w1, h1 = 256, 256

    target_2x = out_dir / f"{slug}@2x.png"
    target_1x = out_dir / f"{slug}.png"
    try:
        sips_resize(target_3x, target_2x, w2, h2)
        sips_resize(target_3x, target_1x, w1, h1)
    except Exception as exc:
        print(f"  [WARN] sips resize failed for {slug}: {exc}")

    (out_dir / "Contents.json").write_text(
        json.dumps(contents_json(slug), indent=2)
    )

    total_cost += COST_PER_IMAGE
    total_gen  += 1
    manifest_entries.append({
        "slug": slug,
        "tier": tier,
        "aspectRatio": aspect,
        "scene": scene,
        "filePath": f"Hero/{slug}.imageset/{slug}@3x.png",
    })

    if total_gen % 10 == 0:
        print(f"  >>> Running total: {total_gen} images | ${total_cost:.2f}")

    # Small inter-request delay to stay under rate limit
    time.sleep(3.0 + random.uniform(0, 2))
    return "ok"


def run_tier(label: str, items: list):
    """items: list of (slug, scene, aspect)."""
    print(f"\n=== {label} ({len(items)} images) ===")
    for slug, scene, aspect in items:
        if total_cost + COST_PER_IMAGE > HARD_CAP:
            print(f"  [STOP] Budget cap reached at ${total_cost:.2f}")
            return
        status = generate(slug, scene, aspect, label)
        marker = "SKIP" if status == "skip" else ("OK  " if status == "ok" else "FAIL")
        print(f"  [{marker}] {slug}")


# ══════════════════════════════════════════════════════════════════════════════
# TIER DEFINITIONS
# ══════════════════════════════════════════════════════════════════════════════

TIER_H1 = [
    ("onboarding_welcome",
     "Magical gateway with rainbow arch, floating sparkles, glowing doorway, welcoming scene, celebration banner made of stars",
     "16:9"),
    ("onboarding_meet_lyalya",
     "Cute butterfly mascot character greeting with big happy eyes, coral peach wings spread wide, sparkles around, waving hello",
     "16:9"),
    ("onboarding_choose_sound",
     "Colorful musical notes floating around cute animals, each animal making a different sound bubble, playful cartoon",
     "16:9"),
    ("onboarding_first_lesson",
     "Cozy classroom scene with friendly animals at desks, a smiling sun through window, open picture books",
     "16:9"),
    ("onboarding_practice",
     "Cute frog practicing sounds with musical bubbles floating out of its mouth, colorful sparkles, happy expression",
     "16:9"),
    ("onboarding_progress",
     "Staircase made of stars leading upward, cute animal climbing each step, golden stars and confetti falling",
     "16:9"),
    ("onboarding_family",
     "Cozy home interior corner with warm lamp, soft cushions, teddy bear, books, heart shapes floating, no people",
     "16:9"),
    ("onboarding_celebration",
     "Confetti explosion with rainbow colors, floating balloons, stars and sparkles, party decorations, festive scene",
     "16:9"),
    ("onboarding_streak",
     "Calendar with flame icons on consecutive days, golden star trail, comet streak across soft sky",
     "16:9"),
    ("onboarding_ready",
     "Cute rocket ship launching into starry sky leaving coral pink trail, stars and planet in background, excited animal astronaut",
     "16:9"),
]

TIER_H2 = [
    ("island_whistling",
     "Magical snake island with friendly cartoon snakes wearing tiny hats, tall grass, flowers, whistling wind spirals",
     "1:1"),
    ("island_hissing",
     "Cheerful butterfly and bee meadow island, colorful flowers, bees with little crowns, butterflies dancing, sunny sky",
     "1:1"),
    ("island_sonor",
     "Tropical crab beach island, happy cartoon crabs, golden sand, gentle waves, seashells, starfish, palm tree",
     "1:1"),
    ("island_backlingual",
     "Enchanted forest island with friendly owls in trees, mushrooms, glowing lanterns, tall oak trees",
     "1:1"),
    ("island_iotic",
     "Rainbow island floating in clouds, rainbow arches, soft cotton candy clouds, golden light, rainbow crystals",
     "1:1"),
    ("island_breathing",
     "Serene calm lake island at dusk, lotus flowers floating, smooth mirror-like water, fireflies, peaceful willows",
     "1:1"),
    ("island_rhythm",
     "Colorful music village island with tiny houses shaped like instruments, musical notes floating, drum bridges",
     "1:1"),
    ("island_storytelling",
     "Fairy tale castle island made of books, towers of stacked colorful books, open book drawbridge, reading owl",
     "1:1"),
]

TIER_H3 = [
    ("celebration_fireworks",
     "Colorful fireworks bursting in soft night sky, pastel colors, sparkles, stars, festive celebration scene",
     "1:1"),
    ("celebration_trophy_glow",
     "Golden trophy glowing with warm light, stars orbiting around it, sparkles, confetti, achievement glow",
     "1:1"),
    ("celebration_rainbow",
     "Brilliant rainbow with clouds at each end, sparkles along the arc, sunshine peeking, soft dreamy sky",
     "1:1"),
    ("celebration_balloons",
     "Bouquet of colorful kawaii balloons floating up, each balloon with a happy face, confetti and streamers",
     "1:1"),
    ("celebration_stars",
     "Shower of golden stars falling from above, big central glowing star, star trails, magical sparkles all around",
     "1:1"),
]

TIER_H4 = [
    ("trophy_bg_gold",
     "Rich golden gradient background with subtle star pattern, radiating golden rays from center, luxurious glow",
     "1:1"),
    ("trophy_bg_silver",
     "Cool silver gradient background with snowflake-like crystal pattern, metallic sheen, soft blue highlights",
     "1:1"),
    ("trophy_bg_bronze",
     "Warm copper-bronze gradient background with autumn leaf pattern, amber glow, cozy warm tones",
     "1:1"),
    ("trophy_bg_streak_7",
     "Week calendar with seven flame icons glowing, warm orange gradient, streak fire trail decoration",
     "1:1"),
    ("trophy_bg_streak_30",
     "Monthly calendar with fire and star icons, golden radiant background, 30 glowing checkmarks",
     "1:1"),
    ("trophy_bg_streak_100",
     "Epic golden cosmic background with comet trails, galaxy sparkles, legendary glow, 100 sparkling dots",
     "1:1"),
    ("trophy_bg_lessons_10",
     "Soft pastel background with ten open book icons, scattered sparkles, achievement badge style",
     "1:1"),
    ("trophy_bg_lessons_50",
     "Purple-lilac gradient background with glowing stars arranged in arc, achievement glow",
     "1:1"),
    ("trophy_bg_lessons_100",
     "Epic royal blue-gold gradient background, starbursts, golden laurel wreath decoration",
     "1:1"),
    ("trophy_bg_perfect",
     "Pristine white-gold gradient background, perfect score star badge, diamond sparkles, rainbow prism edge",
     "1:1"),
]

TIER_H5_CATEGORIES = [
    ("dyslalia",        "sound correction practice"),
    ("phonemic",        "phonemic awareness training"),
    ("grammar",         "grammar building exercise"),
    ("lexical",         "vocabulary development activity"),
    ("coherent",        "storytelling practice session"),
    ("breathing",       "breathing exercise session"),
    ("logorhythmics",   "rhythm and movement activity"),
    ("fluency",         "speech fluency training"),
    ("articulation",    "articulation gymnastics exercise"),
    ("differentiation", "sound differentiation practice"),
    ("advanced",        "advanced speech practice session"),
]

TIER_H5_STAGES = [
    ("warmup",   "warm-up preparation scene"),
    ("practice", "active practice scene"),
    ("game",     "playful game scene"),
    ("review",   "review and recap scene"),
]


def build_tier_h5() -> list:
    items = []
    for cat_slug, cat_desc in TIER_H5_CATEGORIES:
        for stage_slug, stage_desc in TIER_H5_STAGES:
            slug  = f"lesson_intro_{cat_slug}_{stage_slug}"
            scene = (
                f"Lesson introduction for {cat_desc}, {stage_desc}, "
                f"cute cartoon animals in a learning environment, educational, "
                f"colorful and engaging, friendly kawaii cartoon style"
            )
            items.append((slug, scene, "16:9"))
    return items


TIER_H5 = build_tier_h5()  # 44 images

TIER_H6 = [
    ("parent_hero_progress",
     "Upward progress chart with colorful bars and stars, clipboard with checkmarks, growth visualization",
     "16:9"),
    ("parent_hero_streak",
     "Calendar page with consecutive flame icons, glowing streak counter, warm encouraging tones",
     "16:9"),
    ("parent_hero_calendar",
     "Friendly calendar with stars and flowers on completed days, scheduling planner visual",
     "16:9"),
    ("parent_hero_insights",
     "Bar graphs and pie charts made of cute shapes like stars and hearts, data visualization kawaii style",
     "16:9"),
    ("parent_hero_share",
     "Paper airplane flying with sparkle trail, sending achievement certificate, celebration confetti",
     "16:9"),
    ("parent_hero_tips",
     "Open book with light bulb above it, helpful hint icons, soft educational scene",
     "16:9"),
    ("parent_hero_homework",
     "Cozy desk with pencil, notebook, apple, stack of books, warm lamp light",
     "16:9"),
    ("parent_hero_notifications",
     "Bell with gentle sparkles, notification bubbles with stars, friendly reminder scene",
     "16:9"),
    ("parent_hero_settings",
     "Gear icon with flowers growing out of it, wrench with bow, friendly customization visual",
     "16:9"),
    ("parent_hero_achievements",
     "Trophy shelf with gold silver bronze cups, stars and medals, celebratory display",
     "16:9"),
    ("parent_hero_report",
     "Scroll of paper with star ratings, illustrated report card with smiling sun",
     "16:9"),
    ("parent_hero_goals",
     "Target with arrow hitting bullseye made of stars, goal achievement visual",
     "16:9"),
    ("parent_hero_weekly",
     "Weekly planner with colorful activity blocks, rainbow schedule, organized layout",
     "16:9"),
    ("parent_hero_connect",
     "Two phones connected by a glowing heart beam, sharing connection visual",
     "16:9"),
    ("parent_hero_premium",
     "Crown with gems surrounded by stars, premium unlock scene, magical upgrade visual",
     "16:9"),
]

TIER_H7 = [
    ("daily_morning",
     "Morning sunrise over rolling hills, cheerful sun rising, birds singing, fresh dewy flowers",
     "1:1"),
    ("daily_evening",
     "Peaceful evening scene with moon and stars coming out, cozy lantern light, fireflies",
     "1:1"),
    ("daily_breath",
     "Gentle wind swirling around a glowing flower, breath ripples, calm meditation visual",
     "1:1"),
    ("daily_rhythm",
     "Drum and musical notes bouncing in rhythm, colorful sound waves, playful beat visual",
     "1:1"),
    ("daily_word",
     "Open magical book with words floating as butterflies, sparkles, dictionary enchantment",
     "1:1"),
    ("daily_story",
     "Storybook opening with scene popping out, clouds and castle, story magic visual",
     "1:1"),
    ("daily_articulation",
     "Cartoon mouth doing exercises, fun exercise visual for mouth movements",
     "1:1"),
    ("daily_listening",
     "Big friendly ear with sound waves, musical notes floating in, listening training visual",
     "1:1"),
    ("daily_memory",
     "Brain with memory cards glowing, memory game visual, colorful tiles",
     "1:1"),
    ("daily_singing",
     "Musical staff with singing bird, notes floating upward, melody visualization",
     "1:1"),
    ("daily_puzzle",
     "Jigsaw puzzle pieces forming a star, colorful interlocking shapes, completion visual",
     "1:1"),
    ("daily_matching",
     "Two matching cards with sparkle connection between them, match found celebration",
     "1:1"),
    ("daily_sorting",
     "Colorful objects being sorted into matching baskets, categorization visual",
     "1:1"),
    ("daily_drawing",
     "Crayon drawing a rainbow, colorful art supplies, creative expression visual",
     "1:1"),
    ("daily_challenge",
     "Medal with lightning bolt, challenge accepted visual, determined cute animal mascot",
     "1:1"),
    ("daily_bonus",
     "Gift box opening with rainbow light inside, bonus surprise reveal visual",
     "1:1"),
    ("daily_quick",
     "Stopwatch with lightning bolts, quick activity visual, speed stars",
     "1:1"),
    ("daily_calm",
     "Peaceful lotus flower floating on still water, calm mindfulness visual",
     "1:1"),
    ("daily_fun",
     "Carnival pinwheel spinning with confetti, playful party visual, fun celebration",
     "1:1"),
    ("daily_final",
     "Finish line ribbon with stars and confetti, day complete celebration visual",
     "1:1"),
]

TIER_H8 = [
    # animals collection (12 slots)
    ("reward_animal_cat",
     "Adorable kawaii cartoon cat with big eyes and tiny paws, soft pastel fur, happy smile",
     "1:1"),
    ("reward_animal_dog",
     "Cute kawaii puppy with floppy ears and wagging tail, cheerful expression, soft colors",
     "1:1"),
    ("reward_animal_bunny",
     "Fluffy kawaii bunny with long ears, rosy cheeks, holding a tiny carrot, pastel pink",
     "1:1"),
    ("reward_animal_bear",
     "Chubby kawaii bear cub with round ears, honey pot, soft brown and cream colors",
     "1:1"),
    ("reward_animal_fox",
     "Clever kawaii fox with bushy tail, orange and white, curious big eyes",
     "1:1"),
    ("reward_animal_owl",
     "Round kawaii owl with big round glasses, wise expression, sitting on a branch",
     "1:1"),
    ("reward_animal_frog",
     "Happy kawaii frog on lily pad, bright green, big smile, musical notes floating",
     "1:1"),
    ("reward_animal_duck",
     "Cheerful kawaii duck with yellow feathers, rain boots, umbrella, puddle splashing",
     "1:1"),
    ("reward_animal_butterfly",
     "Magical kawaii butterfly with coral peach wings, sparkle trail, flower landing",
     "1:1"),
    ("reward_animal_bee",
     "Striped kawaii bee with tiny crown, honey dripping, flower garden background",
     "1:1"),
    ("reward_animal_squirrel",
     "Fluffy kawaii squirrel with big bushy tail, holding an acorn, autumn leaves",
     "1:1"),
    ("reward_animal_hedgehog",
     "Tiny kawaii hedgehog with round spines carrying an apple, forest mushroom background",
     "1:1"),
    # space collection (12 slots)
    ("reward_space_rocket",
     "Kawaii rocket ship with smiling window, leaving star trail, planets in background",
     "1:1"),
    ("reward_space_planet",
     "Cute kawaii planet with rings and little star friends, colorful space scene",
     "1:1"),
    ("reward_space_star",
     "Glowing kawaii shooting star with sparkle trail, winking expression, golden glow",
     "1:1"),
    ("reward_space_astronaut",
     "Kawaii robot in round space helmet floating in space, robot style no human face, stars",
     "1:1"),
    ("reward_space_moon",
     "Kawaii crescent moon with sleeping face, blanket of stars, soft night scene",
     "1:1"),
    ("reward_space_ufo",
     "Kawaii UFO with twinkling lights, friendly beam of light, starry background",
     "1:1"),
    ("reward_space_comet",
     "Kawaii comet zooming with colorful sparkle trail, happy expression, space scene",
     "1:1"),
    ("reward_space_galaxy",
     "Swirling kawaii galaxy spiral with colorful stars, miniature planets orbiting",
     "1:1"),
    ("reward_space_telescope",
     "Kawaii telescope pointing at stars, magnifying celestial objects, observatory scene",
     "1:1"),
    ("reward_space_satellite",
     "Kawaii satellite with solar panels, beaming signals, orbiting above clouds",
     "1:1"),
    ("reward_space_nebula",
     "Colorful kawaii nebula cloud with embedded stars, pastel purple pink blue tones",
     "1:1"),
    ("reward_space_blackhole",
     "Friendly kawaii black hole with swirling colorful accretion disc, winking star at center",
     "1:1"),
    # forest collection (12 slots)
    ("reward_forest_mushroom",
     "Magical kawaii mushroom house with tiny windows, flowers around base, friendly face",
     "1:1"),
    ("reward_forest_acorn",
     "Adorable kawaii acorn with cap hat, smiling face, autumn leaf friends",
     "1:1"),
    ("reward_forest_leaf",
     "Kawaii maple leaf with happy face, in autumn colors red orange yellow",
     "1:1"),
    ("reward_forest_pinecone",
     "Round kawaii pinecone with spiral pattern, soft brown tones, sitting on moss",
     "1:1"),
    ("reward_forest_berry",
     "Cluster of kawaii berries with happy faces, red and blue varieties, leaf backdrop",
     "1:1"),
    ("reward_forest_snail",
     "Kawaii snail with spiral rainbow shell, carrying a tiny house, garden path",
     "1:1"),
    ("reward_forest_ladybug",
     "Spotted kawaii ladybug with big eyes, sitting on a dewdrop leaf, garden scene",
     "1:1"),
    ("reward_forest_dragonfly",
     "Iridescent kawaii dragonfly with delicate wings, hovering over water, sparkles",
     "1:1"),
    ("reward_forest_treehouse",
     "Kawaii treehouse in a big oak tree, rope ladder, cozy glowing window, bird friend",
     "1:1"),
    ("reward_forest_firefly",
     "Kawaii firefly glowing in a jar, soft golden light, nighttime forest background",
     "1:1"),
    ("reward_forest_moss",
     "Soft kawaii moss patch with tiny fairy mushrooms, dewdrops, morning light",
     "1:1"),
    ("reward_forest_creek",
     "Kawaii babbling brook with stepping stones, tiny fish, flower banks, happy water",
     "1:1"),
    # ocean collection (12 slots)
    ("reward_ocean_fish",
     "Kawaii tropical fish with colorful stripes, bubbles floating, coral reef background",
     "1:1"),
    ("reward_ocean_starfish",
     "Smiling kawaii starfish on sandy bottom, warm ocean water, shells and pebbles",
     "1:1"),
    ("reward_ocean_seahorse",
     "Elegant kawaii seahorse with curly tail, wearing tiny crown, underwater garden",
     "1:1"),
    ("reward_ocean_crab",
     "Friendly kawaii crab with big claws, beach sand, water waves background",
     "1:1"),
    ("reward_ocean_jellyfish",
     "Glowing kawaii jellyfish with trailing tentacles, bioluminescent ocean scene",
     "1:1"),
    ("reward_ocean_octopus",
     "Cute kawaii octopus with eight happy tentacles, holding different colored balls",
     "1:1"),
    ("reward_ocean_dolphin",
     "Playful kawaii dolphin leaping through waves, rainbow splash, sunshine",
     "1:1"),
    ("reward_ocean_whale",
     "Gentle kawaii whale with water spout forming a rainbow, ocean scene",
     "1:1"),
    ("reward_ocean_turtle",
     "Wise kawaii sea turtle with mosaic shell pattern, swimming through coral",
     "1:1"),
    ("reward_ocean_shell",
     "Kawaii spiral seashell with pearl inside, beach setting, gentle waves",
     "1:1"),
    ("reward_ocean_lighthouse",
     "Kawaii lighthouse on rocky island, spinning light beam, clearing sky",
     "1:1"),
    ("reward_ocean_treasure",
     "Kawaii treasure chest on ocean floor, golden coins and gems spilling out, fish friends",
     "1:1"),
    # halloween collection (12 slots) — cute and mild only
    ("reward_halloween_pumpkin",
     "Cute kawaii jack-o-lantern with gentle smile, soft orange glow, autumn leaves",
     "1:1"),
    ("reward_halloween_ghost",
     "Friendly kawaii ghost with big eyes and smile, floating with tiny star companions",
     "1:1"),
    ("reward_halloween_witch_hat",
     "Kawaii witch hat decorated with stars and moon, sparkles, magical swirls around it",
     "1:1"),
    ("reward_halloween_cauldron",
     "Kawaii cauldron with colorful potion bubbling out, stars and sparkles, magical",
     "1:1"),
    ("reward_halloween_bat",
     "Tiny kawaii bat with big eyes and little wings, hanging upside down, moon backdrop",
     "1:1"),
    ("reward_halloween_spider",
     "Cute kawaii spider with eight big eyes and bow on head, sitting on web, friendly",
     "1:1"),
    ("reward_halloween_candy",
     "Collection of kawaii candy treats in pumpkin bucket, colorful sweets, festive",
     "1:1"),
    ("reward_halloween_broom",
     "Kawaii magical broom with star trail, leaving sparkles behind, flying effect",
     "1:1"),
    ("reward_halloween_moon_full",
     "Full kawaii moon face with gentle smile, clouds parting, stars around",
     "1:1"),
    ("reward_halloween_owl_spooky",
     "Kawaii owl on pumpkin perch, glowing eyes, festive autumn leaves, spooky cute style",
     "1:1"),
    ("reward_halloween_potion",
     "Kawaii potion bottle with swirling colors inside, cork with star, magical glow",
     "1:1"),
    ("reward_halloween_scarecrow",
     "Kawaii scarecrow figure made of straw, friendly face, hat and patches, autumn field",
     "1:1"),
    # newYear collection (12 slots)
    ("reward_newyear_snowflake",
     "Intricate kawaii snowflake crystal, icy blue-white sparkle, winter wonderland",
     "1:1"),
    ("reward_newyear_tree",
     "Kawaii decorated holiday tree with star on top, ornaments, tinsel, warm glow",
     "1:1"),
    ("reward_newyear_bell",
     "Golden kawaii jingle bell with red ribbon, ringing with musical notes and sparkles",
     "1:1"),
    ("reward_newyear_gift",
     "Kawaii gift box with enormous bow, polka dots, sparkle bursting from seams",
     "1:1"),
    ("reward_newyear_candle",
     "Kawaii glowing candle in snow, flame as tiny star, cozy winter scene",
     "1:1"),
    ("reward_newyear_mitten",
     "Kawaii woolly mitten with snowflake pattern, cozy warm red and white",
     "1:1"),
    ("reward_newyear_cookie",
     "Kawaii star-shaped holiday cookie with icing and sprinkles, festive decoration",
     "1:1"),
    ("reward_newyear_firework",
     "Kawaii firework bursting into colorful stars at midnight, celebration scene",
     "1:1"),
    ("reward_newyear_deer",
     "Kawaii reindeer with glowing red nose, antlers with bells, snowy backdrop",
     "1:1"),
    ("reward_newyear_snowman",
     "Kawaii snowman with carrot nose, scarf and top hat, friendly wave",
     "1:1"),
    ("reward_newyear_clock",
     "Kawaii grandfather clock counting down to midnight, stars around, new year visual",
     "1:1"),
    ("reward_newyear_champagne",
     "Kawaii sparkling cider bottle popping confetti, celebration, festive party",
     "1:1"),
]

TIER_H9 = [
    ("marketing_appstore_hero",
     "Showcase of cute butterfly mascot surrounded by speech bubble achievements, colorful app interface illustration",
     "16:9"),
    ("marketing_screenshot_bg_1",
     "Gradient background with floating musical notes and stars, soft coral to teal gradient, decorative",
     "9:16"),
    ("marketing_screenshot_bg_2",
     "Soft pastel cloud landscape background, fluffy clouds on sky gradient, minimal, decorative",
     "9:16"),
    ("marketing_screenshot_bg_3",
     "Abstract watercolor-style background with soft coral and mint splashes, gentle texture",
     "9:16"),
    ("marketing_splash_light",
     "Bright welcoming splash screen background, sunburst radiating from center, soft pastels",
     "1:1"),
    ("marketing_splash_dark",
     "Dark navy background with constellation stars forming a butterfly shape, glowing edges",
     "1:1"),
    ("marketing_readme_hero",
     "Wide banner with cute animal characters around speech bubbles showing different sounds, colorful educational scene",
     "16:9"),
    ("marketing_icon_scene_1",
     "Alternative icon composition: butterfly mascot on cloud with rainbow, minimal clean",
     "1:1"),
    ("marketing_icon_scene_2",
     "Alternative icon composition: butterfly mascot emerging from book with sparkles",
     "1:1"),
    ("marketing_icon_scene_3",
     "Alternative icon composition: butterfly mascot on star podium with gold confetti",
     "1:1"),
]


# ══════════════════════════════════════════════════════════════════════════════
# MAIN EXECUTION
# ══════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    BASE_DIR.mkdir(parents=True, exist_ok=True)

    start_time = datetime.datetime.now()
    print("HappySpeech Hero Illustration Generator (google-genai SDK)")
    print("Model: imagen-3.0-generate-001")
    print(f"Hard cap: ${HARD_CAP:.2f} ({int(HARD_CAP / COST_PER_IMAGE)} images)")
    print(f"Start: {start_time.strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 60)

    run_tier("H1", TIER_H1)
    run_tier("H2", TIER_H2)
    run_tier("H3", TIER_H3)
    run_tier("H4", TIER_H4)
    run_tier("H5", TIER_H5)
    run_tier("H6", TIER_H6)
    run_tier("H7", TIER_H7)
    run_tier("H8", TIER_H8)
    run_tier("H9", TIER_H9)

    elapsed = (datetime.datetime.now() - start_time).total_seconds()

    print("\n" + "=" * 60)
    print(f"DONE — {elapsed:.0f}s elapsed")
    print(f"  Generated : {total_gen}")
    print(f"  Skipped   : {total_skip}")
    print(f"  Failed    : {total_fail}")
    print(f"  Total cost: ${total_cost:.2f}")

    # Write manifest
    manifest = {
        "version": 1,
        "model": "imagen-3.0-generate-001",
        "generatedAt": datetime.datetime.now().isoformat(),
        "totalImages": total_gen,
        "totalCost": round(total_cost, 2),
        "skipped": total_skip,
        "failed": total_fail,
        "entries": manifest_entries,
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2, ensure_ascii=False))
    print(f"  Manifest  : {MANIFEST_PATH}")
