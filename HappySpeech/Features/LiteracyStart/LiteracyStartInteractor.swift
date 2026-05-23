import Foundation
import OSLog

// MARK: - LiteracyStartInteractor
//
// VIP-Interactor для «Грамота-старт».
//
// Поток:
//   1. `loadLetter(_:)` — по targetSound берёт букву + 3 слова из
//      `LiteracyCatalog` и просит Presenter сформировать ViewModel.
//   2. `playSound(_:)` — воспроизводит «lyalya_sound_<sound>.m4a»
//      из bundle через AudioService. Если файла нет — лог-warning,
//      экран не падает.
//   3. `startTracing(_:)` — Router → LetterTrace.

@MainActor
final class LiteracyStartInteractor {

    // MARK: - Dependencies

    private let presenter: LiteracyStartPresenter
    private let router: LiteracyStartRouter
    private let audioService: any AudioService
    private let childId: String

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "LiteracyStart.Interactor"
    )

    // MARK: - Init

    init(
        presenter: LiteracyStartPresenter,
        router: LiteracyStartRouter,
        audioService: any AudioService,
        childId: String
    ) {
        self.presenter = presenter
        self.router = router
        self.audioService = audioService
        self.childId = childId
    }

    // MARK: - Load

    func loadLetter(_ request: LiteracyStartModels.LoadLetter.Request) async {
        guard let entry = LiteracyCatalog.entry(for: request.targetSound) else {
            Self.logger.warning(
                "Неизвестный звук для грамоты: \(request.targetSound, privacy: .public)"
            )
            await presenter.presentUnsupportedSound(targetSound: request.targetSound)
            return
        }
        let response = LiteracyStartModels.LoadLetter.Response(
            targetSound: request.targetSound,
            letter: entry.letter,
            words: entry.words
        )
        await presenter.presentLoadLetter(response: response)
    }

    // MARK: - Play Sound

    func playSound(_ request: LiteracyStartModels.PlaySound.Request) async {
        guard let url = audioURL(for: request.targetSound) else {
            Self.logger.info(
                "Аудио для звука \(request.targetSound, privacy: .public) не найдено — пропуск"
            )
            return
        }
        do {
            try await audioService.playAudio(url: url)
        } catch {
            Self.logger.error(
                "Не удалось воспроизвести звук: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    // MARK: - Tracing

    func startTracing(_ request: LiteracyStartModels.StartTracing.Request) {
        Self.logger.info("Переход к прописям буквы \(request.letter, privacy: .public)")
        router.routeToLetterTrace(childId: childId)
    }

    // MARK: - Private

    /// Транслитерирует кириллический звук в имя файла bundle-аудио.
    /// Пример: «Р» → «lyalya_sound_r.m4a». Если такого ресурса нет в bundle,
    /// возвращает nil без падения.
    private func audioURL(for targetSound: String) -> URL? {
        let normalized = targetSound
            .replacingOccurrences(of: "ь", with: "")
            .lowercased()
        let translit: [String: String] = [
            "с": "s", "з": "z", "ц": "ts",
            "ш": "sh", "ж": "zh", "ч": "ch", "щ": "sch",
            "р": "r", "л": "l",
            "к": "k", "г": "g", "х": "h"
        ]
        guard let asciiKey = translit[normalized] else { return nil }
        let resourceName = "lyalya_sound_\(asciiKey)"
        return Bundle.main.url(forResource: resourceName, withExtension: "m4a")
    }
}
