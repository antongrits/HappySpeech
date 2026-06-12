import Foundation

// MARK: - PhonemeReportModels
//
// VIP-модели экрана «Детальный пофонемный отчёт» (A-09) — карта точности
// по целевым звукам ребёнка с историей.
//
// ВАЖНО — честность данных: единственная пофонемная гранулярность, которая
// РЕАЛЬНО персистится в Realm — это `Session.targetSound` (один звук на
// сессию) × эффективная оценка попыток (`max(asrScore, pronunciationScore)`
// или `manualScore`, если выставлена). Пер-IPA-фонемный разбор
// (`PhonemeAnalysisResult.perPhonemeScore`) вычисляется на лету в момент
// сессии, но НЕ сохраняется. Поэтому отчёт строится по ОТРАБОТАННЫМ ЗВУКАМ
// (по тому, что реально есть в истории сессий), а не по выдуманным 42 IPA.
// Звуки группы без сессий показываются явным «нет данных».

enum PhonemeReportModels {

    // MARK: Load

    enum Load {
        struct Request {
            let childId: String
        }

        /// Сырой ответ интерактора — собран из реальных `SessionDTO`.
        struct Response {
            let childName: String
            /// Целевые звуки из профиля ребёнка (план коррекции).
            let targetSounds: [String]
            /// Все сессии ребёнка (для построения истории и охвата).
            let sessions: [SessionDTO]
            let error: Error?
            /// Агрегат «Фонемного паспорта» (GOP-анализ). `nil` — паспорт не
            /// загрузился (его ошибка не валит остальной экран).
            let phonemeProfile: PhonemeProfile?
            /// Прогнозы динамики освоения по топ-проблемным фонемам паспорта.
            let forecasts: [MasteryForecast]

            init(
                childName: String,
                targetSounds: [String],
                sessions: [SessionDTO],
                error: Error? = nil,
                phonemeProfile: PhonemeProfile? = nil,
                forecasts: [MasteryForecast] = []
            ) {
                self.childName = childName
                self.targetSounds = targetSounds
                self.sessions = sessions
                self.error = error
                self.phonemeProfile = phonemeProfile
                self.forecasts = forecasts
            }
        }

        struct ViewModel: Equatable {
            let titleText: String
            let childNameText: String
            let summaryText: String
            /// Группы звуков с данными/без. Пустой массив → общий empty-state.
            let groups: [PhonemeReportGroupViewModel]
            let coverageText: String
            /// `true`, если у ребёнка вообще нет ни одной сессии.
            let isEmpty: Bool
            let errorText: String?
            /// Секция «Фонемный паспорт» (GOP-анализ). Источник —
            /// `PhonemeProfileService`. `nil`, если профиль не удалось загрузить
            /// (ошибка паспорта не валит весь экран — секция просто скрывается).
            let passport: PhonemePassportViewModel?

            init(
                titleText: String,
                childNameText: String,
                summaryText: String,
                groups: [PhonemeReportGroupViewModel],
                coverageText: String,
                isEmpty: Bool,
                errorText: String?,
                passport: PhonemePassportViewModel? = nil
            ) {
                self.titleText = titleText
                self.childNameText = childNameText
                self.summaryText = summaryText
                self.groups = groups
                self.coverageText = coverageText
                self.isEmpty = isEmpty
                self.errorText = errorText
                self.passport = passport
            }
        }
    }
}

// MARK: - Domain row (pure, from real sessions)

/// Точность по одному целевому звуку, агрегированная из реальных сессий.
struct PhonemeReportRow: Sendable, Equatable, Hashable, Identifiable {
    var id: String { sound }
    /// Кириллический целевой звук, например «Р».
    let sound: String
    /// Группа звуков (свистящие/шипящие/соноры/заднеязычные).
    let family: SoundFamily
    /// Суммарное число попыток по звуку за всю историю.
    let attempts: Int
    /// Число верных попыток.
    let successes: Int
    /// Средняя точность 0…1 по сессиям этого звука. `nil` — нет данных.
    let accuracy: Double?
    /// Число сессий по звуку.
    let sessionCount: Int
    /// Дельта тренда (поздняя половина − ранняя половина), в долях 0…1.
    /// `nil`, если сессий < 2 (тренд не определён).
    let trendDelta: Double?
    /// Последний этап коррекционной лестницы (raw `CorrectionStage`).
    let lastStageRaw: String?
    /// Точки истории по сессиям (для спарклайна): отсортированы по дате.
    let history: [HistoryPoint]
    /// `true`, если по звуку нет НИ одной сессии — показываем «нет данных».
    var hasData: Bool { sessionCount > 0 }
}

/// Точка истории точности по конкретной сессии.
struct HistoryPoint: Sendable, Equatable, Hashable, Identifiable {
    var id: String { "\(date.timeIntervalSince1970)" }
    let date: Date
    /// Точность 0…1 в этой сессии.
    let accuracy: Double
}

// MARK: - View-side models

/// Группа звуков (раздел экрана). Содержит строки звуков группы.
struct PhonemeReportGroupViewModel: Identifiable, Equatable, Hashable {
    var id: String { familyRaw }
    let familyRaw: String
    let title: String
    /// Сводка по группе: «3 из 4 звуков отработаны».
    let subtitle: String
    let rows: [PhonemeRowViewModelA09]
}

/// Строка одного звука для отображения.
struct PhonemeRowViewModelA09: Identifiable, Equatable, Hashable {
    var id: String { sound }
    let sound: String
    /// Локализованная подпись точности: «86 %» или «нет данных».
    let accuracyText: String
    /// Процент 0…100 для прогресс-кольца. `nil` — нет данных.
    let accuracyPercent: Int?
    /// Тон точности (good/medium/poor). `nil` — нет данных (нейтральный).
    let tone: AccuracyTone?
    /// «12 попыток · 4 занятия» или пусто.
    let detailText: String
    /// Подпись тренда: «↑ +12 п.п.», «→ стабильно», «↓ −8 п.п.» или пусто.
    let trendText: String?
    /// Направление тренда: 1 рост, 0 стабильно, -1 спад, nil нет тренда.
    let trendDirection: Int?
    /// Последний этап лестницы (локализованный) или nil.
    let stageText: String?
    /// Точки истории для спарклайна (могут быть пустыми).
    let history: [HistoryPoint]
}

// MARK: - Phoneme Passport view models (GOP-анализ)

/// Тон ячейки матрицы паспорта (управляет тёплым цветом и a11y-меткой).
/// Отличается от `AccuracyTone` тем, что учитывает «нет данных» и
/// неопределённость, специфичные для GOP-наблюдений.
enum PhonemePassportTone: Sendable, Equatable, Hashable {
    /// Преобладает корректное произнесение (высокий self-baseline уровень).
    case good
    /// Искажение / умеренный уровень — требует внимания.
    case medium
    /// Замена / пропуск / низкий уровень — приоритет коррекции.
    case poor
    /// Нейтральный (нет данных в ячейке).
    case neutral
}

/// Одна ячейка матрицы «фонема × позиция» для отображения.
struct PhonemePassportCellViewModel: Identifiable, Equatable, Hashable {
    var id: String { "\(phoneme)|\(positionKey)" }
    let phoneme: String
    /// Машинный ключ позиции (initial/medial/final) — для стабильного id.
    let positionKey: String
    /// «GOP 0,72» либо пустая строка, если уровня нет.
    let levelText: String
    /// Тон ячейки (цвет + a11y).
    let tone: PhonemePassportTone
    /// Локализованная подпись состояния («искажение», «норма»…). Может быть пустой.
    let stateText: String
    /// `true`, если в ячейке есть хотя бы одно наблюдение.
    let hasData: Bool
    /// Совмещённая accessibility-метка ячейки.
    let accessibilityLabel: String
}

/// Колонка матрицы — одна позиция (начало/середина/конец) для заголовка.
struct PhonemePassportColumn: Identifiable, Equatable, Hashable {
    var id: String { key }
    /// Машинный ключ позиции.
    let key: String
    /// Локализованный краткий заголовок («Начало»/«Середина»/«Конец»).
    let title: String
}

/// Строка матрицы паспорта — одна фонема × три позиции.
struct PhonemePassportRowViewModel: Identifiable, Equatable, Hashable {
    var id: String { phoneme }
    let phoneme: String
    /// Ячейки в порядке колонок матрицы.
    let cells: [PhonemePassportCellViewModel]
}

/// Точка sparkline-динамики GOP по проблемной фонеме.
struct PhonemePassportTrendPoint: Identifiable, Equatable, Hashable {
    var id: Int { index }
    /// Порядковый индекс наблюдения (ось X).
    let index: Int
    /// Уровень self-baseline [0…1] (ось Y).
    let level: Double
}

/// Sparkline динамики GOP по одной проблемной фонеме.
struct PhonemePassportTrendViewModel: Identifiable, Equatable, Hashable {
    var id: String { phoneme }
    let phoneme: String
    /// «GOP 0,41 · искажение».
    let captionText: String
    let tone: PhonemePassportTone
    let points: [PhonemePassportTrendPoint]
}

/// Прогноз динамики освоения одной целевой фонемы для UI.
struct PhonemePassportForecastViewModel: Identifiable, Equatable, Hashable {
    var id: String { phoneme }
    let phoneme: String
    /// Основной текст прогноза («Ожидаемое освоение через 4 занятия»).
    let summaryText: String
    /// Текст доверительного интервала («диапазон: 3–7 занятий») или пусто.
    let confidenceText: String?
    /// `true` → бейдж «рекомендуется консультация».
    let needsConsultation: Bool
    /// Текущий уровень self-baseline [0…1] для прогресс-полосы.
    let currentLevel: Double
    /// Нормированная нижняя граница CI [0…1] для CI-полосы (доля времени). `nil` если нет.
    let confidenceLowerFraction: Double?
    /// Нормированная верхняя граница CI [0…1] для CI-полосы. `nil` если нет.
    let confidenceUpperFraction: Double?
    let tone: PhonemePassportTone
    let accessibilityLabel: String
}

/// Полная ViewModel секции «Фонемный паспорт».
struct PhonemePassportViewModel: Equatable {
    /// Заголовок секции.
    let titleText: String
    /// Подзаголовок-сводка («38 наблюдений · откалибровано»).
    let subtitleText: String
    /// Колонки матрицы (позиции).
    let columns: [PhonemePassportColumn]
    /// Строки матрицы (фонемы).
    let rows: [PhonemePassportRowViewModel]
    /// Sparkline-динамика по слабейшим фонемам.
    let trends: [PhonemePassportTrendViewModel]
    /// Прогнозы освоения по целевым фонемам.
    let forecasts: [PhonemePassportForecastViewModel]
    /// Дата последнего наблюдения («обновлено 12 июня») или пусто.
    let lastObservationText: String
    /// Честная пометка относительной шкалы.
    let disclaimerText: String
    /// `true`, если паспорт пуст (наблюдений ещё нет) → дружелюбный empty-state.
    let isEmpty: Bool
    /// Текст empty-state.
    let emptyText: String
    /// Готовая CSV-строка для экспорта специалистом. Пустая, если паспорт пуст.
    let csvExport: String
    /// Имя файла CSV (без расширения), без PII.
    let csvFileName: String
}
