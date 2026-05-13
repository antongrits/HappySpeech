#!/usr/bin/env bash
# v22 Block 0.2 — retry pass for missed routes.

set -u

PROJECT_DIR="/Users/antongric/Yandex.Disk.localized/xcode_projects/Диплом/HappySpeech"
SHOT_DIR="${PROJECT_DIR}/_workshop/screenshots/v22"
MISSES_FILE="${PROJECT_DIR}/.claude/team/v22-screenshot-misses.md"
BUNDLE_ID="com.mmf.bsu.HappySpeech"

# Missed routes: <route> <theme>
MISSED=(
  "specialistLogin light"
  "studentsList light"
  "guidedTour light"
  "grammarGame light"
  "siblingMultiplayerLobby light"
  "authVerifyEmail dark"
  "splash dark"
  "specialistHome dark"
  "onboarding10 dark"
  "butterflyCatch dark"
  "soundAndFace dark"
  "rewardAlbum dark"
  "rewardCollection dark"
  "grammarGame dark"
)

REMAINING=""
RETRY_OK=0
RETRY_TOTAL=0

for entry in "${MISSED[@]}"; do
  route="${entry% *}"
  theme="${entry#* }"
  RETRY_TOTAL=$((RETRY_TOTAL+1))
  OUT="${SHOT_DIR}/${route}_${theme}.png"

  xcrun simctl ui booted appearance "$theme" >/dev/null 2>&1
  xcrun simctl terminate booted "$BUNDLE_ID" >/dev/null 2>&1 || true
  sleep 1

  # Retry up to 3 times.
  SUCCESS=0
  for attempt in 1 2 3; do
    if xcrun simctl launch booted "$BUNDLE_ID" -HSStartRoute "$route" >/dev/null 2>&1; then
      sleep 3
      if xcrun simctl io booted screenshot "$OUT" >/dev/null 2>&1; then
        SUCCESS=1
        break
      fi
    fi
    sleep 1
    xcrun simctl terminate booted "$BUNDLE_ID" >/dev/null 2>&1 || true
    sleep 1
  done

  if [ "$SUCCESS" = "1" ]; then
    RETRY_OK=$((RETRY_OK+1))
    echo "RETRY OK: ${route}_${theme}"
  else
    REMAINING+="- ${route} (${theme}): still failing after 3 retries\n"
    echo "RETRY FAIL: ${route}_${theme}"
  fi
done

xcrun simctl terminate booted "$BUNDLE_ID" >/dev/null 2>&1 || true

echo ""
echo "Retry recovered: ${RETRY_OK}/${RETRY_TOTAL}"
echo "Total PNG on disk: $(ls "${SHOT_DIR}"/*.png 2>/dev/null | wc -l)"

# Update misses file with what's still failing.
if [ -n "$REMAINING" ]; then
  {
    echo "# v22 Block 0.2 — Screenshot Misses (after retry)"
    echo ""
    echo "Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "Original misses: 14"
    echo "Recovered on retry: $RETRY_OK"
    echo "Still failing: $((RETRY_TOTAL - RETRY_OK))"
    echo ""
    echo "## Still failing"
    echo ""
    printf '%b' "$REMAINING"
  } > "$MISSES_FILE"
else
  {
    echo "# v22 Block 0.2 — Screenshot Misses (after retry)"
    echo ""
    echo "Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "All 14 original misses recovered on retry."
  } > "$MISSES_FILE"
fi
