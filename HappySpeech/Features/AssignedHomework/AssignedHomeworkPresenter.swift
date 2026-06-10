import Foundation
import OSLog

// MARK: - AssignedHomeworkPresentationLogic

@MainActor
protocol AssignedHomeworkPresentationLogic: AnyObject {
    func presentLoad(response: AssignedHomeworkModels.Load.Response) async
    func presentCreate(response: AssignedHomeworkModels.Create.Response) async
    func presentUpdateStatus(response: AssignedHomeworkModels.UpdateStatus.Response) async
    func presentFamilyLoad(response: AssignedHomeworkModels.FamilyLoad.Response) async
}

// MARK: - AssignedHomeworkPresenter (Clean Swift: Presenter)
//
// Строит ViewModel конструктора заданий: списки детей и шаблонов, строки
// существующих заданий со статусом, сообщение о результате создания.
// Все строки — String(localized:). Никакой бизнес-логики здесь нет.

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

    // MARK: - Load (specialist screen)

    func presentLoad(response: AssignedHomeworkModels.Load.Response) async {
        let childLookup = Dictionary(
            uniqueKeysWithValues: response.children.map { ($0.id, $0.name) }
        )
        let rows = response.assignments.map { assignment in
            makeRowViewModel(assignment: assignment, childLookup: childLookup)
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

    // MARK: - Update status

    func presentUpdateStatus(response: AssignedHomeworkModels.UpdateStatus.Response) async {
        let progress: String
        if let a = response.updatedAssignment {
            progress = String(
                format: String(localized: "assignedHomework.status.progress"),
                a.doneCount,
                a.exercises.count
            )
        } else {
            progress = ""
        }
        let viewModel = AssignedHomeworkModels.UpdateStatus.ViewModel(
            didSucceed: response.didSucceed,
            progressLabel: progress
        )
        await displayLogic?.displayUpdateStatus(viewModel: viewModel)
    }

    // MARK: - Family load (parent / child screen)

    func presentFamilyLoad(response: AssignedHomeworkModels.FamilyLoad.Response) async {
        let rows = response.assignments.map { assignment in
            makeRowViewModel(assignment: assignment, childLookup: [:])
        }
        let viewModel = AssignedHomeworkModels.FamilyLoad.ViewModel(
            assignments: rows,
            emptyStateText: String(localized: "assignedHomework.family.empty")
        )
        await displayLogic?.displayFamilyLoad(viewModel: viewModel)
    }

    // MARK: - Helpers

    private func makeRowViewModel(
        assignment: HomeworkAssignment,
        childLookup: [String: String]
    ) -> AssignedHomeworkModels.Load.AssignmentRowViewModel {
        .init(
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
}
