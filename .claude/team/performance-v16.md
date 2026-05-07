# Performance Audit v16

**Дата:** 2026-05-07
**Устройство:** iPhone SE (3rd generation) — симулятор

---

## Startup

| Метрика | Измерено | Target | Статус |
|---|---|---|---|
| App launch command time | 249 ms | — | — |
| Full render (Permissions screen) | ~3 sec | <2 sec | PARTIAL |

**Методология:** `xcrun simctl launch` от команды до первого кадра. Реальное время "до интерактивного UI" включает инициализацию Firebase, Realm, WhisperKit (lazy), AppContainer — примерно 2–4 секунды на симуляторе.

**Примечание:** Симулятор запускает на процессоре Mac (x86_64/ARM). На реальном iPhone SE 3 (A15 Bionic) старт будет быстрее. Точное измерение требует MetricKit / XCTest measure на реальном устройстве.

---

## Build

```
** TEST BUILD SUCCEEDED **
Scheme: HappySpeech
Destination: iPhone SE (3rd generation) simulator
Configuration: Debug
```

### SPM resolve time
- Зависимостей: 42 SPM-пакета
- Resolve: cached (повторный запуск)

---

## Memory

**Метод:** `xcrun simctl spawn` + pid-наблюдение. Симулятор не даёт точных RSS.

- Холодный старт: ~150–180 MB (оценка по симулятору)
- После Onboarding screen: ~160–200 MB (Realm + Firebase auth initialized)
- AR-режим: не тестировался на симуляторе (требует реальное устройство)

**Target:** <200 MB cold start — ожидаемо в норме.

---

## AR Performance

- AR-FPS: **не измеряется на симуляторе** (ARKit → real device only)
- ARSnapshotTests: 5 тестов корректно падают с "ARKit not supported on simulator"
- На реальном устройстве с A15: ожидается 30–60 fps (LipSync: 30 fps target)

---

## Bundle Size

- Debug build: не анализировался (большой из-за dSYM)
- Target production: ~1.5 GB (включая ML models, видео-ассеты, аудио)
- Core ML модели: SileroVAD + Wav2Vec2RuChild + SoundClassifier + TonguePostureClassifier

---

## Потенциальные проблемы производительности

1. **AppCoordinator.swift** — 40.87% coverage, сложный (438 lines) — может быть bottleneck при старте
2. **ChildHomeViewListComponents.swift** — 9.16% coverage, большой (1179 lines) — риск heavy init
3. **ARZoneViewCards.swift** — 0% coverage, 640 lines — не тестировался

---

## Рекомендации

1. Добавить `XCTest.measure { }` тест для startup time (XCTestCase + MetricKit)
2. Instrument с Time Profiler на реальном устройстве после UI freeze
3. Проверить lazy loading WhisperKit — должен загружаться только при первом использовании ASR
4. Проверить Realm migration на первом запуске — потенциально долго при large schema changes
