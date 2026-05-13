#!/usr/bin/env bash
# v22 Block 0.2 — capture 85 routes x 2 themes = 170 PNG.
# Continues on per-route timeout (>10s hang). Records misses to .claude/team/v22-screenshot-misses.md.

set -u

PROJECT_DIR="/Users/antongric/Yandex.Disk.localized/xcode_projects/Диплом/HappySpeech"
SHOT_DIR="${PROJECT_DIR}/_workshop/screenshots/v22"
MISSES_FILE="${PROJECT_DIR}/.claude/team/v22-screenshot-misses.md"
BUNDLE_ID="com.mmf.bsu.HappySpeech"

mkdir -p "${SHOT_DIR}"

ROUTES=(
  authSignUp authForgotPassword authVerifyEmail anonymousAuth splash specialistHome
  onboarding1 onboarding2 onboarding3 onboarding4 onboarding5
  onboarding6 onboarding7 onboarding8 onboarding9 onboarding10
  lessonListenAndChoose lessonRepeatAfterModel lessonDragAndMatch lessonStoryCompletion
  lessonPuzzleReveal lessonSorting lessonMemory lessonBingo
  lessonSoundHunter lessonArticulationImitation lessonARActivity lessonVisualAcoustic
  lessonBreathingExercise lessonRhythm lessonNarrativeQuest lessonMinimalPairs
  arMirror arStoryQuest breathingAR butterflyCatch holdThePose
  mascot3D mimicLyalya poseSequence soundAndFace
  sessionShell sessionDetail celebrationOverlay rewardDetail rewardAlbum
  settingsTheme settingsNotifications settingsModelPacks settingsPrivacy settingsGDPR
  settingsAbout settingsVoice settingsLanguage settingsAccessibility
  demoStep1 demoStep5 demoStep10 demoStep15 homeTasks rewardCollection dailyStreak
  familyHome profileEditor comparisonDashboard familyCalendar familyLeaderboard familyAchievements
  specialistLogin studentsList programEditor sessionReview reports
  stutteringHome breathingTree fluencyDiaryHome metronome softOnset
  neurolinguistInsights speechVisualization offlineMiniGame arFaceFilter guidedTour grammarGame
  siblingMultiplayerDiscovery siblingMultiplayerLobby siblingMultiplayerGame
  dialectAdaptation logopedistChat weeklyChallenge culturalContent
  pronunciationLeaderboard soundDictionary helpCenter
  dailyChallenge parentInsightsTimeline familyAwardsCabinet voiceCloning
)

echo "Routes to capture: ${#ROUTES[@]}"

MISSES=""
TOTAL=0
CAPTURED=0

for theme in light dark; do
  xcrun simctl ui booted appearance "$theme" >/dev/null 2>&1
  sleep 1
  for route in "${ROUTES[@]}"; do
    TOTAL=$((TOTAL+1))
    OUT="${SHOT_DIR}/${route}_${theme}.png"

    # Terminate any previous instance.
    xcrun simctl terminate booted "$BUNDLE_ID" >/dev/null 2>&1 || true
    sleep 0.3

    # Launch with HSStartRoute. macOS has no `timeout`, rely on simctl's own
    # internal launch timeout + post-launch sleep for render settling.
    if ! xcrun simctl launch booted "$BUNDLE_ID" -HSStartRoute "$route" >/dev/null 2>&1; then
      MISSES+="- ${route} (${theme}): launch failed\n"
      continue
    fi

    # Allow UI to render (page transition ~MotionTokens.page + content load).
    sleep 2

    if xcrun simctl io booted screenshot "$OUT" >/dev/null 2>&1; then
      CAPTURED=$((CAPTURED+1))
    else
      MISSES+="- ${route} (${theme}): screenshot failed\n"
    fi
  done
done

# Final terminate.
xcrun simctl terminate booted "$BUNDLE_ID" >/dev/null 2>&1 || true

echo "Captured: ${CAPTURED}/${TOTAL}"
echo "Files on disk:"
ls "${SHOT_DIR}"/*.png 2>/dev/null | wc -l

if [ -n "$MISSES" ]; then
  {
    echo "# v22 Block 0.2 — Screenshot Misses"
    echo ""
    echo "Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "Total routes: $TOTAL"
    echo "Captured: $CAPTURED"
    echo ""
    echo "## Misses"
    echo ""
    printf '%b' "$MISSES"
  } > "$MISSES_FILE"
  echo "Misses logged to: $MISSES_FILE"
fi
