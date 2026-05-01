# Performance Audit v13 Final

**Date**: 2026-05-01
**Plan**: v13 Iteration 6 Block P
**Agent**: ios-debugger
**Scope**: Bundle stats, ML inference (симулятор), startup time, memory baseline, LOC

---

## Build Stats

| Метрика | Значение |
|---|---|
| App bundle (Debug, iphonesimulator) | 1.1 GB |
| Binary (HappySpeech исполняемый) | 171.1 MB (179,430,464 bytes) |
| Resources в источниках | 851 MB |
| Swift файлов | 597 |
| Строк кода (total LOC) | ~118.8 K |

### Ресурсы (источник, до сборки)

| Категория | Размер | Файлов |
|---|---|---|
| ARAssets (USDZ) | 231 MB | 20 USDZ |
| Audio/Content | 100 MB | 6,509 файлов |
| Audio/Lyalya | 39 MB | — |
| Audio/Ambient | 1.2 MB | — |
| Audio/UI | 1.1 MB | — |
| Assets.xcassets | 62 MB | 102 imageset |
| Videos | 65 MB | 90 .mp4 |
| Models | 351 MB | 9 .mlpackage |
| Animations | 324 KB | — |
| Haptics | 60 KB | — |

### ML модели

| Модель | Размер | Назначение |
|---|---|---|
| Wav2Vec2RuChild.mlpackage | **302 MB** | ASR (русский, детский) |
| RussianPhonemeClassifier.mlpackage | 1.4 MB | 49 IPA фонем, BiLSTM CNN |
| SileroVAD.mlpackage | 80 KB | Voice Activity Detection |
| PronunciationScorer_whistling.mlpackage | 108 KB | Свистящие (С, З, Ц) |
| PronunciationScorer_hissing.mlpackage | 108 KB | Шипящие (Ш, Ж, Ч, Щ) |
| PronunciationScorer_sonants.mlpackage | 108 KB | Соноры (Р, Рь, Л, Ль) |
| PronunciationScorer_velar.mlpackage | 108 KB | Заднеязычные (К, Г, Х) |
| SoundClassifier.mlpackage | 136 KB | Классификация звуков |
| TonguePostureClassifier.mlpackage | 20 KB | AR поза языка |

### App Bundle — крупнейшие файлы (DerivedData)

| Файл | Размер | Статус |
|---|---|---|
| Wav2Vec2RuChild.mlmodelc/weights/weight.bin | 302 MB | КРИТИЧНО — bundled 302 MB модель |
| HappySpeech (бинарник) | 171 MB | Приемлемо для Debug |
| **voice_clone_reference.wav** | **47 MB** | КРИТИЧНО — debug WAV в production bundle |
| kitchen_pancakes.usdz | 30 MB | Высокий |
| Assets.car | 37 MB | Норма |
| animal_hummingbird.usdz | 20 MB | — |
| animal_seahorse.usdz | 19 MB | — |
| animal_chameleon.usdz | 15 MB | — |

---

## ML Inference

> **Ограничение**: iOS Simulator не имеет доступа к Neural Engine (ANE).
> Все замеры — CPU-only. Репрезентативные данные только на реальном устройстве.

| Компонент | Target (iPhone 17 Pro) | Симулятор (CPU) | Реальное устройство |
|---|---|---|---|
| Real MFCC (vDSP 1 сек) | < 10 ms | ~15–40 ms (est.) | ~5–10 ms (est.) |
| PronunciationScorer CoreML | < 100 ms | NOT_MEASURABLE (mlpackage не в test bundle) | ~20–80 ms (est.) |
| RussianPhonemeClassifier | < 50 ms | NOT_MEASURABLE (mlpackage не в test bundle) | ~15–40 ms (est.) |
| WhisperKit warm | < 500 ms | NOT_MEASURABLE (без ANE, модель не bundled) | 150–400 ms (ожидаемо) |
| Wav2Vec2RuChild (302 MB) | < 500 ms | NOT_MEASURABLE (302 MB, без ANE) | 200–450 ms (ожидаемо) |

### Почему NOT_MEASURABLE

- **PronunciationScorer / RussianPhonemeClassifier**: mlpackage не скопированы в HappySpeechTests target → Bundle.main в тестах ≠ app bundle. Для замера нужно добавить mlpackage в Build Phases → Copy Bundle Resources тестового target.
- **WhisperKit / Wav2Vec2**: Neural Engine недоступен на iOS Simulator. CPU-inference нерепрезентативен для production использования.

### Performance тесты (существующие + новые)

| Файл | Тестов | Статус |
|---|---|---|
| Performance/MFCCPerformanceTests.swift | 6 | Существующий (v7) |
| Performance/ColdStartSignpostTests.swift | 3 | Существующий |
| **Performance/MLPerformanceTests.swift** | **8** | **Новый (v13 Block P)** |

MLPerformanceTests.swift покрывает:
- `testRealMFCCExtractor1SecPerformance` — XCTest measure() для RealMFCCExtractor
- `testRealMFCCOutputCoefficientsCount` — форма тензора [39 коэффициентов × nFrames]
- `testRussianPhonemeClassifierPerformance` — XCTest measure() (skip если mlpackage не в bundle)
- `testPronunciationScorerCoreMLPerformance` — direct CoreML inference (skip если mlpackage не в bundle)
- `testWav2Vec2InferenceNotMeasurableOnSimulator` — XCTSkip с документацией
- `testWhisperKitWarmInferenceNotMeasurableOnSimulator` — XCTSkip с документацией

---

## Startup Time

> **Метод**: `xcrun simctl launch` (измеряет время до возврата команды).
> Не эквивалентен Time to First Meaningful Paint. Для точного TTFMP нужен os_signpost + Instruments.

| Устройство | Тип запуска | Время |
|---|---|---|
| iPhone 17 Pro (симулятор) | Cold (1-й запуск) | ~1.4 сек |
| iPhone 17 Pro (симулятор) | Warm (после terminate) | ~0.6–0.9 сек |
| iPhone SE 3 (реальное) | Cold | NOT_MEASURED (нет физ. устройства) |
| iPhone 17 Pro (реальное) | Cold | NOT_MEASURED (нет физ. устройства) |

**Target**: iPhone 17 Pro < 1.5 сек, iPhone SE 3 < 2.5 сек.

**Вывод по симулятору**: 1.4 сек на симуляторе = граничное значение для 1.5 сек target.
На реальном устройстве будет быстрее (SSD vs Xcode DerivedData NFS, ANE инициализация).
Главный риск — загрузка 302 MB Wav2Vec2 весов при первом inference.

---

## Memory

> **Ограничение**: `xcrun simctl spawn ps` не возвращает данные для запущенных приложений
> в текущей конфигурации симулятора. Нужен Xcode Memory Report или Instruments.

| Состояние | Target | Фактически |
|---|---|---|
| Cold start | < 200 MB | NOT_MEASURED |
| Lesson session (без AR) | < 300 MB | NOT_MEASURED |
| AR активна | < 400 MB | NOT_MEASURED (ARKit требует реальное устройство) |

**Метод для замера**: Xcode → Debug Navigator → Memory gauge, или `xcrun instruments -t "Allocations"`.

---

## Issues Found

### КРИТИЧЕСКИЕ (блокируют App Store)

1. **`voice_clone_reference.wav` (47 MB) в production bundle**
   - Путь: `HappySpeech/Resources/Models/voice_clone_reference.wav`
   - В app bundle как активный ресурс — 47 MB WAV файл
   - Это debug/development артефакт для клонирования голоса (TTS)
   - **Действие**: Удалить из Resources, переместить в `_workshop/` или убрать из Copy Bundle Resources
   - **Экономия**: -47 MB из app size

2. **Wav2Vec2RuChild.mlpackage (302 MB) bundled**
   - App Store limit для cellular download: 200 MB (iOS 13+) или 50 MB (старше)
   - 302 MB модель делает app не downloadable по cellular без Apple exemption
   - **Действие**: On-demand resource (ODR) через NSBundleResourceRequest, или lazy download при первом использовании
   - **Экономия**: -302 MB из initial download

### ВЫСОКИЕ (влияют на UX)

3. **9,005 audio файлов в bundle (141 MB total)**
   - 6,509 файлов в Audio/Content — весь контент загружен при установке
   - **Действие**: Разбить на On-demand Resources по sound groups (свистящие/шипящие/соноры/заднеязычные)
   - **Экономия**: -80–100 MB из initial bundle

4. **USDZ файлы суммарно 231 MB (20 файлов)**
   - `kitchen_pancakes.usdz` (30 MB), `animal_hummingbird.usdz` (20 MB), `animal_seahorse.usdz` (19 MB)
   - Слишком много для bundled — нужна приоритизация
   - **Действие**: 3–5 starter USDZ bundled, остальные через ODR или CloudKit Assets

5. **Binary 171 MB (Debug build)**
   - Debug build с debug symbols — нормально для разработки
   - Release build ожидаемо ~40–70 MB после bitcode/symbol stripping
   - **Действие**: Проверить Release build size перед App Store submission

### СРЕДНИЕ (оптимизация)

6. **mlpackage не в HappySpeechTests target**
   - PronunciationScorer и RussianPhonemeClassifier недоступны для unit-тестирования inference
   - **Действие**: Добавить малые mlpackage (<200 KB) в Copy Bundle Resources тестового target

7. **Startup time на симуляторе ~1.4 сек**
   - Граничное значение для target 1.5 сек
   - Нужен os_signpost профилинг для поиска bottleneck при cold start
   - **Действие**: Instruments → Time Profiler на реальном iPhone 17 Pro

---

## Рекомендация

**Needs fixes** — перед App Store submission обязательно:

1. Удалить `voice_clone_reference.wav` из bundle (-47 MB)
2. Перевести `Wav2Vec2RuChild.mlpackage` на On-Demand Resources (-302 MB)
3. Перевести Audio/Content на ODR (-80+ MB)
4. Проверить Release build size (target: <100 MB для initial download)

Для диплома (внутренняя демонстрация без App Store) текущее состояние приемлемо.
Функциональность и архитектура не затронуты — это исключительно bundle size проблемы.

---

## Ограничения аудита (Scope Notes)

- **Instruments**: недоступен через MCP/bash — требует interactive Xcode session
- **AR fps**: не измеримо на симуляторе (нет TrueDepth камеры)
- **Battery drain**: не измеримо без реального устройства и Instruments Energy profiler
- **Memory**: xcrun simctl spawn ps не возвращает данные для запущенных apps
- **WhisperKit / Wav2Vec2 inference**: NOT_MEASURABLE без ANE и physical device
- **Startup time**: измерен через simctl launch command, не через os_signpost TTFMP

Полный profiling (Instruments, Energy, Memory Graph) требует Xcode GUI на реальном устройстве.
