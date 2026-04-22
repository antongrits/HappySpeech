# Открытые датасеты для HappySpeech

> Только бесплатные, без платных API-ключей. Последнее обновление: 2026-04-23

---

## ASR — Датасеты для обучения и fine-tuning (русская речь)

---

### 1. Common Voice Russian — Mozilla (РЕКОМЕНДОВАН #1)

**Имя:** Common Voice Scripted Speech 25.0 — Russian
**URL:** https://mozilladatacollective.com/datasets/cmn2h1dg201gro107lpynbbd6
**Лицензия:** Creative Commons Zero v1.0 (CC0) — полностью свободна для любого использования
**Объём:**
- 290.51 часов записей
- 251.94 часа валидированных
- 201,947 аудио-клипов
- 48,092 предложений
- 3,695 дикторов

**Также доступна Spontaneous Speech версия:**
- 3.1 часа (2.34 validated), 513 клипов, 15 дикторов
- URL: https://mozilladatacollective.com/datasets/cmj8u48ey004xnxzpphv4udzz

**Скачивание:**
Через Mozilla Data Collective (с октября 2025 — единственная точка доступа). Прямая ссылка: `common-voice-scripted-speech-25-0-russia-*.tar.gz` (6.55 GB).

**Применение в HappySpeech:**
- Fine-tuning Whisper-small/tiny для детской речи (дикторское разнообразие 3695 чел.)
- Тренировка PronunciationScorer — бинарный классификатор «правильно/неправильно»
- Аугментация для работы с детским голосом (дети говорят выше и нечётче)

**Ограничения:** нельзя идентифицировать дикторов по голосу, нельзя перераспространять
**Детская речь:** нет — только взрослые, нужна аугментация

---

### 2. GOLOS — SberDevices (РЕКОМЕНДОВАН #2)

**Имя:** Golos: Russian Dataset for Speech Research
**URL:** https://huggingface.co/datasets/SberDevices/Golos
**GitHub:** https://github.com/sberdevices/golos
**OpenSLR:** https://openslr.org/114/
**Лицензия:** Apache 2.0 (нужна дополнительная проверка — некоторые источники указывают только «freely available»)
**Объём:**
- 1,240 часов (1,227 train + 12.6 test)
- 1,103,799 тренировочных файлов
- Crowd recordings: 1,095 часов
- Farfield recordings: 132 часа

**Форматы:** Opus (20.5 GB) или WAV (147 GB)

**Включает предобученные модели:**
- Акустическая модель QuartzNet15x5 (68 MB)
- Языковые модели KenLM (Common Crawl + Golos, 4.8 GB)

**WER качество:**
- Crowd test: 3.318%
- Farfield test: 11.488%
- Common Voice dev: 6.4–8.06%

**Применение в HappySpeech:**
- Основной датасет для fine-tuning WhisperKit на русский (наибольший объём)
- KenLM language model для улучшения beam search декодирования
- Farfield subset полезен для тренировки на шумных условиях (дети дома)

**Детская речь:** нет — взрослые, crowdsourcing

---

### 3. Russian LibriSpeech (RuLS) — OpenSLR 96

**Имя:** Russian LibriSpeech (RuLS)
**URL:** https://www.openslr.org/96/
**Скачивание:** `ruls_data.tar.gz` [9.1 GB] с openslr.trmal.net + EU/CN зеркала
**Лицензия:** Public Domain в США
**Объём:**
- 98.2 часа
- 17 русских аудиокниг LibriVox
- Train / Dev / Test без пересечения дикторов
- Макс. длина клипа: 20 секунд

**Применение в HappySpeech:**
- Дополнительный корпус для повышения разнообразия акустических условий
- Хорошая структура train/dev/test для правильной оценки модели
- Public Domain = нет юридических ограничений

**Детская речь:** нет — аудиокниги читают взрослые

---

### 4. Open STT Russian — snakers4

**Имя:** Russian Open STT Corpus
**GitHub:** https://github.com/snakers4/open_stt
**URL:** https://learn.microsoft.com/en-us/azure/open-datasets/dataset-open-speech-text (Azure mirror)
**Лицензия:** CC-BY-NC 4.0 — ВНИМАНИЕ: некоммерческая. Для research допустимо, для коммерческого релиза нет.
**Объём:**
- 10,000–20,000 часов (v1.0-beta: 15M utterances, 2.3 TB WAV mono)
- Включает разные домены: подкасты, телефон, YouTube и др.

**Детская речь:** нет

---

## Датасеты детской речи

**Важное замечание:** Открытых датасетов детской русской речи практически не существует. Это критический пробел.

### SpeechOcean Kids (коммерческий — только для справки)
- 3000+ часов детской речи на English, Chinese, Russian, French и др.
- Требует лицензирования (платно)
- URL: https://en.speechocean.com/about/newsdetails/80.html

### speechocean762 (English, открытый)
- 5000 высказываний от 250 дикторов (50% — дети), оценка произношения
- Apache 2.0
- OpenSLR: https://openslr.org/101/
- Полезен как reference для PronunciationScorer архитектуры (не русский)

### Рекомендация для HappySpeech:
Синтезировать псевдо-детскую речь через повышение pitch в Common Voice/GOLOS + использовать Silero TTS для генерации дополнительных обучающих примеров. Это стандартная практика при отсутствии детских корпусов.

---

## TTS — Голосовые модели для озвучки приложения

---

### 5. Silero TTS (Russian)

**GitHub:** https://github.com/snakers4/silero-models
**Лицензия:** CC-NC-BY (большинство) / MIT (CIS base models) — ВНИМАНИЕ: проверить для production
**Голоса (v5):** aidar, baya, kseniya, xenia, eugene
**Качество:** 8000 / 24000 / 48000 Hz
**Особенности:** автоматические ударения, обработка омографов
**Формат:** PyTorch `.pt` (нет native ONNX, нет CoreML)

**Применение в HappySpeech:**
- Генерация TTS-озвучки для упражнений в Seed-контенте (offline preparation на Mac)
- НЕ использовать for real-time inference на устройстве

---

### 6. XTTS-v2 (Coqui, Russian)

**HuggingFace:** https://huggingface.co/coqui/XTTS-v2
**Лицензия:** Coqui Public Model License (CPML) — ограничивает коммерческое использование. Компания Coqui закрылась в 2024, поддерживает community.
**Поддерживаемые языки:** 17 языков включая русский
**Качество:** 24 kHz, высокая натуральность (лидер по CMOS)
**Особенности:** клонирование голоса по 6 секундам референса

**Применение в HappySpeech:**
- Генерация озвучки маскота «Ляля» по одному голосовому образцу
- Pre-render всего контент-пака до публикации
- НЕ использовать for real-time inference на устройстве

---

## VAD — Детектор голосовой активности

### 7. Silero VAD (CoreML)

**HuggingFace:** https://huggingface.co/FluidInference/silero-vad-coreml
**GitHub (FluidAudio):** https://github.com/FluidInference/FluidAudio
**Лицензия:** MIT
**Поддержка:** iOS 17.0+, macOS 14.0+, Apple Silicon, Apple Neural Engine

**Применение в HappySpeech:**
Заменить текущий energy-stub SileroVAD на реальную CoreML модель. Swift Package Manager интеграция.

```swift
// Swift Package Manager
.package(url: "https://github.com/FluidInference/FluidAudio.git", from: "x.x.x")
```

---

## Face Tracking

### 8. MediaPipe Face Mesh (478 landmarks)

**GitHub:** https://github.com/google-ai-edge/mediapipe
**Лицензия:** Apache 2.0
**iOS:** XCFramework через build script https://github.com/swittk/MediapipeFaceMeshIOSLibrary
**Модель:** 2 DNN: детектор лица + 3D landmark регрессия

**Применение в HappySpeech:**
Дополнение к ARKit Face Tracking для устройств без TrueDepth или для 478-landmark precision tracking губ и языка.

---

## Рекомендации по приоритету для HappySpeech

| Приоритет | Датасет | Задача | Лицензия | Действие |
|---|---|---|---|---|
| #1 | Common Voice Russian (CV 25.0) | ASR fine-tuning | CC0 | Скачать сразу |
| #2 | GOLOS (SberDevices) | ASR fine-tuning | Apache 2.0 | Скачать через HuggingFace |
| #3 | Russian LibriSpeech | Дополнение | Public Domain | Скачать при необходимости |
| Инструмент | Silero VAD CoreML | VAD на устройстве | MIT | Уже в стеке |
| TTS | Silero TTS v5 | Озвучка контента | CC-NC-BY | Только offline pre-render |
| Дети | Синтетика | Аугментация | — | Pitch shift + TTS |

---

## Источники
- https://mozilladatacollective.com/datasets/cmn2h1dg201gro107lpynbbd6
- https://datacollective.mozillafoundation.org/datasets/cmj8u48ey004xnxzpphv4udzz
- https://huggingface.co/datasets/SberDevices/Golos
- https://github.com/sberdevices/golos
- https://openslr.org/114/
- https://www.openslr.org/96/
- https://github.com/snakers4/open_stt
- https://learn.microsoft.com/en-us/azure/open-datasets/dataset-open-speech-text
- https://github.com/snakers4/silero-models
- https://huggingface.co/coqui/XTTS-v2
- https://huggingface.co/FluidInference/silero-vad-coreml
- https://github.com/FluidInference/FluidAudio
- https://github.com/google-ai-edge/mediapipe
- https://github.com/swittk/MediapipeFaceMeshIOSLibrary
- https://en.speechocean.com/about/newsdetails/80.html
- https://arxiv.org/abs/2104.01378 (speechocean762)
