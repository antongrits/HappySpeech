import Foundation

// MARK: - ObjectDescriptionMapModels
//
// v31 Wave F Ф.2 — «Описательная карта объекта» (Object Description Map,
// план-схема Ткаченко). Ребёнок выбирает объект → видит план-схему из
// 6–8 пиктограмм (цвет / форма / размер / материал / части / для чего /
// где живёт / звук-действие) → устно описывает по плану ≤90 сек → ASR
// (WhisperKit) транскрибирует → `DescriptionCoverageAnalyzer` считает
// сколько пунктов плана покрыто по lemma-keywords → 0…3 звезды + feedback.
//
// Корпус: `pack_objectdescriptionmap.json` (12 объектов × 4 категории,
// по 6–8 пунктов плана, по 3–8 keywords в пункте).
//
// Контур: kid. Возраст 5–8 лет. Уровень: 1–3.

enum ObjectDescriptionMapModels {

    // MARK: - Load Objects (стартовый экран — выбор объекта)

    enum LoadObjects {

        struct Response {
            let objects: [DescriptionObject]
        }

        struct ViewModel {
            /// category → объекты
            let grouped: [String: [DescriptionObject]]
            let categoriesInOrder: [String]
        }
    }

    // MARK: - Select Object (ребёнок выбрал объект — показываем план-схему)

    enum SelectObject {

        struct Response {
            let objectId: String
        }

        struct ViewModel {
            let object: DescriptionObject
            /// Пункты плана в порядке отображения.
            let planItems: [DescriptionPlanItem]
            /// Локализованная подсказка над картой.
            let hintMessage: String
        }
    }

    // MARK: - Record Result (после стоп-записи и ASR)

    enum RecordResult {

        struct Response {
            let object: DescriptionObject
            let transcript: String
            let durationSeconds: Double
            let coverage: DescriptionCoverageReport
        }

        struct ViewModel {
            let object: DescriptionObject
            let transcript: String
            let durationLabel: String
            /// 0…3 звезды.
            let stars: Int
            /// Доля закрытых пунктов 0…1.
            let coverageRatio: Double
            let coveragePercent: Int
            /// Подсветка пунктов плана: closed/open.
            let planDecorated: [DecoratedPlanItem]
            /// Список незакрытых пунктов — для блока feedback.
            let missedTitles: [String]
            /// Короткая русская похвала / совет.
            let feedbackTitle: String
            let feedbackBody: String
            let accessibilityLabel: String
        }
    }
}

// MARK: - DescriptionObject

/// Объект для описания (груша, кот, мяч, машина…).
struct DescriptionObject: Sendable, Identifiable, Equatable {
    let id: String
    let title: String
    /// «животные» | «еда» | «транспорт» | «игрушки».
    let category: String
    /// SF Symbol — рендер-безопасное изображение.
    let symbol: String
    /// План-схема Ткаченко из 6–8 пунктов.
    let plan: [DescriptionPlanItem]
}

// MARK: - DescriptionPlanItem

/// Пункт плана-схемы: «цвет», «форма», «части» и т. д.
struct DescriptionPlanItem: Sendable, Equatable, Identifiable {
    /// Семантический ключ слота (см. `DescriptionSlot`).
    let slot: String
    /// Заголовок-человекочитаемый — «Цвет», «Форма», «Части».
    let slotTitle: String
    /// SF Symbol для иконки слота.
    let icon: String
    /// Подсказка-вопрос для ребёнка: «Какого цвета?».
    let prompt: String
    /// Ключевые слова-lemmas для авто-определения покрытия в транскрипте.
    let keywords: [String]

    var id: String { slot }
}

// MARK: - DecoratedPlanItem (для отображения результата)

/// Пункт плана с флагом «покрыт ли он в речи ребёнка».
struct DecoratedPlanItem: Sendable, Equatable, Identifiable {
    let item: DescriptionPlanItem
    let isCovered: Bool
    /// Конкретные ключевые слова, которые сработали (для подсветки).
    let matchedKeywords: [String]

    var id: String { item.slot }
}

// MARK: - DescriptionCoverageReport

/// Результат анализа транскрипта против плана.
struct DescriptionCoverageReport: Sendable, Equatable {
    /// План-схема в порядке исходного объекта, размеченная по покрытию.
    let decorated: [DecoratedPlanItem]
    /// Сколько пунктов закрыто.
    let coveredCount: Int
    /// Всего пунктов в плане объекта.
    let totalCount: Int
    /// Общее число слов в транскрипте.
    let totalWords: Int
    /// Средняя длина предложения (слов в предложении).
    let avgSentenceLengthWords: Double
    /// Лексическое разнообразие (type-token ratio).
    let lexicalDiversity: Double
    /// Доля покрытия 0…1.
    var coverageRatio: Double {
        guard totalCount > 0 else { return 0 }
        return Double(coveredCount) / Double(totalCount)
    }
    /// Заголовки незакрытых пунктов («Размер», «Где живёт»).
    var missedTitles: [String] {
        decorated.filter { !$0.isCovered }.map(\.item.slotTitle)
    }
}
