# ML Models Research (2026-04-23)

**Автор:** research agent (M4.9)
**Критерий выбора:** только Apache 2.0 / MIT / BSD. CC-NC и коммерческие — отклонены.

---

## 1. Russian TTS (M3.4 content audio — 6000+ слов)

### Кандидат A: utrobinmv VITS High — РЕКОМЕНДОВАН
- **HF URL:** https://huggingface.co/utrobinmv/tts_ru_free_hf_vits_high_multispeaker
- **License:** Apache 2.0 — подходит для App Store
- **Architecture:** VITS (Variational Inference TTS, end-to-end)
- **Size:** ~40MB (39.9M параметров, Safetensors)
- **Voices:** 2 (женский / мужской)
- **Language:** ru_RU, plain text without phoneme preprocessing
- **Dependency:** ruaccent для расстановки ударений (нужно в batch pipeline)
- **Inference:** CPU-capable, ONNX export возможен
- **Pros:** MIT-совместимая лицензия, малый размер, HuggingFace Transformers API
- **Cons:** Только 2 голоса, нет детского голоса для Ляли; нужно решить ruaccent на batch-этапе
- **Use for:** M3.4 batch-генерация 6000+ аудио на машине разработчика (Python → WAV → afconvert → M4A)
- **Integration:** Python batch script на _workshop/, результат — .m4a в Resources/Audio/Content/

### Кандидат B: utrobinmv VITS Low (Fallback)
- **HF URL:** https://huggingface.co/utrobinmv/tts_ru_free_hf_vits_low_multispeaker
- **License:** Apache 2.0
- **Size:** ~15MB (15.1M параметров)
- **Voices:** 2 (женский / мужской)
- **Use for:** Резервная batch-генерация если High качество неприемлемо

### ОТКЛОНЕНЫ:
- **Silero TTS v4_ru** (picphoto/silero-models_v4_ru) — лицензия CC-BY-NC-SA-4.0, НЕЛЬЗЯ в App Store
- **F5-TTS_RUSSIAN** (Misha24-10) — CC-BY-NC-4.0, НЕЛЬЗЯ
- **Facebook MMS TTS** (facebook/mms-tts-rus) — CC-BY-NC 4.0, НЕЛЬЗЯ
- **XTTS-v2** (coqui/XTTS-v2) — Coqui Public Model License, коммерческие ограничения
- **edge-tts** — онлайн-сервис Microsoft (требует интернет), не offline; уже использован для Ляли (M3.3)
- **Kokoro-82M** (hexgrad/Kokoro-82M) — Apache 2.0, но русский язык не подтверждён в VOICES.md

---

## 2. MediaPipe Face Mesh (M5.3 Vision ML — артикуляция)

### РЕКОМЕНДОВАН: gouthamvgk/facemesh_coreml_tf
- **GitHub:** https://github.com/gouthamvgk/facemesh_coreml_tf
- **License:** Apache 2.0
- **Source model:** Google MediaPipe Face Mesh TFLite (оригинал Apache 2.0)
- **Output:** 468 3D facial landmarks (192×192×3 input)
- **Conversion path:** TFLite → TensorFlow PB → CoreML mlmodel через coremltools
- **Caveat:** Содержит кастомный op `Convolution2DTransposeBias` — нужна регистрация через coremltools custom ops
- **Alternative для iOS:** ARKit `ARFaceAnchor.blendShapes` (нативно, без ML-модели) — уже запланирован для TonguePostureClassifier
- **Size:** ~3MB (face_mesh_frontal.tflite = 2.6MB исходник)
- **Use for:** M5.3 — face mesh overlay для артикуляционной гимнастики; fallback при отсутствии TrueDepth камеры

### Стратегия для HappySpeech:
ARKit `ARFaceAnchor.blendShapes` (первичный путь, iPhone X+) + MediaPipe CoreML (fallback для iPad без TrueDepth). Конверсия через `_workshop/scripts/convert_facemesh_coreml.py`.

---

## 3. Silero VAD (M4.4)

### РЕКОМЕНДОВАН: FluidInference/silero-vad-coreml
- **HF URL:** https://huggingface.co/FluidInference/silero-vad-coreml
- **License:** MIT (оригинал snakers4/silero-vad MIT + wrapper MIT)
- **Source:** Silero VAD v6.0.0 (snakers4/silero-vad, MIT)
- **Format:** Готовые `.mlpackage` файлы для iOS/macOS — НЕ требует конверсии
- **Size:** ~2–3MB (ONNX оригинал 2.33MB, CoreML сопоставимо)
- **Variants:** standard + 256ms variant (8 × 32ms chunks для батч-обработки)
- **Performance:** <5ms per chunk на iPhone 12+, 31,857 downloads/month
- **Swift SDK:** FluidAudio (https://github.com/FluidInference/FluidAudio), iOS 17.0+
- **Pros:** Готовый CoreML, активно поддерживается (July 2025), совместим с iOS 17 target проекта
- **Cons:** Зависимость от FluidInference SDK или ручное подключение .mlpackage
- **Use for:** M4.4 — замена заглушки SileroVAD.mlpackage (8K) на реальную модель

### Альтернатива (если FluidInference не нужен как dep):
Конвертировать самостоятельно: `snakers4/silero-vad` (MIT) → ONNX → CoreML через `_workshop/scripts/convert_silero_coreml.py`.

---

## 4. Qwen2.5 LLM (M4.7 on-device LLM)

### РЕКОМЕНДОВАН: mlx-community/Qwen2.5-1.5B-Instruct-4bit
- **HF URL:** https://huggingface.co/mlx-community/Qwen2.5-1.5B-Instruct-4bit
- **License:** Apache 2.0 (Qwen2.5 базовая лицензия Apache 2.0)
- **Size:** 869MB (4-bit quantized MLX format)
- **Converted from:** Qwen/Qwen2.5-1.5B-Instruct via mlx-lm 0.18.1
- **Runtime:** MLX Swift (Apple WWDC 2025 официальный фреймворк)
- **Downloads:** 10,955 в месяц
- **Performance:** ~15–25 tok/s на iPhone 15 Pro (Metal GPU), <2s для structured JSON response
- **Swift integration:** MLX Swift SPM, нативный Metal backend
- **Input/Output:** JSON-only промпты и ответы (валидируется LocalLLMService)
- **Pros:** Официально поддержан Apple на WWDC 2025, активная mlx-community
- **Cons:** 869MB — крупная часть 1.5GB budget; только iPhone 12+ с Metal

### Opt-in кандидат: mlx-community/Qwen2.5-0.5B-Instruct-4bit
- **HF URL:** https://huggingface.co/mlx-community/Qwen2.5-0.5B-Instruct-4bit
- **Size:** ~250MB
- **Use for:** Устройства <iPhone 13 или при нехватке памяти — fallback LLM

### Download path:
```bash
huggingface-cli download mlx-community/Qwen2.5-1.5B-Instruct-4bit \
  --local-dir _workshop/models/qwen2.5-1.5b-4bit/
```

---

## 5. WhisperKit Russian ASR (M4.6)

### РЕКОМЕНДОВАН: argmaxinc/whisperkit-coreml — openai_whisper-large-v3-v20240930_turbo_632MB
- **HF URL:** https://huggingface.co/argmaxinc/whisperkit-coreml
- **License:** MIT (WhisperKit MIT + OpenAI Whisper MIT)
- **Variant выбран:** `openai_whisper-large-v3-v20240930_turbo_632MB` — оптимальный баланс
- **Size:** 632MB (4-bit compressed CoreML)
- **Russian WER:** ~7–9% на Common Voice (large-v3-turbo, multilingual, 99 languages)
- **Fine-tuned Russian вариант:** dvislobokov/whisper-large-v3-turbo-russian (обучен на 118K Common Voice 17 сэмплах) — для рассмотрения как улучшение
- **Latency:** ~0.46s median на Apple Silicon (WhisperKit ICML 2025 paper)
- **Integration:** SPM `argmaxinc/WhisperKit`, модель скачивается при первом запуске
- **Downloads:** 7,567,974 в месяц — production-grade

### Fallback вариант: openai_whisper-small_216MB
- **Size:** 216MB
- **WER:** ~15-20% на русском — приемлемо как fallback
- **Use for:** Устройства с ограниченной памятью / быстрый старт

### Дополнительный вариант: openai_whisper-tiny (~75MB)
- **WER:** ~25% на русском — только для очень старых устройств

---

## 6. PronunciationScorer References (M4.3)

### Нет готовой open-source модели для русского детского произношения — нужна кастомная.

### Reference базы для fine-tuning:

#### A: jonatasgrosman/wav2vec2-large-xlsr-53-russian
- **HF URL:** https://huggingface.co/jonatasgrosman/wav2vec2-large-xlsr-53-russian
- **License:** Apache 2.0
- **Architecture:** facebook/wav2vec2-large-xlsr-53 fine-tuned на Common Voice 6.1 + CSS10 Russian
- **Task:** ASR (CTC), WER 13.3% на Common Voice test
- **Size:** ~1.2GB (large XLSR model) — слишком велик для on-device
- **Use for:** Feature extractor для fine-tuning PronunciationScorer; НЕ деплоить как есть
- **Strategy:** Distill/prune encoder → CoreML MobileNet-inspired CNN (как описано в ml-models.md M-004)

#### B: Wav2Vec2Phoneme (facebook/wav2vec2-lv-60-espeak-cv-ft)
- **HF URL:** https://huggingface.co/docs/transformers/en/model_doc/wav2vec2_phoneme
- **License:** Apache 2.0 (базовая Facebook XLSR)
- **Architecture:** CTC с IPA-фонемным словарём
- **Use for:** Phoneme-level alignment для аннотации датасета D-006 (custom micro-corpus)

#### C: Стратегия для HappySpeech (без готовой модели):
1. Скачать Common Voice 17 Russian (D-001, CC0)
2. Прогнать через wav2vec2-xlsr-53-russian для phoneme alignment (offline)
3. Создать аннотированный micro-corpus ~200 utterances per sound group (D-006)
4. Обучить lightweight CNN (MobileNetV3-inspired, 80×100 mel-spec input) через CreateML / coremltools
5. Целевой размер: <5MB per scorer, latency <100ms

---

## Summary — Рекомендуемый стек

| # | Модель | HF URL | License | Size | Use-case |
|---|--------|--------|---------|------|----------|
| 1 | utrobinmv VITS High | huggingface.co/utrobinmv/tts_ru_free_hf_vits_high_multispeaker | Apache 2.0 | ~40MB | M3.4 batch TTS |
| 2 | MediaPipe FaceMesh CoreML | github.com/gouthamvgk/facemesh_coreml_tf | Apache 2.0 | ~3MB | M5.3 articulation |
| 3 | FluidInference Silero VAD CoreML | huggingface.co/FluidInference/silero-vad-coreml | MIT | ~3MB | M4.4 VAD |
| 4 | Qwen2.5-1.5B-Instruct-4bit (MLX) | huggingface.co/mlx-community/Qwen2.5-1.5B-Instruct-4bit | Apache 2.0 | 869MB | M4.7 LLM decisions |
| 5 | WhisperKit large-v3-v20240930_turbo | huggingface.co/argmaxinc/whisperkit-coreml | MIT | 632MB | M4.6 Russian ASR |
| 6 | wav2vec2-large-xlsr-53-russian | huggingface.co/jonatasgrosman/wav2vec2-large-xlsr-53-russian | Apache 2.0 | ~1.2GB (workshop only) | M4.3 scorer pre-training |

**Суммарный on-device budget:**
- WhisperKit (turbo 632MB) + Qwen (869MB) + VAD (3MB) + FaceMesh (3MB) + PronunciationScorers (4×0.18MB = ~0.7MB) = **~1.5GB** — точно на границе бюджета
- **Решение:** Qwen и WhisperKit large загружаются on demand (не входят в IPA install size), малые модели (VAD, FaceMesh, Scorers) бандлятся в Resources/

---

## Common Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Silero TTS NC лицензия | HIGH | Заменён на utrobinmv Apache 2.0 (batch only, не on-device) |
| Qwen 869MB on-device | MEDIUM | Download on first run; fallback 0.5B 250MB |
| WhisperKit 632MB on-device | MEDIUM | Download on first run; fallback tiny 75MB |
| MediaPipe custom CoreML op | MEDIUM | Использовать ARKit blendshapes как primary; FaceMesh только fallback |
| Нет готового PronunciationScorer RU | HIGH | DIY pipeline через wav2vec2 alignment + custom CNN (M4.3) |
| ruaccent dependency для utrobinmv TTS | LOW | Только в batch pipeline (_workshop Python), не в iOS app |
| FluidInference SDK dependency | LOW | Можно подключить только .mlpackage без полного SDK |
| dvislobokov turbo-russian не gated | LOW | Проверить при скачивании — возможно требует HF token |

---

## Integration checklist для ml-engineer

### Скачивание (bash script: `_workshop/scripts/download_models.sh`)
- [ ] `huggingface-cli download utrobinmv/tts_ru_free_hf_vits_high_multispeaker --local-dir _workshop/models/vits-ru-high/`
- [ ] `huggingface-cli download FluidInference/silero-vad-coreml --local-dir _workshop/models/silero-vad-coreml/`
- [ ] `huggingface-cli download mlx-community/Qwen2.5-1.5B-Instruct-4bit --local-dir _workshop/models/qwen2.5-1.5b-4bit/`
- [ ] `huggingface-cli download jonatasgrosman/wav2vec2-large-xlsr-53-russian --local-dir _workshop/models/wav2vec2-ru/ --ignore-patterns "*.bin"` (safetensors only)
- [ ] Скопировать silero_vad.mlpackage из FluidInference в `HappySpeech/Resources/Models/SileroVAD.mlpackage` (заменить stub 8K)

### Конверсия CoreML
- [ ] MediaPipe FaceMesh: запустить `convert_facemesh.py` из gouthamvgk/facemesh_coreml_tf → `FaceMesh.mlpackage` → `Resources/Models/`
- [ ] Silero VAD: уже готов CoreML от FluidInference — только скопировать
- [ ] Qwen2.5: уже MLX-формат, используется через MLX Swift SPM напрямую
- [ ] WhisperKit: CoreML уже готов на HF argmaxinc/whisperkit-coreml, загружается через SPM

### TTS batch pipeline (не on-device)
- [ ] Установить: `pip install transformers torch ruaccent soundfile`
- [ ] Скрипт: `_workshop/scripts/generate_content_audio.py` — читает content items из Realm/JSON, генерирует WAV через utrobinmv VITS High, конвертирует в M4A через `afconvert`
- [ ] Валидация: прослушать 10 sample files, проверить качество произношения С, Ш, Р, Л

### Validation
- [ ] Silero VAD: тест на 10 аудио-файлах (5 с речью, 5 тишина), accuracy >95%
- [ ] WhisperKit: транскрибировать 5 детских тестовых фраз, WER <15%
- [ ] Qwen2.5: JSON validity test — 20 structured prompts, 100% valid JSON output
- [ ] VITS TTS: MOS-прослушивание 10 sample sentences с логопедом

### Регистрация в ml-models.md
- [ ] Обновить M-003 (SileroVAD): status DEPLOYED (real), size ~3MB, source FluidInference
- [ ] Добавить M-006: FaceMesh CoreML, source gouthamvgk, Apache 2.0, ~3MB
- [ ] Проверить M-005 (Qwen): размер 869MB (не 950MB как было указано)
- [ ] Проверить M-001 (WhisperKit): уточнить variant → large-v3-v20240930_turbo_632MB

---

## Источники

- [utrobinmv/tts_ru_free_hf_vits_high_multispeaker](https://huggingface.co/utrobinmv/tts_ru_free_hf_vits_high_multispeaker)
- [utrobinmv/tts_ru_free_hf_vits_low_multispeaker](https://huggingface.co/utrobinmv/tts_ru_free_hf_vits_low_multispeaker)
- [FluidInference/silero-vad-coreml](https://huggingface.co/FluidInference/silero-vad-coreml)
- [mlx-community/Qwen2.5-1.5B-Instruct-4bit](https://huggingface.co/mlx-community/Qwen2.5-1.5B-Instruct-4bit)
- [argmaxinc/whisperkit-coreml](https://huggingface.co/argmaxinc/whisperkit-coreml)
- [jonatasgrosman/wav2vec2-large-xlsr-53-russian](https://huggingface.co/jonatasgrosman/wav2vec2-large-xlsr-53-russian)
- [gouthamvgk/facemesh_coreml_tf (GitHub)](https://github.com/gouthamvgk/facemesh_coreml_tf)
- [snakers4/silero-vad (MIT)](https://github.com/snakers4/silero-vad)
- [snakers4/silero-models Licensing Wiki](https://github.com/snakers4/silero-models/wiki/Licensing-and-Tiers)
- [openai/whisper-large-v3-turbo](https://huggingface.co/openai/whisper-large-v3-turbo)
- [dvislobokov/whisper-large-v3-turbo-russian](https://huggingface.co/dvislobokov/whisper-large-v3-turbo-russian)
- [mlx-community HuggingFace org](https://huggingface.co/mlx-community)
- [coqui/XTTS-v2 (отклонён, CPML)](https://huggingface.co/coqui/XTTS-v2)
- [picphoto/silero-models_v4_ru (отклонён, CC-NC)](https://huggingface.co/picphoto/silero-models_v4_ru)
- [WhisperKit paper ICML 2025](https://arxiv.org/abs/2507.10860)
