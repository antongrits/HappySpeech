import Foundation
import OSLog

// MARK: - ParentHomeBusinessLogic

@MainActor
protocol ParentHomeBusinessLogic: AnyObject {
    func fetchData(_ request: ParentHomeModels.Fetch.Request) async
    func refresh() async
    func switchChild(to childId: String) async
}

// MARK: - ParentHomeInteractor

@MainActor
final class ParentHomeInteractor: ParentHomeBusinessLogic {

    var presenter: (any ParentHomePresentationLogic)?

    private let childRepository: any ChildRepository
    private let sessionRepository: any SessionRepository
    private var activeChildId: String?

    init(
        childRepository: any ChildRepository,
        sessionRepository: any SessionRepository
    ) {
        self.childRepository = childRepository
        self.sessionRepository = sessionRepository
    }

    func fetchData(_ request: ParentHomeModels.Fetch.Request) async {
        presenter?.presentLoading(true)
        do {
            let children = try await childRepository.fetchAll()
            guard let child = Self.resolveChild(children: children, preferred: request.preferredChildId) else {
                presenter?.presentEmpty()
                return
            }
            activeChildId = child.id
            try await emit(child: child)
        } catch {
            HSLogger.ui.error("ParentHome fetch failed: \(error)")
            presenter?.presentEmpty()
        }
    }

    func refresh() async {
        guard let activeId = activeChildId else {
            await fetchData(.init(preferredChildId: nil))
            return
        }
        do {
            let child = try await childRepository.fetch(id: activeId)
            try await emit(child: child)
        } catch {
            HSLogger.ui.error("ParentHome refresh failed: \(error)")
        }
    }

    func switchChild(to childId: String) async {
        do {
            let child = try await childRepository.fetch(id: childId)
            activeChildId = child.id
            try await emit(child: child)
        } catch {
            HSLogger.ui.error("ParentHome switchChild failed: \(error)")
        }
    }

    // MARK: - Helpers

    private func emit(child: ChildProfileDTO) async throws {
        let recent = (try? await sessionRepository.fetchRecent(childId: child.id, limit: 10)) ?? []
        let sessionData = recent.map { Self.sessionData(from: $0) }

        let overall = Self.overallRate(for: child.progressSummary)
        let homeTask = Self.homeTask(for: child)

        let response = ParentHomeModels.Fetch.Response(
            childId: child.id,
            childName: child.name,
            childAge: child.age,
            targetSounds: child.targetSounds,
            currentStreak: child.currentStreak,
            totalSessionMinutes: child.totalSessionMinutes,
            overallRate: overall,
            recentSessions: sessionData,
            progressSummary: child.progressSummary,
            homeTask: homeTask
        )
        presenter?.presentFetch(response)
    }

    private static func resolveChild(children: [ChildProfileDTO], preferred: String?) -> ChildProfileDTO? {
        if let preferred, let match = children.first(where: { $0.id == preferred }) {
            return match
        }
        return children.first
    }

    private static func sessionData(from dto: SessionDTO) -> ParentHomeModels.SessionData {
        ParentHomeModels.SessionData(
            id: dto.id,
            date: dto.date,
            templateType: dto.templateType,
            targetSound: dto.targetSound,
            durationSeconds: dto.durationSeconds,
            totalAttempts: dto.totalAttempts,
            correctAttempts: dto.correctAttempts
        )
    }

    private static func overallRate(for summary: [String: Double]) -> Double {
        guard !summary.isEmpty else { return 0.0 }
        let total = summary.values.reduce(0.0, +)
        return total / Double(summary.count)
    }

    private static func homeTask(for child: ChildProfileDTO) -> String? {
        // Rule-based Tier C fallback — picks the weakest target sound
        // and builds a simple practice suggestion. LLM-generated tasks
        // will plug into this method when `LLMDecisionService` is wired.
        guard let weakest = child.targetSounds
            .map({ ($0, child.progressSummary[$0] ?? 0.0) })
            .min(by: { $0.1 < $1.1 })?
            .0
        else { return nil }
        let format = String(localized: "parent.home.homeTask.fallback")
        return String.localizedStringWithFormat(format, weakest)
    }
}
