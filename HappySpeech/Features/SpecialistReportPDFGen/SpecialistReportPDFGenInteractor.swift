import Foundation
import OSLog

// MARK: - SpecialistReportPDFGenInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
/// UI-only stub for PDF generation. Real PDF gen — post-launch.
@MainActor
@Observable
final class SpecialistReportPDFGenInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SpecialistReportPDFGen"
    )

    let childId: String
    let specialistId: String
    var state: SpecialistReportPDFGenModels.ViewState

    init(childId: String, specialistId: String) {
        self.childId = childId
        self.specialistId = specialistId
        self.state = .initial
    }

    func toggle(_ section: SpecialistReportPDFGenModels.Section) {
        if state.sections.contains(section) {
            state.sections.remove(section)
        } else {
            state.sections.insert(section)
        }
        Self.logger.info("toggle section \(section.rawValue, privacy: .public)")
    }

    func generate() async {
        state.isGenerating = true
        Self.logger.info("PDF generation requested (UI-stub)")
        try? await Task.sleep(for: .seconds(1))
        state.isGenerating = false
    }
}
