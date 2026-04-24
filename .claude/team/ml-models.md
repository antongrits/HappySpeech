# ML Models Registry — HappySpeech
## Version 2.0 — 2026-04-22
## Managed by ML Trainer. Updated when model is converted and validated.

---

## Active Models

| ID | Model Name | Task | License | Size (on-device) | Path | Status | Fallback |
|----|-----------|------|---------|-----------------|------|--------|---------|
| M-001 | WhisperKit large-v3-turbo | Russian ASR — primary | MIT | ~600 MB | via WhisperKit SPM (download on first run) | Planned (S5) | WhisperKit tiny |
| M-002 | WhisperKit tiny (Russian) | Russian ASR — fallback | MIT | ~150 MB | via WhisperKit SPM | Planned (S5) | AVSpeechRecognizer (online) |
| M-003 | Silero VAD (energy stub) | Voice Activity Detection | MIT | 0.008 MB | Resources/Models/SileroVAD.mlpackage | DEPLOYED (stub) | AmplitudeVAD (Swift actor) |
| M-004a | PronunciationScorer_whistling | Binary scoring: С,З,Ц | Proprietary | 0.18 MB | Resources/Models/PronunciationScorer_whistling.mlpackage | DEPLOYED | MockPronunciationScorer |
| M-004b | PronunciationScorer_hissing | Binary scoring: Ш,Ж,Ч,Щ | Proprietary | 0.18 MB | Resources/Models/PronunciationScorer_hissing.mlpackage | DEPLOYED | MockPronunciationScorer |
| M-004c | PronunciationScorer_sonants | Binary scoring: Р,Л | Proprietary | 0.18 MB | Resources/Models/PronunciationScorer_sonants.mlpackage | DEPLOYED | MockPronunciationScorer |
| M-004d | PronunciationScorer_velar | Binary scoring: К,Г,Х | Proprietary | 0.18 MB | Resources/Models/PronunciationScorer_velar.mlpackage | DEPLOYED | MockPronunciationScorer |
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

### M-003: Silero VAD

- **Source:** Silero AI (https://github.com/snakers4/silero-vad)
- **Integration:** Core ML .mlpackage (converted from ONNX)
- **Input:** 16kHz mono PCM audio chunks (512 samples)
- **Output:** Speech probability 0.0–1.0 per chunk
- **Threshold:** 0.5 (configurable in AudioService)
- **Latency:** < 5ms per chunk
- **Conversion script:** `_workshop/scripts/convert_silero_coreml.py` (pending)

### M-004: PronunciationScorer (custom CNN)

- **Architecture:** Lightweight CNN (MobileNetV3-inspired), input: mel spectrogram 80×100
- **Output:** Binary correct/incorrect + confidence 0.0–1.0 per phoneme attempt
- **Training data:** Logopedist-annotated micro-corpus (target: 200+ annotated utterances per sound group)
- **Target accuracy:** > 80% agreement with logopedist manual scoring
- **Training script:** `_workshop/scripts/06_train_scorer.py`
- **Conversion script:** `_workshop/scripts/07_convert_coreml.py`
- **Status note:** This model requires a custom micro-corpus. Logopedist annotation is the critical path. Start S4–S6.

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
