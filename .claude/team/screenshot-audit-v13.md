# Screenshot Audit v13

**Date**: 2026-05-01
**Plan**: v13 Iteration 6 Block Q
**Agent**: ios-debugger

---

## Coverage

- iPhone 17 Pro: 4 уникальных экрана (14 снятых)
- iPhone SE (3rd generation): 1 экран (краш при запуске)
- Mac Designed for iPhone: не тестировалось

**Total unique screens audited**: 5

---

## Screens audited

### iPhone 17 Pro
- Splash Screen (красный Launch Screen)
- Onboarding Step 1 — "Привет! Я Ляля"
- Onboarding Step 2 — "Кто пользуется приложением?"
- Onboarding Step 3 — "Как зовут ребёнка?"

### iPhone SE (3rd generation)
- Crash at launch — Home Screen (приложение крашится немедленно)

### Не достигнуто (P0 краш блокирует навигацию)
- ChildHome, ParentHome, FamilyHome
- LessonPlayer, LetterTracing, ObjectHunt
- SpectrogramVisualizer, LyalyaRealityKit
- Settings, Changelog, Achievements, Rewards
- ARMirror, MimicLyalya

---

## P0 Crash — Critical (блокирует всю навигацию)

**EXC_CRASH / SIGABRT при каждом запуске приложения** — 100% воспроизводимость на обоих симуляторах.

### Crash stack trace (идентично на обоих устройствах)

```
-[RLMRealm verifyThread]                                 RLMRealm.mm:242
RLMVerifyRealmRead(RLMRealm*)                            RLMObjectStore.mm:48
RLMGetObjects                                            RLMObjectStore.mm:196
Realm.objects<A>(_:)                                     Realm.swift:723
RealmActor.fetchFilteredMapped<A, B>(_:predicate:map:)   RealmActor.swift:78
LiveSessionRepository.fetchRecent(childId:limit:)        SessionRepository.swift:142
SpotlightIndexCoordinator.indexSessions()                SpotlightIndexCoordinator.swift:124
```

### Причина бага

`RealmActor.open()` открывает Realm с `queue: nil` (RealmActor.swift:56):
```swift
let opened = try Realm(configuration: config, queue: nil)
```
Это привязывает инстанс Realm к потоку вызова `open()`. Функция `fetchFilteredMapped` (строка 76-79) синхронная — не `async`. При вызове `try await realmActor.fetchFilteredMapped(...)` из SpotlightIndexCoordinator Swift concurrency hop-ает на cooperative thread pool, откуда Realm.verifyThread() обнаруживает несоответствие потоков и бросает исключение → SIGABRT.

### Рекомендуемый fix

В `SessionRepository.swift:142` заменить синхронный вызов на async-вариант:

```swift
// БЫЛО:
let all = try await realmActor.fetchFilteredMapped(Session.self, predicate: predicate, map: \.asDTO)

// СТАЛО:
let all = try await realmActor.fetchFilteredMappedAsync(Session.self, predicate: predicate, map: \.asDTO)
```

`fetchFilteredMappedAsync` (RealmActor.swift:127-134) использует `Realm(actor: self)` который корректно привязан к актор-изолятору.

Аналогичная проверка нужна для всех синхронных методов RealmActor (`fetchAllMapped`, `fetchMapped`, `fetchFilteredMapped`, `writeVoid`, `updateField`, `delete`) — все они должны вызываться только из actor-изолированного контекста, не из cooperative thread pool.

---

## Visual Analysis

### Splash Screen (iPhone 17 Pro)
- Solid coral/red фон — соответствует brand color primaryRed
- Нет лого, нет анимации, нет маскота — минималистично, приемлемо
- Dynamic Island интегрирован корректно

### Onboarding Step 1 — "Привет! Я Ляля" (iPhone 17 Pro)
- Заголовок с эмодзи бабочки — тёплый детский tone, верный
- Подзаголовок 2 строки, читается без усечения
- Кнопка "Начать" — оранжевая, контрастная, достаточный touch target
- Progress "Шаг 1 из 10" — 10 шагов чрезмерно много для детского онбординга
- Иллюстрация: превью-кадр с рукой на тёмном фоне — Ляля как персонаж не считывается

### Onboarding Step 2 — "Кто пользуется приложением?" (iPhone 17 Pro)
- 3 card-варианта: Родитель / Логопед / Ребёнок — иконки соответствуют
- Родитель выбран по умолчанию — оранжевый чекмарк
- Все описания на русском, понятные
- Подсказка от Ляли внизу — хорошая персонализация
- Фон светло-розовый при выборе — корректный visual feedback

### Onboarding Step 3 — "Как зовут ребёнка?" (iPhone 17 Pro)
- TextField с placeholder "Введи имя"
- 6 аватаров-зверят: котик, собачка, лисичка, медведь, панда, лев
- Кнопка "Далее" деактивирована до ввода имени — правильно
- Возраст ребёнка не запрашивается — потенциальная потеря для адаптивной системы

### iPhone SE (3rd generation)
- Краш до отображения любого экрана
- App Icon: placeholder (нет кастомной иконки) — виден на Home Screen

---

## Issues Summary

| Severity | Count | Description |
|---|---|---|
| P0 | 1 | EXC_CRASH SIGABRT на запуске: Realm thread violation в SpotlightIndexCoordinator (100% воспроизводимость) |
| P1 | 2 | (1) App Icon placeholder на обоих симуляторах; (2) Firebase не сконфигурирован |
| P2 | 3 | (1) 10 шагов онбординга — много; (2) Ляля не считывается как персонаж на Step 1; (3) Возраст ребёнка не собирается |

---

## Visual Quality Scores

(На основе 4 экранов онбординга iPhone 17 Pro)

| Параметр | Score | Комментарий |
|---|---|---|
| Brand consistency | 7/10 | Цвет, шрифт, русский язык верны. Иконка отсутствует |
| Russian text | 9/10 | Все тексты корректно русские, нет усечений |
| Spacing | 8/10 | Комфортные отступы на 17 Pro |
| Animation | N/A | Статичные скриншоты, анимации не оценивались |
| Accessibility | 7/10 | Достаточный контраст кнопок, крупный шрифт |

---

## Recommendation

**NOT READY — P0 fix обязателен.**

Краш в `SpotlightIndexCoordinator.indexSessions()` блокирует весь пользовательский флоу после онбординга. Ни один основной экран (ChildHome, LessonPlayer, LetterTracing и др.) не может быть проверен до исправления Realm threading.

### Action items:
1. Fix P0: `LiveSessionRepository.fetchRecent` — заменить `fetchFilteredMapped` на `fetchFilteredMappedAsync`
2. Аудит всех остальных синхронных вызовов RealmActor из async-контекстов
3. Fix P1: добавить App Icon в Assets.xcassets
4. Повторить screenshot тур после P0 fix (цель: 30+ экранов)

