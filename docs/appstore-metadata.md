# App Store Metadata — HappySpeech

> S12-019 — Финальная версия для App Store Connect  
> Автор: Антон Гриц (Anton Hryts)  
> Bundle ID: ru.happyspeech.app  
> Дата: 2026-05-09 (v18 final update — Block AJ)
> Tag: v1.0.0-final-v18
>
> **NOT submitting к App Store в v1.0** — пользователь без Apple Developer Program ($99/yr).
> Metadata готов для будущего submission когда account активирован.

---

## What's New (v1.0.0-final-v18 + post-tag)

### Production-quality milestone

| Компонент | Метрика |
|---|---|
| Интерактивные экраны | 105+ (*View.swift) |
| Аудио файлы Ляли | 14 501 .m4a (edge-tts SvetlanaNeural) |
| Иллюстрации | 154 imagesets / 600 PNG (FLUX-1-schnell) |
| MP4 motion-design | 117+ (Remotion) |
| Core ML модели | 12 .mlpackage (Wav2Vec2 302 MB real) |
| DesignSystem компоненты | 41 (HSCustom* family) |
| Apple HIG violations | 0 P0 / 0 P1 (96–97% compliance) |
| Cloud Functions enforceAppCheck | 14/14 (kids safety) |
| EN ключей в UI | 0 (3 827 ru keys) |

### Features

- Логопедический анализатор речи (Wav2Vec2 + 4 PronunciationScorer)
- 3D маскот Ляля с blendshapes (8 emotions + 5 lip-sync visemes)
- AR упражнения артикуляции (TrueDepth Face Tracking)
- Семейная синхронизация прогресса (Firestore)
- Adaptive learning planner (skill stages C, V → C, V → C, V)
- Spaced repetition engine (forgetting curve based)
- 25 content packs / 7 555+ lessons (русский / IPA G2P)
- Полностью offline-first работа

### Architecture

- Swift 6 strict concurrency
- iOS 17+ SwiftUI 6
- Clean Swift VIP per feature
- Realm Swift локальная БД
- Firebase backend (Auth / Firestore / FCM / Storage / AppCheck / RemoteConfig / Performance)

### Quality bars

- Light/Dark adaptive (49+ files)
- Reduce Motion compliance
- VoiceOver labels (97% coverage)
- Touch targets ≥56pt Kids / ≥44pt adults
- Dynamic Type Small → AccessibilityLarge
- WCAG AA contrast (≥4.5:1)
- Bundle: 1.4 GB (real ML models, voices, content)

---

## GitHub Pages Deploy (post-v1.0)

Privacy Policy URL и Terms URL должны быть accessible при сабмите:

- https://antongrits.github.io/HappySpeech/privacy-policy.html
- https://antongrits.github.io/HappySpeech/terms.html

Deploy команда (когда нужно):

```bash
# Settings → Pages → Branch main → /docs folder
git push origin main  # GitHub Pages автоматически рендерит /docs
```

Currently: НЕ deployed (404). Будет deployed когда Apple Developer Program активирован и нужна submission.

Локальные файлы готовы:
- `docs/privacy-policy.html`
- `docs/privacy-policy.md`
- `docs/terms.html`
- `docs/terms-of-service.md`

---

## ОБЩИЕ ДАННЫЕ (не зависят от языка)

| Поле | Значение |
|------|---------|
| Bundle ID | ru.happyspeech.app |
| SKU | HAPPYSPEECH-2026-001 |
| Primary Category | Education |
| Secondary Category | Games — Family |
| Age Rating | 4+ (Kids Category) |
| Price | Free |
| In-App Purchases | No |
| Subscriptions | No |
| Ads | No |
| Primary Language | Russian |
| Support URL | https://github.com/antongrits/HappySpeech/issues |
| Privacy Policy URL | https://antongrits.github.io/HappySpeech/privacy |
| Marketing URL | https://antongrits.github.io/HappySpeech/ |
| Copyright | © 2026 Anton Hryts |

---

## v18 HIGHLIGHTS (2026-05-08)

Что добавлено в v1.0.0-final-v18 по сравнению с предыдущими тегами:

| Компонент | Метрика |
|---|---|
| Интерактивные экраны | 105+ (*View.swift) |
| Аудио файлы Ляли | 14 501 .m4a |
| Контент-единицы (уроки) | 7 555 в 25 паках |
| Core ML модели | 12 .mlpackage (304+ MB total) |
| DesignSystem компоненты | 41 (HSCustom* family) |
| Cloud Functions | 16 (6 новых callable v18 + 10 baseline) |
| AR игры | 10 (face tracking + blendshapes) |
| 3D маскот Ляля | USDZ 744 KB + RealityKit blendshapes |
| Snapshot тестов | 469 PNG (light + dark) |
| Эмодзи в UI строках | 0 (заменены на SF Symbols) |
| Hardcoded hex цвета | 0 (86 → 0, ColorTokens) |
| HealthKit refs | 0 (полностью удалён) |
| SwiftLint --strict | 0 ошибок |
| BUILD | SUCCEEDED iPhone SE (3rd generation) |

---

## РУССКАЯ ЛОКАЛИЗАЦИЯ (ru)

### Название (Name) — max 30 символов

```
HappySpeech — Логопед
```

Символов: 21

### Подзаголовок (Subtitle) — max 30 символов

```
Игры для развития речи детей
```

Символов: 29

### Описание (Description) — max 4000 символов

```
HappySpeech — домашний логопед в телефоне для детей 5–8 лет.

Приложение помогает детям научиться правильно произносить звуки через весёлые игры. Маскот Ляля ведёт занятие, хвалит ребёнка и показывает, что делать дальше. Никаких скучных заданий — только игра.

Как это работает:
• Ребёнок играет в речевые игры по 10–15 минут в день
• Приложение слушает произношение прямо на устройстве — аудио не уходит в интернет
• Родитель видит прогресс: какие звуки даются хорошо, а над чем ещё работать
• Специалист-логопед может подключиться и получить подробный отчёт

16 видов речевых игр:
— «Слушай и выбирай» — различаем похожие звуки на слух
— «Повтори за героем» — тренируем правильный звук в слогах и словах
— «Перетащи и соедини» — учим слова с нужным звуком
— «Охотник за звуком» — ищем звук в тексте
— «Минимальные пары» — отличаем слова, похожие по звучанию
— Артикуляционная гимнастика через камеру — следи за положением языка
— Дыхательные упражнения, ритм, истории и ещё 9 видов заданий

Для каких звуков:
• Свистящие — С, З, Ц
• Шипящие — Ш, Ж, Ч, Щ
• Соноры — Р, Рь, Л, Ль

Умный план занятий:
Приложение само составляет расписание с учётом возраста ребёнка, его успехов и времени суток. Трудные задания появляются в начале, когда ребёнок свеж. Пройденный материал повторяется через нужное время — так звуки закрепляются надолго.

Три роли в одном приложении:
— Ребёнок: игры с Лялей, наклейки и награды за успехи
— Родитель: отчёты о прогрессе, рекомендации, история занятий
— Логопед: подробная статистика, экспорт отчётов, профессиональные инструменты

Безопасно для детей:
• Нет рекламы и встроенных покупок
• Нет внешних ссылок без подтверждения родителя
• Аудио и видео обрабатываются только на устройстве
• Соответствует требованиям COPPA и Kids Category App Store
• Работает полностью без интернета

Для диплома разработчик благодарит: Филичеву Т.Б., Жукову Н.С. — методику которых положена в основу содержания занятий.
```

Символов: ~1 820

### Рекламный текст (Promotional Text) — max 170 символов

```
Бесплатно. Без рекламы. Маскот Ляля помогает вашему ребёнку научиться правильно говорить — всего 10 минут в день!
```

Символов: 115

### Ключевые слова (Keywords) — max 100 символов, через запятую

```
логопед,речь,дети,произношение,артикуляция,звуки,фонематика,занятия,автоматизация,дислалия
```

Символов: 90

> Пояснение по выбору: слова «логопед», «произношение», «дети», «речь» — самые частотные запросы родителей в российском App Store. «Фонематика», «автоматизация», «дислалия» дают длинный хвост от родителей, уже посещавших специалиста. «Артикуляция» и «звуки» — широкие смежные запросы. Слово «HappySpeech» не включено: оно уже в названии и App Store его индексирует автоматически.

### Что нового (What's New / Release Notes)

```
Версия 1.0 — первый выпуск

HappySpeech появился в App Store!

В приложении:
• 16 видов речевых игр для работы над звуками С, З, Ц, Ш, Ж, Ч, Щ, Р, Л
• Маскот Ляля ведёт занятия и поддерживает ребёнка
• Умный планировщик составляет расписание с учётом прогресса
• Артикуляционные упражнения через камеру (10 AR игр)
• Оценка произношения прямо на устройстве — без интернета
• Дашборд прогресса для родителей
• Инструменты для логопедов: статистика и экспорт отчётов
• 3D маскот Ляля с анимацией и синхронизацией губ
• Семейная синхронизация прогресса через Firebase
• 14 500+ профессиональных аудио фраз маскота

Работает на iPhone. Требует iOS 17 или новее.
```

### Что нового (v1.0.0-final-v18 — внутренний тег, для документации)

```
v1.0.0-final-v18 (2026-05-08) — финальная сборка перед дипломной защитой

Основные изменения:
• 105+ интерактивных экранов с современным дизайном
• 14 500+ аудио фраз Ляли (профессиональный голос, edge-tts SvetlanaNeural)
• 7 555 уроков в 25 паках (нейролингвистическая методика)
• 12 Core ML моделей (Wav2Vec2 для детской русской речи, 302 MB)
• 16 Cloud Functions в Firebase (6 новых: scoreSpeechQuality, generateNeurolinguistSummary, и др.)
• 10 AR игр с отслеживанием лица и 3D Лялей
• Кабинет специалиста: программы, сессии, PDF-отчёты, чат с логопедом
• Семейная карта прогресса, сравнение детей, достижения семьи
• 41 компонент дизайн-системы (HSCustom* family, kavsoft-паттерны)
• 0 эмодзи в UI, 0 hardcoded цветов, 0 английских ключей
• Полное соответствие Apple HIG + WCAG AA
```

---

## АНГЛИЙСКАЯ ЛОКАЛИЗАЦИЯ (en-US)

### Name — max 30 characters

```
HappySpeech: Speech Therapy
```

Characters: 28

### Subtitle — max 30 characters

```
Speech games for children
```

Characters: 25

### Description — max 4000 characters

```
HappySpeech is a speech therapy app for children ages 5–8. Designed for home practice, it helps kids learn correct Russian pronunciation through fun games — guided by Lyalya, a friendly mascot character.

How it works:
• Your child plays short speech games (10–15 min per day)
• The app evaluates pronunciation on-device — audio never leaves the device
• Parents see a clear progress dashboard with recommendations
• Speech therapists can connect to access detailed reports and analytics

16 types of speech exercises:
— Listen and Choose — train phonemic awareness
— Repeat After the Character — practice correct sounds in syllables and words
— Drag and Match — learn target-sound vocabulary
— Sound Hunter — find the target sound in a sentence
— Minimal Pairs — distinguish similar-sounding words
— Articulation Practice via camera — visual feedback on mouth position
— Breathing, rhythm, storytelling games and 9 more activity types

Sound groups covered:
• Sibilants — S, Z, Ts
• Hissing sounds — Sh, Zh, Ch, Shch
• Sonorants — R, soft R, L, soft L

Smart scheduling:
The app builds a personalized daily plan based on the child's age, progress, and time of day. Harder tasks come first while the child is fresh. Previously learned material is reviewed at optimal intervals — so sounds stick for the long term.

Three roles in one app:
— Child: games with Lyalya, stickers, and rewards
— Parent: progress reports, session history, recommendations
— Speech Therapist: full statistics, professional tools, report export

Safe for children:
• No ads, no in-app purchases
• No external links without parental approval
• Audio and video processed on-device only
• COPPA compliant, App Store Kids Category compliant
• Fully offline — works without internet

Content methodology based on the work of Filitcheva T.B. and Zhukova N.S. — leading Russian speech therapy researchers.
```

Characters: ~1 750

### Promotional Text — max 170 characters

```
Free. No ads. Help your child master Russian sounds in just 10 minutes a day with Lyalya — an AI-powered speech therapy companion!
```

Characters: 130

### Keywords — max 100 characters

```
speech therapy,pronunciation,children,Russian,language,articulation,kids,learning,phonics,sounds
```

Characters: 96

### What's New

```
Version 1.0 — Initial Release

HappySpeech is now on the App Store!

What's included:
• 16 speech exercise types for sounds S, Z, Ts, Sh, Zh, Ch, R, L
• Lyalya the mascot guides every session (3D animated character)
• Smart adaptive planner based on your child's progress
• 10 AR articulation games with face tracking
• On-device pronunciation scoring — no internet required
• Parent progress dashboard with Swift Charts analytics
• Speech therapist cabinet with PDF report export
• Family progress sync via Firebase
• 14,500+ professional voice audio phrases

Works on iPhone. Requires iOS 17 or later.
```

---

## ПРАВА ДОСТУПА (Privacy Manifest / Usage Descriptions)

Эти строки идут в `Info.plist` и `AppPrivacyInfo.xcprivacy`. Для App Store Connect они также отображаются на странице конфиденциальности.

| Ключ Info.plist | Описание RU | Описание EN |
|----------------|-------------|-------------|
| NSMicrophoneUsageDescription | Микрофон нужен для оценки произношения. Запись обрабатывается только на устройстве и не передаётся. | Microphone access is required to evaluate pronunciation. Audio is processed on-device only and is never transmitted. |
| NSCameraUsageDescription | Камера используется для артикуляционных упражнений — приложение отслеживает положение губ и языка. | Camera access is used for articulation exercises. The app tracks lip and tongue position using face landmarks. No video is recorded or transmitted. |
| NSUserNotificationsUsageDescription | Уведомления напоминают ребёнку о ежедневном занятии. Их можно отключить в настройках. | Notifications remind your child about their daily practice session. You can disable them at any time in Settings. |

### Раздел Privacy Nutrition Label (App Store Connect → Privacy)

| Тип данных | Сбор | Связано с пользователем | Трекинг |
|------------|------|------------------------|---------|
| Аудио | Нет (обработка on-device, не хранится) | — | Нет |
| Данные об использовании | Да (локально, Firestore для синхронизации) | Да (UID Firebase Auth) | Нет |
| Идентификаторы | Да (Firebase UID, Sign in with Apple ID) | Да | Нет |
| Диагностика | Нет | — | Нет |

> Firebase App Check включён. Firebase Analytics НЕ подключён. Crashlytics НЕ подключён. Сторонних рекламных SDK нет.

---

## СКРИНШОТЫ (требования App Store Connect)

### Обязательные устройства

| Устройство | Разрешение | Количество |
|-----------|-----------|-----------|
| iPhone 6.9" (iPhone 16 Pro Max) | 1320 × 2868 px | 3–10 |
| iPhone 6.7" (iPhone 15 Plus) | 1290 × 2796 px | 3–10 |
| iPad Pro 13" (M4) | 2064 × 2752 px | 3–10 |

### Рекомендуемый порядок скриншотов

1. Экран ChildHome — Ляля приветствует, виден прогресс дня
2. Игра «Повтори за героем» — активная запись, волна, счётчик
3. Игра «Слушай и выбирай» — варианты ответа, анимация
4. AR-артикуляция — камера + blendshape-индикаторы
5. Награды / наклейки — ResultScreen, конфетти
6. Дашборд родителя — Swift Charts, период, рекомендации
7. Настройки / роли — переключение контуров
8. Онбординг — слайд выбора звуковой группы

### Текст на скриншотах (overlay)

| Скриншот | Текст RU | Текст EN |
|---------|---------|---------|
| 1 | «Учимся говорить — вместе с Лялей» | "Learn to speak — with Lyalya" |
| 2 | «Слушай. Повторяй. Получай звёздочки» | "Listen. Repeat. Earn stars" |
| 3 | «16 видов речевых игр» | "16 types of speech games" |
| 4 | «Артикуляция через камеру» | "Articulation via camera" |
| 5 | «Наклейки и награды за каждое занятие» | "Stickers & rewards every session" |
| 6 | «Родитель видит каждый шаг» | "Parents see every step" |
| 7 | «Три роли: ребёнок, родитель, логопед» | "Three roles: child, parent, therapist" |
| 8 | «Работает без интернета» | "Works offline" |

---

## ЧЕКЛИСТ ПЕРЕД САБМИТОМ

- [ ] Privacy Policy URL отвечает (200 OK): https://antongrits.github.io/HappySpeech/privacy
- [ ] Support URL отвечает (200 OK): https://github.com/antongrits/HappySpeech/issues
- [ ] Все поля заполнены в App Store Connect (ru + en-US)
- [ ] Скриншоты загружены для iPhone 6.9" и iPad Pro 13"
- [ ] Age Rating: 4+ выбран, Kids Category включена
- [ ] Раздел Privacy Nutrition Label заполнен (Data Types)
- [ ] AppPrivacyInfo.xcprivacy добавлен в таргет приложения
- [ ] TestFlight build прошёл Automated Review
- [ ] Build выбран как версия для Review (не Beta)
- [ ] Review Notes для App Review Team (на английском):
  > "This is a Russian-language speech therapy educational app for children ages 5-8. To test: create an account (or use Sign in with Apple), select a child profile, choose a sound group (e.g. 'Ш'), and start any game. Microphone and camera permissions are required for core functionality. The app works fully offline after initial launch."

---

## СТАТУС v18 (2026-05-09 — Block AJ final)

| Критерий | Статус |
|---|---|
| App Store metadata ru + en | READY |
| What's New v18 section | DONE (Block AJ) |
| Privacy Policy (.md + .html) | DONE |
| Terms of Service (.md + .html) | DONE |
| GitHub Pages deploy | DEFERRED (нет Apple Developer Account) |
| AppPrivacyInfo.xcprivacy | DONE (Sprint 12, S12-018) |
| Firebase backend | LIVE (happyspeech-dfd95, europe-west3) |
| BUILD SUCCEEDED | VERIFIED (iPhone SE 3rd generation) |
| SwiftLint --strict 0 errors | VERIFIED |
| 0 EN ключей в UI | VERIFIED (3 827 ru keys) |
| 0 эмодзи в UI | VERIFIED |
| TestFlight submission | BLOCKED (нет платного Apple Developer Account) |
| App Store submission | DEFERRED (explicit — автор подтвердил) |

**Tag:** v1.0.0-final-v18
**Автор:** Anton Hryts (antongrits)
**Дата финальной сборки:** 2026-05-08
**Block AJ metadata pass:** 2026-05-09
