#!/usr/bin/env python3
"""
Generate all named color assets for HappySpeech design system.
Writes .colorset/Contents.json into Assets.xcassets.
Each color has a light and dark variant.
"""

import json
import os

ASSETS_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "HappySpeech", "Resources", "Assets.xcassets"
)

# Palette: name -> (light_hex, dark_hex)
COLORS = {
    # Brand
    "BrandPrimary":    ("#FF7B54", "#FF9070"),
    "BrandPrimaryHi":  ("#FF9A7A", "#FFAC90"),
    "BrandPrimaryLo":  ("#FFD1BE", "#FFB99A"),
    "BrandMint":       ("#34C78A", "#3ED99A"),
    "BrandSky":        ("#3B9EFF", "#5AB0FF"),
    "BrandLilac":      ("#A084E0", "#B898F0"),
    "BrandButter":     ("#FFD740", "#FFE066"),
    "BrandRose":       ("#FF8FAB", "#FFA0BC"),

    # Kid Circuit
    "KidBg":           ("#FFF8F0", "#2A1F18"),
    "KidBgDeep":       ("#FFF0E0", "#1E1510"),
    "KidSurface":      ("#FFFFFF", "#362A22"),
    "KidSurfaceAlt":   ("#FFF3E8", "#3E3028"),
    "KidInk":          ("#2D1A0E", "#F5EDE5"),
    "KidInkMuted":     ("#7A5C4A", "#C4AFA5"),
    "KidInkSoft":      ("#B8A098", "#8A7870"),
    "KidLine":         ("#F0DDD0", "#4A3830"),

    # Parent Circuit
    "ParentBg":        ("#F7F8FA", "#0F1117"),
    "ParentBgDeep":    ("#ECEEF2", "#080B10"),
    "ParentSurface":   ("#FFFFFF", "#1A1E2B"),
    "ParentInk":       ("#0F1117", "#EEF0F5"),
    "ParentInkMuted":  ("#5C6478", "#9BA3BA"),
    "ParentInkSoft":   ("#9BA3BA", "#5C6478"),
    "ParentLine":      ("#E4E7EE", "#2A2F3D"),
    "ParentLineStrong":("#C8CDD8", "#3A3F50"),
    "ParentAccent":    ("#3B9EFF", "#5AB0FF"),

    # Specialist Circuit
    "SpecBg":          ("#F0F2F5", "#0B0D12"),
    "SpecSurface":     ("#FFFFFF", "#161A23"),
    "SpecPanel":       ("#E8EBF0", "#1E2330"),
    "SpecInk":         ("#0B0D12", "#E8EBF0"),
    "SpecInkMuted":    ("#4A5568", "#8C96B0"),
    "SpecLine":        ("#DCE1EA", "#252B38"),
    "SpecGrid":        ("#E8ECF2", "#1C2030"),
    "SpecAccent":      ("#3B9EFF", "#5AB0FF"),
    "SpecWaveform":    ("#34C78A", "#3ED99A"),
    "SpecTarget":      ("#FF7B54", "#FF9070"),

    # Semantic
    "SemSuccess":      ("#34C78A", "#3ED99A"),
    "SemSuccessBg":    ("#E6F9F0", "#0A2A1C"),
    "SemError":        ("#FF4D6A", "#FF6B84"),
    "SemErrorBg":      ("#FFF0F2", "#2A0C10"),
    "SemWarning":      ("#FFB020", "#FFC040"),
    "SemWarningBg":    ("#FFF8E6", "#2A1E04"),
    "SemInfo":         ("#3B9EFF", "#5AB0FF"),
    "SemInfoBg":       ("#EAF3FF", "#061828"),

    # Sound Family Palettes
    "SoundWhistlingHue": ("#3B9EFF", "#5AB0FF"),
    "SoundWhistlingBg":  ("#EAF3FF", "#061828"),
    "SoundHissingHue":   ("#FF7B54", "#FF9070"),
    "SoundHissingBg":    ("#FFF3EE", "#2A1208"),
    "SoundSonorantHue":  ("#34C78A", "#3ED99A"),
    "SoundSonorantBg":   ("#E6F9F0", "#0A2A1C"),
    "SoundVelarHue":     ("#A084E0", "#B898F0"),
    "SoundVelarBg":      ("#F0EAFB", "#1A0E2A"),
    "SoundVowelsHue":    ("#FFD740", "#FFE066"),
    "SoundVowelsBg":     ("#FFFBE6", "#2A2204"),
}


def hex_to_components(hex_color: str) -> dict:
    h = hex_color.lstrip("#")
    r = int(h[0:2], 16) / 255.0
    g = int(h[2:4], 16) / 255.0
    b = int(h[4:6], 16) / 255.0
    return {
        "alpha": "1.000",
        "blue":  f"{b:.3f}",
        "green": f"{g:.3f}",
        "red":   f"{r:.3f}",
    }


def make_contents(light_hex: str, dark_hex: str) -> dict:
    return {
        "colors": [
            {
                "color": {
                    "color-space": "srgb",
                    "components": hex_to_components(light_hex),
                },
                "idiom": "universal",
            },
            {
                "appearances": [
                    {"appearance": "luminosity", "value": "dark"}
                ],
                "color": {
                    "color-space": "srgb",
                    "components": hex_to_components(dark_hex),
                },
                "idiom": "universal",
            },
        ],
        "info": {"author": "xcode", "version": 1},
    }


def main():
    created = 0
    for name, (light, dark) in COLORS.items():
        colorset_dir = os.path.join(ASSETS_DIR, f"{name}.colorset")
        os.makedirs(colorset_dir, exist_ok=True)
        contents_path = os.path.join(colorset_dir, "Contents.json")
        contents = make_contents(light, dark)
        with open(contents_path, "w") as f:
            json.dump(contents, f, indent=2)
        created += 1
        print(f"  ✓ {name}  ({light} / {dark})")

    print(f"\n{created} color assets written to:\n  {ASSETS_DIR}")


if __name__ == "__main__":
    main()
