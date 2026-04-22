# HappySpeech — Knowledge Base

## Проект
iOS речевое терапевтическое приложение для детей 5-8 лет.
Цель: помочь детям с нарушениями речи (дислалия, ОНР, ЗРР, ФФН) через игровые упражнения.
Целевая аудитория: дети + родители + логопеды.

## Tech Stack
- Swift 5.9+, SwiftUI, iOS 17+
- Firebase (Auth, Firestore, Functions)
- Core ML (WhisperKit для ASR, собственная модель произношения)
- ARKit Face Tracking (артикуляция)
- AVAudioEngine (16kHz mono запись)
- SPM зависимости

## Архитектура
MVVM + DI с @Observable ViewModels
Clean Swift для сложных фич
Модульная структура: Features/, Core/, Services/, Shared/, DesignSystem/

## Общие файлы команды
- Sprint: .claude/team/sprint.md
- Backlog: .claude/team/backlog.md
- Design: .claude/team/design-specs.md
- API contracts: .claude/team/api-contracts.md
- Архитектура: .claude/team/architecture.md
- Тест-результаты: .claude/team/test-results.md
- Решения CTO: .claude/team/decisions.md
- ТЗ игр: .claude/team/speech-games-tz.md
- Контент БД: .claude/team/speech-content-db.md
- ML модели: .claude/team/ml-models.md
- Звуки: .claude/team/sound-assets.md

## Mailbox-протокол
Отправить задачу: добавить JSON в .claude/team/orchestration/mailbox/{agent}.jsonl
Результат: .claude/team/orchestration/outbox/{agent}_{task_id}.json
Статус: .claude/team/orchestration/status/{agent}.status

## Правила зависимостей команды
1. speech-methodologist ДОЛЖЕН закончить ТЗ ПЕРЕД тем как team-lead берёт речевые фичи
2. designer-ui пишет design-specs.md ПЕРЕД тем как ios-lead начинает UI
3. backend-lead пишет api-contracts.md ПЕРЕД тем как ios-lead начинает API
4. ml-data-engineer готовит датасет ПЕРЕД тем как ml-trainer начинает обучение
5. speech-content-curator пишет контент-БД ПЕРЕД тем как sound-curator ищет звуки
6. QA начинает ПОСЛЕ завершения ios-lead + backend-lead
