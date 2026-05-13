# Plan v21 Block AH — Plain Russian Audit

**Дата:** 2026-05-13
**Задача:** User explicit #15 — «Всё должно быть ориентировано на обычного пользователя, никаких непонятных слов»

## Jargon findings

- Total potential candidates проверено: 22
- Replaced (kid/parent UI): 20
- Kept (admin/debug acceptable): 2

## Replacements applied

| Ключ | Старое значение | Новое значение |
|---|---|---|
| `SoundClassifier.mlpackage не найден в Resources/Models/` | `SoundClassifier.mlpackage не найден в Resources/Models/` | `Файл распознавания звуков не найден. Попробуйте переустановить приложение.` |
| `onboarding.step.model.title` | `Языковая модель` | `Качество распознавания речи` |
| `session.review.title` | `Обзор сессии` | `Обзор занятия` |
| `session.hud.exit_message` | `Прогресс этой сессии не сохранится` | `Прогресс этого занятия не сохранится` |
| `family_calendar.week_summary.sessions_format` | `%@ сессий` | `%@ занятий` |
| `family_calendar.week_summary.total_sessions` | `Всего сессий` | `Всего занятий` |
| `sessionHistory.empty.noSessions.message` | `...история всех сессий` | `...история всех занятий` |
| `sessionHistory.empty.noSessions.title` | `Сессий пока нет` | `Занятий пока нет` |
| `sessionHistory.error.sessionNotFound` | `Сессия не найдена` | `Занятие не найдено` |
| `sessionHistory.a11y.rowLabelPattern` | `Сессия %@...` | `Занятие %@...` |
| `sessionHistory.a11y.summaryPattern` | `Всего %1$d сессий...` | `Всего %1$d занятий...` |
| `sessionHistory.a11y.chartTrendPattern` | `%1$d сессий: первая...` | `%1$d занятий: первое...` |
| `sessionHistory.empty.noResults.message` | `нет сессий` | `нет занятий` |
| `sessionHistory.a11y.rowHint` | `детали сессии` | `детали занятия` |
| `sessionHistory.detail.metricsTitle` | `Метрики` | `Показатели` |
| `progressDashboard.sound.sessionsPattern` | `%d сессий` | `%d занятий` |
| `settings.models.error.unavailable` | `Менеджер моделей недоступен` | `Не удалось загрузить список пакетов` |
| `settings.data.footer` | `Экспорт данных по запросу GDPR. Очистка кэша...` | `Вы можете скачать все данные по запросу. Очистка временных файлов...` |
| `settings.export.confirm.message` | `Будет создан JSON-файл со всеми сессиями...` | `Будет создан файл со всеми занятиями...` |
| `settings.export.format.json` | `JSON (для интеграций)` | `JSON (для специалиста)` |
| `settings.privacy.body` | `...с вашим аккаунтом Firebase` | `...с вашим аккаунтом` |
| `settings.notifications.weekly_summary_description` | `push-уведомления` | `уведомления` |
| `settings.licenses.openRepo` | `Открыть репозиторий` | `Открыть исходный код` |
| `settings.models.badge.active` | `АКТИВ` | `АКТИВЕН` |
| `demo.step11.title` | `История сессий` | `История занятий` |

## Kept tech terms (with reason)

| Значение | Причина сохранения |
|---|---|
| `CSV`, `JSON`, `PDF` — форматы файлов в export UI | Форматы файлов понятны специалистам; в specialist-контуре приемлемо |
| `AR-игры`, `AR-упражнения`, `AR-маски` | Устоявшийся термин приложения, понятен из контекста камеры |
| Тексты лицензий (`settings.licenses.body.*`) | Юридические тексты — обязательная форма |
| `settings.models.whisper.*` — названия Whisper-пакетов | Технические имена пакетов — идентификаторы, не UI-текст |
| `settings.healthkit.*` — Apple Health | Бренд-название Apple, замена исказит смысл |

## Рекомендации

- При добавлении новых строк — не использовать: «сессия», «модель», «менеджер», «репозиторий», «JSON/CSV» в тексте для детей и родителей
- Специалистский контур может использовать технические термины умеренно
- Слово «сессия» заменить везде на «занятие» как стандарт проекта
