#!/usr/bin/env bash
# Block R — Remotion batch render: 45 new MP4 videos
# Resumable: skips already-rendered files
# Usage: bash scripts/block_r_render.sh [--force]
# Requires: running from project root (/Users/antongric/.../HappySpeech)

set -euo pipefail

PROJECT_ROOT="/Users/antongric/Yandex.Disk.localized/xcode_projects/Диплом/HappySpeech"
REMOTION_DIR="$PROJECT_ROOT/_workshop/remotion"
VIDEOS_DIR="$PROJECT_ROOT/HappySpeech/Resources/Videos"
OUT_DIR="$REMOTION_DIR/out"

FORCE=${1:-""}
CODEC="h264"
CRF="28"

render_video() {
  local comp_id="$1"
  local output_path="$2"

  if [[ "$FORCE" != "--force" ]] && [[ -f "$output_path" ]]; then
    echo "  SKIP (exists): $output_path"
    return 0
  fi

  mkdir -p "$(dirname "$output_path")"
  echo "  RENDERING: $comp_id -> $output_path"
  cd "$REMOTION_DIR"
  npx remotion render src/index.ts "$comp_id" "$output_path" \
    --codec="$CODEC" --crf="$CRF" --log=error 2>&1 | grep -E "(Rendered|Encoded|error|Error)" | tail -3
  echo "  DONE: $(du -sh "$output_path" | cut -f1)"
}

echo "=== Block R Render ==="
echo "Output: $VIDEOS_DIR"
echo "Codec: $CODEC  CRF: $CRF"
echo ""

# ── Group 1: 30 Lesson Walkthroughs ──────────────────────────────────────────
echo "--- Group 1: Lessons (30 videos) ---"

# 16 unique templates
render_video "lesson-listen-and-choose"          "$OUT_DIR/lessons/listen-and-choose.mp4"
render_video "lesson-repeat-after-model"         "$OUT_DIR/lessons/repeat-after-model.mp4"
render_video "lesson-drag-and-match"             "$OUT_DIR/lessons/drag-and-match.mp4"
render_video "lesson-story-completion"           "$OUT_DIR/lessons/story-completion.mp4"
render_video "lesson-puzzle-reveal"              "$OUT_DIR/lessons/puzzle-reveal.mp4"
render_video "lesson-sorting"                    "$OUT_DIR/lessons/sorting.mp4"
render_video "lesson-memory"                     "$OUT_DIR/lessons/memory.mp4"
render_video "lesson-bingo"                      "$OUT_DIR/lessons/bingo.mp4"
render_video "lesson-sound-hunter"               "$OUT_DIR/lessons/sound-hunter.mp4"
render_video "lesson-articulation-imitation"     "$OUT_DIR/lessons/articulation-imitation.mp4"
render_video "lesson-AR-activity"                "$OUT_DIR/lessons/AR-activity.mp4"
render_video "lesson-visual-acoustic"            "$OUT_DIR/lessons/visual-acoustic.mp4"
render_video "lesson-breathing"                  "$OUT_DIR/lessons/breathing.mp4"
render_video "lesson-rhythm"                     "$OUT_DIR/lessons/rhythm.mp4"
render_video "lesson-narrative-quest"            "$OUT_DIR/lessons/narrative-quest.mp4"
render_video "lesson-minimal-pairs"              "$OUT_DIR/lessons/minimal-pairs.mp4"

# 14 variants
render_video "lesson-repeat-after-model-S"       "$OUT_DIR/lessons/repeat-after-model_S.mp4"
render_video "lesson-repeat-after-model-R"       "$OUT_DIR/lessons/repeat-after-model_R.mp4"
render_video "lesson-repeat-after-model-L"       "$OUT_DIR/lessons/repeat-after-model_L.mp4"
render_video "lesson-bingo-Sh"                   "$OUT_DIR/lessons/bingo_Sh.mp4"
render_video "lesson-bingo-Z"                    "$OUT_DIR/lessons/bingo_Z.mp4"
render_video "lesson-minimal-pairs-S-Sh"         "$OUT_DIR/lessons/minimal-pairs_S_Sh.mp4"
render_video "lesson-minimal-pairs-R-L"          "$OUT_DIR/lessons/minimal-pairs_R_L.mp4"
render_video "lesson-minimal-pairs-S-Z"          "$OUT_DIR/lessons/minimal-pairs_S_Z.mp4"
render_video "lesson-sorting-whistles"           "$OUT_DIR/lessons/sorting_whistles.mp4"
render_video "lesson-sorting-hisses"             "$OUT_DIR/lessons/sorting_hisses.mp4"
render_video "lesson-sorting-sonors"             "$OUT_DIR/lessons/sorting_sonors.mp4"
render_video "lesson-articulation-imitation-S"   "$OUT_DIR/lessons/articulation-imitation_S.mp4"
render_video "lesson-articulation-imitation-R"   "$OUT_DIR/lessons/articulation-imitation_R.mp4"
render_video "lesson-AR-activity-breathing"      "$OUT_DIR/lessons/AR-activity_breathing.mp4"

echo ""
echo "--- Group 2: Achievement Reveals (10 videos) ---"
render_video "ach-reward-first-sound"            "$OUT_DIR/achievements/reward_first_sound.mp4"
render_video "ach-reward-streak-7"               "$OUT_DIR/achievements/reward_streak_7.mp4"
render_video "ach-reward-streak-30"              "$OUT_DIR/achievements/reward_streak_30.mp4"
render_video "ach-reward-first-ar"               "$OUT_DIR/achievements/reward_first_ar.mp4"
render_video "ach-reward-grammar-master"         "$OUT_DIR/achievements/reward_grammar_master.mp4"
render_video "ach-reward-family-voice"           "$OUT_DIR/achievements/reward_family_voice.mp4"
render_video "ach-reward-explorer"               "$OUT_DIR/achievements/reward_explorer.mp4"
render_video "ach-reward-perfectionist"          "$OUT_DIR/achievements/reward_perfectionist.mp4"
render_video "ach-reward-champion"               "$OUT_DIR/achievements/reward_champion.mp4"
render_video "ach-reward-first-star"             "$OUT_DIR/achievements/reward_first_star.mp4"

echo ""
echo "--- Group 3: Tutorial Overviews (5 videos) ---"
render_video "tut-tutorial-how-to-play"          "$OUT_DIR/tutorials/tutorial_how_to_play.mp4"
render_video "tut-tutorial-articulation"         "$OUT_DIR/tutorials/tutorial_articulation.mp4"
render_video "tut-tutorial-breathing"            "$OUT_DIR/tutorials/tutorial_breathing.mp4"
render_video "tut-tutorial-progress-tracking"    "$OUT_DIR/tutorials/tutorial_progress_tracking.mp4"
render_video "tut-tutorial-ar-setup"             "$OUT_DIR/tutorials/tutorial_ar_setup.mp4"

echo ""
echo "--- Copying to Resources/Videos ---"

# Copy all rendered videos to Resources
cp -v "$OUT_DIR/lessons/"*.mp4       "$VIDEOS_DIR/lessons/"       2>/dev/null || true
cp -v "$OUT_DIR/achievements/"*.mp4  "$VIDEOS_DIR/achievements/"  2>/dev/null || true
cp -v "$OUT_DIR/tutorials/"*.mp4     "$VIDEOS_DIR/tutorials/"     2>/dev/null || true

echo ""
echo "=== Final count ==="
find "$VIDEOS_DIR" -name "*.mp4" | wc -l | xargs echo "Total MP4 in Resources/Videos:"
du -sh "$VIDEOS_DIR" | echo "Total size: $(cut -f1)"
echo ""
echo "Block R render complete."
