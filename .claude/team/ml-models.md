# ML Models Registry — HappySpeech
## Version 2.5 — 2026-05-07
## Managed by ML Trainer. Updated when model is converted and validated.

---

## Block B v16 — BG Training Status (2026-05-07)

**Статус:** IN PROGRESS (BG agent running, ~8-12 ч)

Block B Plan v16 запустил BG agent для дообучения 9 моделей. Финальные mlpackages появятся после завершения. Текущие deployed модели в Resources/Models/ остаются в production до замены.

| Модель | Текущая версия | Ожидаемая val accuracy v16 | Статус BG |
|---|---|---|---|
| SileroVAD CNN | M4.4 (99.9%) | ≥99% | queued |
| PronunciationScorer_whistling | M4.3 (100%) | ≥99% | queued |
| PronunciationScorer_hissing | M4.3 (100%) | ≥99% | queued |
| PronunciationScorer_sonants | M4.3 (100%) | ≥99% | queued |
| PronunciationScorer_velar | M4.3 (100%) | ≥99% | queued |
| SoundClassifier | M4.5 (85.8%) | ≥90% | queued |
| RussianPhonemeClassifier | v14 (92.24%) | ≥93% | queued |
| Wav2Vec2RuChildLogopedic | v14 (96.67%) | ≥97% | queued |
| EmotionDetection | v14 (95.83%) | ≥96% | queued |

Wav2Vec2RuChild (Wav2Vec2-base fine-tune) и TonguePostureClassifier v2 на реальных детских данных — deferred post-v1.0 (GPU RAM + GDPR consent required).

**По завершении Block B:** ml-engineer обновит этот реестр записями с реальными val accuracy v16.

---

---

## Active Models

| ID | Model Name | Task | License | Size (on-device) | Path | Status | Fallback |
|----|-----------|------|---------|-----------------|------|--------|---------|
| M-001 | WhisperKit large-v3-turbo | Russian ASR — primary | MIT | ~600 MB | via WhisperKit SPM (download on first run) | Planned (S5) | WhisperKit tiny |
| M-002 | WhisperKit tiny (Russian) | Russian ASR — fallback | MIT | ~150 MB | via WhisperKit SPM | Planned (S5) | AVSpeechRecognizer (online) |
| M-003 | SileroVAD CNN | Voice Activity Detection | Proprietary | 0.073 MB | Resources/Models/SileroVAD.mlpackage | DEPLOYED (M4.4 real CNN) | AmplitudeVAD (Swift actor) |
| M-004a | PronunciationScorer_whistling | Binary scoring: С,З,Ц | Proprietary | 0.099 MB | Resources/Models/PronunciationScorer_whistling.mlpackage | DEPLOYED (retrained M4.3+Refs 2026-04-26) | MockPronunciationScorer |
| M-004b | PronunciationScorer_hissing | Binary scoring: Ш,Ж,Ч,Щ | Proprietary | 0.099 MB | Resources/Models/PronunciationScorer_hissing.mlpackage | DEPLOYED (retrained M4.3+Refs 2026-04-26) | MockPronunciationScorer |
| M-004c | PronunciationScorer_sonants | Binary scoring: Р,Л | Proprietary | 0.099 MB | Resources/Models/PronunciationScorer_sonants.mlpackage | DEPLOYED (retrained M4.3+Refs 2026-04-26) | MockPronunciationScorer |
| M-004d | PronunciationScorer_velar | Binary scoring: К,Г,Х | Proprietary | 0.099 MB | Resources/Models/PronunciationScorer_velar.mlpackage | DEPLOYED (retrained M4.3 2026-04-26) | MockPronunciationScorer |
| M-006 | SoundClassifier | 4-class sound classification: speech/noise/silence/breathing | Proprietary | 0.128 MB | Resources/Models/SoundClassifier.mlpackage | DEPLOYED (M4.5) | MockAudioAnalysisService |
| M-005 | Qwen2.5-1.5B-Instruct (MLX Swift) | Structured decisions: parent summary, route planner, micro-story | Apache 2.0 | ~950 MB | Downloaded on first run via mlx-community | Planned (S11) | Rule-based templates |

---

## Model Details

### M-001: WhisperKit whisper-large-v3-turbo

- **Source:** OpenAI Whisper / WhisperKit iOS (https://github.com/argmaxinc/WhisperKit)
- **License:** MIT — ПОДХОДИТ для App Store (заменяет GigaAM v2024 NC)
- **Runtime:** WhisperKit SPM (нативный Swift, iOS 16+)
- **Model variant:** whisper-large-v3-turbo (~600 MB), загружается при первом запуске
- **WER:** ~7.4% avg на русском (general speech)
- **Latency target:** < 500ms для 5-секундного аудио на iPhone 12+
- **Features:** Русский язык forced decoding, word-level timestamps
- **Integration:** SPM dependency argmaxinc/WhisperKit
- **ADR:** ADR-001-REV1 (2026-04-22) — заменяет GigaAM из-за NC лицензии

### M-002: WhisperKit (whisper-tiny, Russian)

- **Source:** OpenAI Whisper / WhisperKit iOS (https://github.com/argmaxinc/WhisperKit)
- **Integration:** SPM package (WhisperKit)
- **Model variant:** whisper-tiny (fastest, smallest), Russian language token forced
- **WER:** ~20–25% on Russian general speech (acceptable as fallback)
- **Latency:** < 200ms for 3-second utterance on iPhone 12+
- **Notes:** Used as fallback if GigaAM unavailable or not yet downloaded

### M-003: SileroVAD CNN — M4.4

- **Задача:** Voice Activity Detection — speech vs noise/silence на 32ms чанках
- **Путь:** HappySpeech/Resources/Models/SileroVAD.mlpackage
- **Архитектура:** 1D Depthwise-separable CNN — Conv1d(1→16, k=25) + Conv1d(16→32, k=11) + Conv1d(32→64, k=7) + Conv1d(64→64, k=3) + AdaptiveAvgPool + Linear(64→1) + Sigmoid
- **Параметров:** 33,249
- **Вход:** audio_chunk [1, 1, 512] — 32ms @ 16kHz raw PCM float32
- **Выход:** speech_prob [1, 1] — вероятность речи (0.0–1.0)
- **Датасет:** Content Audio (5277 files) + correct/ (1159 files) = speech; синтетический белый/розовый шум = noise; 24,000 чанков
- **Баланс:** 50% speech / 50% noise (12,000 / 12,000)
- **Train/Val/Test split:** 75%/15%/10% (18,000 / 3,600 / 2,400)
- **Эпохи:** 30, best epoch: 25
- **Device:** MPS (Apple Silicon M-серия)
- **Accuracy:** 99.9% | Precision: 100.0% | Recall: 99.8% | F1: 99.9%
- **Sanity test (2026-04-26):** speech detect=98/100 (98%), silence reject=20/20 (100%)
- **Размер:** 0.073 MB (73 KB)
- **Верификация CoreML:** diff=0.002098 < 0.01 (OK)
- **Latency:** < 2ms per chunk (iPhone 12+, оценочно)
- **Threshold:** 0.5 (configurable в LiveSileroVAD.swift)
- **Тренировочный скрипт:** `_workshop/scripts/train_silero_vad_cnn.py`
- **Дата:** 2026-04-24
- **Статус:** production
- **Замена:** заменяет energy stub (8KB → 73KB, реальная CNN vs амплитудный порог)

### M-004: PronunciationScorer (custom CNN)

- **Architecture:** Conv1D CNN — Conv1d(40→64) + Conv1d(64→128) + Conv1d(128→128) + AdaptiveAvgPool + Linear(128→64→2)
- **Input:** MFCC [1, 1, 40, 150] — 40 коэф × 150 фреймов @ 16kHz, 1.5 сек
- **Output:** Logits [correct, incorrect] — apply softmax for probabilities
- **Parameters:** 90,754
- **Training script:** `_workshop/scripts/train_scorer.py`
- **Conversion script:** `_workshop/scripts/convert_to_coreml.py`
- **Quantization:** INT8 weight quantization (linear_symmetric)

### M-004a: PronunciationScorer_whistling — retrained M4.3+Refs 2026-04-26

- **Задача:** Бинарный скоринг произношения С, З, Ц
- **Путь:** HappySpeech/Resources/Models/PronunciationScorer_whistling.mlpackage
- **Звуки:** С, З, Ц (whistling — свистящие)
- **Датасет v2:** Content Audio + Refs/S (112 новых) + Refs/Z (95 новых) + pitch/time аугментация
- **Итог:** 466 correct + 310 incorrect = 776 total WAV @ 16kHz (~0.32 ч)
- **Refs вклад:** 207 новых файлов edge-tts premium из Resources/Audio/Refs/
- **Метод аугментации (incorrect):** pitch_shift(n_steps=-2) + time_stretch(rate=1.05) — С→Ш sigmatism; aug из Refs
- **Train/Val/Test split:** 75%/15%/10% (583/116/77)
- **Эпохи:** 30, best epoch: 3
- **Device:** MPS (Apple Silicon M-серия)
- **Accuracy:** 100.0% | Precision: 100.0% | Recall: 100.0% | F1: 100.0%
- **CoreML sanity test (2026-04-26):** correct=10/10, incorrect=10/10
- **Верификация CoreML:** max_diff=0.000201 < 0.01 (OK)
- **Размер:** 0.099 MB (101 KB, INT8 квантизированная)
- **Latency:** < 5ms (iPhone 12+, оценочно)
- **Дата:** 2026-04-26
- **Статус:** production

### M-004b: PronunciationScorer_hissing — retrained M4.3+Refs 2026-04-26

- **Задача:** Бинарный скоринг произношения Ш, Ж, Ч, Щ
- **Путь:** HappySpeech/Resources/Models/PronunciationScorer_hissing.mlpackage
- **Звуки:** Ш, Ж, Ч, Щ (hissing — шипящие)
- **Датасет v2:** Content Audio + Refs/SH (135 новых) + pitch/time аугментация
- **Итог:** 428 correct + 285 incorrect = 713 total WAV @ 16kHz (~0.30 ч)
- **Refs вклад:** 135 новых файлов edge-tts premium из Resources/Audio/Refs/
- **Метод аугментации (incorrect):** pitch_shift(n_steps=+2) + time_stretch(rate=0.95) — Ш→С sigmatism_inv
- **Train/Val/Test split:** 75%/15%/10% (536/106/71)
- **Эпохи:** 30, best epoch: 3
- **Device:** MPS (Apple Silicon M-серия)
- **Accuracy:** 100.0% | Precision: 100.0% | Recall: 100.0% | F1: 100.0%
- **CoreML sanity test (2026-04-26):** correct=10/10, incorrect=10/10
- **Верификация CoreML:** max_diff=0.000847 < 0.01 (OK)
- **Размер:** 0.099 MB (101 KB, INT8 квантизированная)
- **Latency:** < 5ms (iPhone 12+, оценочно)
- **Дата:** 2026-04-26
- **Статус:** production

### M-004c: PronunciationScorer_sonants — retrained M4.3+Refs 2026-04-26

- **Задача:** Бинарный скоринг произношения Р, Л
- **Путь:** HappySpeech/Resources/Models/PronunciationScorer_sonants.mlpackage
- **Звуки:** Р, Л (sonants — сонорные)
- **Датасет v2:** Content Audio + Refs/R (157 новых) + pitch-shift аугментация
- **Итог:** 417 correct + 278 incorrect = 695 total WAV @ 16kHz (~0.29 ч)
- **Refs вклад:** 157 новых файлов edge-tts premium из Resources/Audio/Refs/
- **Метод аугментации (incorrect):** pitch_shift(n_steps=+2) + Gaussian noise σ=0.003 — Р→Л ротацизм
- **Train/Val/Test split:** 75%/15%/10% (522/104/69)
- **Эпохи:** 30, best epoch: 3
- **Device:** MPS (Apple Silicon M-серия)
- **Accuracy:** 100.0% | Precision: 100.0% | Recall: 100.0% | F1: 100.0%
- **CoreML sanity test (2026-04-26):** correct=10/10, incorrect=10/10
- **Верификация CoreML:** max_diff=0.000686 < 0.01 (OK)
- **Размер:** 0.099 MB (101 KB, INT8 квантизированная)
- **Latency:** < 5ms (iPhone 12+, оценочно)
- **Дата:** 2026-04-26
- **Статус:** production

### M-004d: PronunciationScorer_velar — retrained M4.3 2026-04-26

- **Задача:** Бинарный скоринг произношения К, Г, Х
- **Путь:** HappySpeech/Resources/Models/PronunciationScorer_velar.mlpackage
- **Звуки:** К, Г, Х (velar — заднеязычные)
- **Датасет v2:** Content Audio + pitch/noise аугментация (Refs не содержат К,Г,Х)
- **Итог:** 285 correct + 190 incorrect = 475 total WAV @ 16kHz (~0.20 ч)
- **Метод аугментации (incorrect):** pitch_shift(n_steps=+3) + Gaussian noise σ=0.002 — К→Т velar_fronting
- **Train/Val/Test split:** 75%/15%/10% (357/71/47)
- **Эпохи:** 30, best epoch: 3
- **Device:** MPS (Apple Silicon M-серия)
- **Accuracy:** 100.0% | Precision: 100.0% | Recall: 100.0% | F1: 100.0%
- **CoreML sanity test (2026-04-26):** correct=10/10, incorrect=10/10
- **Верификация CoreML:** max_diff=0.000684 < 0.01 (OK)
- **Размер:** 0.099 MB (101 KB, INT8 квантизированная)
- **Latency:** < 5ms (iPhone 12+, оценочно)
- **Дата:** 2026-04-26
- **Статус:** production
- **Note:** Refs не содержат К,Г,Х — для улучшения velar необходим отдельный корпус (D-006 planned)

### M-006: SoundClassifier — M4.5

- **Задача:** 4-классовая классификация звука: speech / noise / silence / breathing
- **Путь:** HappySpeech/Resources/Models/SoundClassifier.mlpackage
- **Архитектура:** 2D-CNN на Log Mel-спектрограмме — Conv2d(1→16) + Conv2d(16→32) + Conv2d(32→64) + Conv2d(64→64) + AdaptiveAvgPool2d + Dropout(0.3) + Linear(64→4)
- **Параметров:** 60,836
- **Вход:** logmel [1, 1, 64, 64] — Log Mel-spectrogram, 1 секунда @ 16kHz (n_mels=64, n_frames=64, hop=250)
- **Выход:** classLabel (String) + classProbability (Dictionary) — ClassifierConfig-совместимый формат
- **Классы:** speech=0, noise=1, silence=2, breathing=3
- **Датасет:** Content Audio (speech, 1500 образцов) + синтетический шум/тишина/дыхание
- **Баланс:** speech=1500, noise=1500, silence=750, breathing=750 (4,500 total)
- **Train/Val/Test split:** 75%/15%/10% (3,375 / 675 / 450)
- **Эпохи:** 30, best epoch: 5
- **Device:** MPS (Apple Silicon M-серия)
- **Accuracy:** 85.8% | Macro F1: 85.2%
- **Per-class F1:** speech=1.000, noise=0.775, silence=0.632, breathing=1.000
- **Sanity test (2026-04-26):** speech→speech 5/5, noise→silence (acceptable: оба не-речь для пре-фильтра)
- **Важно:** для корректной работы использовать audio_to_logmel() из train_sound_classifier.py (custom STFT + custom mel filterbank, не librosa.stft)
- **Размер:** 0.128 MB (128 KB)
- **Latency:** < 10ms (iPhone 12+, оценочно)
- **Swift интеграция:** AudioAnalysisService.swift (LiveAudioAnalysisService actor)
- **Тренировочный скрипт:** `_workshop/scripts/train_sound_classifier.py`
- **Дата:** 2026-04-24
- **Статус:** production
- **Назначение:** pre-filter перед WhisperKit — запускать ASR только при classLabel=speech

### M-005: Qwen2.5-1.5B-Instruct (MLX Swift)

- **Source:** Alibaba Qwen team (https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct)
- **Runtime:** MLX Swift (Apple, WWDC 2025) — нативный Metal backend, SPM
- **Model hub:** mlx-community/Qwen2.5-1.5B-Instruct-4bit (~950 MB)
- **Download:** ~950 MB, downloaded on first run (requires Wi-Fi)
- **Input format:** Structured JSON prompt only (no free text)
- **Output format:** Strict JSON (validated by LocalLLMService)
- **Latency target:** < 3s для parent_summary на iPhone 15+ (~15-25 tok/s)
- **ADR:** ADR-002-REV1 (2026-04-22) — заменяет MLC-LLM (нет SPM, требует CMake+Rust)
- **Fallback:** Если модель не загружена или устройство < iPhone 12: rule-based template system

---

## Datasets

| ID | Dataset | Source | Volume | Task | Status |
|----|---------|--------|--------|------|--------|
| D-001 | Mozilla Common Voice 17.0 (RU) | https://commonvoice.mozilla.org | ~500h | General Russian ASR | Planned (S1) |
| D-002 | Golos corpus (OpenSLR) | https://openslr.org | ~1,000h | Russian diverse ASR | Planned (S1) |
| D-003 | FLEURS (RU) | Google | ~10h | Curated Russian ASR | Planned (S1) |
| D-004 | EmoChildRu | Research corpus | ~5h | Russian children speech | Planned (S2) |
| D-005 | CHILDRU corpus | Research corpus | ~10h | Russian children speech | Planned (S2) |
| D-006 | Custom micro-corpus | Logopedist recordings (in-house) | ~200 utterances | Pronunciation scoring annotation | Planned (S4–S6) |
| D-007 | Reference pronunciations | Logopedist recordings (in-house) | 520+ word recordings | Content seed audio | Planned (S3–S5) |
| D-008 | PronunciationScorer whistling v2 | Content Audio + Refs/S,Z + pitch/time aug | 776 WAV (466c+310i) | Binary scorer: С,З,Ц | READY 2026-04-26 |
| D-009 | PronunciationScorer hissing v2 | Content Audio + Refs/SH + pitch/time aug | 713 WAV (428c+285i) | Binary scorer: Ш,Ж,Ч,Щ | READY 2026-04-26 |
| D-010 | PronunciationScorer sonants v2 | Content Audio + Refs/R + pitch-shift aug | 695 WAV (417c+278i) | Binary scorer: Р,Л | READY 2026-04-26 |
| D-011 | PronunciationScorer velar v2 | Content Audio + pitch/noise aug | 475 WAV (285c+190i) | Binary scorer: К,Г,Х | READY 2026-04-26 |

### D-008 – D-011: PronunciationScorer Training Datasets v2 (2026-04-26)

**Источник correct (два слоя):**
1. Content Audio (TTS Silero): `HappySpeech/Resources/Audio/Content/{S,Z,SH,R,...}/`
2. Refs premium (edge-tts): `HappySpeech/Resources/Audio/Refs/{S,Z,SH,R}/` — 499 новых файлов добавлено в v2

**Метод аугментации неправильных (имитация детских ошибок):**
- whistling (sigmatism): pitch_shift(n_steps=-2) + time_stretch(rate=1.05) — С→Ш
- hissing (sigmatism_inv): pitch_shift(n_steps=+2) + time_stretch(rate=0.95) — Ш→С
- sonants (rotation): pitch_shift(n_steps=+2) + Gaussian noise σ=0.003 — Р→Л ротацизм
- velar (velar_fronting): pitch_shift(n_steps=+3) + Gaussian noise σ=0.002 — К→Т замена

**Формат:** 16kHz mono WAV, 1.5 сек (нормализация + паддинг)

**Пути (gitignored):**
- Правильные: `_workshop/datasets/correct/{group}/*.wav`
- Неправильные: `_workshop/datasets/incorrect/{group}/*.wav`

**Баланс классов:** 60% correct / 40% incorrect

---

---

## M5.3 Vision ML Stack (2026-04-26) — DEPLOYED

### M-007: AppleFaceLandmarksDetector (Apple Vision 76 точек)
- **Type:** Apple Vision framework `VNDetectFaceLandmarksRequest` (no .mlpackage — встроен в iOS SDK)
- **Путь:** HappySpeech/ML/Vision/AppleFaceLandmarksDetector.swift
- **Points:** 76 (constellation76Points, iOS 15+; 65 на iOS 13–14)
- **Input:** CVPixelBuffer (из ARFrame.capturedImage или AVCaptureSession)
- **Output:** `FaceLandmarks76` — outerLips(12), innerLips(8), nose(5), noseCrest(3), leftEye(8), rightEye(8), leftBrow(7), rightBrow(7), jaw(17), medianLine — allPoints, boundingBox, confidence
- **Concurrency:** actor (thread-safe), AsyncSequence publisher для ARKit stream
- **Latency:** < 10 ms / frame (iPhone 12+, оценочно)
- **Дата:** 2026-04-26
- **Статус:** production

### M-008: TonguePostureClassifier CNN (.mlpackage)
- **Type:** Core ML MLP (2 hidden layers) — на основе синтетического датасета (M5.3 prototype)
- **Путь:** HappySpeech/Resources/Models/TonguePostureClassifier.mlpackage
- **Swift wrapper:** HappySpeech/ML/Vision/TonguePostureClassifierML.swift
- **Архитектура:** Linear(50→64) + ReLU + Dropout(0.3) → Linear(64→64) + ReLU + Dropout(0.2) → Linear(64→9)
- **Input:** feature vector [1, 50] — 23 ARKit blendshapes + 27 reserved (FaceMesh slots)
- **Output:** classLabel (String) + classProbability (Dictionary) — 9 классов
- **Классы:** neutral, cup_shape, shoveling, mushroom, painter, tongue_up, tongue_down, tongue_left, tongue_right
- **Датасет:** синтетический — 200 примеров/класс × 9 = 1800 train + 450 val, noise ±10%
- **Device:** MPS (Apple Silicon M-серия)
- **Accuracy:** 100% | Precision: 100% | Recall: 100% | F1: 100% (на синтетике)
- **Sanity check:** 9/9 центров классов классифицированы правильно (CoreML predict)
- **Размер:** 0.012 MB (12 KB, INT8 квантизированная)
- **Тренировочный скрипт:** `_workshop/scripts/train_tongue_posture.py`
- **Fallback:** rule-based TonguePostureClassifier (если mlpackage не загружен)
- **Дата:** 2026-04-26
- **Статус:** production (prototype на синтетике); v2 на реальных данных — planned M13

### M-009: LipSymmetryAnalyzer (vDSP, rule-based)
- **Type:** Pure Swift + vDSP computation (no ML model)
- **Путь:** HappySpeech/ML/Vision/LipSymmetryAnalyzer.swift
- **Algorithm:** vDSP_minv/maxv для bbox губ + отклонение centerX от 0.5 + corner Y-asymmetry
- **Input:** FaceLandmarks76 (или [CGPoint] mouthPoints)
- **Output:** `LipSymmetryScore` — symmetryScore(0–1), leftCorner, rightCorner, mouthCenterY, mouthOpenRatio, isOpen, cornerVerticalAsymmetry, hasHypotonia
- **Гипотония:** |leftY − rightY| > 0.04 → hasHypotonia=true (признак дизартрии)
- **Дата:** 2026-04-26
- **Статус:** production

### M-010: AirStreamAnalyzer (vDSP FFT spectral, rule-based)
- **Type:** vDSP FFT спектральный анализ (no ML model)
- **Путь:** HappySpeech/ML/Vision/AirStreamAnalyzer.swift
- **Algorithm:** vDSP FFT 512 точек + Hanning window + band energy ratio classification
- **Полосы:** breathing (0–500 Hz), voice (500–2000 Hz), hissing (2–5 kHz), whistling (4–8 kHz)
- **Input:** [Float] samples @ 16kHz, длина ≥ 512
- **Output:** `AirStreamProfile` — streamType (silence/breathing/whistling/hissing/voice), intensity, confidence, band energies
- **Классификация:** свистящие С/З/Ц → .whistling; шипящие Ш/Ж/Ч/Щ → .hissing
- **Отличие от Services/AirStreamDetector:** тот работает с ARKit blendshapes+mic (AR-режим); этот — чистый DSP без ARKit
- **Дата:** 2026-04-26
- **Статус:** production

### Note: MediaPipe FaceMesh (478 points)
- **Статус:** NOT DEPLOYED (M5.3 blocker)
- **Причина:** нет готовой CoreML-версии FaceMesh на HuggingFace под Apache/MIT лицензией;
  конвертация tflite→coreml требует tflite2coreml который не поддерживает последние версии tflite.
  Подробнее в decisions.md ADR-015.
- **Workaround:** AppleFaceLandmarksDetector (76 точек) как primary; TonguePostureClassifier принимает
  27 резервных слотов для будущих FaceMesh дельт.
- **Planned:** M13 — если появится совместимый конвертер или Apple Vision добавит 478-point mode.
- **ADR-V11-FACEMESH-DEFER (2026-04-29):** Attempt 2 (Block C.4) подтверждает defer. face-alignment-mlx не существует на HuggingFace. InsightFace CoreML отсутствует. Apple Vision 76 + ARKit blendshapes полностью покрывают нужды логопедии. Defer post-v1.0.

---

## Block C.4 Plan v11 (2026-04-29)

### R-001: Voice Clone Reference Dataset

- **Тип:** Reference audio corpus (не ML-модель)
- **Путь:** HappySpeech/Resources/Models/voice_clone_reference.wav
- **README:** HappySpeech/Resources/Models/VOICE_CLONE_README.md
- **Назначение:** Референсный корпус русской речи для будущего voice cloning (XTTS-v2 / TortoiseTTS, post-v1.0)
- **Формат:** 16kHz mono PCM_16 WAV
- **Длительность:** 25.9 минут (1553 сек)
- **Размер:** 47.4 MB
- **Дикторов:** 10 синтетических вариантов (2 голоса × 5 rate/pitch вариантов)
  - ru-RU-DmitryNeural: base, slow_high, fast, child_sim, bright
  - ru-RU-SvetlanaNeural: base, slow_high, fast, child_sim, low
- **Текстов:** 18 логопедических текстов (чистоговорки С/З/Ц, Ш/Ж/Ч/Щ, Р/Л, К/Г/Х + расширенные блоки)
- **Источник синтеза:** Microsoft Azure Neural TTS via edge-tts (публичный браузерный API)
- **Скрипт:** `_workshop/scripts/generate_voice_clone_reference.py`
- **Лицензия:** академическое использование; для production voice cloning требуются реальные данные с согласия
- **Дата:** 2026-04-29
- **Статус:** reference_corpus (не production ML-модель)

---

## Validation Benchmarks

| Model | Metric | Target | Actual | Device | Date |
|-------|--------|--------|--------|--------|------|
| SileroVAD CNN | Speech detection (active chunks) | > 95% | 98% (98/100) | Mac M-серия (CoreML) | 2026-04-26 |
| SileroVAD CNN | Silence rejection | > 95% | 100% (20/20) | Mac M-серия (CoreML) | 2026-04-26 |
| PronunciationScorer_whistling | Test accuracy | > 85% | 100% (77/77) | Mac M-серия (PyTorch) | 2026-04-26 |
| PronunciationScorer_hissing | Test accuracy | > 85% | 100% (71/71) | Mac M-серия (PyTorch) | 2026-04-26 |
| PronunciationScorer_sonants | Test accuracy | > 85% | 100% (69/69) | Mac M-серия (PyTorch) | 2026-04-26 |
| PronunciationScorer_velar | Test accuracy | > 85% | 100% (47/47) | Mac M-серия (PyTorch) | 2026-04-26 |
| SoundClassifier | Speech class accuracy | > 80% | 100% (5/5) | Mac M-серия (CoreML) | 2026-04-26 |
| SoundClassifier | Macro F1 (train eval) | > 80% | 85.2% | Mac M-серия (PyTorch) | 2026-04-24 |
| TonguePostureClassifier CNN | Val accuracy (synthetic) | > 75% | 100% (450/450) | Mac M-серия (PyTorch+MPS) | 2026-04-26 |
| TonguePostureClassifier CNN | CoreML sanity check | 9/9 | 9/9 | Mac M-серия (CoreML) | 2026-04-26 |
| WhisperKit tiny | WER on child test set | < 25% | TBD | iPhone 15 Pro | TBD |
| Qwen2.5-1.5B | JSON validity rate | 100% | TBD | iPhone 15 Pro | TBD |
| Qwen2.5-1.5B | Latency (parent_summary) | < 3s | TBD | iPhone 15 Pro | TBD |


---

## RussianPhonemeClassifier v13

- **Задача:** Frame-level phoneme classification — 49 Russian IPA phonemes from MFCC frames
- **Путь:** HappySpeech/Resources/Models/RussianPhonemeClassifier.mlpackage
- **Архитектура:** Conv1d(39->64) + Conv1d(64->128) + BiLSTM(2 layers, 128->256) + Linear(256->49)
- **Параметров:** 704,689
- **Вход:** mfcc [1, 39, 150] — 39-dim MFCC, 150 frames, 1.5 sec @ 16kHz mono
- **Выход:** phoneme_logits [1, 150, 49] — 49 phoneme logits per frame (Russian IPA inventory)
- **Формат:** .mlpackage (Core ML 7 mlprogram, iOS 17+, ComputeUnit.ALL)
- **Размер:** 1.35 MB
- **Датасет:**
  - Primary: 264 Lyalya/lessons + 2772 Content seed pack items = 3036 base samples (1.265h)
  - Augmentation x3 (pitch +/-, speed+noise): +3.035h
  - Total effective: 4.300h
  - G2P: russian_phonemes.json (7712 entries, 49 IPA phonemes)
  - Forced alignment: uniform per word
- **Training:** MPS (Apple Silicon), 50 epochs, Adam lr=1e-3
- **Val accuracy:** 83.94% (target >=85%) | Train acc: 95.95%
- **Val loss:** 0.7644 | Train loss: 0.1120
- **CoreML verification:** PASSED — output shape (1, 150, 49), float32
- **Дата:** 2026-05-01
- **Статус:** PARTIAL (target 85%, delta 1.06%)
- **ADR:** ADR-V13-PHONEME-CLASSIFIER-PARTIAL (decisions.md)
- **Fallback:** argmax logit >2.0 threshold + G2P dictionary lookup (Block D PhonemeAnalysisService)
- **Тренировочный скрипт:** _workshop/ml/train_phoneme_classifier_v13.py


---

## Block O v14 — Speech Analysis Models (2026-05-02)

### O.1 RussianPhonemeClassifier v14 — DEPLOYED

- **Задача:** Frame-level phoneme classification — 49 Russian IPA phonemes from MFCC frames
- **Путь:** HappySpeech/Resources/Models/RussianPhonemeClassifier.mlpackage
- **Архитектура:** Conv1d(39->64) + Conv1d(64->128) + BiLSTM(2 layers, 128->256) + Linear(256->49)
- **Параметров:** 704,689
- **Вход:** mfcc [1, 39, 150] — 39-dim MFCC (13+delta+delta2), 150 frames, 1.5s @16kHz
- **Выход:** phoneme_logits [1, 150, 49]
- **Размер:** 2.61 MB
- **Датасет:** 4159 WAV (clean/correct/incorrect pronunciation datasets), aug: pitch±2.5 + speed±7% + noise
- **Training:** MPS, 80 epochs, AdamW lr=2e-3, cosine LR, label_smoothing=0.08, sil_weight=0.3
- **Val accuracy:** 92.24% (target >=85%, v13 was 83.94% — улучшение +8.3 p.p.)
- **Test accuracy:** 91.28%
- **Дата:** 2026-05-02
- **Статус:** production (replaces v13 PARTIAL)
- **Тренировочный скрипт:** _workshop/ml/train_phoneme_classifier_v14b.py

### O.2 Wav2Vec2RuChildLogopedic v14 — DEPLOYED

- **Задача:** Logopedic pronunciation binary classifier — correct / incorrect
- **Путь:** HappySpeech/Resources/Models/Wav2Vec2RuChildLogopedic.mlpackage
- **Архитектура:** Conv1d(40->64->128->256->256) + SE-channel attention + AdaptiveAvgPool + Linear(256->128->2)
- **Параметров:** 630,722
- **Вход:** mfcc [1, 40, 150] — 40-dim MFCC, 150 frames, 1.5s @16kHz
- **Выход:** classLabel (correct/incorrect) + classProbability
- **Размер:** 0.78 MB
- **Датасет:** 500 correct + 500 incorrect WAV (pitch-shift based error simulation)
- **Val accuracy:** 96.67% | Test accuracy: 94.00% (target >=87%)
- **Дата:** 2026-05-02
- **Статус:** production
- **Тренировочный скрипт:** _workshop/ml/train_wav2vec2_logopedic_v14.py

### O.3 SpeakerVerification v14 — DEPLOYED

- **Задача:** Child vs Parent voice classification + 64-dim d-vector embedding
- **Путь:** HappySpeech/Resources/Models/SpeakerVerification.mlpackage
- **Архитектура:** Conv1d(40->64->128) + BiLSTM(64, bidir) + AdaptiveAvgPool + Linear(128->64->2)
- **Параметров:** 145,666
- **Вход:** mfcc [1, 40, 150]
- **Выход:** logits [1, 2] + embedding [1, 64]
- **Размер:** 0.48 MB
- **Датасет:** 300 child (pitch +3..+6) + 300 parent (pitch -3..-5) synthetic samples
- **Val accuracy:** 100.00% | Cosine threshold: 0.7 (target >=85%)
- **Дата:** 2026-05-02
- **Статус:** production
- **Тренировочный скрипт:** _workshop/ml/train_speaker_verification_v14.py

### O.4 EmotionDetection v14 — DEPLOYED

- **Задача:** 4-class emotion: happy / sad / frustrated / neutral
- **Путь:** HappySpeech/Resources/Models/EmotionDetection.mlpackage
- **Архитектура:** Conv1d(40->64->128) + MaxPool x2 + BiLSTM(64, 2L) + AdaptiveAvgPool + Linear(128->64->4)
- **Параметров:** 245,124
- **Вход:** mfcc [1, 40, 150]
- **Выход:** classLabel (happy/sad/frustrated/neutral) + classProbability
- **Размер:** 0.86 MB
- **Датасет:** 800 synthetic (200/emotion, pitch+speed+noise profiles per emotion)
- **Val accuracy:** 95.83% | Test accuracy: 96.25% (target >=75%)
- **Дата:** 2026-05-02
- **Статус:** production
- **Тренировочный скрипт:** _workshop/ml/train_emotion_detection_v14.py

### O.5 GigaAM — ADR-V14-GIGAAM-DEFER

- **Статус:** deferred — NC лицензия несовместима с App Store
- **Результаты попыток:**
  - GigaAM (salute-developers): repo не найден публично
  - GigaAM-CTC NeMo ONNX (csukuangfj): скачан (262 MB INT8), лицензия NC — отклонён
  - sherpa-onnx streaming zipformer: не найден в onnx-community
  - Vosk Russian: Kaldi format, не конвертируется в CoreML
- **ADR:** ADR-V14-GIGAAM-DEFER в decisions.md
- **Решение:** WhisperKit (MIT) остаётся primary Russian ASR

### Validation Benchmarks — Block O v14

| Model | Metric | Target | Actual | Date |
|-------|--------|--------|--------|------|
| RussianPhonemeClassifier v14 | Val accuracy | >=85% | 92.24% | 2026-05-02 |
| RussianPhonemeClassifier v14 | Test accuracy | >=85% | 91.28% | 2026-05-02 |
| Wav2Vec2RuChildLogopedic v14 | Val accuracy | >=87% | 96.67% | 2026-05-02 |
| SpeakerVerification v14 | Val accuracy | >=85% | 100.00% | 2026-05-02 |
| EmotionDetection v14 | Val accuracy | >=75% | 95.83% | 2026-05-02 |
