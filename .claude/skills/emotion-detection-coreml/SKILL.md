---
name: emotion-detection-coreml
description: Emotion Detection Conv1d-LSTM для HappySpeech — определяет 4 эмоции ребёнка (happy, sad, frustrated, neutral) по голосу для adaptive feedback. Input 40 MFCC features, target accuracy >= 75%, EmotionDetection.mlpackage (~5 MB). Swift integration через EmotionDetectionServiceProtocol для adaptive learning logic. Workflow для ml-engineer.
---

# Skill: emotion-detection-coreml

## When to use

Этот skill активируется в **Block E v14** плана HappySpeech:

- Нужна адаптивная логика feedback на основе эмоционального состояния ребёнка.
- Задача: определить frustrated/happy/sad/neutral и передать в `AdaptivePlannerService` для корректировки сложности и частоты подсказок.
- Применяется: после каждой попытки упражнения (1–3 секунды аудио).
- Нельзя: показывать эмоциональный диагноз ребёнку или родителю напрямую — только внутренний сигнал для адаптации.

Используй этот skill когда:
- ml-engineer обучает и конвертирует модель.
- ios-developer интегрирует `EmotionDetectionServiceLive` с `AdaptivePlannerService`.
- speech-specialist определяет правила реакции на каждую эмоцию.

---

## Architecture overview

```
Raw audio (16 kHz mono Float32, 1–3 sec)
        │
        ▼
Feature extraction (vDSP)
  40 MFCC coefficients per frame (25 ms window, 10 ms hop)
  Output: [40, T] feature matrix
        │
        ▼
Conv1d-LSTM architecture
  ├── Conv1d(40→128, kernel=3, padding=1) + ReLU
  ├── Conv1d(128→128, kernel=3, padding=1) + ReLU + MaxPool(2)
  ├── LSTM(128, hidden=64, num_layers=2, dropout=0.3)
  ├── Temporal mean pooling
  └── Linear(64→4) + Softmax
  Output: [happy, sad, frustrated, neutral] probabilities
        │
        ▼
EmotionDetectionResult
  { emotion: Emotion, confidence: Double, probabilities: [Float] }
```

---

## 4 эмоции и адаптивная логика

| Эмоция | Признаки в речи | Реакция AdaptivePlanner |
|---|---|---|
| `happy` | высокий F0, быстрый темп, звонкий голос | продолжить текущую сложность, можно усложнить |
| `neutral` | нормальный F0 и темп | стандартный режим |
| `sad` | низкий F0, медленный темп, тихо | снизить сложность, добавить поддержку Ляли |
| `frustrated` | резкие F0 флуктуации, обрывистость, паузы | дать подсказку, уменьшить число попыток, взять паузу |

---

## Training data strategy

### Источники (лицензия CC0 / Apache 2.0 / Fair Use for Research)

| Датасет | Язык | Размер | Примечание |
|---|---|---|---|
| Lyalya recordings (augmented) | RU child | ~4 938 samples | pitch + tempo augmentation |
| RAVDESS subset | EN | ~800 samples | children actors, 4 emotions |
| EmoV-DB subset | EN | ~500 samples | нейтрально-грустный диапазон |

Суммарный объём: ~6 000–7 000 samples. Достаточно для простой 4-class задачи.

### Augmentation для балансировки классов

```python
def balance_emotions(dataset):
    # frustrated часто недопредставлен
    # используем pitch jitter + noise injection для upsampling
    target_per_class = max(counts.values())
    for emotion in ['frustrated', 'sad']:
        while counts[emotion] < target_per_class:
            sample = random.choice(emotion_samples[emotion])
            augmented = add_noise(pitch_jitter(sample), snr_db=15)
            dataset.append((augmented, emotion))
```

### Кросс-языковое обучение (cross-lingual transfer)

RAVDESS/EmoV-DB на английском используются для преобразования эмоциональных паттернов F0/tempo. Русские семплы из Lyalya доминируют (80% тренировочного сета).

---

## Model architecture (PyTorch)

```python
import torch
import torch.nn as nn

class EmotionDetectionCNN(nn.Module):
    def __init__(self, n_mfcc=40, n_emotions=4):
        super().__init__()
        self.conv1 = nn.Sequential(
            nn.Conv1d(n_mfcc, 128, kernel_size=3, padding=1),
            nn.ReLU()
        )
        self.conv2 = nn.Sequential(
            nn.Conv1d(128, 128, kernel_size=3, padding=1),
            nn.ReLU(),
            nn.MaxPool1d(2)
        )
        self.lstm = nn.LSTM(
            128, 64,
            num_layers=2,
            batch_first=True,
            dropout=0.3
        )
        self.classifier = nn.Linear(64, n_emotions)

    def forward(self, x):
        # x: [batch, n_mfcc, time_frames]
        x = self.conv1(x)
        x = self.conv2(x)
        x = x.permute(0, 2, 1)  # [batch, time, channels]
        x, _ = self.lstm(x)
        x = x.mean(dim=1)       # temporal mean pooling
        return self.classifier(x)  # [batch, 4] logits
```

Training setup:
- Optimizer: AdamW, lr=1e-3, weight_decay=1e-4
- Loss: CrossEntropy с class weights (frustrated upweighted x1.5)
- Epochs: 50, early stopping patience=10
- Batch size: 32

---

## CoreML conversion pipeline

```python
import coremltools as ct
import torch

model = EmotionDetectionCNN()
model.load_state_dict(torch.load("emotion_detection_best.pt"))
model.eval()

example_input = torch.randn(1, 40, 150)  # ~1.5 sec при 100 Hz
traced = torch.jit.trace(model, example_input)

mlmodel = ct.convert(
    traced,
    inputs=[ct.TensorType(
        name="mfcc_features",
        shape=(1, 40, ct.RangeDim(50, 500))
    )],
    outputs=[ct.TensorType(name="emotion_logits")],
    compute_units=ct.ComputeUnit.ALL,
    minimum_deployment_target=ct.target.iOS17,
    convert_to="mlprogram"
)

mlmodel.author = "HappySpeech ML Team"
mlmodel.short_description = "Emotion detection: happy/sad/frustrated/neutral for child voice"
mlmodel.input_description["mfcc_features"] = "40 MFCC coefficients [1, 40, T]"
mlmodel.output_description["emotion_logits"] = "4-class emotion logits [1, 4]"
mlmodel.save("HappySpeech/Resources/Models/EmotionDetection.mlpackage")
```

Целевой размер: **~5 MB** (компактная архитектура).

---

## Swift integration

Файл: `HappySpeech/Services/EmotionDetection/EmotionDetectionService.swift`

### Protocol

```swift
public protocol EmotionDetectionService: Actor {
    func detect(audio: Data) async throws -> EmotionDetectionResult
}

public struct EmotionDetectionResult: Sendable {
    public let emotion: ChildEmotion
    public let confidence: Double
    public let probabilities: EmotionProbabilities
}

public struct EmotionProbabilities: Sendable {
    public let happy: Double
    public let sad: Double
    public let frustrated: Double
    public let neutral: Double
}

public enum ChildEmotion: String, Sendable, CaseIterable {
    case happy, sad, frustrated, neutral

    /// Рекомендуемое действие для AdaptivePlanner
    public var adaptiveAction: AdaptiveAction {
        switch self {
        case .happy:     return .continueOrIncreaseDifficulty
        case .neutral:   return .continueNormal
        case .sad:       return .decreaseDifficultyAddSupport
        case .frustrated: return .pauseGiveHintDecreaseDifficulty
        }
    }
}
```

### Интеграция с AdaptivePlannerService

```swift
// В AdaptivePlannerService
public func updatePlanIfNeeded(emotion: ChildEmotion) async {
    guard emotion != .neutral else { return }
    let action = emotion.adaptiveAction
    await applyAdaptiveAction(action)
}
```

Важно: детектировать эмоцию только если confidence >= 0.65. При низкой уверенности — не менять план.

---

## Performance budgets

| Операция | iPhone SE 3 | iPhone 15+ |
|---|---|---|
| Feature extraction (2 sec) | < 40 ms | < 20 ms |
| Model inference | < 30 ms | < 15 ms |
| Total detect() | < 75 ms | < 40 ms |
| Model size | ~5 MB | ~5 MB |
| Memory peak | < 30 MB | < 30 MB |

---

## Проверка готовности (DoD)

- [ ] `EmotionDetection.mlpackage` в `HappySpeech/Resources/Models/` (~5 MB)
- [ ] Validation accuracy >= 75% на hold-out set (cross-validated 5-fold)
- [ ] Precision/recall для `frustrated` class >= 0.70 (критически важный класс)
- [ ] `EmotionDetectionServiceLive` компилируется без предупреждений Swift 6
- [ ] `EmotionDetectionServiceMock` с детерминированными ответами для тестов
- [ ] Детекция активна только при confidence >= 0.65 (не даёт ложных адаптаций)
- [ ] Интегрирован с `AdaptivePlannerService`
- [ ] Unit-тесты: 4 кейса (по одному на каждую эмоцию)
- [ ] Запись в `~/.claude/team/ml-models.md`

---

## Порядок работы агентов (Block E.0)

**Step 1 (этот skill — создан):** Skill создан pm-агентом.

**Step 2 — speech-specialist:**
1. Верифицировать правила `adaptiveAction` для каждой эмоции (см. таблицу выше).
2. Описать пороговые значения (после скольких `frustrated` подряд — взять паузу).
3. Зафиксировать в `~/.claude/team/backlog.md` как SPEECH-требование.

**Step 3 — ml-engineer:**
1. Собрать training set из Lyalya augmentations + RAVDESS subset.
2. Обучить `EmotionDetectionCNN`.
3. Конвертировать → `EmotionDetection.mlpackage`.
4. Записать метрики в `~/.claude/team/ml-models.md`.

**Step 4 — ios-developer:**
1. Реализовать `EmotionDetectionServiceLive`.
2. Интегрировать с `AdaptivePlannerService`.
3. Написать unit-тесты.
