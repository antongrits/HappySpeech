# Audio и голос

AVAudioEngine, фоновые звуки, тактильная отдача и уведомления.

## Overview

Аудио-слой HappySpeech работает на `AVAudioEngine` с форматом 16kHz mono (для ML-пайплайна).
Параллельно работает `AmbientSoundService` с фоновыми ambient-сценами.

## AudioService

`AudioService` управляет записью речи через `AVAudioEngine`:
- Частота дискретизации: 16kHz mono (оптимально для WhisperKit и PronunciationScorer)
- Буфер: 4096 семплов (`AVAudioFrameCount`)
- VAD перед отправкой буфера в ASR

## AmbientSoundService

``AmbientSoundService`` воспроизводит фоновые ambient-сцены через `AVAudioPlayer`.

AVAudioSession категория `.ambient` + `.mixWithOthers` — не блокирует музыку пользователя.

Доступные сцены (`AmbientScene`):

| Сцена | Описание |
|-------|----------|
| `.childHome` | Мягкий пэд + птички |
| `.forest` | Шелест листьев + ветер |
| `.ocean` | Волны + чайки |
| `.space` | Космический дрон |
| `.circus` | Орган + толпа |

```swift
let ambientService: AmbientSoundService = LiveAmbientSoundService()
await ambientService.play(scene: .ocean, fadeDuration: 1.5)
// ... через несколько секунд
await ambientService.stop(fadeDuration: 0.8)
```

## HapticService

``HapticService`` управляет тактильной отдачей через `CHHapticEngine`.

15 именованных паттернов (`HapticPattern`): от `.celebration` до `.errorBuzz`.
Интенсивность настраивается пользователем: `.off`, `.subtle`, `.full`.

```swift
let hapticService: HapticService = LiveHapticService()
await hapticService.prepare()
try await hapticService.play(.celebration)
```

> Note: На устройствах без Taptic Engine (старые iPad) — graceful fallback через
> `UIImpactFeedbackGenerator`.

## NotificationService

``NotificationServiceLive`` планирует уведомления через `UNUserNotificationCenter`.

Поддерживает:
- Ежедневное напоминание (`hs.daily.reminder`)
- Стрик-оповещение (`hs.streak.reminder`)
- Еженедельный отчёт для родителя (`hs.weekly.report`)
- Разовые советы родителю (`hs.parent.tip.<uuid>`)

> Important: В kids-mode сервис **не планирует** уведомления и отменяет все pending.

## VoiceCloneService

``VoiceCloneService`` — placeholder для клонирования голоса Ляли.
В v1.0 реализовано только `loadReference(speakerIndex:)`.
Полная реализация XTTS-v2 — в roadmap v1.1.

## Темы

### Сервисы
- ``AmbientSoundService``
- ``HapticService``
- ``NotificationServiceLive``
- ``VoiceCloneService``
