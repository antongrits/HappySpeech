# ТЗ на 3 новые фичи — Phase 6.1 (v25)
## HappySpeech — финальный релиз дипломного проекта
> Автор: speech-specialist  
> Дата: 2026-05-17  
> Статус: утверждено к реализации

---

## Обоснование выбора

### Почему именно эти три

**Фича 1 — WeeklySoundReport (Еженедельный звуковой отчёт для родителя)**  
Родительский контур сейчас даёт ProgressDashboard с дневной детализацией и HomeTasks с рекомендациями. Но нет сводного недельного взгляда: что улучшилось за 7 дней, какой звук требует внимания, сколько занятий провёл ребёнок. Это типичный pain point реальных родителей (подтверждён конкурентным анализом в `competitor-gap-v21.md`). Фича читает только уже имеющиеся Realm-данные (Session, ProgressEntry, ChildProfile) — никакой новой инфраструктуры.

**Фича 2 — ArticulationGymView (Артикуляционная гимнастика без AR)**  
В LessonPlayer уже есть `articulation-imitation` (шаблон) и `ARZone` (требует камеру). Но нет автономного экрана разминки, куда ребёнок может зайти сам перед занятием без входа в сессию. Артикуляционная гимнастика — обязательный этап 0 в методике (therapy-stages.md). Реализуется через статичные SVG-иллюстрации + таймер + маскот Ляля без AR, микрофона, ML.

**Фича 3 — WordBankView (Копилка слов ребёнка)**  
Все отработанные слова уже хранятся в Attempt.word внутри Session. Но нигде в детском контуре нет «полки», где ребёнок видит свою коллекцию освоенных слов — это мощный мотивационный инструмент (принцип положительного подкрепления из methodology). Фича агрегирует Attempt-записи с isCorrect=true по звуку, визуализирует как карточки в альбоме. Полностью offline, никакого нового ML.

---

## Фича 1. WeeklySoundReport — «Итоги недели» для родителя

### Контур
Родительский (Parent Circuit)

### Методическое обоснование
Родитель должен видеть динамику коррекции на уровне недели, а не только отдельных дней. Согласно `parent-guidance-full.md`: «регулярная обратная связь о прогрессе повышает вовлечённость семьи в домашнюю практику и снижает тревожность». Недельный срез позволяет заметить тренды (звук улучшается / стагнирует / регрессирует) до следующего визита к логопеду. Рекомендуемая методиками частота родительской рефлексии — 1 раз в неделю.

### Пользовательский сценарий

1. Родитель открывает ParentHome в воскресенье вечером.
2. Видит баннер «Итоги недели готовы» (или заходит через таб «Прогресс» → кнопка «Неделя»).
3. Открывается WeeklySoundReportView: сверху — краткое резюме «5 занятий за неделю, лучший день — пятница», ниже — карточки по каждому целевому звуку с прогресс-кольцом и стрелкой тренда.
4. Каждая карточка звука раскрывается: топ-3 слова с высоким результатом (зелёные), топ-3 слова с ошибками (жёлтые), рекомендация на следующую неделю.
5. Кнопка «Поделиться отчётом» — UIActivityViewController с текстовым summary.

### Структура VIP

**WeeklySoundReportView.swift**
- Отображает `ViewModel` (summary-строка + массив `SoundCardViewModel`)
- Использует `HSCard`, `HSProgressRing`, `HSScrollTransitionList`
- Поддерживает Dark Mode, Dynamic Type до `.accessibilityLarge`

**WeeklySoundReportInteractor.swift**
- `loadReport(request: Load.Request)` — передаёт childId и dateRange в Worker
- `selectSound(request: SelectSound.Request)` — раскрытие карточки звука
- `shareReport(request: Share.Request)` — генерирует текстовый дайджест

**WeeklySoundReportPresenter.swift**
- Формирует `SoundCardViewModel` из ProgressEntry + Session агрегатов
- Вычисляет `trendArrow`: `.up` (Δ > +5%), `.stable` (|Δ| ≤ 5%), `.down` (Δ < -5%)
- Форматирует дни в «Пн–Вс», числа сессий в «5 занятий»

**WeeklySoundReportModels.swift**
```
enum WeeklySoundReport {
    enum Load {
        struct Request { var childId: String; var weekOffset: Int = 0 }
        struct Response { var sessions: [Session]; var entries: [ProgressEntry]; var child: ChildProfile }
        struct ViewModel { var summaryLine: String; var totalSessions: Int; var sounds: [SoundCardViewModel] }
    }
    enum SelectSound {
        struct Request { var soundTarget: String }
        struct Response { var topWords: [WordStat]; var weakWords: [WordStat]; var recommendation: String }
        struct ViewModel { var topWordsFormatted: [String]; var weakWordsFormatted: [String]; var tipText: String }
    }
    enum Share {
        struct Request {}
        struct Response { var text: String }
        struct ViewModel { var shareText: String }
    }
}

struct SoundCardViewModel: Identifiable {
    var id: String           // soundTarget
    var soundLabel: String   // "Звук Ш"
    var successRate: Double  // 0.0–1.0 за неделю
    var previousRate: Double // 0.0–1.0 за прошлую неделю
    var trendArrow: TrendArrow
    var sessionCount: Int
}

enum TrendArrow { case up, stable, down }
```

**WeeklySoundReportWorker.swift**
- `fetchWeekSessions(childId:weekOffset:) async throws -> [Session]`
- `fetchWeekEntries(childId:weekOffset:) async throws -> [ProgressEntry]`
- Использует `SessionRepository` и `ChildRepository` (уже существуют)
- Агрегация: группировка Attempt.word по targetSound, подсчёт isCorrect-rate

**WeeklySoundReportRouter.swift**
- `dismissToParentHome()`
- Запускает `UIActivityViewController` для share

### Существующие сервисы
- `SessionRepository` — запрос сессий за диапазон дат (уже есть метод fetchSessions)
- `ChildRepository` — профиль ребёнка
- `AnalyticsService` — событие `weekly_report_viewed`
- `HapticService.shared.impact(.light)` при раскрытии карточки

### UI-описание

**Шапка экрана:**
- Navigation title: «Итоги недели» (HSGlassNavigationBar)
- Subtitle: «12–18 мая 2026»
- Кнопка «‹ Прошлая неделя» / «Следующая ›» для навигации по неделям (weekOffset: Int)

**Summary-блок (HSCard, cornerRadius: 20):**
- Иконка маскота Ляля + строка «Миша позанимался 5 раз — это отличный результат!»
- HSProgressBar на 5/7 дней (показывает занятые дни из 7)

**Звуковые карточки (вертикальный список, HSCard):**
- Слева: HSProgressRing (диаметр 56 pt, цвет из DesignSystem: `.accentGreen` / `.accentYellow` / `.accentRed`)
- По центру: «Звук Ш», подпись «3 занятия», тренд-стрелка (SF Symbol: `arrow.up` / `minus` / `arrow.down`)
- Tap → раскрывается секция с зелёными и жёлтыми словами (HSPictTile без картинки, только текст)

**Рекомендация (HSCard, цвет `.surfaceSecondary`):**
- Иконка `lightbulb.fill` + текст «На следующей неделе уделите больше внимания Р в середине слова»
- Rule-based логика: если weakWords содержит слова с одинаковой позицией звука — рекомендация по этой позиции

**Кнопка «Поделиться отчётом»** (HSButton, style `.secondary`, внизу экрана)

### Данные (Realm)
| Модель | Поля | Использование |
|---|---|---|
| Session | date, targetSound, correctAttempts, totalAttempts, attempts | Фильтр по дате + childId |
| Attempt | word, isCorrect, asrScore | Агрегация слов по результату |
| ProgressEntry | soundTarget, successRate, date | Тренд: текущая vs прошлая неделя |
| ChildProfile | name, targetSounds | Заголовок + список звуков для отчёта |

### Маршрут AppCoordinator
```
case weeklyReport(childId: String, weekOffset: Int = 0)
// Вход: ParentHome → кнопка «Итоги недели» (баннер или таб Прогресс)
// push-навигация, dismissible
```

### Критерии готовности (DoD)
- [ ] Корректно агрегирует данные за текущую и предыдущую недели
- [ ] trendArrow рассчитывается верно (unit-тест на Presenter)
- [ ] weekOffset=0 → текущая неделя, weekOffset=-1 → прошлая
- [ ] Share текст локализован (ru)
- [ ] Light + Dark — snapshot-тесты
- [ ] Dynamic Type до `.accessibilityLarge` не ломает layout
- [ ] Работает offline (все данные из Realm)
- [ ] Нет print / TODO / force-unwrap
- [ ] VoiceOver: progressRing имеет `.accessibilityLabel("Успешность звука Ш: 78%")`

### Что тестировать
- **Unit (Presenter):** trendArrow при Δ=+10%, Δ=0%, Δ=-8%; summaryLine при 0 сессиях
- **Unit (Worker):** агрегация Attempt → WordStat при смешанных isCorrect
- **Snapshot:** состояния empty (0 сессий), partial (1 звук), full (3 звука)

---

## Фича 2. ArticulationGymView — «Артикуляционная разминка»

### Контур
Детский (Kid Circuit), с опциональным просмотром для родителя

### Методическое обоснование
Артикуляционная гимнастика — фундаментальный инструмент логопедической практики. По методике Фомичёвой и Нищевой: «Без регулярной артикуляционной гимнастики постановка звука невозможна». Этап 0 (articulation_prep) уже присутствует в контент-паках, но реализован только внутри LessonPlayer. Ребёнок не может пройти разминку отдельно от урока. Автономная гимнастика — это «зарядка для языка» перед любым занятием, обеспечивающая:
- готовность артикуляционного аппарата;
- снижение утомляемости при последующей работе со звуком;
- самостоятельность ребёнка (может делать без родителя).

Экран работает без микрофона, без AR, без ML — снижает барьер входа.

### Пользовательский сценарий

1. Ребёнок открывает ChildHome, нажимает кнопку «Разминка» (под миссией дня, маленький значок языка).
2. Открывается ArticulationGymView с выбором звуковой группы (свистящие / шипящие / соноры).
3. Ляля объясняет: «Сначала сделаем зарядку для язычка!»
4. Запускается карусель упражнений: 5–7 поз, каждая 5–8 секунд с автоматическим обратным счётчиком.
5. Каждое упражнение: крупная SVG-иллюстрация позы языка (из артикуляционного атласа), название («Блинчик», «Лопатка», «Чашечка»), счётчик секунд, строчка-инструкция.
6. После последнего упражнения — анимация «Готово! Язычок размят, можно тренироваться» + кнопка «Начать урок» (переход в WorldMap) или «Ещё раз».
7. Результат фиксируется в аналитике (gymCompleted event), но в отдельную Realm-запись не пишется (легковесная фича).

### Структура VIP

**ArticulationGymView.swift**
- `HSMascotView` (Ляля в анимированном состоянии «speaking»)
- `TabView` в режиме `.page` или кастомная карусель (HSScrollTransitionList)
- `ArticulationExerciseCard` — компонент: иллюстрация + счётчик + инструкция
- `HSButton` «Начать урок» на завершающем экране

**ArticulationGymInteractor.swift**
- `loadGym(request: Load.Request)` — выбирает набор упражнений по soundGroup
- `startTimer(request: StartTimer.Request)` — запускает таймер для текущего упражнения
- `nextExercise(request: Next.Request)` — переход к следующей позе
- `completeGym(request: Complete.Request)` — финальный экран + аналитика

**ArticulationGymPresenter.swift**
- Формирует `ExerciseViewModel` из JSON-данных контент-пака (stage_id: 0, type: "articulation")
- Вычисляет прогресс (currentIndex / totalCount)
- Форматирует timerText: «5», «4», «3»...

**ArticulationGymModels.swift**
```
enum ArticulationGym {
    enum Load {
        struct Request { var soundGroup: SoundGroup }
        struct Response { var exercises: [ArticulationItem] }
        struct ViewModel { var exercises: [ExerciseViewModel]; var soundGroupLabel: String }
    }
    enum TimerTick {
        struct Request { var exerciseIndex: Int; var secondsRemaining: Int }
        struct ViewModel { var timerText: String; var progress: Double }
    }
    enum Next {
        struct Request { var currentIndex: Int }
        struct Response { var nextIndex: Int; var isLast: Bool }
        struct ViewModel { var nextIndex: Int; var showCompletion: Bool }
    }
    enum Complete {
        struct Request {}
        struct ViewModel { var celebrationText: String }
    }
}

struct ExerciseViewModel: Identifiable {
    var id: String
    var title: String           // «Блинчик»
    var instruction: String     // «Язык широкий, лежит на нижней губе»
    var illustrationName: String // имя ассета из Assets.xcassets
    var durationSeconds: Int    // 5 или 8
}

enum SoundGroup: String, CaseIterable {
    case sibilant = "свистящие"
    case hissing  = "шипящие"
    case sonor    = "соноры"
}
```

**ArticulationGymWorker.swift**
- `loadExercises(soundGroup: SoundGroup) async -> [ArticulationItem]`
- Читает items stage_id=0 из ContentEngine (уже существует) по soundGroup
- Фильтрует type == "articulation"
- Fallback: если контент-пак звука не загружен — возвращает универсальный набор (5 упражнений, подходящих для любого звука: Улыбка, Трубочка, Блинчик, Качели, Чашечка)

**ArticulationGymRouter.swift**
- `routeToWorldMap()` — кнопка «Начать урок»
- `dismiss()` — кнопка «✕» в навигации

### Существующие сервисы
- `ContentEngine` — загрузка items stage_id=0 из контент-паков (уже есть)
- `AnalyticsService` — event `articulation_gym_completed(soundGroup:exerciseCount:)`
- `HapticService` — лёгкий haptic при переходе между упражнениями (`impact(.light)`)
- `SoundService` — опциональный короткий звук «дзынь» при завершении таймера

### UI-описание

**Шапка:**
- Navigation title: «Зарядка для язычка» (HSGlassNavigationBar)
- Пикер звуковой группы: HSSegmentedPicker («Свистящие / Шипящие / Соноры»)
- Прогресс-полоска: HSProgressBar (текущее упражнение / всего), цвет `.accentPurple`

**Карточка упражнения (центр экрана, HSCard, cornerRadius: 24):**
- Иллюстрация артикуляционной позы: Image из Assets, заполняет 60% высоты карточки
- Название упражнения: шрифт `.hs_title2` (жирный, 22 pt), цвет `.labelPrimary`
- Инструкция: шрифт `.hs_body`, цвет `.labelSecondary`, `.lineLimit(nil)`
- Круговой таймер: HSProgressRing (диаметр 64 pt, цвет `.accentPurple`), по центру цифра

**Ляля (HSMascotView):**
- Позиционируется снизу справа, анимация «encouraging» во время упражнения
- При смене упражнения: короткая анимация «clap»

**Кнопки:**
- «Пропустить» (HSButton, style `.ghost`, выравнивание вправо в шапке) — переход к следующему
- «Начать урок» на завершающем экране (HSButton, style `.primary`)

**Иллюстрации:**
Необходимо подготовить минимум 15 PNG/SVG ассетов артикуляционных поз:
- Универсальные (5): Улыбка, Трубочка, Блинчик, Качели, Чашечка
- Свистящие (5): Горка, Мостик, Заборчик, Насос, Ниточка
- Шипящие (5): Лопатка, Чашечка-глубокая, Фокус, Грибок, Парус

### Данные
| Источник | Поле | Использование |
|---|---|---|
| ContentEngine | items (stage_id: 0, type: "articulation") | Список упражнений по звуку |
| sound_s_pack.json / sound_sh_pack.json | items[stage_id=0] | Упражнения для свистящих / шипящих |
| Hardcoded fallback | ArticulationGymWorker.universalExercises | Если пак не загружен |

### Маршрут AppCoordinator
```
case articulationGym(soundGroup: SoundGroup = .hissing)
// Вход 1: ChildHome → кнопка «Разминка» (под миссией дня)
// Вход 2: LessonPlayer (WarmUp) → как модальный sheet перед сессией
// Вход 3: ParentHome → HomeTasks рекомендация «Сделайте зарядку»
```

### Критерии готовности (DoD)
- [ ] Таймер корректно считает обратный отсчёт и автоматически переходит к следующему упражнению
- [ ] Fallback-набор из 5 упражнений работает при отсутствии контент-пака
- [ ] Смена soundGroup через пикер перезагружает набор упражнений
- [ ] Нет обращений к микрофону / камере / ML
- [ ] Light + Dark — snapshot-тесты (карточка упражнения, завершающий экран)
- [ ] Dynamic Type до `.accessibilityLarge`
- [ ] VoiceOver: таймер `accessibilityLabel("Осталось 3 секунды")`
- [ ] `AnalyticsService` получает событие при завершении

### Что тестировать
- **Unit (Interactor):** autoAdvance при timerTick(secondsRemaining: 0); nextExercise на последнем индексе → showCompletion=true
- **Unit (Worker):** fallback при пустом контент-паке; корректная фильтрация type=="articulation"
- **Snapshot:** карточка Блинчик (light), завершающий экран (dark)

---

## Фича 3. WordBankView — «Копилка слов»

### Контур
Детский (Kid Circuit)

### Методическое обоснование
Принцип положительного подкрепления (methodology, п. 1.6) требует не только наград за сессию, но и долгосрочной видимости накопленного результата. Ребёнок, который видит «коллекцию» слов, которые он научился говорить правильно, получает:
- мотивационный якорь («я уже умею 32 слова!»);
- гордость за прогресс, стимулирующую продолжать;
- конкретное подтверждение, что практика работает.

Кроме того, копилка слов — отличный инструмент для логопеда и родителя: они видят реальный словарный объём автоматизации, а не только абстрактный процент.

По методике Коноваленко: «Ребёнок должен знать и чувствовать, что его слова — это его достижение». WordBank реализует именно это ощущение.

### Пользовательский сценарий

1. Ребёнок заходит в «Мои слова» (кнопка в ChildHome, под секцией наград, или через RewardsView → таб «Слова»).
2. Открывается WordBankView: крупный счётчик «Твоих слов: 47», ниже — фильтр по звуку (Ш, Р, С...), ниже — сетка слов-карточек.
3. Каждая карточка: слово крупным шрифтом + маленькая иконка звука + звёздочки (1–3, по среднему asrScore).
4. Нажатие на карточку: небольшой pop-over / sheet с историей: «Ты сказал это слово 4 раза, в последний раз — вчера». Кнопка «Сказать снова» → запускает ListenAndChoose / RepeatAfterModel с этим словом (deeplink в ContentEngine).
5. При открытии WordBank впервые (< 5 слов): Ляля говорит «Здесь будут появляться слова, которые ты научишься говорить. Начни занятие!»

### Структура VIP

**WordBankView.swift**
- Счётчик слов: крупный Text с анимацией изменения числа (withAnimation при загрузке)
- HSSegmentedPicker для фильтра по targetSound (динамически — только звуки с данными)
- LazyVGrid (3 колонки) из `WordTileView`
- Empty state: HSEmptyStateView (Ляля + приглашение к первому уроку)
- Sheet для детали слова: `WordDetailSheet`

**WordBankInteractor.swift**
- `loadBank(request: Load.Request)` — загружает словарь из Realm по childId
- `filterBySound(request: Filter.Request)` — фильтрация по targetSound
- `selectWord(request: SelectWord.Request)` — детальная информация по слову
- `practiceWord(request: Practice.Request)` — роутинг в сессию с конкретным словом

**WordBankPresenter.swift**
- Формирует `WordTileViewModel` из агрегированных Attempt (группировка по word + targetSound)
- `starRating(avgScore: Double) -> Int` — 1 звезда (<0.6), 2 (<0.8), 3 (≥0.8)
- Сортирует: сначала 3-звёздочные (гордость), потом 2-звёздочные, потом 1-звёздочная
- Форматирует дату «последний раз вчера / 3 дня назад / N дней назад»

**WordBankModels.swift**
```
enum WordBank {
    enum Load {
        struct Request { var childId: String }
        struct Response { var wordStats: [WordStat] }
        struct ViewModel { var totalCount: Int; var soundFilters: [String]; var tiles: [WordTileViewModel] }
    }
    enum Filter {
        struct Request { var soundTarget: String? }   // nil = все звуки
        struct Response { var filtered: [WordStat] }
        struct ViewModel { var tiles: [WordTileViewModel] }
    }
    enum SelectWord {
        struct Request { var word: String }
        struct Response { var stat: WordStat }
        struct ViewModel { var word: String; var starRating: Int; var attemptCount: Int; var lastPracticedText: String; var targetSound: String }
    }
    enum Practice {
        struct Request { var word: String; var targetSound: String }
        // Router получает запрос и открывает RepeatAfterModel
    }
}

struct WordStat: Identifiable {
    var id: String           // word + "_" + targetSound
    var word: String
    var targetSound: String
    var avgScore: Double
    var attemptCount: Int
    var lastPracticedAt: Date
    var isCorrectCount: Int
}

struct WordTileViewModel: Identifiable {
    var id: String
    var word: String
    var targetSoundLabel: String   // «Ш»
    var starRating: Int            // 1–3
    var bgColorName: String        // из DesignSystem ("accentGreen", "accentYellow")
}
```

**WordBankWorker.swift**
- `fetchWordStats(childId:) async throws -> [WordStat]`
- Realm-запрос: все Session → все Attempt where attempt.isCorrect == true и attempt.word != ""
- Группировка по (word, targetSound) через Swift-словарь: avg(asrScore), count(attempts), max(timestamp)
- Порог включения в банк: >= 1 правильная попытка (isCorrect == true)

**WordBankRouter.swift**
- `routeToPractice(word: String, targetSound: String)` → AppCoordinator → LessonPlayer (RepeatAfterModel, 1 слово)
- `dismissSheet()`

### Существующие сервисы
- `SessionRepository` — fetchSessions(childId:) → агрегация Attempt (уже есть)
- `AnalyticsService` — event `word_bank_opened`, `word_practiced_from_bank`
- `HapticService` — impact(.medium) при тапе на карточку с 3 звёздами (celebration)
- `ContentEngine` — для запуска практики конкретного слова через RepeatAfterModel

### UI-описание

**Шапка:**
- Navigation title: «Мои слова» (HSGlassNavigationBar, детский стиль — rounded font)
- Subtitle: «47 слов» — HSBadge рядом с заголовком (цвет `.accentPurple`)

**Счётчик (HSCard, gradient background `.accentPurple` → `.accentBlue`):**
- Крупное число: шрифт `.hs_largeTitle` (48 pt), белый
- Подпись: «слов в копилке», шрифт `.hs_caption`, белый, 80% opacity
- Иконка: SF Symbol `star.fill` (анимированный pulse при первом появлении)

**Фильтр:**
- HSSegmentedPicker: «Все» | «Ш» | «Р» | «С» (только те звуки, по которым есть слова)

**Сетка слов (LazyVGrid, columns: 3, spacing: 12):**
- `WordTileView` (HSCard, cornerRadius: 16, padding: 12):
  - Слово: `.hs_headline` (жирный), `.labelPrimary`
  - Звёзды: HStack из `Image(systemName: "star.fill")`, цвет `.accentYellow`
  - Маленький бейдж звука внизу справа: «Ш» (HSBadge, 14 pt)
  - Цвет фона: зелёный для 3 звёзд, жёлтый для 2, серый для 1

**WordDetailSheet (bottom sheet, detents: [.medium]):**
- Слово крупным шрифтом
- «Сказано X раз, последний раз вчера»
- Строка звёзд
- HSButton «Сказать снова» (style `.primary`) → practice action
- HSButton «Закрыть» (style `.ghost`)

**Empty state:**
- HSEmptyStateView: Ляля + «Здесь появятся слова, которые ты научишься говорить. Начни своё первое занятие!»
- HSButton «К урокам» → WorldMap

### Данные (Realm)
| Модель | Поля | Использование |
|---|---|---|
| Session | childId, targetSound, attempts | Фильтрация по childId |
| Attempt | word, isCorrect, asrScore, timestamp | Агрегация в WordStat |
| ChildProfile | targetSounds | Фильтр по актуальным звукам |

### Маршрут AppCoordinator
```
case wordBank(childId: String)
// Вход 1: ChildHome → кнопка «Мои слова» (под секцией награды)
// Вход 2: RewardsView → таб «Слова» (альтернатива StickerAlbum)
// Вход 3: SessionComplete → «Посмотреть слова» (дополнительная кнопка)
```

### Критерии готовности (DoD)
- [ ] Корректно агрегирует Attempt.isCorrect==true из всех сессий ребёнка
- [ ] starRating рассчитывается из avg(asrScore) (unit-тест на Presenter)
- [ ] Фильтр по звуку работает корректно (только доступные звуки в пикере)
- [ ] Empty state показывается при 0 слов
- [ ] «Сказать снова» открывает RepeatAfterModel с одним словом
- [ ] Light + Dark — snapshot-тесты (сетка 9+ слов, empty state)
- [ ] Dynamic Type до `.accessibilityLarge` (сетка перестраивается: из 3 колонок в 2 при xxxLarge)
- [ ] VoiceOver: `WordTileView` → `accessibilityLabel("шапка, 3 звезды, звук Ш")`
- [ ] Нет print / TODO / force-unwrap
- [ ] Работает полностью offline

### Что тестировать
- **Unit (Presenter):** starRating(0.5)=1, starRating(0.75)=2, starRating(0.85)=3; lastPracticedText для today / yesterday / 5 days ago
- **Unit (Worker):** агрегация при дублирующихся attempt.word одного звука; слово с isCorrect==false не попадает в банк
- **Snapshot:** сетка полная (12 слов, mixed stars), сетка empty

---

## Сводная таблица

| ID | Фича | Контур | LOC (~) | Новые Realm-модели | Маршрут |
|---|---|---|---|---|---|
| F-301 | WeeklySoundReport | Родительский | 400–500 | 0 (читает Session, ProgressEntry) | `.weeklyReport(childId:weekOffset:)` |
| F-302 | ArticulationGym | Детский | 350–450 | 0 (читает ContentEngine) | `.articulationGym(soundGroup:)` |
| F-303 | WordBank | Детский | 400–500 | 0 (агрегирует Attempt) | `.wordBank(childId:)` |

**Суммарная оценка LOC:** ~1150–1450. Все три фичи read-only по отношению к данным (новых Realm-объектов не требуют). Offline-first, без новых ML и бэкенд-вызовов.

---

> Обновлено: 2026-05-17. Следующий шаг: передать ТЗ ios-developer для оценки сроков и включения в спринт.
