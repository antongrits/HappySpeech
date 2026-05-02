---
name: russian-asr-pipeline
description: Combined ensemble ASR pipeline для HappySpeech — Whisper + Wav2Vec2 + RussianPhonemeClassifier с weighted voting для максимальной точности на детской русской речи. Два тира: Tier A (kid on-device, lightweight), Tier B (parent/specialist, full accuracy). Output type EnsembleASRResult. Workflow для ml-engineer + ios-developer.
---

# Skill: russian-asr-pipeline

## When to use

Этот skill активируется в **Block E v14** плана HappySpeech:

- Нужен maximum accuracy на детской русской речи — ни одна модель поодиночке недостаточна.
- Задача: объединить три уже задеплоенных модели (Whisper, Wav2Vec2RuChild, RussianPhonemeClassifier) в единый ensemble с confidence-based voting.
- Нельзя использовать: cloud ASR, Apple AVSpeechRecognizer (требует сети).
- Используется как высший уровень PhonemeAnalysisService (Tier 4 — ensemble).

Используй этот skill когда:
- ios-developer расширяет `ASRServiceLive` поддержкой ensemble.
- ml-engineer калибрует веса голосования между моделями.
- qa-engineer проверяет PER (Phone Error Rate) ensemble vs. одиночных моделей.

---

## Architecture overview

```
Raw audio (16 kHz mono Float32)
        │
        ├──────────────────────────────────────────┐
        │                                          │
        ▼                                          ▼
  WhisperKit (tiny)                        Wav2Vec2RuChild
  word-level transcription                 phoneme CTC logits
  output: [WordTimestamp]                  output: [PhonemeLogit]
        │                                          │
        └──────────────┬───────────────────────────┘
                       │
                       ▼
             RussianPhonemeClassifier
             phoneme refinement / re-scoring
             output: [PhonemeScore]
                       │
                       ▼
            Ensemble Voting Engine
            confidence-weighted majority voting
                       │
                       ▼
              EnsembleASRResult
       { transcription, phonemes, confidence, tier }
```

Ключевые свойства:
- **Tier A (kid mode):** только Whisper-tiny + RussianPhonemeClassifier. Latency < 300 ms на iPhone SE 3.
- **Tier B (parent/specialist):** все три модели. Latency 300–800 ms на iPhone 15+.
- **Offline-first:** все модели on-device.
- **Confidence threshold:** если ensemble confidence < 0.60 — возвращается `lowConfidence` flag для UI.

---

## Output type

```swift
public struct EnsembleASRResult: Sendable, Codable {
    public let transcription: String
    public let phonemes: [PhonemeMatch]
    public let confidence: Double
    public let tier: EnsembleTier
    public let processingTimeMs: Double
}

public struct PhonemeMatch: Sendable, Codable {
    public let phoneme: String
    public let startMs: Double
    public let endMs: Double
    public let confidence: Double
    public let source: PhonemeSource
}

public enum PhonemeSource: String, Sendable, Codable {
    case whisper, wav2vec2, phonemeClassifier, ensemble
}

public enum EnsembleTier: String, Sendable, Codable {
    case lightweight  // Tier A: Whisper-tiny + RussianPhonemeClassifier
    case full         // Tier B: все три модели
}
```

---

## Ensemble voting strategy

### Confidence-based weighted majority voting

Каждая модель даёт оценку фонемы с confidence [0.0, 1.0].

Итоговая оценка фонемы:

```
score(phoneme_p) = Σ weight_i * confidence_i(p)
```

Веса по умолчанию (калибруются по валидационному сету):

| Модель | Вес Tier A | Вес Tier B |
|---|---|---|
| Whisper-tiny | 0.5 | 0.25 |
| Wav2Vec2RuChild | — | 0.45 |
| RussianPhonemeClassifier | 0.5 | 0.30 |

Финальный phoneme = argmax(score).

Если max(score) < 0.60 — флаг `lowConfidence = true`.

### Alignment strategy

Whisper даёт word-level timestamps. Wav2Vec2 даёт frame-level logits.

Для alignment:
1. Разбить word timestamps на phoneme-sized сегменты (avg 70 ms/phoneme для русского).
2. Смэпить Wav2Vec2 CTC output на сегменты через DTW (Dynamic Time Warping).
3. RussianPhonemeClassifier получает те же сегменты и переоценивает каждый фонем отдельно.

---

## iOS Swift integration (ASRServiceLive extension)

Файл: `HappySpeech/Services/ASRService/EnsembleASRService.swift`

### Protocol

```swift
public protocol EnsembleASRService: Actor {
    func recognize(audio: Data, tier: EnsembleTier) async throws -> EnsembleASRResult
}
```

### Live implementation skeleton

```swift
import CoreML
import WhisperKit

public actor EnsembleASRServiceLive: EnsembleASRService {
    private let whisper: WhisperKit
    private let wav2vec2: Wav2Vec2Service
    private let phonemeClassifier: RussianPhonemeClassifierService

    public init(
        whisper: WhisperKit,
        wav2vec2: Wav2Vec2Service,
        phonemeClassifier: RussianPhonemeClassifierService
    ) {
        self.whisper = whisper
        self.wav2vec2 = wav2vec2
        self.phonemeClassifier = phonemeClassifier
    }

    public func recognize(audio: Data, tier: EnsembleTier) async throws -> EnsembleASRResult {
        let startTime = Date()

        let whisperResult = try await whisper.transcribe(audio: audio)
        let classifierResult = try await phonemeClassifier.classify(audio: audio)

        if tier == .full {
            let wav2vec2Result = try await wav2vec2.transcribe(audio: audio)
            let phonemes = vote(
                whisper: whisperResult,
                wav2vec2: wav2vec2Result,
                classifier: classifierResult,
                tier: .full
            )
            return buildResult(phonemes: phonemes, tier: .full, start: startTime)
        }

        let phonemes = vote(
            whisper: whisperResult,
            wav2vec2: nil,
            classifier: classifierResult,
            tier: .lightweight
        )
        return buildResult(phonemes: phonemes, tier: .lightweight, start: startTime)
    }
}
```

### AppContainer registration

```swift
// App/DI/AppContainer.swift
let ensembleASR = EnsembleASRServiceLive(
    whisper: container.whiskerService,
    wav2vec2: container.wav2vec2Service,
    phonemeClassifier: container.phonemeClassifierService
)
container.register(EnsembleASRService.self) { ensembleASR }
```

---

## Tier selection logic

```swift
extension EnsembleTier {
    static func select(for userRole: UserRole, device: DeviceCapability) -> EnsembleTier {
        switch (userRole, device) {
        case (.child, _):
            return .lightweight  // всегда быстро для детей
        case (.parent, .highEnd), (.specialist, _):
            return .full
        case (.parent, .lowEnd):
            return .lightweight
        }
    }
}
```

---

## Performance budgets

| Tier | iPhone SE 3 (A15) | iPhone 15 (A16) | iPhone 17 Pro (A19) |
|---|---|---|---|
| Tier A (lightweight) | < 350 ms | < 200 ms | < 150 ms |
| Tier B (full) | < 900 ms | < 500 ms | < 300 ms |
| Memory peak | < 150 MB | < 200 MB | < 250 MB |

---

## Проверка готовности (DoD)

- [ ] `EnsembleASRServiceLive` компилируется без предупреждений Swift 6
- [ ] Unit-тест: silence / correct / incorrect phoneme / low confidence
- [ ] Tier A latency < 350 ms на симуляторе iPhone SE
- [ ] Tier B ensemble accuracy >= single-model на тестовом сете (10+ русских слов)
- [ ] `EnsembleASRResult` Codable (для Realm сохранения SessionLog)
- [ ] 0 force-unwrap в production-коде
- [ ] Зарегистрирован в `AppContainer`
- [ ] Документация в `~/.claude/team/ml-models.md`

---

## Порядок работы агентов (Block E.0)

**Step 1 (этот skill — создан):** Skill создан pm-агентом.

**Step 2 — ml-engineer:**
1. Калибровать веса voting на валидационном сете (минимум 50 русских слов).
2. Реализовать DTW alignment для Wav2Vec2 ↔ Whisper timestamps.
3. Записать результаты в `~/.claude/team/ml-models.md`.

**Step 3 — ios-developer:**
1. Реализовать `EnsembleASRServiceLive` по скелету выше.
2. Добавить `EnsembleASRServiceMock` для Preview и тестов.
3. Интегрировать Tier selection в `SessionInteractor`.
4. Написать unit-тесты (минимум 4 кейса).
