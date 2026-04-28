# Firebase Runbook — HappySpeech

Проект: `happyspeech-dfd95` (регион `eur3`)

---

## Деплой

```bash
# Только rules
firebase deploy --only firestore:rules --project happyspeech-dfd95

# Только indexes
firebase deploy --only firestore:indexes --project happyspeech-dfd95

# Только functions
firebase deploy --only functions --project happyspeech-dfd95

# Всё сразу
firebase deploy --project happyspeech-dfd95

# Dry-run (только синтаксис rules)
firebase deploy --only firestore:rules --dry-run --project happyspeech-dfd95
```

---

## Customization Ляли (Plan v9 F2)

- Коллекция: `users/{uid}/customization/{document}`
- Схема документа: `skin`, `color`, `voice`, `updatedAt`
- Auth-guard: только аутентифицированный не-анонимный пользователь (`sign_in_provider != 'anonymous'`)
- Enum-валидация при write:
  - `skin`: `classic | princess | scientist | athlete | artist`
  - `color`: `warm | cool | nature`
  - `voice`: `classic | soft | cheerful`
- Индекс: не требуется (single document per user, без range queries)
- Cloud Function: не требуется на текущем этапе

Реализовано в `firestore.rules` v1.2 (2026-04-28).

---

## Версии rules

| Версия | Дата       | Изменения                                      |
|--------|------------|------------------------------------------------|
| 1.0    | 2026-04-22 | Базовые правила (M1, sprint backend-dev-infra) |
| 1.1    | 2026-04-22 | isAdmin custom claim, specialist consent, rewards, routes, weekly_reports, assignments, content packs, audits |
| 1.2    | 2026-04-28 | Customization Ляли — Plan v9 F2                |

---

## Emulator

```bash
firebase emulators:start --only firestore,functions --project happyspeech-dfd95
```

UI: http://localhost:4000

---

## Smoke-тест после деплоя

1. `firebase_get_security_rules` — правила совпадают с `firestore.rules`
2. `firestore_list_indexes` — все 9 индексов в статусе READY
3. `functions_list_functions` — 4 функции в `europe-west3`
4. Запустить `functions/seed.js` в окружении `dev`, убедиться что данные появились
