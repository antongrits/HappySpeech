import Foundation
import OSLog

// MARK: - AssignedHomeworkPresentationLogic

@MainActor
protocol AssignedHomeworkPresentationLogic: AnyObject {
    func presentLoad(response: AssignedHomeworkModels.Load.Response) async
    func presentCreate(response: AssignedHomeworkModels.Create.Response) async
}

// MARK: - AssignedHomeworkPresenter (Clean Swift: Presenter)
//
// v29 Фаза 8, Функция 4 «Домашнее задание от логопеда».
//
// Строит ViewModel конструктора заданий: списки детей и шаблонов, строки
// существующих заданий со статусом, сообщение о результате создания.
// Все строки — String(localized:).

@MainActor
final class AssignedHomeworkPresenter: AssignedHomeworkPresentationLogic {

    weak var displayLogic: (any AssignedHomeworkDisplayLogic)?

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM"
        return formatter
    }()

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "AssignedHomework.Presenter"
    )

    init(displayLogic: (any AssignedHomeworkDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    // MARK: - Load

    func presentLoad(response: AssignedHomeworkModels.Load.Response) async {
        let childLookup = Dictionary(
            uniqueKeysWithValues: response.children.map { ($0.id, $0.name) }
        )
        let rows = response.assignments.map { assignment in
            AssignedHomeworkModels.Load.AssignmentRowViewModel(
                id: assignment.id,
                childName: childLookup[assignment.childId]
                    ?? String(localized: "assignedHomework.unknownChild"),
                exerciseCountLabel: String(
                    format: String(localized: "assignedHomework.exerciseCount"),
                    assignment.exercises.count
                ),
                dueLabel: String(
                    format: String(localized: "assignedHomework.due"),
                    Self.dateFormatter.string(from: assignment.dueDate)
                ),
                statusLabel: assignment.isComplete
                    ? String(localized: "assignedHomework.status.done")
                    : String(
                        format: String(localized: "assignedHomework.status.progress"),
                        assignment.doneCount,
                        assignment.exercises.count
                      ),
                isComplete: assignment.isComplete,
                accessibilityLabel: String(
                    format: String(localized: "assignedHomework.row.a11y"),
                    childLookup[assignment.childId]
                        ?? String(localized: "assignedHomework.unknownChild"),
                    assignment.exercises.count
                )
            )
        }
        let viewModel = AssignedHomeworkModels.Load.ViewModel(
            title: String(localized: "assignedHomework.title"),
            children: response.children.map { .init(id: $0.id, name: $0.name) },
            templates: response.availableTemplates.map {
                .init(id: $0.rawValue, name: $0.displayName)
            },
            assignments: rows,
            emptyStateText: String(localized: "assignedHomework.empty")
        )
        await displayLogic?.displayLoad(viewModel: viewModel)
    }

    // MARK: - Create

    func presentCreate(response: AssignedHomeworkModels.Create.Response) async {
        let viewModel = AssignedHomeworkModels.Create.ViewModel(
            didSucceed: response.didSucceed,
            message: response.didSucceed
                ? String(localized: "assignedHomework.create.success")
                : String(localized: "assignedHomework.create.failure")
        )
        await displayLogic?.displayCreate(viewModel: viewModel)
    }
}
