import Foundation
import OSLog

// MARK: - ARFaceFilterBusinessLogic

@MainActor
protocol ARFaceFilterBusinessLogic: AnyObject {
    func setMask(request: ARFaceFilterModels.SetMask.Request) async
    func processTranscription(request: ARFaceFilterModels.Trigger.Request) async
}

// MARK: - ARFaceFilterInteractor (Clean Swift: Interactor)
//
// Block S.4 v16 — переключение масок и обработка ASR-trigger.
//
// Алгоритм:
//   1. setMask(.kitten) → presenter обновляет UI с приглашением «Скажи "кот"!»
//   2. ASR (polling 1-sec chunks) → передаёт recognizedText сюда
//   3. Если matched → glow → celebration (Lyalya phrase)

@MainActor
final class ARFaceFilterInteractor: ARFaceFilterBusinessLogic {

    // MARK: VIP

    var presenter: (any ARFaceFilterPresentationLogic)?

    // MARK: State

    private var currentMask: FaceMaskKind = .kitten
    private static let logger = Logger(subsystem: "ru.happyspeech", category: "ARFaceFilter")

    // MARK: - Set mask

    func setMask(request: ARFaceFilterModels.SetMask.Request) async {
        currentMask = request.mask
        await presenter?.presentSetMask(mask: request.mask)
    }

    // MARK: - Trigger

    func processTranscription(request: ARFaceFilterModels.Trigger.Request) async {
        let normalized = request.recognizedText
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let triggerWord = currentMask.triggerWord.lowercased()
        let isMatched = normalized.contains(triggerWord)

        let response = ARFaceFilterModels.Trigger.Response(
            isMatched: isMatched,
            matchedWord: isMatched ? triggerWord : ""
        )
        await presenter?.presentTrigger(response: response, mask: currentMask)
        if isMatched {
            Self.logger.info("Face filter trigger matched: mask=\(self.currentMask.rawValue, privacy: .public)")
        }
    }
}

// TODO defer to Block Q (test coverage): unit tests for case-insensitive
// matching, partial match (substring vs whole word), wrong-trigger negative.
