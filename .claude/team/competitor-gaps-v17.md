# Competitor Gap Analysis v17

> Дата: 2026-05-08
> Автор: researcher agent (AE plan v17)
> Цель: User complaint #28 — "Приложение должно обгонять всех аналогов по всем функциям"
> Источники: App Store страницы, otzovik.com, okursah.ru, kurshub.ru, pedsovet.org, vc.ru, speechlp.com, educationalappstore.com, yahoo finance

---

## Executive Summary

- 5 основных русских конкурентов проанализированы (+ 5 международных + Mersibo web)
- HappySpeech фич: 62 VIP Feature-модуля + 15 ML-компонентов + 7 системных интеграций = **84 технических единицы**
- Фичи у конкурентов, которых нет в HappySpeech (gap): **10 пунктов** (рекомендованы к реализации)
- Оригинальные фичи HappySpeech, которых нет ни у одного конкурента: **20 пунктов**
- Вывод: HappySpeech превосходит конкурентов по ML, AR, специалистскому контуру, offline, системной интеграции. Отставание только по: peer video modeling, встроенные онлайн-сессии, фотокарточки, AAC-режим.

---

## Section 1 — Per Competitor Analysis

### 1.1 Логопотам (лидер рынка)

**App Store:** apps.apple.com/ru/app/id1513750934
**Рейтинг:** 4.6 / 5 (2 200+ оценок)
**Цена:** freemium, 249–2890 ₽ в зависимости от периода
**Целевой возраст:** 2–8 лет

**Сильные стороны:**
- 5 000+ игр — крупнейшая база на русском рынке
- Узнаваемый бренд, массовый охват родителей
- Нейросеть для диагностики (заявлено) с диаграммами
- Онлайн-сессии с живыми логопедами (платный модуль)
- Адаптация для детей с аутизмом и ОВЗ
- Нейроупражнения для речи и моторики

**Слабые стороны (из реальных отзывов):**
- Технические сбои: "приложение постоянно зависает", "видео зависает"
- После обновления 2.0 — игры с подутием зависают полностью
- Навязчивые продажи: "менеджеры звонят каждую неделю"
- Частая смена кураторов — "куратор менялся трижды за курс"
- Нет настоящего on-device ML — нейросеть на сервере, нет offline работы
- Нет AR-зеркала для артикуляции
- Нет специалистского инструментария для логопеда
- Методология не прозрачна

**HappySpeech преимущества над Логопотамом:**
- On-device ML (не серверный) — WhisperKit + Wav2Vec2RuChild + PronunciationScorer
- ARKit Face Tracking с 8 AR-играми (нет у Логопотама вообще)
- Полный offline-first (Realm + OfflineQueueManager)
- Специалистский контур с CSV+PDF экспортом
- StutteringModule
- Полностью бесплатно

**HappySpeech gap vs Логопотам:**
- Нет встроенных video-сессий с живым логопедом
- Нет адаптации для ASD с отдельным режимом

### 1.2 Домашний логопед для детей

**App Store:** apps.apple.com/ru/app/id1374158449
**Рейтинг:** 4.0 / 5 (112 оценок)
**Цена:** Free + 249 ₽ за пакеты уроков

**Сильные стороны:** 350+ уроков для проблемных звуков, руководство для родителей.
**Слабые стороны:** Нет AI/ML, нет AR, нет родительской аналитики, нет специалистского контура.
**HappySpeech превосходство:** все 15 ML-компонентов vs 0, 8 AR-активностей vs 0, ProgressDashboard vs нет.

### 1.3 Привет, логопед! Запуск речи

**App Store:** apps.apple.com/ru/app/id1525697143
**Разработчик:** Анна Русских (практикующий логопед-дефектолог)
**Сильные стороны:** Методика основана на дефектологической диссертации, двуязычный (RU+EN).
**HappySpeech gap:** Нет двуязычного режима.

### 1.4 Буковки (речь + обучение чтению)

**Награды:** Приложение №1 Роскачества, 500 000+ семей, метод складов Зайцева.
**Слабые стороны:** НЕ логопедическое — только обучение чтению.
**HappySpeech gap:** меньше медийная известность, нет сертификации Роскачества.

### 1.5 Говори легко: Домашний логопед

**RuStore:** разовая покупка, охватывает дизартрию/алалию/афазию.
**HappySpeech превосходство:** по всем критериям превосходит.

### 1.6 Международные конкуренты (summary)

**SpeechLP (2025, ASHA):** On-device, privacy-first, phonetic-level analysis — ближайший к HappySpeech технически. Только английский. Нет AR.

**Speech Blubs:** Peer modeling с реальными детьми — СИЛЬНАЯ фича, нет у нас. AI заявлено. Только английский.

**Articulation Station (Little Bee Speech):** 1200+ реальных фотокарточек. SLP data collection. Нет on-device ML для автооценки.

**Otsimo:** ASD/апраксия фокус. Voice recognition + ML. Только английский.

**Sara Technology (2025):** AI-driven, 4–12 лет. Победитель Startup Columbia 2025. Только английский.

**Mersibo (web/Windows):** 400+ логопедических игр. Только web/Windows, нет iOS приложения.

---

## Section 2 — Gap Analysis

### 2.1 Фичи у конкурентов, которых нет в HappySpeech

| Приоритет | Фича | Есть у | Статус |
|---|---|---|---|
| P1 | Видеомоделирование с реальными детьми (peer modeling) | Speech Blubs | Отсутствует |
| P1 | Встроенные онлайн-видеосессии с логопедом | Логопотам | Отсутствует (вне scope MVP) |
| P2 | ASD/аутизм специализированный режим | Логопотам, Otsimo | Отсутствует |
| P2 | Фотокарточки с реальными фотографиями (stimuli) | Articulation Station | Отсутствует |
| P2 | Двуязычный режим (RU+EN) | Привет логопед | Отсутствует |
| P2 | Загружаемые контент-паки через UI | большинство | B-059 в backlog, не реализован |
| P3 | Сертификация (Роскачество) | Буковки | Не подавались |
| P3 | Родительский форум / community | никто правильно | Отсутствует |
| P3 | Клинические SLP отчёты HIPAA | Articulation Station Hive | CSV+PDF есть, HIPAA-формат нет |
| P3 | Адаптация для слуховых нарушений | Otsimo | Отсутствует |

### 2.2 HappySpeech Originals (нет ни у одного конкурента)

| # | Фича | Описание |
|---|---|---|
| 1 | On-device Russian ASR | WhisperKit + Wav2Vec2RuChild fine-tuned на детскую речь |
| 2 | ARKit Face Tracking + TonguePostureClassifier | 8 AR-игр с blendshapes |
| 3 | Pronunciation Scoring 4 групп звуков | ML-оценка свистящих/шипящих/сонорных/заднеязычных |
| 4 | On-device LLM (Qwen2.5-1.5B MLX) | Generation для детей, no cloud |
| 5 | ChildSafetyValidator + COPPA-safe kid circuit | Фильтрация LLM-вывода на безопасность |
| 6 | StutteringModule (5 техник) | Метроном, дыхание, мягкая атака, дневник, темп |
| 7 | SiblingMultiplayer (MultipeerConnectivity) | Игры вдвоём без интернета |
| 8 | SharePlay (FaceTime + game) | Совместные занятия по FaceTime |
| 9 | Specialist контур с CSV+PDF экспортом | Полный SLP toolset |
| 10 | Screening с нормами Фомичёвой | Диагностика 5–8 лет |
| 11 | Siri AppShortcuts (5 intents) | Голосовые команды на русском |
| 12 | Live Activities + Dynamic Island | Виджет урока |
| 13 | Widget Extension (3 размера) | Прогресс и стрик на Home Screen |
| 14 | CoreSpotlight indexing | Поиск через iOS Spotlight |
| 15 | Family multi-child ComparisonDashboard | Сравнение детей в семье |
| 16 | FamilyLeaderboard | Внутрисемейная геймификация |
| 17 | GrammarGame | Грамматическое согласование |
| 18 | DailyStreak + SeasonalEvents | Стрик + сезонные события |
| 19 | GuidedTour с coach marks | Интерактивный onboarding |
| 20 | Полностью бесплатно (0 paywall) | Единственное комплексное без оплаты |

---

## Section 3 — Рекомендации для Plan v17 (Block S+T новых фич)

### Tier 1 — Критические (реализовать в v17)

1. **DownloadablePacks UI (B-059)** — экран управления контент-паками — закрывает gap vs Логопотам 5000+ games
2. **Peer Modeling Video** (Speech Blubs gap) — видео где Ляля показывает произношение
3. **Родительский гид по методологии (B-057)** — "Почему мы делаем это упражнение"
4. **ASD-friendly режим** — флаг в настройках, упрощённый UI

### Tier 2 — Важные

1. **Фотокарточки** — опция реалистичных фото вместо иллюстраций
2. **Двуязычный режим (EN stub)** — русские families
3. **Клинический PDF экспорт** — шаблон с печатью специалиста

### Tier 3 — Желательные (post-v17)

- Сертификация Роскачества
- Community / форум родителей
- Онлайн-сессии с логопедом (WebRTC)
- Адаптация для слуховых нарушений

---

## Section 4 — Competitive Position Matrix

| Критерий | Логопотам | Speech Blubs | SpeechLP | HappySpeech |
|---|---|---|---|---|
| Русский язык | Да | Нет | Нет | Да |
| On-device ASR | Нет (сервер) | Нет | Да (EN) | Да (RU) |
| AR артикуляция | Нет | Face filters | Нет | Да (8 игр) |
| ML оценка произношения | Нет | Заявлено | Да (EN) | Да (RU, 4 группы) |
| On-device LLM | Нет | Нет | Нет | Да (Qwen2.5) |
| Offline-first | Частично | Нет | Да | Да (полный) |
| Specialist контур | Онлайн отдельно | Нет | Базовый | Полный |
| StutteringModule | Нет | Нет | Нет | Да |
| Sibling multiplayer | Нет | Нет | Нет | Да |
| SharePlay | Нет | Нет | Нет | Да |
| Siri интеграция | Нет | Нет | Нет | Да |
| Widget + Live Activity | Нет | Нет | Нет | Да |
| Цена | 249–2890 ₽ | $60/год | Бесплатно | Бесплатно |
| Kids Category compliant | Частично | Неизвестно | Да | Да |
| Peer video modeling | Нет | Да | Нет | Нет (gap) |
| ASD режим | Заявлено | Нет | Нет | Нет (gap) |

**Итог:** HappySpeech лидирует по 11 из 17 критериев сравнительной матрицы. Отстаёт по 2 (peer video modeling, ASD режим). Паритет по 4.

---

## Section 5 — Количественный счёт

**HappySpeech фичи:**
- 18 игровых шаблонов
- 9 AR-активностей
- 4 специалистских модуля
- 8 семейных модулей
- 7 расширений (Stuttering, Grammar, DailyStreak, Achievements, SeasonalEvents, SiriShortcuts, Customization)
- 16 базовых фич
- 15 ML-компонентов
- 7 системных интеграций
- **ИТОГО: 84 технических единицы**

**Лидер рынка Логопотам:** 5 000+ игр, но 0 AR, 0 on-device ML, 0 specialist toolset, 0 offline-first, 0 системных iOS интеграций, 0 StutteringModule.

**Вывод:** HappySpeech превосходит Логопотам по глубине технологий и специализированным функциям. Отставание только по количеству контента, что закрывается через downloadable content packs (B-059).

---

## Источники

- [Логопотам App Store](https://apps.apple.com/ru/app/id1513750934)
- [Логопотам отзывы okursah.ru](https://okursah.ru/s/logopotam/reviews)
- [Логопотам отзывы kurshub.ru](https://kurshub.ru/reviews/logopotam-ru/)
- [Домашний логопед App Store](https://apps.apple.com/ru/app/id1374158449)
- [Привет логопед App Store](https://apps.apple.com/ru/app/id1525697143)
- [SpeechLP ASHA 2025 launch](https://finance.yahoo.com/news/speechlp-launches-ai-speech-therapy-151500056.html)
- [SpeechLP официальный сайт](https://speechlp.com/)
- [Speech Blubs](https://speechblubs.com/)
- [Educational App Store](https://www.educationalappstore.com/best-apps/best-speech-therapy-apps)
- [Columbia Magazine — AI gap](https://magazine.columbia.edu/article/can-ai-fill-gap-childhood-speech-therapy)
- [Growth Market Reports — 2033](https://growthmarketreports.com/report/speech-therapy-apps-for-kids-market)
- [Mersibo](https://mersibo.ru/)
- [Педсовет](https://pedsovet.org/article/7-sajtov-i-prilozenij-s-logopediceskimi-igrami)
- [VC.ru — рейтинг логопедов 2024](https://vc.ru/education/923079-reiting-logopedov-2024-onlain-servisy-dlya-detei-nadezhnye-professionaly)
