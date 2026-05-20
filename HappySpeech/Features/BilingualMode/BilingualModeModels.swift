import Foundation

// MARK: - BilingualModeModels
//
// v31 Wave F Ф.11 — «Билингвальный режим» (Bilingual Mode).
//
// Идея: для двуязычных детей (русский + белорусский / английский / другой)
// логопедическая методика (Глухов, Цейтлин) рекомендует НЕ подавлять
// второй язык, а строить «зеркало понятий» — поддерживать словарь и в Я1,
// и в Я2. Это не курс языка, а методический модуль поддержки билингвизма.
//
// MVP-режим:
//   - Toggle: выкл / русский+белорусский / русский+английский.
//   - Словарь: 32 базовых слова (`pack_bilingual_vocabulary.json`).
//     На каждое слово — символ, русское написание, перевод на второй язык,
//     кнопка «послушать на втором языке» (AVSpeechSynthesizer).
//   - Practice: 10 раундов tap-выбора правильного перевода из 3 вариантов.
//     Подсчёт корректных ответов → 0…3 звёзд.

enum BilingualModeModels {

    // MARK: - LoadVocabulary

    enum LoadVocabulary {

        struct Response {
            let secondLanguage: BilingualSecondLanguage
            let words: [BilingualWord]
        }

        struct ViewModel {
            let secondLanguage: BilingualSecondLanguage
            /// category-id → слова в этой категории.
            let grouped: [String: [BilingualWord]]
            /// Порядок категорий — стабильный (из паковой схемы).
            let categoriesInOrder: [String]
            /// category-id → человекочитаемое название («Семья» / «Дом»).
            let categoryTitles: [String: String]
            /// Локализованное имя второго языка (как видит родитель/ребёнок).
            let secondLanguageDisplayName: String
        }
    }

    // MARK: - SelectSecondLanguage

    enum SelectSecondLanguage {

        struct Request {
            let language: BilingualSecondLanguage
        }
    }

    // MARK: - StartPractice

    enum StartPractice {

        struct Request {
            /// Сколько раундов в сессии (по умолчанию 10).
            let totalRounds: Int
        }

        struct Response {
            let secondLanguage: BilingualSecondLanguage
            let rounds: [BilingualPracticeRound]
        }

        struct ViewModel {
            let secondLanguage: BilingualSecondLanguage
            let totalRounds: Int
            let rounds: [BilingualPracticeRound]
        }
    }

    // MARK: - SubmitAnswer

    enum SubmitAnswer {

        struct Request {
            let roundIndex: Int
            let selectedOptionId: String
        }

        struct Response {
            let roundIndex: Int
            let isCorrect: Bool
            let correctTranslation: String
        }

        struct ViewModel {
            let roundIndex: Int
            let isCorrect: Bool
            /// Что было правильным ответом (для подсветки).
            let correctTranslation: String
        }
    }

    // MARK: - FinishPractice

    enum FinishPractice {

        struct Response {
            let correctCount: Int
            let totalRounds: Int
            let secondLanguage: BilingualSecondLanguage
        }

        struct ViewModel {
            let correctCount: Int
            let totalRounds: Int
            /// 0…3 звезды.
            let stars: Int
            let title: String
            let body: String
            let accessibilityLabel: String
        }
    }
}

// MARK: - BilingualSecondLanguage

/// Выбор второго языка. `off` означает, что режим выключен и экран
/// показывает только pre-roll с тоглом.
enum BilingualSecondLanguage: String, Sendable, Equatable, CaseIterable, Codable {
    case off
    case belarusian = "be-BY"
    case english    = "en-US"

    /// Идентификатор для AVSpeechSynthesisVoice.
    var bcp47: String { rawValue }

    /// Человекочитаемый ярлык (используется в UI + accessibility).
    var displayName: String {
        switch self {
        case .off:        return String(localized: "bilingualMode.lang.off")
        case .belarusian: return String(localized: "bilingualMode.lang.belarusian")
        case .english:    return String(localized: "bilingualMode.lang.english")
        }
    }
}

// MARK: - BilingualWord

/// Одно слово в bilingual-словаре.
/// `russian` — оригинал. `translations` — словарь bcp47 → перевод.
struct BilingualWord: Sendable, Equatable, Identifiable, Codable {
    let id: String
    let russian: String
    let category: String
    let symbol: String
    let translations: [String: String]

    /// Перевод на выбранный второй язык. nil если перевода нет.
    func translation(for language: BilingualSecondLanguage) -> String? {
        guard language != .off else { return nil }
        return translations[language.bcp47]
    }
}

// MARK: - BilingualPracticeRound

/// Один раунд тренировки. Показываем русское слово → 3 варианта перевода.
struct BilingualPracticeRound: Sendable, Equatable, Identifiable {
    let id: String
    /// Слово, которое мы спрашиваем («какое слово на втором языке означает …?»).
    let word: BilingualWord
    /// 3 опции — id опции (равен id слова-источника).
    let options: [BilingualPracticeOption]
    /// id опции, которая правильная.
    let correctOptionId: String
}

/// Опция-вариант ответа в practice-раунде.
struct BilingualPracticeOption: Sendable, Equatable, Identifiable {
    let id: String
    /// Текст перевода (на втором языке).
    let translation: String
}
