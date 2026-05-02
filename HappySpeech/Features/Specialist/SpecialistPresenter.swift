import Foundation
import OSLog
import SwiftUI

// MARK: - SpecialistPresentationLogic

@MainActor
protocol SpecialistPresentationLogic: AnyObject {
    func presentFetch(_ response: SpecialistModels.Fetch.Response)
    func presentUpdate(_ response: SpecialistModels.Update.Response)
    func presentChildDashboard(_ response: SpecialistModels.FetchChildDashboard.Response)
    func presentSaveNote(_ response: SpecialistModels.SaveNote.Response)
    func presentFetchNotes(_ response: SpecialistModels.FetchNotes.Response)
    func presentExport(_ response: SpecialistModels.RequestExport.Response)
    func presentSendMessage(_ response: SpecialistModels.SendParentMessage.Response)
    func presentDeleteNote(_ response: SpecialistModels.DeleteNote.Response)
    func presentError(_ message: String)
}

// MARK: - SpecialistPresenter

@MainActor
final class SpecialistPresenter: SpecialistPresentationLogic {

    weak var viewModel: (any SpecialistDisplayLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "Specialist.Presenter")

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.unitsStyle = .full
        return f
    }()

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    // MARK: - Fetch

    func presentFetch(_ response: SpecialistModels.Fetch.Response) {
        let rows = response.children.map { entry in
            let ageLine = Self.ageLine(age: entry.age)
            let lastSession = entry.lastSessionAt.map {
                Self.relativeFormatter.localizedString(for: $0, relativeTo: Date())
            } ?? String(localized: "spec.neverPracticed")
            let progress = Int((entry.overallSuccessRate * 100).rounded())
            let needs = entry.targetSounds.filter { _ in
                entry.overallSuccessRate < 0.5
            }
            return SpecialistModels.Fetch.ViewModel.ChildRow(
                id: entry.id,
                name: entry.name,
                ageLine: ageLine,
                targetSounds: entry.targetSounds,
                lastSessionLabel: lastSession,
                overallProgressPercent: progress,
                needsAttentionSounds: needs
            )
        }
        let vm = SpecialistModels.Fetch.ViewModel(rows: rows, sortLabel: String(localized: "spec.sort.byActivity"))
        viewModel?.displayFetch(vm)
    }

    func presentUpdate(_ response: SpecialistModels.Update.Response) {
        viewModel?.displayUpdate(SpecialistModels.Update.ViewModel())
    }

    // MARK: - Child Dashboard

    func presentChildDashboard(_ response: SpecialistModels.FetchChildDashboard.Response) {
        let child  = response.child
        let summary = response.summary
        let ageLine = Self.ageLine(age: child.age)
        let totalSessions = String(format: String(localized: "spec.sessions.count"), summary.totalSessions)
        let totalMinutes  = String(format: String(localized: "spec.minutes.count"), summary.totalMinutes)
        let overallPct    = "\(Int((summary.overallSuccessRate * 100).rounded()))%"

        let soundRows: [SpecialistModels.FetchChildDashboard.ViewModel.SoundProgressRow] = response.soundBreakdown.map { row in
            let pct  = Int((row.averageConfidence * 100).rounded())
            let sign = row.weekOverWeekDelta >= 0 ? "+" : ""
            let delta = "\(sign)\(Int((row.weekOverWeekDelta * 100).rounded()))%"
            return .init(
                id: row.sound,
                sound: row.sound,
                percentText: "\(pct)%",
                deltaText: delta,
                isStruggling: row.averageConfidence < 0.5
            )
        }

        let report = response.llmReport
        let vm = SpecialistModels.FetchChildDashboard.ViewModel(
            childName: child.name,
            childAgeLine: ageLine,
            totalSessionsText: totalSessions,
            totalMinutesText: totalMinutes,
            overallPercentText: overallPct,
            soundRows: soundRows,
            llmHeadline: report?.headline ?? String(localized: "spec.report.noData"),
            llmStrengths: report?.strengths ?? [],
            llmWeaknesses: report?.weaknesses ?? [],
            llmRecommendations: report?.recommendations ?? [],
            nextMilestoneText: report?.nextMilestone ?? ""
        )
        viewModel?.displayChildDashboard(vm)
    }

    // MARK: - Notes

    func presentSaveNote(_ response: SpecialistModels.SaveNote.Response) {
        let vm = SpecialistModels.SaveNote.ViewModel(
            confirmationText: String(localized: "spec.note.saved"),
            notePreview: String(response.note.text.prefix(60))
        )
        viewModel?.displaySaveNote(vm)
    }

    func presentFetchNotes(_ response: SpecialistModels.FetchNotes.Response) {
        let rows = response.notes.map { note in
            SpecialistModels.FetchNotes.ViewModel.NoteRow(
                id: note.id,
                dateLabel: Self.shortDateFormatter.string(from: note.createdAt),
                preview: String(note.text.prefix(80))
            )
        }
        let vm = SpecialistModels.FetchNotes.ViewModel(
            rows: rows,
            emptyStateText: String(localized: "spec.notes.empty")
        )
        viewModel?.displayFetchNotes(vm)
    }

    func presentDeleteNote(_ response: SpecialistModels.DeleteNote.Response) {
        let text = response.success
            ? String(localized: "spec.note.deleted")
            : String(localized: "spec.note.deleteFailed")
        viewModel?.displayDeleteNote(.init(feedbackText: text))
    }

    // MARK: - Export

    func presentExport(_ response: SpecialistModels.RequestExport.Response) {
        let kb = Double(response.sizeBytes) / 1024.0
        let sizeLabel = String(format: "%.1f KB", kb)
        let message = String(format: String(localized: "spec.export.ready"), response.format.rawValue)
        let vm = SpecialistModels.RequestExport.ViewModel(
            shareURL: response.fileURL,
            sizeLabel: sizeLabel,
            successMessage: message
        )
        viewModel?.displayExport(vm)
    }

    // MARK: - Send Message

    func presentSendMessage(_ response: SpecialistModels.SendParentMessage.Response) {
        let text = response.delivered
            ? String(localized: "spec.message.sent")
            : String(localized: "spec.message.failed")
        viewModel?.displaySendMessage(.init(statusText: text, isError: !response.delivered))
    }

    // MARK: - Error

    func presentError(_ message: String) {
        logger.error("Specialist error: \(message, privacy: .public)")
        viewModel?.displayError(message)
    }

    // MARK: - Private helpers

    private static func ageLine(age: Int) -> String {
        let suffix: String
        switch age {
        case 1, 21, 31: suffix = "год"
        case 2, 3, 4, 22, 23, 24: suffix = "года"
        default: suffix = "лет"
        }
        return "\(age) \(suffix)"
    }
}
