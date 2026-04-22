# HappySpeech Master Plan
## Version 2.0 — 2026-04-22
### На основе v1.0 + 13 новых требований пользователя
### Разделы 1–18 — из v1.0 (обновлены статусы). Разделы 19–28 — новые.

---

## 1. Product Vision and Scope

### What HappySpeech IS

HappySpeech — **offline-first, Russian-language iOS speech therapy support platform** для детей 5–8 лет.

- Детский контур (kid): геймификация, маскот «Ляля», адаптивный дневной маршрут
- Родительский контур (parent): прогресс, аналитика без жаргона, домашние задания
- Специалистский контур (specialist): ручной скоринг, waveform/spectrogram, PDF/CSV экспорт
- Скрытый адаптивный планировщик (AdaptivePlannerService) на базе LLM + fallback-правил
- On-device AI: GigaAM ASR, Silero VAD, PronunciationScorer, LLMDecisionService (HF Hub)
- AR-артикуляция (ARKit Face Tracking)
- Visual-acoustic biofeedback (waveform + mel-spectrogram)
- 16 шаблонов игр, ≥6 000 контент-единиц
- Демо-режим с анимированным обучением

### Honest Product Boundaries

| Граница | Причина |
|---|---|
| Нет медицинской диагностики | Только педагогическая поддержка |
| Нет клинической гарантии | Не может обещать исправление в заданный срок |
| Нет полного tongue-tracking внутри рта | ARKit только external blendshapes |
| Не замена живого логопеда | Рекомендует очный визит при тяжёлых нарушениях |
| Нет сторонних трекеров и аналитики SDK | Kids Category compliance |
| Нет рекламы и внешних in-app покупок | Kids Category compliance |
| Нет открытых внешних ссылок без parental gate | Kids Category compliance |
| Нет real-time server-side речевого скоринга | Весь ML — on-device |
| Нет chat-интерфейса для LLM | Только структурированные JSON-решения |

### Target Audience

- **Первичная:** Дети 5–8 лет (детский контур)
- **Вторичная:** Родители (координатор домашней практики)
- **Третичная:** Логопеды/специалисты (инструмент наблюдения и аннотации)

---

## 2. Семь Фаз Работы (обновлено: было 5, стало 7)

### Phase 0 — Research & Spec Finalization (Week 1) — DONE

**Статус:** Завершена. Все артефакты созданы.

**Выполнено:**
- `master-plan.md` v1.0 — утверждён
- `screen-map.md` — 65 экранов
- `backlog.md` — 83 задачи, 13 спринтов
- `architecture.md`, `api-contracts.md`, `ml-models.md`, `decisions.md`
- 231 Swift-файл (DesignSystem полностью, 17 Features-директорий, Services, Core, Data)

---

### Phase 1 — Foundation (Weeks 2–3) — DONE (Sprint 1+2)

**Статус:** Завершена.

**Выполнено:**
- `HappySpeechApp.swift` — @main, ThemeManager, Realm bootstrap
- `AppCoordinator.swift`, `AppContainer.swift` (DI)
- DesignSystem: ColorTokens, TypographyTokens, SpacingTokens, MotionTokens, ShadowTokens, ThemeEnvironment
- 13 компонентов: HSButton, HSCard, HSMascotView, HSAudioWaveform, HSSticker, HSBadge, HSProgressBar, HSProgressRing, HSSoundChip, HSRewardBurst, HSOfflineBanner, HSErrorStateView, HSEmptyStateView, HSLoadingView
- Services: AudioService, LiveServices, MockServices, AnalyticsService, SyncService, NetworkMonitor, ContentEngine

---

### Phase 2 — MVP (Weeks 4–6) — В процессе (Sprint 3–5)

**Цель:** Ребёнок завершает реальную сессию. Родитель видит результаты.

**Deliverables:**
- Auth flow (Firebase Auth + Sign in with Apple)
- Onboarding (5 экранов)
- ChildHome с маскотом + DailyMissionCard
- LessonPlayer: 3 шаблона (listen-and-choose, repeat-after-model, sorting)
- ASRService (WhisperKit, русская модель)
- AdaptivePlannerService skeleton
- ParentHome (базовый)
- Rewards: счётчик звёзд + 3 набора стикеров
- ContentEngine seed-пак для звука С (этапы 0–3)

---

### Phase 3 — Content Scale (Weeks 7–9) — Sprint 6–9

**Цель:** Все 16 шаблонов. Все 4 группы звуков. Полный родительский дашборд. Специалист.

*Без изменений по сравнению с v1.0 — см. исходный план.*

---

### Phase 4 — AR + ML + LLM-Core (Weeks 10–11) — Sprint 10–11

**Цель:** AR-игры, PronunciationScorer, LLMDecisionService — центральный мозг приложения.

**Обновлено vs v1.0:** LLM теперь не просто parent_summary — это LLMDecisionService, интегрированный в 12+ точек приложения (см. Раздел 19). Модель выбирается из HF Hub, не только Qwen через MLC.

---

### Phase 5 — Polish + QA (Weeks 12–13) — Sprint 12–13

**Цель:** Итеративное screenshot-тестирование. Визуальный контент. Переключение темы.

**Обновлено vs v1.0:** + итеративный цикл qa-simulator (скриншот → анализ → фикс → повтор), + кастомные иконки, + полный визуальный контент.

---

### Phase 6 — Demo & Network Layer (Week 14) — Sprint 14 — НОВАЯ

**Цель:** Демо-режим с 3D/2D анимациями, полноценный NetworkClient, ClaudeAPIClient.

**Deliverables:**
- DemoTour с Lottie-анимациями + SceneKit-сценами
- NetworkClient (URLSession, retry, request signing, error mapping)
- ClaudeAPIClient (опциональная интеграция с Claude API для онлайн-рекомендаций)
- HFInferenceClient (Hugging Face Inference API fallback для LLM)
- OfflineState фича: усиленная — queue синхронизации, статус сети, retry UI

---

### Phase 7 — Screenshot Iteration + App Store (Week 15) — Sprint 15 — НОВАЯ

**Цель:** Автоматическая итеративная валидация всех экранов. App Store готовность. Диплом.

**Deliverables:**
- Итерационный скрипт: xcodebuild → screenshot → анализ через MCP → фикс → повтор
- Полная локализация (ru + en), ревью носителем
- Snapshot-тесты всех 65+ экранов (light + dark)
- TestFlight build
- Диплом: архитектурная диаграмма, demo-video, ML pipeline

---

## 3. Sprint Plan (15 Спринтов)

| Sprint | Week | Goal | Key Tasks | Статус |
|--------|------|------|-----------|--------|
| S0 | 1 | Planning complete | master-plan, screen-map, backlog, architecture, api-contracts, ml-models | Done |
| S1 | 2 | Xcode project boots | project.yml, Core layer, Logger, AppError, SPM deps | Done |
| S2 | 3 | DesignSystem + DI | ColorTokens, 13 компонентов, ThemeEnvironment, AppContainer | Done |
| S3 | 4 | Auth + Onboarding | Firebase Auth, Sign in with Apple, 5 onboarding screens | In Progress |
| S4 | 5 | Child home + 1st template | ChildHomeView, MascotView, DailyMissionCard, listen-and-choose | Planned |
| S5 | 6 | Core ASR + 2 templates | WhisperKit, repeat-after-model, sorting, ContentEngine seed С | Planned |
| S6 | 7 | AdaptivePlanner + Rewards | AdaptivePlannerService, RewardsView, StickerCollection | Planned |
| S7 | 8 | Templates 4–10 | drag-and-match, story-completion, puzzle-reveal, memory, bingo, sound-hunter, breathing | Planned |
| S8 | 9 | Templates 11–16 + звуки | articulation-imitation, visual-acoustic, rhythm, narrative-quest, minimal-pairs, ar-activity skeleton | Planned |
| S9 | 10 | Parent dashboard + Sync | ParentHomeView, heatmap, AudioRecordingPlayer, SyncService, Firestore | Planned |
| S10 | 11 | AR + ML + LLMDecisionService | ARService, PronunciationScorer, LLMDecisionService (12 точек интеграции) | Planned |
| S11 | 12 | Specialist + NetworkClient | SpecialistView, waveform, PDF export, NetworkClient, ClaudeAPIClient, HFInferenceClient | Planned |
| S12 | 13 | Demo Tour + Theme Switch | DemoTour (Lottie/SceneKit), Settings theme switch, кастомные иконки | Planned |
| S13 | 14 | Visual Content + Datasets | Иллюстрации Canva/HF-Space, word-cards image dataset, CreateML pipeline, валидационный скрипт | Planned |
| S14 | 15 | Screenshot Iteration + App Store | итеративный qa-simulator цикл, локализация, snapshot coverage ≥85%, TestFlight | Planned |

**Milestones (обновлены):**
- **M1 (S5 end):** MVP — ребёнок завершает реальную 3-шаблонную сессию
- **M2 (S8 end):** Content Scale — 16 шаблонов + 4 группы звуков
- **M3 (S9 end):** Parent circuit complete
- **M4 (S10 end):** AR + ML + LLMDecisionService on-device
- **M5 (S11 end):** Specialist + Network Layer complete
- **M6 (S12 end):** Demo Tour + Theme Switch + кастомные иконки
- **M7 (S14 end):** App Store submission + диплом готов

---

## 4. Modular Architecture

*Без изменений vs v1.0. Добавлены новые сервисы в Services Layer:*

```
Services/ (добавлены в v2.0):
├── LLMDecisionService.swift     — центральный мозг: 12 точек интеграции
├── NetworkClient.swift          — URLSession wrapper: retry, signing, error mapping
├── ClaudeAPIClient.swift        — опциональная интеграция с Anthropic Claude API
├── HFInferenceClient.swift      — Hugging Face Inference API fallback
├── DemoTourService.swift        — состояние и логика demo-тура

Слой ML/ (добавлен):
├── LLMDecisionService.swift     — HF/MLC inference wrapper с JSON-парсером
```

**FORBIDDEN по-прежнему:**
- Features → Data (direct)
- Features → ML (direct)
- Features → Sync (direct)

---

## 5. Screen Map (обновлено: 65 + 4 новых = 69 экранов)

*Все 65 оригинальных экранов сохранены. Добавлены:*

| # | Screen | File | Status |
|---|---|---|---|
| 66 | DemoTour (anимированный обучающий тур) | DemoTourView | [N] |
| 67 | NetworkStatus (детальный offline-статус, retry) | NetworkStatusView | [N] |
| 68 | ThemeSettings (Light/Dark/System переключатель) | ThemeSettingsView | [N] — уже в Settings |
| 69 | LLMDownloadProgress (прогресс загрузки HF модели) | LLMDownloadView | [N] |

**Total v2.0: 69 экранов**

---

## 6. Content Engine

*Без изменений vs v1.0. Добавлено в v2.0:*

### Image Dataset (новое)

Для word-cards каждого контент-элемента нужно изображение:
- Источники: public domain (Wikimedia Commons, OpenClipArt), Canva MCP, HF Space image generation
- Формат: WebP 512×512, < 30 KB
- Хранение: `HappySpeech/Content/Seed/images/` (bundled), Firebase Storage (downloadable packs)
- Куратор: `image-dataset-curator` агент (новая роль)
- Автоматизация: `_workshop/scripts/16_fetch_images.py` — пакетный fetch из public domain API + генерация через FLUX/SDXL на HF Space

### Custom Icon Library (новое)

- Путь: `HappySpeech/Resources/Icons/Custom/`
- Форматы: `.svg` (vector) или `.pdf` для Asset Catalog
- Стиль: мягкий, скругленный, kiddo-дружественный, соответствует ColorTokens.Brand
- Источники: SVGRepo (license-free), Flaticon (free tier), designer-visual сам рисует простые через CoreGraphics описание
- Категории:
  - Navigation (tab bar: home, world, rewards, parent, settings)
  - Game types (16 иконок шаблонов)
  - Sounds (22 иконки звуков)
  - AR (5 иконок сценариев)
  - Status (offline, sync, loading, error)

---

## 7. Data Architecture

*Без изменений vs v1.0. Добавлена Realm-модель для LLM-решений:*

```swift
// LLMDecisionLog — хранит историю LLM-решений для debugging + analytics
LLMDecisionLog
├── id: String
├── childId: String
├── decisionType: String      // "routePlanner", "parentSummary", "microStory", etc.
├── inputHash: String         // hash входных данных
├── output: String            // JSON-вывод LLM
├── modelId: String           // какая модель использовалась
├── usedFallback: Bool        // true если LLM недоступна
├── latencyMs: Int
└── createdAt: Date
```

---

## 8. ML Layer

*Обновлена секция LLM (расширена для HF Hub + MLC дуального пути)*

### Model Registry v2.0

| Model | Task | License | Size | Fallback |
|---|---|---|---|---|
| GigaAM-v3 ONNX (sherpa-onnx) | Russian ASR primary | Apache 2.0 | ~300 MB | WhisperKit |
| WhisperKit (whisper-tiny) | Russian ASR fallback | MIT | ~150 MB | AVSpeechRecognizer |
| Silero VAD | VAD | MIT | ~2 MB | amplitude threshold |
| PronunciationScorer (custom CNN) | Binary scoring | Proprietary | ~5 MB | ASR confidence |
| **LLMDecisionService primary** | Structured decisions | Apache 2.0 | **see Section 19** | Rule-based |
| CreateML Classifier (new) | Word-image classification, content tagging | Proprietary | ~2 MB | Rule-based |

### CreateML Pipeline (новое, дополнение к PyTorch path)

Параллельный путь для простых классификаторов без GPU:
- `CreateML.MLSoundClassifier` — классификатор для простых фонемных категорий (< 1 h обучение)
- `CreateML.MLImageClassifier` — классификатор word-cards изображений
- Интеграция через Create ML app (GUI) + Python `coremltools` CLI
- Скрипт: `_workshop/scripts/17_train_createml_classifier.py`

---

## 9. LLM Integration (v1.0 базовая версия)

*Раздел 9 сохранён из v1.0 как baseline. Полная расширенная архитектура LLM — в Разделе 19.*

Базовые 4 решения (parent summary, route planner, micro-story, logopedist recommendation) из v1.0 сохраняются. Раздел 19 добавляет ещё 8+ точек интеграции.

---

## 10. Python Tooling (_workshop/scripts/)

*v1.0 скрипты 01–15 сохранены. Добавлены:*

| Скрипт | Назначение | Input | Output |
|---|---|---|---|
| `16_fetch_images.py` | Batch-скачивание CC0 изображений для word-cards | word_lists/*.csv | _workshop/images/raw/ |
| `17_train_createml_classifier.py` | Обучение CreateML классификатора | _workshop/datasets/ | models/createml/*.mlpackage |
| `18_validate_datasets_iterative.py` | Итеративная валидация датасетов: запуск → найти ошибки → исправить | любой датасет | logs/validation_{timestamp}.json |
| `19_generate_word_images_hfspace.py` | Генерация недостающих изображений через HF Space (FLUX/SDXL) | word_list без картинки | _workshop/images/generated/ |
| `20_screenshot_analysis.py` | Анализ скриншотов: overflow, clip, темная тема через PIL | _workshop/screenshots/ | logs/screenshot_issues.json |
| `21_hf_model_benchmark.py` | Бенчмарк HF Hub моделей на русских тестах | model_ids list | logs/hf_benchmark.csv |

### Правило итеративной валидации (новое)

```
ИТЕРАЦИОННЫЙ ЦИКЛ (скрипт 18):
1. Запуск: python3 _workshop/scripts/18_validate_datasets_iterative.py
2. Анализ errors в logs/validation_*.json
3. Исправление: нормализация, удаление дублей, добавление меток
4. Повтор до validation_score > 0.95
5. Только после этого — передача в ml-trainer
```

---

## 11. Design System

*Полностью реализован в коде. Из v1.0 сохранены токены и компоненты.*

### v2.0 Обновления

**Новые компоненты (добавить):**
- `HSDemoTourOverlay` — overlay для demo tour с highlight-рамкой и tooltip
- `HSThemeToggle` — 3-state toggle (Light/Dark/System) для Settings
- `HSNetworkStatusBar` — нижний бар со статусом сети и pending sync count
- `HSLLMThinkingIndicator` — анимация "LLM думает" (3 точки, kid-safe)
- `HSCustomIcon` — враппер для кастомных SVG/PDF иконок из Asset Catalog

**Кастомные иконки vs SF Symbols:**
- SF Symbols разрешены только для системных действий (share, chevron, xmark)
- Все предметные иконки (звуки, игры, AR-сценарии) — кастомные
- Путь: `Resources/Icons/Custom/{category}/{name}.imageset`

---

## 12. AR Subsystem

*Без изменений vs v1.0.*

---

## 13. Test Strategy

*v1.0 базовая стратегия сохранена. Добавлены в v2.0:*

### Snapshot Tests v2.0

- Все **69 экранов** тестируются в 5 конфигурациях (SE/Pro × light/dark + AccessibilityLarge)
- Итого целевых снимков: **69 × 5 = 345 snapshots**
- Обязательна проверка темы через `HSThemeToggle` в SettingsView

### Итеративное Screenshot-тестирование (новое)

Процесс описан в Разделе 24. Ключевой принцип: qa-simulator НЕ сдаёт задачу пока все проблемы не исправлены.

### Тесты LLMDecisionService (новое)

- `LLMDecisionServiceTests` — 12 тест-кейсов, по одному на каждую decision-точку
- Mock: `MockLLMDecisionService` возвращает детерминированный JSON
- Fallback: тест что при `useFallback = true` возвращается корректный rule-based output

---

## 14. Screenshot Tour Specification

*v1.0 сохранён (40 скриншотов на device). Добавлены:*

| # | Screen | Purpose |
|---|---|---|
| 41 | DemoTour (анимированный) | Демо-режим showcase |
| 42 | LLMDecisionService thinking indicator | AI-фича showcase |
| 43 | NetworkStatus (offline queue) | Offline-first showcase |
| 44 | ThemeSettings (dark mode toggle) | Кастомизация |
| 45 | Custom icons showcase (world map с кастомными иконками) | Визуальный стиль |

**Итого в v2.0: 45 скриншотов на device × 2 = 90 App Store screenshots**

---

## 15. Sprint Plan with Milestones (Detailed)

*Gates обновлены:*

- **Gate 1 (S2):** DesignSystem + все 13 компонентов — PASSED (уже готово)
- **Gate 2 (S5 — M1 MVP):** Ребёнок завершает 3-шаблонную сессию
- **Gate 3 (S8 — M2 Content):** Все 16 шаблонов + smoke test
- **Gate 4 (S9 — M3 Parent):** Parent dashboard + Sync round-trip
- **Gate 5 (S10 — M4 AR+ML):** AR tongue-catch + LLMDecisionService (12 точек)
- **Gate 6 (S11 — M5 Specialist+Network):** PDF export + NetworkClient retry-test
- **Gate 7 (S12 — M6 Demo):** DemoTour анимация + безупречный Theme Switch
- **Gate 8 (S14 — M7 App Store):** TestFlight + 345 snapshot tests green + диплом

---

## 16. Success Metrics and DoD per Phase

*v1.0 DoD сохранён. Добавлены:*

### Phase 6 DoD (Demo & Network)
- [ ] DemoTour показывает ≥5 ключевых фич с анимациями (Lottie или SceneKit)
- [ ] NetworkClient успешно retry при 2 последовательных ошибках сети
- [ ] ClaudeAPIClient возвращает рекомендацию родителю при наличии интернета
- [ ] OfflineState: pending-синхронизация отображается с корректным счётчиком

### Phase 7 DoD (Screenshot Iteration)
- [ ] Все 69 экранов сняты на iPhone SE + iPhone 17 Pro
- [ ] qa-simulator прошёл ≥3 итерации без новых ошибок
- [ ] Нулевые UI-проблемы: нет overflow, нет clip, нет сломанной dark темы
- [ ] Snapshot coverage ≥ 85% (345 из 405 target snapshots)
- [ ] Unit coverage ≥ 70% на Interactors/Presenters
- [ ] Zero lint errors, zero build warnings
- [ ] TestFlight build загружен

---

## 17. Risk Register (обновлён)

*v1.0 риски R1–R10 сохранены. Добавлены:*

| # | Risk | Probability | Impact | Mitigation |
|---|---|---|---|---|
| R11 | HF Hub LLM модель слишком большая для on-device | Medium | High | Начать с SmolLM2-360M (360 MB), Vikhr-Nemo (7B → только HF Inference API). Оценить size/quality trade-off. |
| R12 | Lottie/SceneKit анимации в DemoTour лагают на SE | Medium | Medium | Профилировать на SE 4th gen. Fallback — простые CSS-подобные SwiftUI анимации с ReducedMotion. |
| R13 | Claude API вызовы из приложения — COPPA риск | High | Critical | ClaudeAPIClient доступен ТОЛЬКО из родительского/специалистского контура. Никогда не из детского контура. API key хранить в Keychain. |
| R14 | Canva MCP / HF Space генерация изображений — лицензии | Medium | High | Использовать только явно CC0/public domain. Документировать источник каждого изображения в `sound-assets.md`. |
| R15 | Кастомные иконки не совпадают по стилю с DesignSystem | Low | Medium | designer-visual проверяет каждую иконку против ColorTokens.Brand и RadiusTokens до коммита. |
| R16 | Screenshot итерация > 3 циклов, диплом под угрозой | Medium | High | Начать screenshot-тестирование с S12, не ждать S14. Параллельно с Demo и Theme. |

---

## 18. Build / Test / Screenshot Command Reference

*v1.0 команды сохранены. Добавлены:*

```bash
# Итеративная валидация датасетов
python3 _workshop/scripts/18_validate_datasets_iterative.py

# Бенчмарк HF Hub моделей
python3 _workshop/scripts/21_hf_model_benchmark.py

# Обучение CreateML классификатора
python3 _workshop/scripts/17_train_createml_classifier.py

# Генерация изображений через HF Space
python3 _workshop/scripts/19_generate_word_images_hfspace.py

# Анализ скриншотов
python3 _workshop/scripts/20_screenshot_analysis.py --dir _workshop/screenshots/

# Screenshot тур v2.0 (все 69 экранов)
./scripts/generate_screenshots_v2.sh

# Benchmark LLMDecisionService latency
xcodebuild test -scheme HappySpeech -only-testing:HappySpeechTests/LLMBenchmarkTests
```

---

## 19. LLM как Центральный Мозг (НОВЫЙ)

### 19.1 Исследование HF Hub — Выбор Модели

**Критерии отбора:**
- Русскоязычная поддержка (benchmark на ruwiki / ruBQ / IndicHeadLine)
- iOS/on-device совместимость (размер ≤ 2 GB после квантизации Q4)
- Apache 2.0 / MIT лицензия
- Структурированный JSON output (instruction following)

**Кандидаты (исследовать в порядке приоритета):**

| Модель | HF ID | Размер (Q4) | Русский | iOS-путь | Оценка |
|---|---|---|---|---|---|
| Qwen2.5-1.5B-Instruct | Qwen/Qwen2.5-1.5B-Instruct | ~950 MB | Хорошо | MLC LLM Swift SDK | Рекомендован (ADR-002) |
| SmolLM2-1.7B-Instruct | HuggingFaceTB/SmolLM2-1.7B-Instruct | ~1.1 GB | Средне | MLC или llama.cpp iOS | Резерв |
| Vikhr-Nemo-12B | Vikhrmodels/Vikhr-Nemo-12B-Instruct-R-21-09-24 | ~7 GB | Отлично | Только HF Inference API | Только online |
| Saiga-Llama3.2-3B | IlyaGusev/saiga_llama3_2_3b | ~1.8 GB | Отлично | MLC (требует конвертация) | Перспективно |
| GigaChat-lite (SberDevices) | seara/rubert-tiny-turbo | ~0.1 GB | Хорошо | Core ML | Только классификация |

**ADR-009: LLM Selection v2 (обновлено)**

Решение: **Двойной путь**
1. **On-device:** Qwen2.5-1.5B-Instruct через MLC LLM Swift SDK (основной, если модель загружена)
2. **HF Inference API:** Vikhr-Nemo-12B через `HFInferenceClient` (если online + модель не загружена)
3. **Fallback:** Полностью детерминированные правила (всегда доступны)

Детские решения (child circuit) — **только on-device или fallback**. Никогда не через сетевой API из детского контура (COPPA).

---

### 19.2 LLMDecisionService — Архитектура

```swift
// Services/LLMDecisionService.swift

protocol LLMDecisionServiceProtocol: AnyObject {
    // Все методы — async, возвращают либо LLM-ответ либо rule-based fallback
    func planDailyRoute(context: RoutePlanContext) async throws -> DailyRoute
    func generateParentSummary(session: SessionLog) async throws -> ParentSummary
    func generateMicroStory(context: StoryContext) async throws -> MicroStory
    func generateLogopedistNote(history: [SessionLog]) async throws -> String
    func selectNextExercise(progress: ProgressSnapshot) async throws -> ExerciseSelection
    func generateEncouragement(attempt: AttemptResult) async throws -> String
    func generateRewardMessage(milestone: RewardMilestone) async throws -> String
    func interpretResponse(transcript: String, target: SoundTarget) async throws -> ResponseInterpretation
    func generateParentTip(soundTarget: SoundTarget, stage: CorrectionStage) async throws -> String
    func generateHomeworkTask(weakWords: [String]) async throws -> HomeTask
    func adaptDifficulty(recentAttempts: [AttemptResult]) async throws -> DifficultyAdjustment
    func generateSessionWarmup(childName: String, targetSound: SoundTarget) async throws -> WarmupScript
}

// Внутренняя реализация
final class LiveLLMDecisionService: LLMDecisionServiceProtocol {
    private let mlcEngine: MLCEngine?          // on-device
    private let hfClient: HFInferenceClient?   // online fallback (не для kid circuit)
    private let fallback: RuleBasedDecisionService  // всегда доступен

    // Routing logic:
    private func route(prompt: String, context: DecisionContext) async throws -> String {
        // 1. Если модель загружена + device ≥ iPhone 12 → MLC
        // 2. Если online + context.circuit != .kid → HF Inference API
        // 3. Иначе → fallback
    }
}
```

---

### 19.3 Двенадцать Точек Интеграции LLM в Приложении

| # | Точка | Где | Контур | Fallback |
|---|---|---|---|---|
| 1 | **planDailyRoute** | AdaptivePlannerService → запускает перед сессией | Все | Статическая таблица приоритетов по sound/stage |
| 2 | **generateParentSummary** | SessionCompleteView → после завершения сессии | Parent | Template substitution |
| 3 | **generateMicroStory** | narrative-quest template → нужна история | Kid | Pre-written story pool (20 bundled) |
| 4 | **generateLogopedistNote** | SpecialistView → PDF export | Specialist | Templated paragraph |
| 5 | **selectNextExercise** | LessonPlayer → после каждого упражнения | Kid | Round-robin по difficulty |
| 6 | **generateEncouragement** | LessonPlayer → после attempt | Kid | 50 pre-written phrases (on-device) |
| 7 | **generateRewardMessage** | RewardsView → разблокировка стикера | Kid | 20 pre-written messages |
| 8 | **interpretResponse** | ASRService → уточнение результата ASR | Kid | ASR confidence score |
| 9 | **generateParentTip** | ParentHome → совет дня | Parent | Static tips database (50 tips) |
| 10 | **generateHomeworkTask** | HomeTasksView → слабые слова → задание | Parent | Template homework |
| 11 | **adaptDifficulty** | AdaptivePlannerService → после 3 подряд ошибок | Kid | ±1 difficulty rule |
| 12 | **generateSessionWarmup** | LessonWarmUpView → персональное приветствие | Kid | Static welcome scripts |

---

### 19.4 Prompt Templates

Все промпты — на русском. JSON-only output. Max tokens: 256 (чтобы уложиться в latency budget).

**Пример — Parent Summary:**
```
SYSTEM: Ты помощник логопеда. Отвечай ТОЛЬКО в JSON формате без markdown.
USER: Сессия ребёнка {child_name}, возраст {age}, звук {target_sound}, этап {stage}.
Попыток: {total}, правильных: {correct}. Трудные слова: {error_words}.
Длительность: {duration_sec} сек.
Ответь JSON: {"parent_summary": "...", "home_task": "..."}
```

**Пример — Encouragement:**
```
SYSTEM: Ты добрый голос для ребёнка 5-8 лет. ТОЛЬКО JSON, без markdown.
USER: Ребёнок {child_name} произнёс слово "{word}" для звука {sound}.
Результат: {result}. Предыдущих правильных: {streak}.
Ответь JSON: {"message": "...", "emoji": "..."}
```

---

### 19.5 Latency Budgets

| Решение | Max Latency | Стратегия |
|---|---|---|
| planDailyRoute | 2 000 ms | Вызывается до начала сессии, не blocking |
| generateParentSummary | 3 000 ms | После сессии, async background |
| generateMicroStory | 2 500 ms | Предварительная генерация во время предыдущего упражнения |
| generateEncouragement | 500 ms | Если > 500ms → немедленный fallback фраза |
| interpretResponse | 300 ms | Максимально короткий prompt |
| selectNextExercise | 800 ms | Precompute следующего упражнения во время текущего |
| adaptDifficulty | 1 000 ms | Background, не blocking |
| generateSessionWarmup | 1 500 ms | Pre-generate во время загрузки сессии |

**Правило:** Любой LLM-вызов с ожиданием > 500ms в kid-circuit должен иметь immediate UI feedback: `HSLLMThinkingIndicator` показывается немедленно.

---

### 19.6 HF Hub Integration (HFInferenceClient)

```swift
// Services/HFInferenceClient.swift
// Используется ТОЛЬКО для parent + specialist circuit (не kid)

struct HFInferenceClient {
    private let baseURL = URL(string: "https://api-inference.huggingface.co/models/")!
    private let apiToken: String  // Keychain, не hardcode

    func generate(model: String, prompt: String, maxTokens: Int) async throws -> String {
        // POST /models/{model}
        // Authorization: Bearer {token}
        // retry policy: 3 attempts, exponential backoff
        // JSON parse → extract generated_text
    }
}
```

**Модели через HF Inference API (только online, только parent/specialist):**
- Vikhr-Nemo-12B — рекомендации родителям + specialist notes
- Vikhr-7B-Instruct (резерв, быстрее)

---

### 19.7 Fallback Rules (RuleBasedDecisionService)

Полная детерминированная логика. НЕ зависит от ML. Всегда работает.

```swift
// Services/RuleBasedDecisionService.swift

struct RuleBasedDecisionService {
    func planDailyRoute(context: RoutePlanContext) -> DailyRoute {
        // Статическая матрица: sound × stage × fatigue → [template priorities]
        // Правило: Active → Passive → Motor → Active (fatigue rotation)
        // Если successRate > 0.85 → promote stage
        // Если successRate < 0.60 → demote или review stage
    }

    func generateEncouragement(attempt: AttemptResult) -> String {
        // 50 pre-written Russian encouragement phrases
        // Выбор по: isCorrect, streak, sound group
        // Никогда не "неправильно" — только "давай ещё раз!"
    }
    // ...все 12 методов реализованы через правила
}
```

---

## 20. Демо-Режим и Onboarding-Tour (НОВЫЙ)

### 20.1 Назначение

DemoTour — интерактивный анимированный тур по приложению, активируется с главного экрана (кнопка "Демо" в DemoModeView). Показывает родителю и ребёнку как работает приложение. Не требует авторизации.

### 20.2 Сценарий Тура (8 шагов)

| Шаг | Экран | Что показываем | Анимация | Длительность |
|---|---|---|---|---|
| 1 | ChildHome | Маскот Ляля, DailyMissionCard | HSMascotView bounce + confetti | 4 sec |
| 2 | WorldMap | Острова звуков, навигация | Карта "разворачивается" + island pulse | 5 sec |
| 3 | LessonPlayer (listen-and-choose) | Игровой процесс, аудио-кнопка | Card flip + audio wave | 6 sec |
| 4 | ARZone | AR-артикуляция, блендшейпы | Face mesh overlay анимация | 5 sec |
| 5 | SessionComplete | Награда: звёзды + стикер | HSRewardBurst full burst | 4 sec |
| 6 | ParentHome | Прогресс ребёнка, хитмэп | Heatmap fade-in по клеткам | 5 sec |
| 7 | ProgressDashboard | График прогресса | Chart bars animate up | 4 sec |
| 8 | SpecialistView | Waveform, ручной скоринг | Waveform real-time scroll | 4 sec |

**Итого: ~37 секунд непрерывного тура**

### 20.3 Техническая Реализация

```swift
// Features/Demo/DemoTourView.swift (обновить существующий DemoModeView)

struct DemoTourView: View {
    @State private var currentStep: Int = 0
    @State private var isAnimating: Bool = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        ZStack {
            // Overlay поверх preview-экрана
            DemoTourStepView(step: demoSteps[currentStep])
            DemoTourControlsView(step: currentStep, total: demoSteps.count) {
                advanceStep()
            }
        }
    }
}

// Анимации:
// Option A — Lottie (через wiggle скилл): для confetti, burst, wave
// Option B — SceneKit (для 3D island map reveal)
// Option C — SwiftUI анимации (для большинства шагов)
// Решение: SwiftUI primary + Lottie для confetti/burst (2 файла: confetti.json, star-burst.json)
```

### 20.4 Lottie Integration

```swift
// SPM dependency: com.airbnb.ios:lottie-spm (MIT)
// Добавить в project.yml → packages

import Lottie

struct HSLottieView: UIViewRepresentable {
    let animationName: String
    let loopMode: LottieLoopMode

    func makeUIView(context: Context) -> LottieAnimationView {
        let view = LottieAnimationView(name: animationName)
        view.loopMode = loopMode
        view.play()
        return view
    }
}
```

**Lottie файлы для бандла (CC0/MIT):**
- `confetti.json` — конфетти для наград (LottieFiles free tier)
- `star-burst.json` — звёздный взрыв для стикера
- `loading-mascot.json` — маскот загружается
- `wave-audio.json` — аудио-волна для recording

### 20.5 DemoTourService

```swift
// Services/DemoTourService.swift

@Observable
final class DemoTourService {
    var isActive: Bool = false
    var currentStep: DemoStep = .childHome
    var hasCompletedDemo: Bool  // persisted in AppStorage

    func startTour() { isActive = true; currentStep = .childHome }
    func nextStep() { /* advance or complete */ }
    func skipTour() { isActive = false; hasCompletedDemo = true }
}
```

---

## 21. Network Layer и API-Интеграция (НОВЫЙ)

### 21.1 NetworkClient

```swift
// Services/NetworkClient.swift

struct NetworkRequest {
    let url: URL
    let method: HTTPMethod
    let headers: [String: String]
    let body: Data?
    let timeout: TimeInterval  // default 30s
}

protocol NetworkClientProtocol {
    func execute<T: Decodable>(_ request: NetworkRequest) async throws -> T
}

final class LiveNetworkClient: NetworkClientProtocol {
    private let session: URLSession
    private let retryPolicy: RetryPolicy  // max 3 attempts, exponential backoff

    func execute<T: Decodable>(_ request: NetworkRequest) async throws -> T {
        var lastError: Error?
        for attempt in 0..<retryPolicy.maxAttempts {
            do {
                let (data, response) = try await session.data(for: request.urlRequest)
                try validate(response)
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                lastError = error
                if !retryPolicy.shouldRetry(error: error, attempt: attempt) { throw error }
                try await Task.sleep(nanoseconds: retryPolicy.delay(attempt: attempt))
            }
        }
        throw lastError ?? NetworkError.unknown
    }
}
```

### 21.2 Retry Policy

```swift
struct RetryPolicy {
    let maxAttempts: Int = 3
    let baseDelay: TimeInterval = 1.0  // doubles each attempt: 1s, 2s, 4s

    func shouldRetry(error: Error, attempt: Int) -> Bool {
        guard attempt < maxAttempts - 1 else { return false }
        if let networkError = error as? NetworkError {
            return networkError.isRetryable  // 5xx, timeout, network lost
        }
        return false
    }
}
```

### 21.3 ClaudeAPIClient

**КРИТИЧНО:** Используется ТОЛЬКО из родительского и специалистского контуров. Никогда из детского (COPPA).

```swift
// Services/ClaudeAPIClient.swift

struct ClaudeAPIClient {
    private let apiKey: String  // Keychain, никогда hardcode
    private let model = "claude-haiku-4-5"  // бюджетная модель для продакшн
    private let networkClient: NetworkClientProtocol

    func generateRecommendation(prompt: String) async throws -> String {
        let request = ClaudeRequest(
            model: model,
            maxTokens: 512,
            messages: [.user(prompt)]
        )
        // POST https://api.anthropic.com/v1/messages
        // Возвращает строку для ParentGuideView или SpecialistView
    }
}
```

**Сценарии использования Claude API (только online, только parent/specialist):**
- ParentGuide: персональный совет родителю на основе 30-дневной истории
- SpecialistView: расширенная интерпретация акустических данных
- Если нет интернета — `ClaudeAPIClient` бросает `NetworkError.offline`, UI показывает "совет будет доступен онлайн"

### 21.4 OfflineState — Усиленная Реализация

```swift
// Features/OfflineState/ — уже существует. Расширить:

struct OfflineStateViewModel {
    var pendingSyncCount: Int       // сколько записей ждут синхронизации
    var lastSyncDate: Date?         // когда последний раз синхронизировались
    var retryInProgress: Bool       // активна ли retry-попытка
    var networkStatus: NetworkStatus // .offline / .cellular / .wifi / .ethernet

    // Действия:
    func retrySync() async { /* попытка слить очередь */ }
    func viewPendingChanges() { /* показать список pending SyncQueueItem */ }
}
```

**OfflineState UX:**
- HSOfflineBanner показывается на всех экранах при `NetworkStatus.offline`
- Pending count badge на sync-иконке
- При восстановлении сети: автоматический retry + toast "Данные синхронизированы"
- Никогда не блокирует пользователя — все действия офлайн продолжают работать

---

## 22. Визуальный Контент (НОВЫЙ)

### 22.1 Стратегия Иллюстраций

**Принцип:** На каждом экране — минимум одна иллюстрация или иконка. Никаких "простыней" текста.

| Тип контента | Источник | Формат | Хранение |
|---|---|---|---|
| Word-cards (8 800 изображений) | Public domain API + HF Space генерация | WebP 512×512 | Firebase Storage + local cache |
| Game illustrations (16 шаблонов) | designer-visual создаёт / Canva MCP | PNG SVG | Bundle |
| AR scenario previews (10 сценариев) | designer-visual | PNG | Bundle |
| Mascot Ляля (5 эмоций) | Уже в коде (HSMascotView) | SwiftUI vector | Code |
| Onboarding illustrations (5 экранов) | designer-visual | SVG → PDF | Bundle |
| Trophy/reward illustrations (30+) | designer-visual + Canva | SVG | Bundle |
| Background textures (3 контура) | designer-visual | PNG 512×512 | Bundle |

### 22.2 Canva MCP Pipeline

```bash
# Использование Canva MCP для batch-генерации иллюстраций:
# 1. Сгенерировать шаблон в Canva
# 2. Экспортировать через Canva API / MCP
# 3. Оптимизировать: cwebp input.png -q 80 -o output.webp
# 4. Разместить в Content/Seed/images/

# LottieFiles MCP — поиск анимаций:
# Запрос: "children speech therapy animation free"
# Фильтр: license = free, format = JSON
# Скачать в Resources/Animations/
```

### 22.3 HF Space Генерация Изображений

```python
# _workshop/scripts/19_generate_word_images_hfspace.py

import requests
import json

HF_TOKEN = "hf_..."  # из env, не hardcode
SPACE_URL = "https://api-inference.huggingface.co/models/black-forest-labs/FLUX.1-schnell"

def generate_word_image(word: str, style: str = "cute cartoon illustration for children") -> bytes:
    prompt = f"Simple {style}, showing the concept '{word}', white background, no text"
    response = requests.post(
        SPACE_URL,
        headers={"Authorization": f"Bearer {HF_TOKEN}"},
        json={"inputs": prompt}
    )
    return response.content  # PNG bytes

# Использовать только для слов без public domain изображений
# Проверить: сгенерированные изображения safety-check через HF moderation
```

### 22.4 Правила Визуального Контента

1. **Ни одного экрана без иллюстрации:** Каждый экран имеет хотя бы одну иконку или иллюстрацию > 48pt
2. **Текст ≤ 3 строк без иллюстрации:** Если текстовый блок > 3 строк — рядом должна быть иллюстрация
3. **Кастомные иконки везде:** SF Symbols только для generic actions (share, close, back)
4. **Иллюстрации Kid Circuit:** яркие, тёплые, coral+mint+butter palette
5. **Иллюстрации Parent Circuit:** спокойные, нейтральные, линейный стиль
6. **Иллюстрации Specialist Circuit:** минималистичные, data-focused, только для section headers

---

## 23. Датасеты и CreateML Pipeline (НОВЫЙ)

### 23.1 Расширенная Стратегия Датасетов

**Аудио-датасеты для ASR/VAD/Scorer:**

| Датасет | HF ID | Размер | Дети? | Приоритет |
|---|---|---|---|---|
| Mozilla Common Voice 17 (RU) | mozilla-foundation/common_voice_17_0 | ~500h | Нет | P1 |
| Golos (OpenSLR) | SberDevices/Golos | ~1000h | Нет | P1 |
| FLEURS (RU) | google/fleurs | ~10h | Нет | P2 |
| EmoChildRu | Локальный | ~5h | Да | P1 — критично |
| CHILDRU corpus | Локальный | ~20h | Да | P1 — критично |
| Custom micro-corpus | Запись с логопедом | 100–200 утт. | Да | P1 |

**Image датасеты для word-cards:**

| Источник | API | Объём | Лицензия |
|---|---|---|---|
| Wikimedia Commons | commons.wikimedia.org/w/api.php | Неограничен | CC0/PD |
| OpenClipArt | openclipart.org/api/ | ~170k images | CC0 |
| HF Space (FLUX.1-schnell) | HF Inference API | По запросу | ОС (generated) |
| Canva | Canva MCP | По шаблонам | Canva license |

### 23.2 Итеративная Валидация (validate-and-fix loop)

```python
# _workshop/scripts/18_validate_datasets_iterative.py

import json, os
from pathlib import Path

VALIDATION_SCORE_THRESHOLD = 0.95

class DatasetValidator:
    def __init__(self, dataset_path: str):
        self.path = Path(dataset_path)

    def run_pass(self) -> dict:
        """Один проход валидации. Возвращает score + список ошибок."""
        errors = []
        errors += self._check_audio_files()      # существование, duration 0.5-10s, sample_rate 16000
        errors += self._check_annotations()      # наличие транскрипции, непустые labels
        errors += self._check_duplicates()       # дубли по content hash
        errors += self._check_balance()          # баланс классов ≥ 0.7 (min/max ratio)
        score = 1.0 - len(errors) / max(self.count_items(), 1)
        return {"score": score, "errors": errors, "pass_count": len(errors) == 0}

    def fix_auto(self, errors: list) -> int:
        """Автоматически исправляет исправляемые ошибки. Возвращает кол-во исправленных."""
        fixed = 0
        for err in errors:
            if err["type"] == "DUPLICATE": self._remove_duplicate(err); fixed += 1
            if err["type"] == "WRONG_SR": self._resample(err); fixed += 1
        return fixed

if __name__ == "__main__":
    validator = DatasetValidator("_workshop/datasets/clean/")
    iteration = 0
    while True:
        result = validator.run_pass()
        print(f"Iteration {iteration}: score={result['score']:.3f}, errors={len(result['errors'])}")
        if result['score'] >= VALIDATION_SCORE_THRESHOLD:
            print("PASS — dataset ready for training")
            break
        fixed = validator.fix_auto(result['errors'])
        print(f"Auto-fixed {fixed} errors. Manual fixes needed: {len(result['errors']) - fixed}")
        if fixed == 0:
            print("ERROR — no progress, manual intervention needed")
            break
        iteration += 1
```

### 23.3 CreateML Pipeline

**Когда использовать CreateML вместо PyTorch:**
- Бинарные классификаторы (correct/incorrect) — CreateML MLSoundClassifier
- Image tagging для word-cards — CreateML MLImageClassifier
- Нет GPU, нет времени — быстрый прототип за 1-2 часа

**Шаги:**

```bash
# Option A: Create ML App (GUI)
# 1. Открыть Create ML.app (Xcode → Open Developer Tool)
# 2. New Project → Sound Classifier или Image Classifier
# 3. Drag & drop датасет (папки по классам)
# 4. Train → Evaluate → Export .mlmodel/.mlpackage

# Option B: Python (coremltools + CreateML framework)
python3 _workshop/scripts/17_train_createml_classifier.py \
  --type sound \
  --data _workshop/datasets/children/ \
  --output _workshop/models/createml/PhonemeClassifier.mlpackage
```

---

## 24. Автоматическое Тестирование через Симулятор (НОВЫЙ)

### 24.1 Итеративный Цикл Screenshot-Валидации

```
ЦИКЛ (повторять до победы):
1. BUILD    → xcodebuild build (iPhone SE + iPhone 17 Pro)
2. LAUNCH   → mcp__ios-simulator__boot + mcp__ios-simulator__launch
3. CAPTURE  → mcp__ios-simulator__screenshot для каждого из 69 экранов
4. ANALYZE  → python3 _workshop/scripts/20_screenshot_analysis.py
             + mcp__xcodebuild__get_ui_hierarchy (проверить что все View видны)
5. REPORT   → logs/screenshot_issues_{timestamp}.json
6. FIX      → ios-dev-ui исправляет найденные проблемы
7. GOTO 1   → пока issues > 0
```

### 24.2 Критерии Качества Скриншота

Автоматическая проверка через PIL + Accessibility Tree:

| Проблема | Как детектируется | Severity |
|---|---|---|
| Текст обрезан (clip) | PIL: пиксели текста у boundary | Critical |
| Layout overflow | UI hierarchy: frame вылезает за bounds | Critical |
| Тёмная тема сломана | PIL: background = white в dark mode | Critical |
| Текст нечитаем (контраст) | PIL: WCAG contrast ratio < 4.5:1 | Major |
| Пустой экран (пусто) | PIL: >70% однородный цвет | Major |
| SF Symbols placeholder | UI hierarchy: Image("questionmark") | Minor |
| Hardcoded debug text | UI hierarchy: Label containing "error_code" / "session_id" | Critical |

### 24.3 MCP Tools для Симулятора

```bash
# Доступные MCP инструменты (из mcp__xcodebuild + mcp__ios-simulator):

# Сборка
mcp__xcodebuild__build_for_testing --scheme HappySpeech --destination "iPhone SE (4th generation)"

# Симулятор
mcp__ios-simulator__boot --device "iPhone SE (4th generation)"
mcp__ios-simulator__launch --bundleId com.happyspeech.app

# Скриншот
mcp__ios-simulator__screenshot --device "iPhone SE (4th generation)" --output "_workshop/screenshots/se_screen_{n}.png"

# UI Hierarchy (для проверки overflow)
mcp__xcodebuild__get_ui_hierarchy --device "iPhone SE (4th generation)"

# Смена темы (для dark mode тестирования)
mcp__ios-simulator__set_appearance --device "iPhone SE (4th generation)" --appearance dark
```

### 24.4 Screenshot Analysis Script

```python
# _workshop/scripts/20_screenshot_analysis.py

from PIL import Image
import numpy as np, json, sys
from pathlib import Path

def check_text_clipping(img_path: str) -> list:
    """Проверяет обрезание текста у краёв изображения."""
    img = Image.open(img_path).convert("RGB")
    arr = np.array(img)
    issues = []
    # Текстовые пиксели у boundary → clip
    edge_pixels = np.concatenate([arr[0, :], arr[-1, :], arr[:, 0], arr[:, -1]])
    dark_edge_count = np.sum(edge_pixels.mean(axis=1) < 50)
    if dark_edge_count > 20:
        issues.append({"type": "POSSIBLE_TEXT_CLIP", "file": img_path})
    return issues

def check_dark_mode_background(img_path: str, expected_dark: bool) -> list:
    """Проверяет что фон тёмный в dark mode / светлый в light mode."""
    img = Image.open(img_path).convert("RGB")
    arr = np.array(img)
    brightness = arr.mean()
    issues = []
    if expected_dark and brightness > 150:
        issues.append({"type": "DARK_MODE_BROKEN", "brightness": brightness, "file": img_path})
    if not expected_dark and brightness < 80:
        issues.append({"type": "LIGHT_MODE_BROKEN", "brightness": brightness, "file": img_path})
    return issues

# Точка входа
if __name__ == "__main__":
    screenshots_dir = Path(sys.argv[1] if len(sys.argv) > 1 else "_workshop/screenshots/")
    all_issues = []
    for f in screenshots_dir.glob("*.png"):
        is_dark = "_dark" in f.stem
        all_issues += check_text_clipping(str(f))
        all_issues += check_dark_mode_background(str(f), is_dark)
    output = {"total_issues": len(all_issues), "issues": all_issues}
    with open("logs/screenshot_issues_latest.json", "w") as out:
        json.dump(output, out, indent=2, ensure_ascii=False)
    print(f"Found {len(all_issues)} issues.")
```

---

## 25. Переключение Темы — Детальная Спецификация (НОВЫЙ)

### 25.1 Архитектура ThemeManager

```swift
// App/DI/ThemeManager.swift (существует, расширить)

enum AppTheme: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"  // следует за .colorScheme среды
}

@Observable
final class ThemeManager {
    @AppStorage("app_theme") var selectedTheme: AppTheme = .system

    var preferredColorScheme: ColorScheme? {
        switch selectedTheme {
        case .light:  return .light
        case .dark:   return .dark
        case .system: return nil  // iOS сам решает
        }
    }

    // Применяется в WindowGroup:
    // .preferredColorScheme(container.themeManager.preferredColorScheme)
}
```

### 25.2 HSThemeToggle Component

```swift
// DesignSystem/Components/HSThemeToggle.swift

struct HSThemeToggle: View {
    @Environment(ThemeManager.self) var themeManager

    var body: some View {
        Picker(String(localized: "Тема"), selection: $themeManager.selectedTheme) {
            Label(String(localized: "Светлая"), systemImage: "sun.max").tag(AppTheme.light)
            Label(String(localized: "Тёмная"), systemImage: "moon").tag(AppTheme.dark)
            Label(String(localized: "Системная"), systemImage: "circle.lefthalf.filled").tag(AppTheme.system)
        }
        .pickerStyle(.segmented)
        .accessibilityLabel(String(localized: "Выбор цветовой темы"))
    }
}
```

### 25.3 Интеграция в Settings

```
SettingsView
└── SettingsInteractor.handleThemeChange(theme:)
    └── themeManager.selectedTheme = theme
        → @AppStorage сохраняет автоматически
        → WindowGroup.preferredColorScheme обновляется
        → Все экраны перерисовываются мгновенно
```

### 25.4 Snapshot Tests для Theme

Для каждого из 69 экранов:
```swift
// HappySpeechTests/Snapshots/ThemeSnapshotTests.swift

func test_childHome_light() {
    let view = ChildHomeView(...)
        .environment(AppContainer.preview().themeManager)
        .preferredColorScheme(.light)
    assertSnapshot(matching: view, as: .image(on: .iPhoneSe), named: "ChildHome_light")
}

func test_childHome_dark() {
    // ... preferredColorScheme(.dark)
    assertSnapshot(matching: view, as: .image(on: .iPhoneSe), named: "ChildHome_dark")
}
```

### 25.5 Правила Использования Цветов в View

- Запрещено: `Color(.white)`, `Color(.black)`, `Color(hex: "#FFFFFF")`
- Обязательно: `ColorTokens.Kid.bg`, `ColorTokens.Parent.surface`, `ColorTokens.Semantic.success`
- Проверка: SwiftLint custom rule `no_hardcoded_colors` (`Color(hex:` → warning)

---

## 26. Качество Текста и UI-Копирайт (НОВЫЙ)

### 26.1 Правила Локализации

**Структура Localizable.xcstrings:**
- Все строки — через `String(localized: "key", table: "Localizable")`
- Никаких литеральных строк в View (только в превью)
- Ключи — на английском, camelCase: `childHome.dailyMission.title`
- Значения на русском — tone-of-voice для детей 5–8 лет (простые слова, короткие предложения)

**Tone-of-voice для контуров:**

| Контур | Tone | Примеры |
|---|---|---|
| Kid | Тёплый, игровой, без жаргона | "Отлично! Ты молодец!", "Попробуй ещё раз, у тебя получится!" |
| Parent | Спокойный, конкретный, без медицинского жаргона | "Прогресс за неделю", "Рекомендуем повторить эти слова" |
| Specialist | Точный, профессиональный | "Успешность: 78%", "Этап: Слова-начало" |

### 26.2 Dynamic Type Стратегия

```swift
// Обязательные модификаторы для КАЖДОГО текстового View:
Text("...")
    .lineLimit(nil)
    .minimumScaleFactor(0.85)
    .fixedSize(horizontal: false, vertical: true)

// Для кнопок:
HSButton(title: "...") // HSButton уже применяет эти модификаторы внутри

// Запрещено:
Text("...").lineLimit(1)  // может обрезать
Text("...").frame(height: 44)  // может обрезать при AccessibilityLarge
```

### 26.3 Правила Против Debug-Текста

**SwiftLint custom rules (добавить в .swiftlint.yml):**
```yaml
custom_rules:
  no_debug_ui_text:
    name: "No Debug Text in UI"
    regex: '(Text|Label)\(.*("error_code|session_id|debug|uuid|0x)[^)]*\)'
    severity: error
  no_hardcoded_colors:
    name: "No Hardcoded Colors"
    regex: 'Color\(hex:|Color\.(white|black|red|green|blue)\)'
    severity: warning
  no_force_unwrap:
    name: "No Force Unwrap"
    regex: '\w+!'
    severity: error
    excluded: ["Tests/", "Mocks/"]
```

### 26.4 Все Error Messages — LocalizedError

```swift
// Core/Errors/AppError.swift — расширить:

enum AppError: LocalizedError {
    case networkUnavailable
    case realmWriteFailed
    case llmUnavailable
    case asrUnavailable
    case arUnsupported
    case contentNotFound

    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return String(localized: "Нет соединения с интернетом. Приложение работает офлайн.", table: "Errors")
        case .llmUnavailable:
            return String(localized: "ИИ-помощник недоступен. Используем базовые рекомендации.", table: "Errors")
        // ...
        }
    }
    // Никаких "error_code: 42", "realm_write_error", UUID в messages
}
```

---

## 27. Производительность и Отзывчивость (НОВЫЙ)

### 27.1 Actor-Based Concurrency для ML

```swift
// ML-инференс изолирован в dedicated actor

actor MLInferenceActor {
    // Все ML-вызовы проходят через этот actor
    func runASR(audio: AVAudioPCMBuffer) async throws -> String { /* ... */ }
    func runVAD(chunk: [Float]) async throws -> Float { /* ... */ }
    func runPronunciationScorer(spectrogram: [[Float]]) async throws -> Float { /* ... */ }
    func runLLM(prompt: String) async throws -> String { /* ... */ }
}

// Использование в Service:
final class LiveASRService: ASRServiceProtocol {
    private let mlActor = MLInferenceActor()

    func transcribe(audio: AVAudioPCMBuffer) async throws -> String {
        return try await mlActor.runASR(audio: audio)
    }
}
```

### 27.2 AVAudioEngine — Производительность

```swift
// Services/AudioService.swift — правила:

// 1. Прогрев буфферов при инициализации AppContainer, не при первом нажатии
func warmUp() async {
    engine.prepare()  // вызывается в AppContainer.live() → bootstrapApp()
}

// 2. Запись — background очередь через actor
// 3. Buffer size = 4096 samples (оптимум для 16kHz Silero VAD chunks)
// 4. tap установить только после engine.start()

// 5. НЕ запускать engine.start() в main thread:
Task(priority: .userInitiated) {
    try await audioService.startRecording()
}
```

### 27.3 ARKit — 30fps при слабом CPU

```swift
// Features/ARZone/ARZoneView.swift — ARSCNView configuration:

configuration.videoFormat = ARFaceTrackingConfiguration.supportedVideoFormats
    .filter { $0.framesPerSecond == 30 }  // 30fps, не 60fps (экономит CPU)
    .first ?? ARFaceTrackingConfiguration.supportedVideoFormats[0]

// Упрощение при thermal state:
NotificationCenter.default.addObserver(
    forName: ProcessInfo.thermalStateDidChangeNotification,
    object: nil, queue: .main
) { _ in
    if ProcessInfo.processInfo.thermalState == .critical {
        arSession.pause()  // пауза AR при перегреве
    }
}
```

### 27.4 UI Performance — 60fps на iPhone SE

```swift
// Правила для SwiftUI Views в детском контуре:

// 1. Избегать ForEach с большими данными без Identifiable
// 2. LazyVStack вместо VStack для списков > 10 элементов
// 3. .drawingGroup() для сложных анимаций (confetti, particles)
// 4. Анимации через withAnimation(.spring()) — не Timer-based
// 5. Image кэширование через AsyncImage + NSCache wrapper
// 6. Профилирование: Time Profiler в Instruments, target frame time = 16.67ms
```

### 27.5 Memory Budget

| Компонент | Лимит | Стратегия |
|---|---|---|
| LLM (Qwen2.5-1.5B) | 1.2 GB | Выгружать из памяти когда не нужен (MLCEngine.unload()) |
| GigaAM ONNX | 400 MB | Один экземпляр через singleton, не создавать повторно |
| Realm | < 50 MB | Paginate large queries, не загружать все 8800 items |
| Image cache | < 100 MB | NSCache с cost limit, WebP format |
| Audio buffers | < 20 MB | Circular buffer, не накапливать |

---

## 28. Обновлённый Sprint-План v2 (НОВЫЙ)

### 28.1 Детальные Sprint Cards — Новые Спринты

---

#### Sprint 12 — Week 13
**Goal:** Demo Tour + Theme Switch + Custom Icons

| Task | Owner | Est |
|------|-------|-----|
| DemoTourView (8 шагов, SwiftUI primary) | ios-dev-ui | 3d |
| Lottie SPM dependency + confetti.json + star-burst.json | ios-dev-ui | 1d |
| HSThemeToggle component | ios-dev-ui | 0.5d |
| ThemeManager → AppStorage → WindowGroup wiring | ios-dev-arch | 0.5d |
| Settings → Theme section | ios-dev-ui | 0.5d |
| Custom icons: navigation (5), games (16), sounds (22) | designer-visual | 3d |
| HSCustomIcon wrapper | ios-dev-ui | 0.5d |
| Snapshot tests: ThemeSnapshotTests (all 69 screens × light/dark) | qa-unit | 2d |
| DemoTourService | ios-dev-arch | 1d |

**Acceptance:**
- [ ] DemoTour проходит все 8 шагов без краша на SE и Pro
- [ ] Theme switch мгновенный, сохраняется после рестарта
- [ ] ≥43 кастомных иконок в Asset Catalog
- [ ] 138 snapshot tests (69 × light + dark) проходят

---

#### Sprint 13 — Week 14
**Goal:** Visual Content + Datasets + CreateML

| Task | Owner | Est |
|------|-------|-----|
| _workshop/scripts/16_fetch_images.py (public domain fetch) | ml-data-engineer | 1d |
| _workshop/scripts/19_generate_word_images_hfspace.py | ml-data-engineer | 1d |
| _workshop/scripts/18_validate_datasets_iterative.py | ml-data-engineer | 1d |
| _workshop/scripts/17_train_createml_classifier.py | ml-trainer | 2d |
| Illustrations: onboarding (5), game templates (16), AR previews (10) | designer-visual | 3d |
| Word-cards: MVP seed batch (520 images) | ml-data-engineer | 2d |
| HSLLMThinkingIndicator component | ios-dev-ui | 0.5d |
| LLMDecisionService — все 12 точек интеграции | ios-dev-arch | 3d |
| RuleBasedDecisionService — все 12 fallback методов | ios-dev-arch | 2d |
| HFInferenceClient (Vikhr-Nemo через HF API) | ios-dev-arch | 1d |
| LLMDecisionServiceTests (12 test cases) | qa-unit | 1d |

**Acceptance:**
- [ ] 520 MVP word-card images в Content/Seed/images/
- [ ] dataset validation score > 0.95
- [ ] LLMDecisionService.planDailyRoute работает in < 2000ms на iPhone 12+
- [ ] Все 12 fallback методов возвращают валидный результат

---

#### Sprint 14 — Week 15
**Goal:** Screenshot Iteration + Локализация + App Store

| Task | Owner | Est |
|------|-------|-----|
| _workshop/scripts/20_screenshot_analysis.py | qa-simulator | 1d |
| Screenshot tour v2.0 (69 экранов × 2 девайса) | qa-simulator | 1d |
| Итерация 1: анализ → список проблем | qa-simulator | 0.5d |
| Итерация 1: фиксы UI | ios-dev-ui | 1d |
| Итерация 2: повторный тур | qa-simulator | 0.5d |
| Итерация 2+: продолжать до нуля проблем | ios-dev-ui + qa-simulator | 2d |
| Localizable.xcstrings — полный аудит (ru+en, все 69 экранов) | ios-dev-arch | 1d |
| Tone-of-voice ревью (все строки kid circuit) | pm | 1d |
| VoiceOver audit (все interactive elements) | qa-unit | 1d |
| Dynamic Type audit (SE 4th gen AccessibilityLarge) | qa-unit | 1d |
| AppPrivacyInfo.xcprivacy | ios-dev-arch | 0.5d |
| App Store metadata (ru + en: название, описание, keywords) | pm | 1d |
| TestFlight build | ios-lead | 1d |
| Diploma materials: architecture diagram, demo video, ML pipeline | pm + ios-lead | 2d |

**Acceptance:**
- [ ] 0 screenshot issues после финальной итерации
- [ ] Все строки локализованы (0 missing keys)
- [ ] TestFlight build открывается без краша на SE + Pro
- [ ] Diploma deck готов

---

### 28.2 Текущий Статус (2026-04-22)

| Sprint | Статус | Примечания |
|---|---|---|
| S0 | Done | Все планировочные артефакты |
| S1 | Done | Xcode project, Core layer, 231 Swift файл |
| S2 | Done | DesignSystem полностью, все 13 компонентов |
| S3 | In Progress | Auth + Onboarding (Features shell создан) |
| S4–S14 | Planned | — |

**Следующий шаг после одобрения v2.0:** Запуск оркестратора → Phase 0 (обновить phases.json) → Phase 1 (реализация S3 Auth+Onboarding)

---

## Appendix A: Speech Methodology Summary

*Без изменений vs v1.0 — см. `HappySpeech/ResearchDocs/speech-methodology.md`*

---

## Appendix B: Competitor Differentiators

*Без изменений vs v1.0 — см. `HappySpeech/ResearchDocs/speech-competitor-analysis.md`*

---

## Appendix C: ADR Log v2.0 (новые решения)

### ADR-009: LLM Selection v2 — Dual Path
**Decision:** Двойной путь: Qwen2.5-1.5B on-device (MLC) + Vikhr-Nemo-12B через HF Inference API (online only, parent/specialist circuit only).
**Reason:** Qwen покрывает offline use case (kid circuit). Vikhr даёт лучшее русское качество для родительских рекомендаций.
**Alternatives:** SmolLM2 (меньше, хуже русский), Saiga (нужна конвертация MLC).
**Risk:** HF API ключ в Keychain, COPPA — только parent/specialist.

### ADR-010: Lottie vs SceneKit для DemoTour
**Decision:** SwiftUI primary анимации + Lottie для confetti/burst (2 JSON файла). SceneKit — только для island map reveal если потребуется.
**Reason:** Lottie — MIT, легковесен, CC0 анимации доступны. SceneKit — излишне для большинства шагов тура.
**Risk:** Lottie SPM может конфликтовать. Mitigation: проверить совместимость в S12.

### ADR-011: ClaudeAPIClient — COPPA Isolation
**Decision:** ClaudeAPIClient и HFInferenceClient доступны только из parent/specialist circuit. Детский контур — исключительно on-device + rule-based.
**Reason:** Любые сетевые запросы из детского контура нарушают COPPA/Kids Category.
**Risk:** Родители могут хотеть AI-рекомендации в offline. Mitigation: graceful "совет будет доступен онлайн" message.

### ADR-012: Screenshot Iteration — Start Early
**Decision:** Начать screenshot-тестирование с S12 (параллельно с Demo), не ждать S14.
**Reason:** R16 — риск что итерации заберут всё время S14. Ранний старт даёт буфер.

### ADR-013: CreateML как дополнительный путь
**Decision:** CreateML для простых бинарных классификаторов параллельно с PyTorch-путём.
**Reason:** Нет GPU, нет времени на fine-tuning → CreateML Sound/Image Classifier за 1-2 часа.

---

*Master Plan v2.0 — Compiled by CTO. 10 новых требований интегрированы.*
*Разделы 19–28 — новые. Разделы 1–18 обновлены по статусу (S0, S1, S2 — Done).*
*Ожидает одобрения пользователя перед запуском оркестратора.*
