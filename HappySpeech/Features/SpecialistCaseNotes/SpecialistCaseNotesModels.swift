import Foundation

// MARK: - SpecialistCaseNotesModels

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
enum SpecialistCaseNotesModels {

    struct Note: Identifiable, Hashable {
        let id: UUID
        let date: Date
        let body: String
    }

    struct ViewState: Equatable {
        var notes: [Note]
        var isAddingNote: Bool
        var draftBody: String

        static let initial: ViewState = {
            // Seed 3 заметки за последние дни.
            let now = Date()
            let calendar = Calendar.current
            let notes: [Note] = [
                Note(
                    id: UUID(),
                    date: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
                    body: "Чёткое улучшение Р. Произнесла «рыбка» 4/5 раз. Закрепляем на следующей сессии."
                ),
                Note(
                    id: UUID(),
                    date: calendar.date(byAdding: .day, value: -4, to: now) ?? now,
                    body: "Усталость к концу занятия — снизили нагрузку на артикуляционную гимнастику с 5 до 3 повторений."
                ),
                Note(
                    id: UUID(),
                    date: calendar.date(byAdding: .day, value: -7, to: now) ?? now,
                    body: "Начали работу над звуком Ш. Хорошее понимание инструкции, но язык в широком положении ещё не уверенно."
                )
            ]
            return ViewState(notes: notes, isAddingNote: false, draftBody: "")
        }()
    }
}
