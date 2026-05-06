# Performance Audit — Block L v15

**Дата:** 2026-05-07
**Устройство:** iPhone SE 3rd generation (симулятор)
**Конфигурация:** Debug (Release build подтверждён — BUILD SUCCEEDED)

## L.4 Performance Targets vs Reality

### Startup Time

**Target:** <2s на SE 3
**Measured:** Не замерено инструментально (Instruments не запускался в рамках Block L).
**Оценочно:** AppContainer.preview() инициализируется за ~130ms в unit-тестах.
**Статус:** ADR — требует замера на реальном устройстве или через os_signpost в Release build.

### PronunciationScorer

**Target:** <100ms (Conv1D + MFCC)
**Measured:** Core ML inference на симуляторе не репрезентативен.
**Статус:** Requires device testing. В Block D v13 добавлен signpost `🎤 PronunciationScorer`.

### WhisperKit ASR

**Target:** <500ms (tiny model)
**Measured:** WhisperKit не инициализируется на симуляторе (device-only).
**Статус:** Deferred до реального устройства. ADR-V15-PERF-001.

### Memory Cold Start

**Target:** <200MB
**Measured:** Через unit test allocation: AppContainer.preview() ~45MB в тест-процессе.
  Полный production app с Firebase + Realm + WhisperKit оценочно: 120-180MB.
**Статус:** В пределах target, но требует profiling на device.

### AR FPS

**Target:** ≥30fps
**Measured:** ARKit не поддерживается на симуляторе. Fallback 2D-маскот отображается.
**Статус:** Deferred. AR FPS можно мерить только на device с Face Tracking.

## Выводы

Все performance targets требуют проверки на физическом устройстве.
На симуляторе доступны только:
- Compile-time checks (BUILD SUCCEEDED)
- Unit test execution time (~27ms на suite)
- Memory allocation в тест-контексте (~45MB AppContainer.preview)

## ADR

**ADR-V15-PERF-001:** Performance audit Block L выполнен на симуляторе.
Все 5 метрик (startup, scorer, whisper, memory, AR) требуют физического устройства
для репрезентативного замера. Рекомендуется запуск Instruments Time Profiler на
iPhone SE (3rd gen) с Release конфигурацией до TestFlight submission.

**Workaround:** os_signpost markers добавлены в Block D/K для ключевых путей:
- `🎤 PronunciationScorer.predict`
- `🎯 AdaptivePlanner.buildDailyRoute`
- `🔊 WhisperKitWrapper.transcribe`

## Build Check

**Release build:** BUILD SUCCEEDED (iPhone SE 3 симулятор)
**Debug build:** BUILD SUCCEEDED
**Russian-only:** 0 EN strings в Localizable.xcstrings ✓
