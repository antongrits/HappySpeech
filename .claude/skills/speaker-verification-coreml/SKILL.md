---
name: speaker-verification-coreml
description: Speaker Verification CNN для HappySpeech — отличает голос родителя от голоса ребёнка (COPPA-safe). d-vector CNN (Conv1d + Bi-LSTM + 64-dim projection), cosine similarity threshold 0.7. Workflow для ml-engineer: обучение на augmented Lyalya phrases + synthetic parent samples, конвертация в SpeakerVerification.mlpackage (~30 MB). Swift integration через SpeakerVerificationServiceProtocol.
---

# Skill: speaker-verification-coreml

## When to use

Этот skill активируется в **Block E v14** плана HappySpeech:

- Нужно COPPA-safe разграничение контекстов родителя и ребёнка по голосу.
- Задача: определить, кто говорит — взрослый или ребёнок — без сохранения биометрии (только embedding сравнение in-memory).
- Применяется при: автоматическом переключении контуров (kid/parent), парентальном контроле (подтверждение действия родителя), персонализации adaptive planner.
- Нельзя: хранить raw audio или embeddings на сервере. Только локальный cosine similarity в RAM.

---

## Architecture overview

```
Raw audio (16 kHz mono Float32, 2–10 sec)
        │
        ▼
Feature extraction (vDSP в Swift)
  ├── 40 MFCC coefficients
  ├── log-mel spectrogram (40 mel bins)
  └── delta + delta-delta MFCC
  Combined: 120-dim feature vector per frame
        │
        ▼
d-vector CNN architecture
  ├── Conv1d(120→256, kernel=5, stride=1) + ReLU + BatchNorm
  ├── Conv1d(256→256, kernel=5, stride=2) + ReLU + BatchNorm
  ├── Bi-LSTM(256, hidden=256, bidirectional=True)
  └── Linear projection(512→64) + L2 normalize
  Output: 64-dim L2-normalized speaker embedding
        │
        ▼
Cosine similarity comparison
  threshold = 0.7
  similarity >= 0.7 → speaker match
  similarity <  0.7 → different speaker
        │
        ▼
SpeakerVerificationResult
  { isChildVoice: Bool, confidence: Double, embedding: [Float]? }
```

---

## Training data strategy

### Проблема
Нет готового русского детского датасета для speaker verification.

### Решение: синтетические вариации из Lyalya recordings

Из 2469 Lyalya .m4a фраз (детская речь, имитация) генерируем:
- **Детские варианты:** pitch shift +2..+4 semitones, tempo 1.05-1.15x (имитация более высокого детского голоса).
- **Взрослые варианты:** pitch shift -3..-6 semitones, tempo 0.90-0.98x (имитация взрослого).

```python
import librosa
import soundfile as sf
import numpy as np

def augment_child(audio, sr=16000):
    shifted = librosa.effects.pitch_shift(audio, sr=sr, n_steps=3.0)
    stretched = librosa.effects.time_stretch(shifted, rate=1.10)
    return stretched

def augment_adult(audio, sr=16000):
    shifted = librosa.effects.pitch_shift(audio, sr=sr, n_steps=-4.0)
    stretched = librosa.effects.time_stretch(shifted, rate=0.94)
    return stretched
```

Целевой объём:
- Child class: 2469 оригинал + 2469 pitch-shifted = ~4 938 samples.
- Adult class: 2469 adult-augmented = ~2 469 samples.
- Train/val split: 80/20.

### Валидационный критерий
- Equal Error Rate (EER) <= 15%.
- Validation accuracy (child/adult binary) >= 85%.
- False Accept Rate (FAR) <= 10% (взрослый принят как ребёнок).

---

## Model architecture (PyTorch)

```python
import torch
import torch.nn as nn

class DVectorCNN(nn.Module):
    def __init__(self, input_dim=120, embedding_dim=64):
        super().__init__()
        self.conv1 = nn.Sequential(
            nn.Conv1d(input_dim, 256, kernel_size=5, padding=2),
            nn.ReLU(),
            nn.BatchNorm1d(256)
        )
        self.conv2 = nn.Sequential(
            nn.Conv1d(256, 256, kernel_size=5, stride=2, padding=2),
            nn.ReLU(),
            nn.BatchNorm1d(256)
        )
        self.lstm = nn.LSTM(
            256, 256,
            bidirectional=True,
            batch_first=True
        )
        self.projection = nn.Linear(512, embedding_dim)

    def forward(self, x):
        # x: [batch, input_dim, time_frames]
        x = self.conv1(x)
        x = self.conv2(x)
        x = x.permute(0, 2, 1)  # [batch, time, channels]
        x, _ = self.lstm(x)
        # temporal mean pooling
        x = x.mean(dim=1)
        x = self.projection(x)
        # L2 normalize
        x = nn.functional.normalize(x, p=2, dim=-1)
        return x
```

---

## CoreML conversion pipeline

```python
import coremltools as ct
import torch

model = DVectorCNN(input_dim=120, embedding_dim=64)
model.load_state_dict(torch.load("speaker_verification_best.pt"))
model.eval()

# Trace с фиксированным batch
example_input = torch.randn(1, 120, 200)  # 2 секунды при 100 Hz frame rate
traced = torch.jit.trace(model, example_input)

mlmodel = ct.convert(
    traced,
    inputs=[ct.TensorType(
        name="features",
        shape=(1, 120, ct.RangeDim(50, 1000))
    )],
    outputs=[ct.TensorType(name="embedding")],
    compute_units=ct.ComputeUnit.ALL,
    minimum_deployment_target=ct.target.iOS17,
    convert_to="mlprogram"
)

mlmodel.author = "HappySpeech ML Team"
mlmodel.short_description = "Speaker verification d-vector: child vs adult classification"
mlmodel.input_description["features"] = "MFCC+log-mel features [1, 120, T]"
mlmodel.output_description["embedding"] = "64-dim L2-normalized speaker embedding"
mlmodel.save("HappySpeech/Resources/Models/SpeakerVerification.mlpackage")
```

Целевой размер: **~30 MB** (FP32 → FP16 quantization).

---

## Swift integration

Файл: `HappySpeech/Services/SpeakerVerification/SpeakerVerificationService.swift`

### Protocol

```swift
public protocol SpeakerVerificationService: Actor {
    /// Энролл референсного голоса (один раз при setup)
    func enroll(audio: Data, role: UserRole) async throws

    /// Проверка: совпадает ли голос с сохранённым роль-профилем
    func verify(audio: Data, expectedRole: UserRole) async throws -> SpeakerVerificationResult
}

public struct SpeakerVerificationResult: Sendable {
    public let isMatch: Bool
    public let confidence: Double
    public let detectedRole: UserRole?
}
```

### Cosine similarity

```swift
private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
    var dot: Float = 0
    vDSP_dotpr(a, 1, b, 1, &dot, vDSP_Length(a.count))
    // embeddings уже L2-normalized в модели
    return dot
}
```

### Privacy notes (COPPA)

- Embeddings хранятся только in-memory (никогда на диске, никогда в Firestore).
- Raw audio удаляется сразу после получения embedding.
- Enrollment требует явного действия пользователя (родителя).
- AppPrivacyInfo.xcprivacy: объявить `NSMicrophoneUsageDescription` (уже есть).

---

## Performance budgets

| Операция | iPhone SE 3 | iPhone 15+ |
|---|---|---|
| Feature extraction (2 sec audio) | < 50 ms | < 25 ms |
| Model inference | < 100 ms | < 50 ms |
| Cosine similarity | < 1 ms | < 1 ms |
| Total verify() | < 160 ms | < 80 ms |
| Model size | ~30 MB | ~30 MB |
| Memory peak | < 60 MB | < 60 MB |

---

## Проверка готовности (DoD)

- [ ] `SpeakerVerification.mlpackage` в `HappySpeech/Resources/Models/` (~30 MB)
- [ ] Validation accuracy >= 85% на hold-out set
- [ ] EER <= 15%
- [ ] `SpeakerVerificationServiceLive` компилируется без предупреждений Swift 6
- [ ] Embeddings не сохраняются на диск (проверить через unit-тест)
- [ ] `SpeakerVerificationServiceMock` для Preview и тестов
- [ ] Enrollment flow защищён от доступа из детского контура
- [ ] Зарегистрирован в `AppContainer`
- [ ] Запись в `~/.claude/team/ml-models.md`

---

## Порядок работы агентов (Block E.0)

**Step 1 (этот skill — создан):** Skill создан pm-агентом.

**Step 2 — ml-engineer:**
1. Генерировать augmented dataset из Lyalya recordings (скрипт выше).
2. Обучить `DVectorCNN` на MacBook Apple Silicon (MPS backend).
3. Конвертировать в `SpeakerVerification.mlpackage`.
4. Записать метрики в `~/.claude/team/ml-models.md`.

**Step 3 — ios-developer:**
1. Реализовать `SpeakerVerificationServiceLive`.
2. Интегрировать с `AdaptivePlannerService` для контекст-переключения.
3. Реализовать enrollment UX в родительском контуре.
4. Unit-тесты: enroll + verify + privacy (нет записи на диск).
