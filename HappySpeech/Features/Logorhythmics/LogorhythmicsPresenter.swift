import Foundation

// MARK: - LogorhythmicsPresenter

@MainActor
final class LogorhythmicsPresenter {

    weak var displayLogic: (any LogorhythmicsDisplayLogic)?

    private let scorer = BeatScorer()

    init(displayLogic: any LogorhythmicsDisplayLogic) {
        self.displayLogic = displayLogic
    }

    // MARK: - Load Exercises

    func presentLoadExercises(response: LogorhythmicsModels.LoadExercises.Response) async {
        var grouped: [String: [LogorhythmicsExercise]] = [:]
        for exercise in response.exercises {
            grouped[exercise.category, default: []].append(exercise)
        }
        // Внутри категории — по возрасту, потом по title.
        for key in grouped.keys {
            grouped[key]?.sort { lhs, rhs in
                if lhs.ageMin != rhs.ageMin { return lhs.ageMin < rhs.ageMin }
                return lhs.title < rhs.title
            }
        }
        let viewModel = LogorhythmicsModels.LoadExercises.ViewModel(
            grouped: grouped,
            categoriesInOrder: LogorhythmicsCorpus.categoriesInOrder,
            categoryTitles: LogorhythmicsCorpus.categoryTitles
        )
        await displayLogic?.displayLoadExercises(viewModel: viewModel)
    }

    // MARK: - Select

    func presentSelectExercise(response: LogorhythmicsModels.SelectExercise.Response) async {
        guard let exercise = LogorhythmicsCorpus.exercise(id: response.exerciseId) else { return }
        let hint = makeHint(forCategory: exercise.category)
        let viewModel = LogorhythmicsModels.SelectExercise.ViewModel(
            exercise: exercise,
            totalBeats: exercise.totalBeats,
            beatDurationSeconds: exercise.beatDurationSeconds,
            hintMessage: hint
        )
        await displayLogic?.displaySelectExercise(viewModel: viewModel)
    }

    // MARK: - Beat tick

    func presentBeatTick(
        response: LogorhythmicsModels.BeatTick.Response,
        totalBeats: Int
    ) async {
        let viewModel = LogorhythmicsModels.BeatTick.ViewModel(
            beatIndex: response.beatIndex,
            totalBeats: totalBeats,
            isStrong: response.isStrong,
            accessibilityLabel: "Доля \(response.beatIndex + 1) из \(totalBeats)"
        )
        await displayLogic?.displayBeatTick(viewModel: viewModel)
    }

    // MARK: - Finish

    func presentFinishExercise(response: LogorhythmicsModels.FinishExercise.Response) async {
        let stars = scorer.stars(forF1: response.score.f1)
        let f1Percent = Int((response.score.f1 * 100).rounded())
        let (title, body) = makeFeedback(
            stars: stars,
            misses: response.score.misses,
            extras: response.score.extras
        )
        let hitsLabel = "Попаданий: \(response.score.hits) из \(response.score.expectedBeats)"
        let detailLabel = "Опоздал или пропустил: \(response.score.misses) · Лишних: \(response.score.extras)"
        let a11y = """
        \(response.exercise.title): \(stars) из 3 звёзд, \
        F1 \(f1Percent) процентов, попаданий \
        \(response.score.hits) из \(response.score.expectedBeats).
        """
        let viewModel = LogorhythmicsModels.FinishExercise.ViewModel(
            exercise: response.exercise,
            stars: stars,
            f1Percent: f1Percent,
            hitsLabel: hitsLabel,
            detailLabel: detailLabel,
            feedbackTitle: title,
            feedbackBody: body,
            accessibilityLabel: a11y
        )
        await displayLogic?.displayFinishExercise(viewModel: viewModel)
    }

    // MARK: - Helpers

    private func makeHint(forCategory category: String) -> String {
        switch category {
        case "топот":
            return "Топай в такт ножками!"
        case "хлопок":
            return "Хлопай в ладошки в такт!"
        case "качание":
            return "Качайся в такт — медленно и плавно."
        default:
            return "Двигайся в такт!"
        }
    }

    private func makeFeedback(stars: Int, misses: Int, extras: Int) -> (title: String, body: String) {
        switch stars {
        case 3:
            return ("Отличный ритм!",
                    "Ты попадал в такт почти всегда. Молодец!")
        case 2:
            if misses > extras {
                return ("Хороший ритм!",
                        "Постарайся не пропускать удары — слушай метроном.")
            }
            return ("Хороший ритм!",
                    "Постарайся не торопиться — двигайся ровно в такт.")
        case 1:
            return ("Хороший старт!",
                    "Послушай метроном внимательнее и двигайся вместе с ним.")
        default:
            return ("Попробуем ещё раз!",
                    "Слушай метроном и топай или хлопай ровно в такт.")
        }
    }
}
