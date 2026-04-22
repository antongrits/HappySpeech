# HappySpeech — Project Instructions for Claude Code Agents

## Проект
- **Название:** HappySpeech
- **Тип:** iOS-приложение по логопедии для детей 5–8 лет
- **Архитектура:** Clean Swift (VIP), SwiftUI + UIKit, SPM

## Team communication folder

**Все агенты читают и пишут командные файлы в `.claude/team/` (относительно корня проекта).**

Полный путь: `/Users/antongric/Yandex.Disk.localized/xcode_projects/Диплом/HappySpeech/.claude/team/`

| Файл | Содержимое |
|---|---|
| `sprint.md` | Текущий спринт и задачи |
| `backlog.md` | Бэклог продукта |
| `architecture.md` | Архитектурные решения (ADR) |
| `design-specs.md` | Спецификации дизайна |
| `api-contracts.md` | iOS ↔ Backend контракты |
| `test-results.md` | Результаты QA |
| `decisions.md` | Лог решений |
| `ml-models.md` | Реестр Core ML моделей |
| `sound-assets.md` | Реестр звуков |

## Запуск

```bash
cd ~/Yandex.Disk.localized/xcode_projects/Диплом/HappySpeech && claude
```

## Глобальные ресурсы (не трогать, они уже есть)

- Агенты: `~/.claude/agents/`
- Скиллы: `~/.claude/skills/`
- MCPs: `~/.claude.json` (mcpServers)
