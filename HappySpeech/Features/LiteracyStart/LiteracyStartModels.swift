import Foundation

// MARK: - LiteracyStartModels
//
// «Грамота-старт» — мост от логопедической работы к школьному чтению.
// После того как ребёнок отработал звук, экран показывает соответствующую
// букву кириллицы + 3 стартовых слова + переход к прописям.

enum LiteracyStartModels {

    // MARK: - LoadLetter

    enum LoadLetter {

        struct Request: Sendable {
            let targetSound: String
        }

        struct Response: Sendable {
            let targetSound: String
            let letter: String
            let words: [WordSample]
        }

        struct ViewModel: Sendable {
            let titleText: String           // «Учим букву «Р»»
            let letter: String              // «Р»
            let words: [WordSample]
            let traceButtonTitle: String    // «Прописать букву»
            let listenButtonTitle: String   // «Послушать звук»
            let accessibilityLabel: String
        }
    }

    // MARK: - PlaySound

    enum PlaySound {

        struct Request: Sendable {
            let targetSound: String
        }
    }

    // MARK: - StartTracing

    enum StartTracing {

        struct Request: Sendable {
            let letter: String
        }
    }
}

// MARK: - WordSample

/// Слово-пример со звуком в начале для буквенной карточки.
struct WordSample: Sendable, Identifiable, Equatable {
    let id: String
    let text: String        // «Рак»
    let assetName: String   // «word_rak» (HSContentSymbol-friendly)

    init(text: String, assetName: String) {
        self.id = assetName
        self.text = text
        self.assetName = assetName
    }
}

// MARK: - LiteracyCatalog

/// Статический каталог буква ↔ примеры. Покрывает все группы звуков
/// (свистящие, шипящие, соноры, заднеязычные).
enum LiteracyCatalog {

    /// Возвращает (буква, 3 слова) для звука, либо nil если звук не известен.
    static func entry(for targetSound: String) -> (letter: String, words: [WordSample])? {
        return catalog[normalize(targetSound)]
    }

    /// Список всех поддерживаемых звуков (для тестов / диагностики).
    static var supportedSounds: [String] { Array(catalog.keys).sorted() }

    // MARK: - Private

    /// Нормализация ввода: «р», «Р», «Рь» → ключ каталога.
    /// Мягкие пары используют ту же запись, что и твёрдые (звук Р и Рь
    /// делят букву Р).
    private static func normalize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Мягкая пара заканчивается на «ь» — отбрасываем.
        if trimmed.hasSuffix("ь") {
            return String(trimmed.dropLast()).uppercased()
        }
        return trimmed.uppercased()
    }

    private static let catalog: [String: (letter: String, words: [WordSample])] = [
        // Свистящие
        "С": ("С", [
            WordSample(text: "Сова",   assetName: "word_sova"),
            WordSample(text: "Сок",    assetName: "word_sok"),
            WordSample(text: "Самолёт", assetName: "word_samolyot")
        ]),
        "З": ("З", [
            WordSample(text: "Зонт",   assetName: "word_zont"),
            WordSample(text: "Заяц",   assetName: "word_zayats"),
            WordSample(text: "Звезда", assetName: "word_zvezda")
        ]),
        "Ц": ("Ц", [
            WordSample(text: "Цветок", assetName: "word_tsvetok"),
            WordSample(text: "Цапля",  assetName: "word_tsaplya"),
            WordSample(text: "Цирк",   assetName: "word_tsirk")
        ]),

        // Шипящие
        "Ш": ("Ш", [
            WordSample(text: "Шар",   assetName: "word_shar"),
            WordSample(text: "Шапка", assetName: "word_shapka"),
            WordSample(text: "Шуба",  assetName: "word_shuba")
        ]),
        "Ж": ("Ж", [
            WordSample(text: "Жук",    assetName: "word_zhuk"),
            WordSample(text: "Жираф",  assetName: "word_zhiraf"),
            WordSample(text: "Жёлудь", assetName: "word_zhyolud")
        ]),
        "Ч": ("Ч", [
            WordSample(text: "Часы",   assetName: "word_chasy"),
            WordSample(text: "Чашка",  assetName: "word_chashka"),
            WordSample(text: "Черепаха", assetName: "word_cherepaha")
        ]),
        "Щ": ("Щ", [
            WordSample(text: "Щенок",  assetName: "word_shchenok"),
            WordSample(text: "Щётка",  assetName: "word_shchetka"),
            WordSample(text: "Щука",   assetName: "word_shchuka")
        ]),

        // Соноры
        "Р": ("Р", [
            WordSample(text: "Рак",  assetName: "word_rak"),
            WordSample(text: "Роза", assetName: "word_rose"),
            WordSample(text: "Рыба", assetName: "word_ryba")
        ]),
        "Л": ("Л", [
            WordSample(text: "Лук",   assetName: "word_luk"),
            WordSample(text: "Лиса",  assetName: "word_lisa"),
            WordSample(text: "Лимон", assetName: "word_limon")
        ]),

        // Заднеязычные
        "К": ("К", [
            WordSample(text: "Кот",   assetName: "word_kot"),
            WordSample(text: "Кит",   assetName: "word_kit"),
            WordSample(text: "Книга", assetName: "word_kniga")
        ]),
        "Г": ("Г", [
            WordSample(text: "Гусь",   assetName: "word_gus"),
            WordSample(text: "Гриб",   assetName: "word_grib"),
            WordSample(text: "Город",  assetName: "word_gorod")
        ]),
        "Х": ("Х", [
            WordSample(text: "Хлеб",  assetName: "word_hleb"),
            WordSample(text: "Хвост", assetName: "word_khvost"),
            WordSample(text: "Холод", assetName: "word_holod")
        ])
    ]
}
