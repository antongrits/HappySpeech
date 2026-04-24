# ML Models Registry — HappySpeech
## Version 2.3 — 2026-04-24
## Managed by ML Trainer. Updated when model is converted and validated.

---

## Active Models

| ID | Model Name | Task | License | Size (on-device) | Path | Status | Fallback |
|----|-----------|------|---------|-----------------|------|--------|---------|
| M-001 | WhisperKit large-v3-turbo | Russian ASR — primary | MIT | ~600 MB | via WhisperKit SPM (download on first run) | Planned (S5) | WhisperKit tiny |
| M-002 | WhisperKit tiny (Russian) | Russian ASR — fallback | MIT | ~150 MB | via WhisperKit SPM | Planned (S5) | AVSpeechRecognizer (online) |
| M-003 | SileroVAD CNN | Voice Activity Detection | Proprietary | 0.073 MB | Resources/Models/SileroVAD.mlpackage | DEPLOYED (M4.4 real CNN) | AmplitudeVAD (Swift actor) |
| M-004a | PronunciationScorer_whistling | Binary scoring: С,З,Ц | Proprietary | 0.10 MB | Resources/Models/PronunciationScorer_whistling.mlpackage | DEPLOYED (retrained M4.3) | MockPronunciationScorer |
| M-004b | PronunciationScorer_hissing | Binary scoring: Ш,Ж,Ч,Щ | Proprietary | 0.10 MB | Resources/Models/PronunciationScorer_hissing.mlpackage | DEPLOYED (retrained M4.3) | MockPronunciationScorer |
| M-004c | PronunciationScorer_sonants | Binary scoring: Р,Л | Proprietary | 0.10 MB | Resources/Models/PronunciationScorer_sonants.mlpackage | DEPLOYED (retrained M4.3) | MockPronunciationScorer |
| M-004d | PronunciationScorer_velar | Binary scoring: К,Г,Х | Proprietary | 0.10 MB | Resources/Models/PronunciationScorer_velar.mlpackage | DEPLOYED (retrained M4.3) | MockPronunciationScorer |
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

### M-004a: PronunciationScorer_whistling — retrained M4.3

- **Задача:** Бинарный скоринг произношения С, З, Ц
- **Путь:** HappySpeech/Resources/Models/PronunciationScorer_whistling.mlpackage
- **Звуки:** С, З, Ц (whistling — свистящие)
- **Датасет:** TTS-синтезированные (Silero TTS) + pitch/time аугментация; 259 correct + 180 incorrect = 439 WAV @ 16kHz
- **Датасет источник:** `~/Downloads/HappySpeech/_workshop/datasets/correct/whistling/` + `incorrect/whistling/`
- **Валидация M4.2:** 100% валидных (удалено 41 слишком тихих / clipping из correct, 20 из incorrect)
- **Train/Val/Test split:** 75%/15%/10% (331/65/43)
- **Эпохи:** 30, best epoch: 2
- **Device:** MPS (Apple Silicon M-серия)
- **Accuracy:** 100.0% | Precision: 100.0% | Recall: 100.0% | F1: 100.0%
- **Размер:** 0.10 MB (INT8 квантизированная, было 0.18 MB)
- **Latency:** < 5ms (iPhone 12+, оценочно)
- **Дата:** 2026-04-24
- **Статус:** production

### M-004b: PronunciationScorer_hissing — retrained M4.3

- **Задача:** Бинарный скоринг произношения Ш, Ж, Ч, Щ
- **Путь:** HappySpeech/Resources/Models/PronunciationScorer_hissing.mlpackage
- **Звуки:** Ш, Ж, Ч, Щ (hissing — шипящие)
- **Датасет:** TTS-синтезированные (Silero TTS) + pitch/time аугментация; 300 correct + 200 incorrect = 500 WAV @ 16kHz
- **Датасет источник:** `~/Downloads/HappySpeech/_workshop/datasets/correct/hissing/` + `incorrect/hissing/`
- **Метод аугментации (incorrect):** `pitch_shift(n_steps=+2)` + `time_stretch(rate=0.95)` — Ш→С-подобное искажение (sigmatism_inv)
- **Train/Val/Test split:** 75%/15%/10% (375/75/50)
- **Эпохи:** 30, best epoch: 2
- **Device:** MPS (Apple Silicon M-серия)
- **Accuracy:** 100.0% | Precision: 100.0% | Recall: 100.0% | F1: 100.0%
- **Размер:** 0.10 MB (INT8 квантизированная, было 0.18 MB)
- **Верификация CoreML:** max_diff=0.000142 < 0.01 (OK)
- **Latency:** < 5ms (iPhone 12+, оценочно)
- **Дата:** 2026-04-24
- **Статус:** production

### M-004c: PronunciationScorer_sonants — retrained M4.3

- **Задача:** Бинарный скоринг произношения Р, Л
- **Путь:** HappySpeech/Resources/Models/PronunciationScorer_sonants.mlpackage
- **Звуки:** Р, Л (sonants — сонорные)
- **Датасет:** TTS-синтезированные (Silero TTS) + pitch-shift аугментация; 300 correct + 200 incorrect = 500 WAV @ 16kHz
- **Датасет источник:** `~/Downloads/HappySpeech/_workshop/datasets/correct/sonants/` + `incorrect/sonants/`
- **Метод аугментации (incorrect):** `pitch_shift(n_steps=+2)` + Gaussian noise σ=0.003 — Р→Л ротацизм
- **Train/Val/Test split:** 75%/15%/10% (375/75/50)
- **Эпохи:** 30, best epoch: 2
- **Device:** MPS (Apple Silicon M-серия)
- **Accuracy:** 100.0% | Precision: 100.0% | Recall: 100.0% | F1: 100.0%
- **Размер:** 0.10 MB (INT8 квантизированная, было 0.18 MB)
- **Верификация CoreML:** max_diff=0.000447 < 0.01 (OK)
- **Latency:** < 5ms (iPhone 12+, оценочно)
- **Дата:** 2026-04-24
- **Статус:** production

### M-004d: PronunciationScorer_velar — retrained M4.3

- **Задача:** Бинарный скоринг произношения К, Г, Х
- **Путь:** HappySpeech/Resources/Models/PronunciationScorer_velar.mlpackage
- **Звуки:** К, Г, Х (velar — заднеязычные)
- **Датасет:** TTS-синтезированные (Silero TTS) + pitch/noise аугментация; 300 correct + 200 incorrect = 500 WAV @ 16kHz
- **Датасет источник:** `~/Downloads/HappySpeech/_workshop/datasets/correct/velar/` + `incorrect/velar/`
- **Метод аугментации (incorrect):** `pitch_shift(n_steps=+3)` + Gaussian noise σ=0.002 — К→Т переднеязычная замена (velar_fronting)
- **Train/Val/Test split:** 75%/15%/10% (375/75/50)
- **Эпохи:** 30, best epoch: 3
- **Device:** MPS (Apple Silicon M-серия)
- **Accuracy:** 100.0% | Precision: 100.0% | Recall: 100.0% | F1: 100.0%
- **Размер:** 0.10 MB (INT8 квантизированная, было 0.18 MB)
- **Верификация CoreML:** max_diff=0.000689 < 0.01 (OK)
- **Latency:** < 5ms (iPhone 12+, оценочно)
- **Дата:** 2026-04-24
- **Статус:** production

### M-006: SoundClassifier — M4.5

- **Задача:** 4-классовая классификация звука: speech / noise / silence / breathing
- **Путь:** HappySpeech/Resources/Models/SoundClassifier.mlpackage
- **Архитектура:** 2D-CNN на Log Mel-спектрограмме — Conv2d(1→16) + Conv2d(16→32) + Conv2d(32→64) + Conv2d(64→64) + AdaptiveAvgPool2d + Dropout(0.3) + Linear(64→4)
- **Параметров:** 60,836
- **Вход:** logmel [1, 1, 64, 64] — Log Mel-spectrogram, 1 секунда @ 16kHz (n_mels=64, n_frames=64)
- **Выход:** classLabel (String) + classProbability (Dictionary) — CreateML-совместимый формат
- **Классы:** speech=0, noise=1, silence=2, breathing=3
- **Датасет:** Content Audio (speech, 1500 образцов) + синтетический шум/тишина/дыхание
- **Баланс:** speech=1500, noise=1500, silence=750, breathing=750 (4,500 total)
- **Train/Val/Test split:** 75%/15%/10% (3,375 / 675 / 450)
- **Эпохи:** 30, best epoch: 5
- **Device:** MPS (Apple Silicon M-серия)
- **Accuracy:** 85.8% | Macro F1: 85.2%
- **Per-class F1:** speech=1.000, noise=0.775, silence=0.632, breathing=1.000
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
| D-008 | PronunciationScorer whistling | Content Audio (S,Z,C) + pitch/time augmentation | 500 WAV (300 correct + 200 aug) | Binary scorer training: С,З,Ц | READY 2026-04-24 |
| D-009 | PronunciationScorer hissing | Content Audio (SH,ZH,CH,SHCH) + pitch/time augmentation | 500 WAV (300 correct + 200 aug) | Binary scorer training: Ш,Ж,Ч,Щ | READY 2026-04-24 |
| D-010 | PronunciationScorer sonants | Content Audio (R,L,RL) + pitch-shift augmentation | 500 WAV (300 correct + 200 aug) | Binary scorer training: Р,Л | READY 2026-04-24 |
| D-011 | PronunciationScorer velar | Content Audio (K,G,KH) + pitch/noise augmentation | 500 WAV (300 correct + 200 aug) | Binary scorer training: К,Г,Х | READY 2026-04-24 |

### D-008 – D-011: PronunciationScorer Training Datasets (2026-04-24)

**Источник правильных:** `HappySpeech/Resources/Audio/Content/{S,Z,C,SH,ZH,CH,SHCH,R,L,RL,K,G,KH}/` — TTS-синтезированные слова (Silero TTS), лицензия MIT-совместимая.

**Метод аугментации неправильных (имитация детских ошибок):**
- whistling (sigmatism): `librosa.effects.pitch_shift(n_steps=-2)` + `time_stretch(rate=1.05)` — С→Ш-подобное искажение
- hissing (sigmatism_inv): `pitch_shift(n_steps=+2)` + `time_stretch(rate=0.95)` — Ш→С-подобное
- sonants (rotation): `pitch_shift(n_steps=+2)` + Gaussian noise σ=0.003 — Р→Л ротацизм
- velar (velar_fronting): `pitch_shift(n_steps=+3)` + Gaussian noise σ=0.002 — К→Т переднеязычная замена

**Формат:** 16kHz mono WAV, длина 1.2–2.6 сек (нативная из контентного аудио)

**Пути (не в репо, в .gitignore):**
- Правильные: `~/Downloads/HappySpeech/_workshop/datasets/correct/{group}/*.wav`
- Неправильные: `~/Downloads/HappySpeech/_workshop/datasets/incorrect/{group}/*.wav`
- Манифесты: `~/Downloads/HappySpeech/_workshop/datasets/{group}_manifest.csv`

**Скрипт подготовки:** `~/Downloads/HappySpeech/_workshop/scripts/prepare_datasets.py`

**Баланс классов:** 60% correct / 40% incorrect (300/200) — намеренная асимметрия в пользу правильных для снижения ложноположительных ошибок при оценке детской речи.

---

## Validation Benchmarks (to be filled after S10)

| Model | Metric | Target | Actual | Device | Date |
|-------|--------|--------|--------|--------|------|
| GigaAM-v3 | WER on child test set | < 15% | TBD | iPhone 15 Pro | TBD |
| WhisperKit tiny | WER on child test set | < 25% | TBD | iPhone 15 Pro | TBD |
| Silero VAD | Detection accuracy | > 95% | TBD | iPhone 12 | TBD |
| PronunciationScorer | Agreement with logopedist | > 80% | TBD | iPhone 12 | TBD |
| Qwen2.5-1.5B | JSON validity rate | 100% | TBD | iPhone 15 Pro | TBD |
| Qwen2.5-1.5B | Latency (parent_summary) | < 3s | TBD | iPhone 15 Pro | TBD |
