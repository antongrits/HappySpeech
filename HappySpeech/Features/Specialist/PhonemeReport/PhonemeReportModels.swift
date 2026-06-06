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

            init(
                childName: String,
                targetSounds: [String],
                sessions: [SessionDTO],
                error: Error? = nil
            ) {
                self.childName = childName
                self.targetSounds = targetSounds
                self.sessions = sessions
                self.error = error
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
