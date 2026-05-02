import Foundation
import OSLog
import RealmSwift

// MARK: - ScreeningBusinessLogic

@MainActor
protocol ScreeningBusinessLogic: AnyObject {
    func startScreening(_ request: ScreeningModels.StartScreening.Request) async
    func prepareStage(_ request: ScreeningModels.PrepareStage.Request) async
    func startRecording(_ request: ScreeningModels.StartRecording.Request) async
    func stopRecordingAndScore(_ request: ScreeningModels.StopRecording.Request) async
    func submitAnswer(_ request: ScreeningModels.SubmitAnswer.Request) async
    func replayReferenceAudio(_ request: ScreeningModels.ReplayAudio.Request) async
    func finishScreening(_ request: ScreeningModels.FinishScreening.Request) async
    func completeScreening(_ request: ScreeningModels.CompleteRequest) async
    func requestMicrophonePermission() async
    func checkRescreeningEligibility(_ request: ScreeningModels.CheckRescreening.Request) async
}

// MARK: - ScreeningInteractor

/// Orchestrates the initial diagnostic flow covering 10 phoneme targets.
///
/// ## Flow
/// Welcome → IntroLyalya → SoundTest (10 stages) → Result → Persist → ParentHome
///
/// Each stage:
///   1. `prepareStage` — Ляля произносит подсказку, показывает target word
///   2. `startRecording` — AudioService начинает запись
///   3. `stopRecordingAndScore` — AudioService останавливает, PronunciationScorer оценивает
///   4. `submitAnswer` — сохраняет score, проверяет adaptive-stop (2 wrong подряд)
///
/// ## Adaptive early stop
/// Если 2 раза подряд score < threshold (0.4) — финиш досрочно со специальным флагом.
///
/// ## Scoring
/// - PronunciationScorer (4 group CoreML): hissing, whistling, sonants, velar
/// - Threshold ≥0.70 = mastered, 0.40–0.70 = needs practice, <0.40 = problem
/// - ASR fallback: если scorer недоступен — WhisperKit проверяет транскрипт
///
/// ## Persist
/// `ScreeningOutcomeObject` → Realm. Linked to childId.
/// Используется AdaptivePlannerService для initial plan.
///
/// ## Re-screening
/// Проверяет последнее `ScreeningOutcomeObject` — если прошло < 90 дней,
/// показывает предупреждение. Иначе: compare с предыдущим (improvement/regression).
@MainActor
final class ScreeningInteractor: ScreeningBusinessLogic {

    // MARK: - Dependencies

    var presenter: (any ScreeningPresentationLogic)?
    var router: ScreeningRouter?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "Screening")
    private let realmActor: RealmActor?
    private let audioService: (any AudioService)?
    private let pronunciationScorer: (any PronunciationScorerService)?
    private let asrService: (any ASRService)?

    // MARK: - Mutable state

    private var prompts: [ScreeningPrompt] = []
    private var scores: [String: Float] = [:]
    private var rawAudioURLs: [String: URL] = [:]
    private var childAge: Int = 6
    private var childId: String = ""
    private var consecutiveWrongCount: Int = 0
    private var isRecording: Bool = false
    private var currentStageIndex: Int = 0
    private var recordingStartedAt: Date?
    private var previousOutcome: ScreeningModels.PreviousOutcomeSummary?

    // MARK: - Constants

    private enum Threshold {
        static let achieved: Float = 0.70
        static let problem: Float = 0.40
        static let adaptiveStopWrongCount: Int = 2
        static let minRecordingSeconds: Double = 0.3
        static let maxRecordingSeconds: Double = 5.0
        static let rescreeningMinDays: Int = 90
    }

    // MARK: - Init

    init(
        realmActor: RealmActor? = nil,
        audioService: (any AudioService)? = nil,
        pronunciationScorer: (any PronunciationScorerService)? = nil,
        asrService: (any ASRService)? = nil
    ) {
        self.realmActor = realmActor
        self.audioService = audioService
        self.pronunciationScorer = pronunciationScorer
        self.asrService = asrService
    }

    // MARK: - ScreeningBusinessLogic: Start

    func startScreening(_ request: ScreeningModels.StartScreening.Request) async {
        childId = request.childId
        childAge = request.childAge
        prompts = ScreeningPromptFactory.tenSoundPrompts(for: childAge)
        scores.removeAll()
        rawAudioURLs.removeAll()
        consecutiveWrongCount = 0
        currentStageIndex = 0

        let cid = request.childId
        let age = request.childAge
        let count = prompts.count
        logger.info("screening start childId=\(cid, privacy: .private) age=\(age, privacy: .public) prompts=\(count, privacy: .public)")

        await loadScorerIfNeeded()

        let response = ScreeningModels.StartScreening.Response(
            prompts: prompts,
            totalBlocks: ScreeningBlock.allCases.count,
            lyalyaPhrase: String(localized: "screening.lyalya.welcome")
        )
        await presenter?.presentStartScreening(response)
    }

    // MARK: - ScreeningBusinessLogic: Stage preparation

    func prepareStage(_ request: ScreeningModels.PrepareStage.Request) async {
        guard prompts.indices.contains(request.stageIndex) else { return }
        currentStageIndex = request.stageIndex
        let prompt = prompts[request.stageIndex]

        let isFirst = request.stageIndex == 0
        let lyalyaPhrase: String
        if isFirst {
            lyalyaPhrase = String(localized: "screening.lyalya.first_sound")
        } else if request.stageIndex == prompts.count - 1 {
            lyalyaPhrase = String(localized: "screening.lyalya.last_sound")
        } else {
            lyalyaPhrase = String(localized: "screening.lyalya.next_sound")
        }

        let response = ScreeningModels.PrepareStage.Response(
            stageIndex: request.stageIndex,
            totalStages: prompts.count,
            prompt: prompt,
            lyalyaPhrase: lyalyaPhrase,
            canRecord: audioService != nil
        )
        await presenter?.presentPrepareStage(response)
    }

    // MARK: - ScreeningBusinessLogic: Recording

    func startRecording(_ request: ScreeningModels.StartRecording.Request) async {
        guard !isRecording else {
            logger.warning("screening startRecording called while already recording")
            return
        }
        guard let audio = audioService else {
            await presenter?.presentRecordingError(.init(
                errorMessage: String(localized: "screening.error.no_audio_service"),
                canContinueWithoutRecording: true
            ))
            return
        }
        guard audio.isPermissionGranted else {
            logger.notice("screening mic permission not granted — requesting")
            await requestMicrophonePermission()
            return
        }

        do {
            try await audio.startRecording()
            isRecording = true
            recordingStartedAt = Date()
            let idx = request.stageIndex
            logger.debug("screening recording started stage=\(idx, privacy: .public)")

            let response = ScreeningModels.StartRecording.Response(
                stageIndex: request.stageIndex,
                maxDurationSec: Threshold.maxRecordingSeconds
            )
            await presenter?.presentStartRecording(response)
        } catch {
            let msg = error.localizedDescription
            logger.error("screening startRecording failed: \(msg, privacy: .public)")
            await presenter?.presentRecordingError(.init(
                errorMessage: String(localized: "screening.error.recording_failed"),
                canContinueWithoutRecording: true
            ))
        }
    }

    func stopRecordingAndScore(_ request: ScreeningModels.StopRecording.Request) async {
        guard isRecording, let audio = audioService else {
            await skipCurrentSound(reason: .recordingUnavailable)
            return
        }

        let elapsed = recordingStartedAt.map { Date().timeIntervalSince($0) } ?? 0
        if elapsed < Threshold.minRecordingSeconds {
            logger.notice("screening recording too short — skipping")
            await skipCurrentSound(reason: .tooShort)
            return
        }

        do {
            let audioURL = try await audio.stopRecording()
            isRecording = false
            let idx = request.stageIndex
            logger.debug("screening recording stopped stage=\(idx, privacy: .public)")

            guard prompts.indices.contains(request.stageIndex) else { return }
            let prompt = prompts[request.stageIndex]
            rawAudioURLs[prompt.id] = audioURL

            let score = await scoreRecording(audioURL: audioURL, prompt: prompt)
            await handleScoredResult(score: score, promptId: prompt.id, stageIndex: request.stageIndex)
        } catch {
            isRecording = false
            let msg = error.localizedDescription
            logger.error("screening stopRecording failed: \(msg, privacy: .public)")
            await skipCurrentSound(reason: .recordingFailed)
        }
    }

    // MARK: - ScreeningBusinessLogic: Manual submit (no recording)

    func submitAnswer(_ request: ScreeningModels.SubmitAnswer.Request) async {
        scores[request.promptId] = request.score
        consecutiveWrongCount = request.score < Threshold.problem
            ? consecutiveWrongCount + 1
            : 0

        let currentIdx = prompts.firstIndex(where: { $0.id == request.promptId }) ?? -1
        let isLast = currentIdx >= prompts.count - 1
        let adaptiveStop = consecutiveWrongCount >= Threshold.adaptiveStopWrongCount

        let nextIdx = currentIdx + 1
        let blockTransition = !isLast
            && currentIdx >= 0
            && prompts[currentIdx].block != prompts[nextIdx].block

        let response = ScreeningModels.SubmitAnswer.Response(
            isBlockComplete: blockTransition,
            isScreeningComplete: isLast || adaptiveStop,
            currentPromptIndex: currentIdx,
            adaptiveStopTriggered: adaptiveStop && !isLast
        )
        await presenter?.presentSubmitAnswer(response)

        if isLast || adaptiveStop {
            await finishScreening(.init(childId: childId))
        }
    }

    // MARK: - ScreeningBusinessLogic: Replay reference audio

    func replayReferenceAudio(_ request: ScreeningModels.ReplayAudio.Request) async {
        guard let audio = audioService else { return }
        guard let referenceAsset = request.referenceAudioAsset,
              let url = Bundle.main.url(forResource: referenceAsset, withExtension: "mp3")
                ?? Bundle.main.url(forResource: referenceAsset, withExtension: "m4a") else {
            let asset = request.referenceAudioAsset ?? "nil"
            logger.notice("screening reference audio not found: \(asset, privacy: .public)")
            return
        }
        do {
            try await audio.playAudio(url: url)
        } catch {
            let msg = error.localizedDescription
            logger.error("screening replayReferenceAudio failed: \(msg, privacy: .public)")
        }
    }

    // MARK: - ScreeningBusinessLogic: Finish

    func finishScreening(_ request: ScreeningModels.FinishScreening.Request) async {
        if isRecording, let audio = audioService {
            isRecording = false
            _ = try? await audio.stopRecording()
        }

        let effectiveChildId = request.childId.isEmpty ? childId : request.childId
        let outcome = ScreeningScoringEngine.evaluate(
            childId: effectiveChildId,
            childAge: childAge,
            scores: scores,
            prompts: prompts
        )

        let priorities = outcome.priorityTargetSounds.joined(separator: ",")
        let dur = outcome.recommendedSessionDurationSec
        let cnt = scores.count
        logger.info("screening finish priorities=\(priorities, privacy: .public) duration=\(dur, privacy: .public)s scores=\(cnt, privacy: .public)")

        let adaptiveStopped = consecutiveWrongCount >= Threshold.adaptiveStopWrongCount
        let response = ScreeningModels.FinishScreening.Response(
            outcome: outcome,
            wasAdaptiveStopped: adaptiveStopped,
            testedSoundsCount: scores.count,
            totalSoundsCount: prompts.count,
            lyalyaFinishPhrase: outcome.priorityTargetSounds.isEmpty
                ? String(localized: "screening.lyalya.all_good")
                : String(localized: "screening.lyalya.plan_ready")
        )
        await presenter?.presentFinishScreening(response)
    }

    // MARK: - ScreeningBusinessLogic: Complete & persist

    /// Финальный шаг: сохраняет `ScreeningOutcomeObject` в Realm и переходит
    /// на ParentHome. Если RealmActor не предоставлен (preview / тесты) —
    /// persist шаг пропускается, навигация всё равно вызывается.
    func completeScreening(_ request: ScreeningModels.CompleteRequest) async {
        let soundsList = request.problematicSounds.joined(separator: ",")
        let cid = request.childId
        let sev = request.severity
        let resc = request.isRescreening
        logger.info("screening complete cid=\(cid, privacy: .private) sev=\(sev, privacy: .public) sounds=\(soundsList, privacy: .public) resc=\(resc, privacy: .public)")

        await persistOutcomeToRealm(request)
        router?.routeToParentHome()
    }

    // MARK: - ScreeningBusinessLogic: Microphone permission

    func requestMicrophonePermission() async {
        guard let audio = audioService else { return }
        let granted = await audio.requestPermission()
        logger.info("screening mic permission granted=\(granted, privacy: .public)")
        let response = ScreeningModels.MicrophonePermission.Response(isGranted: granted)
        await presenter?.presentMicrophonePermission(response)
    }

    // MARK: - ScreeningBusinessLogic: Re-screening check

    func checkRescreeningEligibility(_ request: ScreeningModels.CheckRescreening.Request) async {
        guard let realm = realmActor else {
            await presenter?.presentRescreeningCheck(.init(
                isEligible: true,
                daysSinceLastScreening: nil,
                previousOutcomeSummary: nil
            ))
            return
        }

        let lastObject = await Self.fetchLastOutcome(childId: request.childId, realmActor: realm)
        let response: ScreeningModels.CheckRescreening.Response

        if let lastDate = lastObject?.completedAt {
            let daysSince = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
            let eligible = daysSince >= Threshold.rescreeningMinDays
            let summary = lastObject.map { obj in
                ScreeningModels.PreviousOutcomeSummary(
                    completedAt: obj.completedAt,
                    severity: obj.overallSeverity,
                    problematicSounds: Array(obj.problematicSounds),
                    daysSince: daysSince
                )
            }
            previousOutcome = summary
            logger.info("screening rescreening check daysSince=\(daysSince, privacy: .public) eligible=\(eligible, privacy: .public)")
            response = .init(
                isEligible: eligible,
                daysSinceLastScreening: daysSince,
                previousOutcomeSummary: summary
            )
        } else {
            response = .init(isEligible: true, daysSinceLastScreening: nil, previousOutcomeSummary: nil)
        }

        await presenter?.presentRescreeningCheck(response)
    }

    // MARK: - Private: Scorer loading

    private func loadScorerIfNeeded() async {
        guard let scorer = pronunciationScorer, !scorer.isModelLoaded else { return }
        do {
            try await scorer.loadModel()
            logger.info("screening PronunciationScorer loaded")
        } catch {
            let msg = error.localizedDescription
            logger.warning("screening PronunciationScorer load failed: \(msg, privacy: .public)")
        }
    }

    // MARK: - Private: Score audio recording

    private func scoreRecording(audioURL: URL, prompt: ScreeningPrompt) async -> Float {
        // Breathing block uses duration heuristic, not phoneme model
        if prompt.block == .breathingDuration {
            return scoreBreathingPrompt(prompt: prompt)
        }

        // Try PronunciationScorer first
        if let scorer = pronunciationScorer {
            do {
                let result = try await scorer.score(audioURL: audioURL, targetSound: prompt.targetSound)
                let score = Float(result.value)
                let sound = prompt.targetSound
                logger.debug("screening scorer sound=\(sound, privacy: .public) score=\(score, privacy: .public)")
                return score
            } catch {
                let sound = prompt.targetSound
                let msg = error.localizedDescription
                logger.warning("screening scorer failed for \(sound, privacy: .public): \(msg, privacy: .public)")
            }
        }

        // ASR fallback: compare transcribed word with stimulus
        if let asr = asrService, asr.isReady {
            return await scoreWithASR(audioURL: audioURL, prompt: prompt, asr: asr)
        }

        // Last resort: neutral score (не штрафуем ребёнка если сервисы недоступны)
        logger.notice("screening all scorers unavailable — assigning neutral score 0.55")
        return 0.55
    }

    private func scoreWithASR(audioURL: URL, prompt: ScreeningPrompt, asr: any ASRService) async -> Float {
        do {
            let result = try await asr.transcribe(url: audioURL)
            let transcript = result.transcript.lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let stimulus = prompt.stimulus.lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if transcript.contains(stimulus) || stimulus.contains(transcript) {
                return 0.80
            }
            // Partial match: check if target sound is present in transcript
            let targetLower = prompt.targetSound.lowercased()
            if transcript.contains(targetLower) {
                return 0.55
            }
            return 0.25
        } catch {
            let msg = error.localizedDescription
            logger.warning("screening ASR fallback failed: \(msg, privacy: .public)")
            return 0.50
        }
    }

    private func scoreBreathingPrompt(prompt: ScreeningPrompt) -> Float {
        // Breathing scored by duration held vs acceptableHoldSeconds
        guard let holdTarget = prompt.acceptableHoldSeconds else { return 0.70 }
        let elapsed = recordingStartedAt.map { Date().timeIntervalSince($0) } ?? holdTarget
        let ratio = Float(min(elapsed, holdTarget * 1.5) / holdTarget)
        return min(1.0, max(0.0, ratio))
    }

    // MARK: - Private: Handle scored result

    private func handleScoredResult(score: Float, promptId: String, stageIndex: Int) async {
        scores[promptId] = score
        let isWrong = score < Threshold.problem
        consecutiveWrongCount = isWrong ? consecutiveWrongCount + 1 : 0

        let wrong = consecutiveWrongCount
        logger.debug("screening scored promptId=\(promptId, privacy: .public) score=\(score, privacy: .public) consecutiveWrong=\(wrong, privacy: .public)")

        let adaptiveStop = consecutiveWrongCount >= Threshold.adaptiveStopWrongCount
        let isLast = stageIndex >= prompts.count - 1

        let nextIdx = stageIndex + 1
        let blockTransition = !isLast
            && stageIndex >= 0
            && stageIndex < prompts.count - 1
            && prompts[stageIndex].block != prompts[nextIdx].block

        let response = ScreeningModels.SubmitAnswer.Response(
            isBlockComplete: blockTransition,
            isScreeningComplete: isLast || adaptiveStop,
            currentPromptIndex: stageIndex,
            adaptiveStopTriggered: adaptiveStop && !isLast
        )
        await presenter?.presentSubmitAnswer(response)

        if isLast || adaptiveStop {
            if adaptiveStop {
                logger.info("screening adaptive stop triggered after \(wrong, privacy: .public) consecutive wrong")
            }
            await finishScreening(.init(childId: childId))
        }
    }

    // MARK: - Private: Skip sound

    private enum SkipReason { case recordingUnavailable, tooShort, recordingFailed }

    private func skipCurrentSound(reason: SkipReason) async {
        guard prompts.indices.contains(currentStageIndex) else { return }
        let prompt = prompts[currentStageIndex]
        let sound = prompt.targetSound
        logger.notice("screening skipping sound=\(sound, privacy: .public)")
        // Assign "not tested" score — neutral, не влияет на приоритет
        await handleScoredResult(score: 0.55, promptId: prompt.id, stageIndex: currentStageIndex)
    }

    // MARK: - Private: Realm persist

    private func persistOutcomeToRealm(_ request: ScreeningModels.CompleteRequest) async {
        guard let realmActor else {
            logger.notice("screening persist skipped — realmActor not provided")
            return
        }

        let perSoundJSON = buildPerSoundJSON()
        await Self.writeOutcome(
            request: request,
            perSoundJSON: perSoundJSON,
            realmActor: realmActor
        )
    }

    private func buildPerSoundJSON() -> String {
        // Serialize per-sound scores as JSON string for Realm notes field
        var dict: [String: Float] = [:]
        for prompt in prompts {
            if let score = scores[prompt.id] {
                dict[prompt.targetSound] = score
            }
        }
        let pairs = dict
            .sorted { $0.key < $1.key }
            .map { "\"\($0.key)\":\($0.value)" }
            .joined(separator: ",")
        return "{\(pairs)}"
    }

    nonisolated private static func writeOutcome(
        request: ScreeningModels.CompleteRequest,
        perSoundJSON: String,
        realmActor: RealmActor
    ) async {
        await realmActor.asyncWrite { realm in
            let outcome = ScreeningOutcomeObject()
            outcome.childId = request.childId
            outcome.completedAt = Date()
            outcome.overallSeverity = request.severity
            outcome.problematicSounds.removeAll()
            outcome.problematicSounds.append(objectsIn: request.problematicSounds)
            outcome.recommendedPacks.removeAll()
            outcome.recommendedPacks.append(objectsIn: request.recommendedPacks)
            let notesPrefix = perSoundJSON.isEmpty ? "" : "scores:\(perSoundJSON);"
            outcome.notes = notesPrefix + request.notes
            outcome.screeningVersion = 2
            realm.add(outcome, update: .modified)
        }
    }

    // MARK: - Private: Re-screening — fetch last outcome

    private struct OutcomeSnapshot: Sendable {
        let childId: String
        let completedAt: Date
        let overallSeverity: String
        let problematicSounds: [String]
        let notes: String
        let screeningVersion: Int
    }

    nonisolated private static func fetchLastOutcome(
        childId: String,
        realmActor: RealmActor
    ) async -> ScreeningOutcomeObject? {
        let predicate = NSPredicate(format: "childId == %@", childId)
        let snapshots: [OutcomeSnapshot] = (try? await realmActor.fetchFilteredMappedAsync(
            ScreeningOutcomeObject.self,
            predicate: predicate
        ) { obj in
            OutcomeSnapshot(
                childId: obj.childId,
                completedAt: obj.completedAt,
                overallSeverity: obj.overallSeverity,
                problematicSounds: Array(obj.problematicSounds),
                notes: obj.notes,
                screeningVersion: obj.screeningVersion
            )
        }) ?? []

        guard let latest = snapshots.sorted(by: { $0.completedAt > $1.completedAt }).first else {
            return nil
        }

        let copy = ScreeningOutcomeObject()
        copy.childId = latest.childId
        copy.completedAt = latest.completedAt
        copy.overallSeverity = latest.overallSeverity
        copy.problematicSounds.append(objectsIn: latest.problematicSounds)
        copy.notes = latest.notes
        copy.screeningVersion = latest.screeningVersion
        return copy
    }

    // MARK: - Testing helpers

    func testState() -> (prompts: [ScreeningPrompt], scores: [String: Float], consecutiveWrong: Int) {
        (prompts, scores, consecutiveWrongCount)
    }
}
