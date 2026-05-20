import Foundation
import OSLog

// MARK: - CustomWordListWorkerProtocol

@MainActor
protocol CustomWordListWorkerProtocol {
    func fetchAll(specialistId: String) async -> [CustomWordListData]
    func save(_ data: CustomWordListData) async
    func delete(id: String) async -> Bool
    func generateExercises(from draft: WordListDraft) -> [GeneratedExercise]
}

// MARK: - LiveCustomWordListWorker

@MainActor
final class LiveCustomWordListWorker: CustomWordListWorkerProtocol {

    private let realmActor: RealmActor

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "CustomWordList.Worker"
    )

    init(realmActor: RealmActor) {
        self.realmActor = realmActor
    }

    func fetchAll(specialistId: String) async -> [CustomWordListData] {
        await realmActor.fetchCustomWordLists(specialistId: specialistId)
    }

    func save(_ data: CustomWordListData) async {
        await realmActor.persistCustomWordList(data)
    }

    func delete(id: String) async -> Bool {
        await realmActor.deleteCustomWordList(id: id)
    }

    /// Преобразует draft в набор сгенерированных упражнений.
    /// Это лёгкий комбинатор поверх плоского списка слов; «настоящий»
    /// ContentEngine использует ту же логику в SoundPack — здесь
    /// дублируется минимальный pure-Swift вариант для предпросмотра
    /// специалисту.
    func generateExercises(from draft: WordListDraft) -> [GeneratedExercise] {
        let trimmedWords = draft.words
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !trimmedWords.isEmpty else { return [] }
        let sound = draft.targetSound
        var exercises: [GeneratedExercise] = []
        // 1) repeat-after-model — всегда генерируется, базовое упражнение
        exercises.append(GeneratedExercise(
            id: "\(draft.id)-rep",
            kind: .repeatAfterModel,
            words: trimmedWords,
            targetSound: sound
        ))
        // 2) bingo — требует минимум 4 слов
        if trimmedWords.count >= 4 {
            exercises.append(GeneratedExercise(
                id: "\(draft.id)-bingo",
                kind: .bingo,
                words: Array(trimmedWords.prefix(9)),
                targetSound: sound
            ))
        }
        // 3) memory — требует минимум 4 слова (пары формируются повторением)
        if trimmedWords.count >= 4 {
            exercises.append(GeneratedExercise(
                id: "\(draft.id)-mem",
                kind: .memory,
                words: Array(trimmedWords.prefix(8)),
                targetSound: sound
            ))
        }
        return exercises
    }
}
