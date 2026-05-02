---
name: gigaam-coreml-russian
description: Workflow для оценки GigaAM-v2/v3 (Sber, лучший Russian ASR) и попытки конвертации в Core ML через coremltools или sherpa-onnx. Если конвертация невозможна до v1.0 диплома — ADR-V14-GIGAAM defer с обоснованием и roadmap на post-v1.0. Workflow для ml-engineer. Альтернативы: sherpa-onnx CTC streaming, Vosk Russian.
---

# Skill: gigaam-coreml-russian

## When to use

Этот skill активируется в **Block E v14** плана HappySpeech:

- Нужно оценить, возможно ли использовать GigaAM (Sber, state-of-art Russian ASR) на iOS.
- Задача: попытка конвертации GigaAM-v2 (HuggingFace: `salute-developers/gigaam-v2-ctc`) в Core ML.
- Если конвертация не удаётся в отведённые сроки — зафиксировать ADR-V14-GIGAAM с обоснованием defer и конкретным roadmap.
- Основной WhisperKit fallback остаётся в любом случае.

Используй этот skill когда:
- ml-engineer исследует возможности GigaAM для русского языка.
- Нужен честный технический assessment: возможно ли это до дедлайна диплома (2026-05-05).

---

## GigaAM — что это

**GigaAM** (Gigachat Acoustic Model) — серия акустических моделей для распознавания русской речи от Sber AI:

| Версия | HuggingFace ID | Architecture | Notes |
|---|---|---|---|
| GigaAM-v2 CTC | `salute-developers/gigaam-v2-ctc` | CTC | **Доступен публично**, Apache 2.0 |
| GigaAM-v2 RNNT | `salute-developers/gigaam-v2-rnnt` | RNN-T | Доступен, сложнее конвертировать |
| GigaAM-v3 | не найден публично (2026-05) | неизвестна | Предположительно closed или research-only |

**Рекомендуемый кандидат для конвертации: `salute-developers/gigaam-v2-ctc`** (CTC архитектура — наиболее совместима с coremltools).

---

## Конвертация в Core ML — оценка сложности

### Путь A: coremltools (прямая конвертация)

```python
from transformers import AutoModelForCTC, AutoProcessor
import torch
import coremltools as ct

model_id = "salute-developers/gigaam-v2-ctc"
model = AutoModelForCTC.from_pretrained(model_id)
model.eval()

# Попытка trace
example_input = torch.randn(1, 16000)  # 1 sec
try:
    traced = torch.jit.trace(model, example_input, strict=False)
    print("Trace: SUCCESS")
except Exception as e:
    print(f"Trace FAILED: {e}")
    # → Переходим к Пути B
```

Потенциальные блокеры:
- **Dynamic control flow** в attention layers → `strict=False` может не помочь.
- **Variable-length inputs** → RangeDim должен покрывать диапазон.
- **Custom ops** (если есть) → нет coremltools реализации → FAILED.

### Путь B: sherpa-onnx (ONNX runtime на iOS)

sherpa-onnx поддерживает CTC streaming Russian models.

```bash
# Установка
pip install sherpa-onnx

# Проверка наличия готовой Russian CTC модели
python3 -c "import sherpa_onnx; print(sherpa_onnx.__version__)"
```

Готовые Russian CTC модели в sherpa-onnx:
- `sherpa-onnx-streaming-zipformer-ru-2024-03-01` (Zipformer CTC, ~320 MB)
- `sherpa-onnx-whisper-small.ru` (Whisper small, Russian-only)

iOS integration через sherpa-onnx Swift SDK:
- Добавить SPM зависимость `k2-fsa/sherpa-onnx` (Swift Package).
- Обёртка: `SherpaOnnxASRService: ASRService`.

### Путь C: Vosk Russian (самый простой fallback)

```
vosk-model-ru-0.42 — 1.8 GB (слишком большой)
vosk-model-small-ru-0.22 — 45 MB (подходит для bundle)
```

Vosk имеет C API + Swift wrapper. Качество ниже GigaAM, но проще деплоить.

---

## Decision tree

```
START
  │
  ▼
Попытка 1: coremltools trace GigaAM-v2-CTC
  │
  ├── SUCCESS → конвертация → GigaAMRu.mlpackage → ✅ DONE
  │
  └── FAILED (dynamic ops / custom kernels)
        │
        ▼
  Попытка 2: sherpa-onnx Zipformer Russian CTC
        │
        ├── SUCCESS (SPM + Swift wrapper) → SherpaASRService → ✅ DONE
        │
        └── FAILED (размер/лицензия/complexity)
              │
              ▼
        Попытка 3: Vosk small-ru (45 MB)
              │
              ├── SUCCESS → VoskASRService → ✅ DONE (lower quality)
              │
              └── FAILED или время вышло
                    │
                    ▼
              ADR-V14-GIGAAM: defer post-v1.0
              WhisperKit остаётся primary
```

---

## ADR-V14-GIGAAM шаблон (если defer)

Если ни один путь не укладывается до дедлайна 2026-05-05:

```markdown
### [2026-05-XX] [ml-engineer] ADR-V14-GIGAAM: GigaAM defer post-v1.0

**Decision:** GigaAM интеграция отложена до post-v1.0. WhisperKit (tiny) остаётся
primary ASR. Ensemble pipeline (russian-asr-pipeline skill) использует Whisper +
Wav2Vec2 + RussianPhonemeClassifier.

**Попытки конвертации:**
1. coremltools trace GigaAM-v2-CTC — FAILED: [причина]
2. sherpa-onnx Zipformer Russian — FAILED/SKIPPED: [причина]
3. Vosk small-ru — FAILED/SKIPPED: [причина]

**Почему не в v1.0:**
- Дедлайн диплома 2026-05-05.
- WhisperKit + Ensemble достаточны для diploma defense.
- GigaAM интеграция требует дополнительного testing (≥2 недели).

**Post-v1.0 roadmap:**
1. Попытка 1: coremltools с GigaAM-v3 (если станет публичным).
2. Попытка 2: sherpa-onnx streaming zipformer + Swift wrapper.
3. Если оба неуспешны — кастомный Conformer CTC fine-tuned на русской детской речи.

**Risk:** Нет. WhisperKit + Wav2Vec2 ensemble покрывает diploma requirements.
```

---

## Если конвертация успешна: Swift integration

Файл: `HappySpeech/ML/GigaAM/GigaAMService.swift`

### Protocol

```swift
public protocol GigaAMService: Actor {
    func transcribe(audio: Data) async throws -> GigaAMTranscription
}

public struct GigaAMTranscription: Sendable, Codable {
    public let text: String
    public let tokens: [ASRToken]
    public let confidence: Double
}
```

Если `GigaAMRu.mlpackage` создан:
- Добавить в `HappySpeech/Resources/Models/`.
- Заменить Whisper-tiny в Tier B `EnsembleASRService` на GigaAM.
- Ожидаемый прирост accuracy: +5–15% WER на русской речи vs Whisper-tiny.

---

## Performance ожидания (если задеплоено)

| Параметр | Ожидание |
|---|---|
| Размер GigaAMRu.mlpackage | ~150–300 MB (после int8 quantization) |
| Latency на 2 sec audio, iPhone 15 | ~300–600 ms |
| WER на русской детской речи | ~10–18% (vs Whisper-tiny ~22%) |
| Требуемый iOS | iOS 17+ |

---

## Проверка готовности (DoD) — два варианта

### Вариант A (конвертация успешна):
- [ ] `GigaAMRu.mlpackage` в `HappySpeech/Resources/Models/`
- [ ] `GigaAMServiceLive` компилируется без предупреждений Swift 6
- [ ] WER тест на 10+ русских слов
- [ ] Интегрирован в `EnsembleASRService` Tier B
- [ ] Запись в `~/.claude/team/ml-models.md`

### Вариант B (defer):
- [ ] ADR-V14-GIGAAM записан в `~/.claude/team/decisions.md`
- [ ] Все три пути задокументированы с причинами отказа
- [ ] Post-v1.0 roadmap описан
- [ ] WhisperKit остаётся primary — подтверждено

---

## Порядок работы агентов (Block E.0)

**Step 1 (этот skill — создан):** Skill создан pm-агентом.

**Step 2 — ml-engineer:**
1. Выполнить Путь A (coremltools trace). Записать результат.
2. Если неудача — Путь B (sherpa-onnx). Записать результат.
3. Если неудача — записать ADR-V14-GIGAAM defer.
4. Срок: до 2026-05-03 (2 дня до дедлайна диплома).

**Step 3 — ios-developer (только если Путь A или B успешен):**
1. Реализовать `GigaAMServiceLive` или `SherpaASRServiceLive`.
2. Интегрировать в `EnsembleASRService`.
3. Unit-тесты.
