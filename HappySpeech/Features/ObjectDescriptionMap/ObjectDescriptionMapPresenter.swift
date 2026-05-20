import Foundation

// MARK: - ObjectDescriptionMapPresenter
//
// VIP-Presenter. Получает Response из Interactor → формирует ViewModel
// с локализованными подписями и итоговой оценкой 0…3 ★.

@MainActor
final class ObjectDescriptionMapPresenter {

    weak var displayLogic: (any ObjectDescriptionMapDisplayLogic)?

    private let analyzer = DescriptionCoverageAnalyzer()

    init(displayLogic: any ObjectDescriptionMapDisplayLogic) {
        self.displayLogic = displayLogic
    }

    // MARK: - Load Objects

    func presentLoadObjects(response: ObjectDescriptionMapModels.LoadObjects.Response) async {
        var grouped: [String: [DescriptionObject]] = [:]
        for object in response.objects {
            grouped[object.category, default: []].append(object)
        }
        let viewModel = ObjectDescriptionMapModels.LoadObjects.ViewModel(
            grouped: grouped,
            categoriesInOrder: ObjectDescriptionMapCorpus.categoriesInOrder
        )
        await displayLogic?.displayLoadObjects(viewModel: viewModel)
    }

    // MARK: - Select Object

    func presentSelectObject(response: ObjectDescriptionMapModels.SelectObject.Response) async {
        guard let object = ObjectDescriptionMapCorpus.object(id: response.objectId) else { return }
        let hint = "Посмотри на план и расскажи о \(genitive(of: object.title)) по пунктам."
        let viewModel = ObjectDescriptionMapModels.SelectObject.ViewModel(
            object: object,
            planItems: object.plan,
            hintMessage: hint
        )
        await displayLogic?.displaySelectObject(viewModel: viewModel)
    }

    // MARK: - Record Result

    func presentRecordResult(response: ObjectDescriptionMapModels.RecordResult.Response) async {
        let ratio = response.coverage.coverageRatio
        let stars = analyzer.stars(forRatio: ratio)
        let percent = Int((ratio * 100).rounded())
        let missed = response.coverage.missedTitles
        let (title, body) = makeFeedback(stars: stars, missed: missed)
        let durationLabel = formatDuration(response.durationSeconds)
        let accessibility = makeAccessibilityLabel(
            object: response.object.title,
            stars: stars,
            covered: response.coverage.coveredCount,
            total: response.coverage.totalCount,
            words: response.coverage.totalWords
        )

        let viewModel = ObjectDescriptionMapModels.RecordResult.ViewModel(
            object: response.object,
            transcript: response.transcript,
            durationLabel: durationLabel,
            stars: stars,
            coverageRatio: ratio,
            coveragePercent: percent,
            planDecorated: response.coverage.decorated,
            missedTitles: missed,
            feedbackTitle: title,
            feedbackBody: body,
            accessibilityLabel: accessibility
        )
        await displayLogic?.displayRecordResult(viewModel: viewModel)
    }

    // MARK: - Helpers

    private func makeFeedback(stars: Int, missed: [String]) -> (title: String, body: String) {
        switch stars {
        case 3:
            return ("Отличный рассказ!",
                    "Ты раскрыл почти весь план. Молодец!")
        case 2:
            if missed.isEmpty {
                return ("Хорошо получилось!", "Ещё чуть-чуть подробностей — и будет супер.")
            }
            return ("Хорошо получилось!",
                    "В следующий раз добавь: \(missed.joined(separator: ", ")).")
        case 1:
            return ("Хороший старт!",
                    "Попробуй рассказать ещё про: \(missed.joined(separator: ", ")).")
        default:
            return ("Попробуем ещё раз!",
                    "Посмотри на план и расскажи по пунктам — что видишь.")
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    /// Грубая морфология для подсказки «расскажи о груше / о коте».
    /// На уровне MVP — простые правила, никаких внешних NLP-зависимостей.
    private func genitive(of word: String) -> String {
        let lower = word.lowercased()
        if lower.hasSuffix("а") {
            return String(lower.dropLast()) + "е"      // груша → груше
        }
        if lower.hasSuffix("я") {
            return String(lower.dropLast()) + "е"      // дыня → дыне
        }
        if lower.hasSuffix("ь") {
            return String(lower.dropLast()) + "и"      // морковь → моркови
        }
        // Согласный: машин… → машине. Кот → коте.
        return lower + "е"
    }

    private func makeAccessibilityLabel(
        object: String,
        stars: Int,
        covered: Int,
        total: Int,
        words: Int
    ) -> String {
        "Описание \(object): \(stars) из 3 звёзд. Раскрыто \(covered) из \(total) пунктов. Слов: \(words)."
    }
}
