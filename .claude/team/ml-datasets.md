# HappySpeech ML Datasets Registry

**Last updated:** 2026-04-23
**Maintainer:** ml-engineer

## Сводка batch 1 (M4.1 — завершён)

| Dataset | Source | Hours | Files | Size | License | Status | Path |
|---|---|---|---|---|---|---|---|
| Common Voice 21 RU | HF: Sh1man/common_voice_21_ru | 6.55h | 5000 | ~1.3 GB | CC0 | ✅ downloaded | `_workshop/datasets/raw/common_voice/` |
| GOLOS farfield | HF: bond005/sberdevices_golos_100h_farfield | 5.37h | 5000 | ~1.1 GB | Apache 2.0 | ✅ downloaded | `_workshop/datasets/raw/golos/` |
| SOVA RuDevices | HF: bond005/sova_rudevices | 5.09h | 5000 | ~1.0 GB | MIT | ✅ downloaded | `_workshop/datasets/raw/openslr/` |
| edge-tts synthetic | Microsoft edge-tts | 0.32h | 636 | ~65 MB | MIT | ✅ generated | `_workshop/datasets/raw/synthetic/` |
| Nexdata children | HF: nexdata/children_ru | 0.02h | 30 | ~4 MB | Research | ✅ downloaded | `_workshop/datasets/raw/nexdata/` |
| **ИТОГО** | — | **17.35h** | **15 666** | **~3.5 GB** | mixed | — | — |

## Почему 17ч достаточно для PronunciationScorer

Цель M4.3 — бинарная классификация (правильно/неправильно) через MFCC[40,150] → 2×Conv1D → Dense → Sigmoid. Для бинарной задачи с фиксированной архитектурой достаточно ~500-1000 per-group примеров:

- **whistling** (С, З, Ц): ~4700 нарезок из общего corpus
- **hissing** (Ш, Ж, Ч, Щ): ~4200 нарезок
- **sonants** (Р, Рь, Л, Ль): ~5100 нарезок
- **velar** (К, Г, Х): ~2800 нарезок (меньше всего — приоритет M4.1 expansion)

17.35ч ≈ 41 000 фрагментов по 1.5с при нарезке с учётом target phonemes.

## Диагностика проблем прошлой итерации (403 → исправлено)

| Сломанный источник | Причина | Рабочая замена |
|---|---|---|
| `mozilla-foundation/common_voice_17_0` | README-only repo, no data | `Sh1man/common_voice_21_ru` (WebDataset) |
| `SberDevices/Golos` | loading script API deprecated в datasets 3.x | `bond005/sberdevices_golos_100h_farfield` (Parquet зеркало) |
| OpenSLR SLR96 (8.7 GB) | HTTPS 503 | `bond005/sova_rudevices` |
| OpenSLR SLR23/24 | 404 | SOVA |

## Детали по источникам

### Common Voice 21 RU (Sh1man)
- **Формат:** WAV 16kHz mono + manifest.json (id, text, duration, speaker)
- **Характер:** взрослый русский speech, микс гендеров и акцентов
- **Использование:** baseline для ASR и PronunciationScorer negative examples

### GOLOS farfield (bond005)
- **Формат:** Parquet → WAV 16kHz mono после pre-processing
- **Характер:** фары условия, разные микрофоны, есть фоновый шум
- **Использование:** noisy conditions для robustness PronunciationScorer

### SOVA RuDevices (bond005)
- **Формат:** WAV + transcript в JSON
- **Характер:** мобильные устройства, бытовая речь
- **Использование:** дополнительное покрытие домашних условий

### edge-tts synthetic
- **Формат:** WAV 16kHz mono (сгенерировано Microsoft edge-tts)
- **Распределение:** whistling/hissing/sonants/velar (per-group balance)
- **Использование:** M4.3 training data, целевые слова из 20 content packs

### Nexdata children
- **Лицензия:** Research only — только некоммерческое обучение
- **Характер:** детская речь 5-10 лет (редкий ресурс)
- **Использование:** child voice adaptation слой в scorer

## M4.2 Validation — спецификация

Скрипт: `_workshop/scripts/validate_datasets.py`

**Критерии фильтрации:**
- Sample rate == 16000 Hz (resample если нет)
- Channels == 1 mono (downmix если нет)
- Amplitude max < 0.95 (clipping detection)
- SNR ≥ 15 dB (через librosa.effects.split + noise estimate)
- Silence ratio < 20%
- Duration 0.3s — 30s (фильтр слишком коротких/длинных)
- Duplicate detection: xxhash от MFCC[40,150] коэффициентов

**Output:**
- `_workshop/datasets/clean/manifest_clean.json` — отобранный subset
- `_workshop/logs/validation_report.json` — per-source статистика отбраковки

**Предыдущий прогон на synthetic:** 93.4% pass rate (297/318).

## Расширение до ~100ч (опциональный M4.1 expansion)

Для полного покрытия per-group и robustness:

```bash
cd /Users/antongric/Yandex.Disk.localized/xcode_projects/Диплом/HappySpeech/_workshop
nohup python3 scripts/collect_datasets.py --source all --max_samples 15000 > logs/collect_expansion.log 2>&1 &
```

Скрипт идемпотентен (уже скачанное пропускает).

## Следующие milestones

- **M4.2** Validation (готов к запуску)
- **M4.3** Train 4× PronunciationScorer per-group на Apple Silicon MPS (accuracy ≥88%)
- **M4.4** Silero VAD real conversion (MIT pretrained → Core ML)
- **M4.5** CreateML SoundClassifier
- **M4.6** WhisperKit download manager (tiny/base/small)
- **M4.7** Qwen2.5-1.5B MLX 4-bit download manager
- **M4.8** LLMDecisionService расширение с 12 → 25+ decision points

## См. также

- `_workshop/scripts/collect_datasets.py` — download pipeline
- `_workshop/scripts/validate_datasets.py` — validation pipeline
- `_workshop/logs/collect_progress.jsonl` — лог скачивания
- `.claude/team/ml-models-research.md` — исследование HF моделей (researcher M4.9)
- `.claude/team/ml-models.md` — реестр Core ML моделей в `Resources/Models/`
