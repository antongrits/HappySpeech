#!/usr/bin/env bash
# Plan v23 Block 1.3 — Pre-grant iOS Simulator permissions для AllScreensTourUITests.
#
# Решение Issue #1: mic permission alert оверлеит ~56 P0 screens. Pre-grant
# выполняется снаружи теста (Foundation.Process недоступен в iOS test runner),
# чтобы system alert не появлялся вообще. Interruption monitor в captureScreen
# остаётся как defense-in-depth.
#
# Usage:
#   ./scripts/grant_uitest_permissions.sh                 # booted simulator
#   ./scripts/grant_uitest_permissions.sh <device-udid>   # конкретный UDID
#
# Затем:
#   xcodebuild test -project HappySpeech.xcodeproj \
#     -scheme HappySpeech \
#     -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
#     -only-testing:HappySpeechUITests/AllScreensTourUITests/test_route_lessonBingo

set -uo pipefail

BUNDLE_ID="com.mmf.bsu.HappySpeech"
DEVICE="${1:-booted}"
SERVICES=(
    microphone
    camera
    notifications
    location-always
    location
)

echo "[grant_uitest_permissions] Target device: ${DEVICE}"
echo "[grant_uitest_permissions] Bundle ID:     ${BUNDLE_ID}"
echo ""

# Если device != booted и симулятор ещё не запущен — поднимаем его.
if [[ "${DEVICE}" != "booted" ]]; then
    xcrun simctl boot "${DEVICE}" 2>/dev/null || true
fi

FAILED=0
for service in "${SERVICES[@]}"; do
    if xcrun simctl privacy "${DEVICE}" grant "${service}" "${BUNDLE_ID}" 2>&1; then
        echo "  [OK]   ${service}"
    else
        echo "  [SKIP] ${service} (возможно не поддерживается в текущей версии Xcode)"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
if [[ ${FAILED} -eq 0 ]]; then
    echo "[grant_uitest_permissions] Все permissions выданы — можно запускать UI tour."
    exit 0
else
    echo "[grant_uitest_permissions] ${FAILED} services пропущено. Interruption monitor в captureScreen покроет недостающее."
    exit 0
fi
