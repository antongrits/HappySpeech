# ML Pipeline

On-device машинное обучение: VAD, оценка произношения, ASR и LLM.

## Overview

HappySpeech использует полностью on-device ML — никакие аудиоданные ребёнка не покидают устройство.
Пайплайн состоит из четырёх уровней:

```
Микрофон → VAD → ASR (WhisperKit) → PronunciationScorer → LLMDecisionService
```

## Модели (задеплоены в Resources/Models/)

| Модель | Размер | Назначение |
|--------|--------|-----------|
| `SileroVAD.mlpackage` | 0.008 MB | Детектор речевой активности |
| `PronunciationScorer_whistling.mlpackage` | 0.18 MB | С, З, Ц — 95% accuracy |
| `PronunciationScorer_hissing.mlpackage` | 0.18 MB | Ш, Ж, Ч, Щ — 100% accuracy |
| `PronunciationScorer_sonants.mlpackage` | 0.18 MB | Р, Л — 93% accuracy |
| `PronunciationScorer_velar.mlpackage` | 0.18 MB | К, Г, Х — 87% accuracy |

## VAD — SileroVAD

``SileroVAD`` определяет наличие речи в аудиофрейме до запуска тяжёлого ASR-инференса.
Вход: PCM 16kHz mono. Выход: `Bool` (речь обнаружена).

```swift
let vad = SileroVAD()
let hasSpeech = try await vad.isSpeech(buffer: pcmBuffer)
if hasSpeech {
    let result = try await whisperKit.transcribe(buffer)
}
```

## PronunciationScorer

``PronunciationScorer`` оценивает произношение отдельного звука через MFCC-фичи.

**Вход модели:** MFCC тензор `[1, 40, 150]`, 16kHz mono, 1.5 секунды.
**Выход:** `PronunciationResult` с `correctProbability` (0.0–1.0).

```swift
let scorer = PronunciationScorer()
let result = try await scorer.evaluate(buffer: audioBuffer, group: .whistling)
print(result.displayScore) // 0–100
```

## ASR — WhisperKit

WhisperKit (whisper-large-v3-turbo — primary, whisper-tiny — fallback) транскрибирует
русскую речь ребёнка. Лицензия MIT. Заменил GigaAM (ADR-001-REV1 от 2026-04-22,
причина: GigaAM имеет некоммерческую лицензию).

## LLM Tier Routing

``LLMDecisionService`` маршрутизирует запросы по трём уровням:

- **Tier A** — Qwen2.5-1.5B (MLX Swift, on-device) — детский контур
- **Tier B** — HuggingFace Vikhr-Nemo-12B — только родительский/специалистский
- **Tier C** — `RuleBasedDecisionService` — всегда работает, нет инференса

> Warning: Детский контур (kid circuit) **никогда** не вызывает Tier B (COPPA).

## Темы

### Типы ML
- ``PronunciationScorer``
- ``SileroVAD``
- ``LLMDecisionService``
