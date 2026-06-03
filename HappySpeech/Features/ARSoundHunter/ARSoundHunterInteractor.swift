import Foundation
import OSLog

// MARK: - ARSoundHunterBusinessLogic

@MainActor
protocol ARSoundHunterBusinessLogic: AnyObject {
    func startGame(_ request: ARSoundHunterModels.StartGame.Request)
    func frameClassified(_ request: ARSoundHunterModels.FrameClassified.Request)
    func selectCard(_ request: ARSoundHunterModels.SelectCard.Request)
    func scoreNaming(_ request: ARSoundHunterModels.ScoreNaming.Request)
    func nextRound(_ request: ARSoundHunterModels.NextRound.Request)
}

// MARK: - ARSoundHunterInteractor
//
// Бизнес-логика игры «Звуковой охотник по комнате».
//
// Clean Swift поток:
//   View (камера/карточки + запись голоса) → Interactor → Presenter → ViewModel → View
//
// Зависимости (через протоколы, не импортируя Data/ML/Sync напрямую):
//   - VisionObjectClassifierWorker: классификация кадра (Apple Vision, on-device)
//   - ChildRepository: возраст + целевые звуки ребёнка
//
// Бизнес-правила:
//   - Целевой звук: override (планировщик) → первый targetSound ребёнка → "С".
//   - Анти-мерцание: предмет «захвачен» только после `lockFramesRequired` подряд
//     кадров с тем же словом-кандидатом и достаточной уверенностью.
//   - Скоринг: совпадение ASR-слова + произношение ≥ порога = 3★; одно из двух = 2★;
//     иначе 1★ (звезда «за попытку» — мягкая логопедическая мотивация, без 0★).
//   - Звёзды НИКОГДА не ставятся за молчание (пустой transcript + notScored → повтор).
//
// COPPA: вся обработка on-device; никаких сетевых вызовов из детского контура.

@MainActor
final class ARSoundHunterInteractor: ARSoundHunterBusinessLogic {

    var presenter: (any ARSoundHunterPresentationLogic)?

    /// Worker классификации кадра. Внедряется (mock в тестах/preview).
    private let classifier: any VisionObjectClassifierWorkerProtocol
    /// Источник профиля ребёнка (возраст / целевые звуки). nil → дефолты.
    private let childRepository: (any ChildRepository)?

    // MARK: - Tuning

    /// Сколько подряд кадров нужно удерживать предмет, чтобы «захватить» его.
    private let lockFramesRequired = 6
    /// Минимальная уверенность Vision, при которой кадр считается кандидатом.
    private let candidateConfidence: Float = 0.30
    /// Порог произношения для зачёта звука.
    private let pronunciationPassThreshold = 0.6

    // MARK: - State

    private var targetSound: String = "С"
    private var childAge: Int = 6
    private var currentMode: ARSoundHunterModels.Mode = .camera
    private var lockedWord: String?
    private var lockCandidate: String?
    private var lockCount = 0
    private var totalFound = 0
    /// Какие слова-карточки фоллбэк-сетки содержат целевой звук (word → isTarget).
    /// Заполняется при старте фото-карточного режима; используется в `selectCard`
    /// для различения целевых и дистракторов.
    private var cardTargets: [String: Bool] = [:]

    init(
        classifier: any VisionObjectClassifierWorkerProtocol,
        childRepository: (any ChildRepository)? = nil
    ) {
        self.classifier = classifier
        self.childRepository = childRepository
    }

    // MARK: - StartGame

    func startGame(_ request: ARSoundHunterModels.StartGame.Request) {
        resetRoundState()
        totalFound = 0
        cardTargets = [:]
        currentMode = request.cameraAvailable ? .camera : .photoCards

        Task { [weak self] in
            guard let self else { return }
            var sound = request.targetSoundOverride
            var age = 6
            if let repo = childRepository, !request.childId.isEmpty {
                if let profile = try? await repo.fetch(id: request.childId) {
                    age = profile.age
                    if sound == nil { sound = profile.targetSounds.first }
                }
            }
            let resolvedSound = sound ?? "С"

            // Сетка фото-карточек нужна только в фоллбэк-режиме. Состав по возрасту:
            // 5–6 лет — 4 карточки (1–2 целевых + 2–3 дистрактора), 7–8 — 6 карточек
            // (2–3 целевых + 3–4 дистрактора). Минимумы (≥1 цель, ≥2 дистрактора)
            // гарантирует сам Worker.
            var grid: [SoundHunterMapping.GridCard] = []
            if self.currentMode == .photoCards {
                let young = age <= 6
                let targetCount = young ? 2 : 3
                let distractorCount = young ? 2 : 3
                // Передаём предикат наличия ассета: выбираются только слова,
                // для которых есть реальный word_* imageset в каталоге контента.
                // Это исключает пустые карточки (Телескоп, Мыло и т.п.), у которых
                // нет иллюстрации в word_manifest.json.
                grid = await self.classifier.huntableGrid(
                    forSound: resolvedSound,
                    targetCount: targetCount,
                    distractorCount: distractorCount,
                    hasAsset: { LessonContentMap.asset(for: $0) != nil }
                )
            }
            guard !Task.isCancelled else { return }

            // Interactor — @MainActor, Task наследует изоляцию: безопасно мутируем
            // состояние и вызываем presenter без отдельного MainActor.run.
            self.targetSound = resolvedSound
            self.childAge = age
            self.cardTargets = Dictionary(
                grid.map { ($0.match.word, $0.isTarget) },
                uniquingKeysWith: { first, _ in first }
            )
            self.presenter?.presentStartGame(.init(
                targetSound: resolvedSound,
                mode: self.currentMode,
                gridCards: grid,
                childAge: age
            ))
        }
    }

    // MARK: - FrameClassified

    func frameClassified(_ request: ARSoundHunterModels.FrameClassified.Request) {
        // Уже захватили предмет — игнорируем дальнейшие кадры до next round.
        guard lockedWord == nil else { return }

        // Лучший кандидат с целевым звуком (matches уже отфильтрованы Worker'ом
        // по targetSound и отсортированы по убыванию confidence).
        guard let best = request.matches.first(where: { $0.confidence >= candidateConfidence }) else {
            // Кадр без кандидата — мягко «остываем».
            decayLock()
            presenter?.presentFrameClassified(.init(foundObject: nil, lockProgress: lockProgress()))
            return
        }

        if best.word == lockCandidate {
            lockCount += 1
        } else {
            lockCandidate = best.word
            lockCount = 1
        }

        if lockCount >= lockFramesRequired {
            lockedWord = best.word
            HSLogger.ar.info("SoundHunter: locked word for sound '\(self.targetSound, privacy: .public)'")
            presenter?.presentFrameClassified(.init(foundObject: best, lockProgress: 1))
        } else {
            presenter?.presentFrameClassified(.init(foundObject: nil, lockProgress: lockProgress()))
        }
    }

    // MARK: - SelectCard (фоллбэк)

    func selectCard(_ request: ARSoundHunterModels.SelectCard.Request) {
        // cardId == word (детерминированный id из Presenter).
        // Дистрактор (слово без целевого звука по умолчанию) → мягкий фидбэк, без
        // звезды и штрафа; не захватываем слово, ребёнок продолжает выбирать.
        let isTarget = cardTargets[request.cardId] ?? false
        guard isTarget else {
            HSLogger.ar.info("SoundHunter: distractor card selected (no target sound) — soft feedback")
            presenter?.presentSelectCard(.init(
                word: request.cardId,
                isTarget: false,
                targetSound: targetSound
            ))
            return
        }
        lockedWord = request.cardId
        presenter?.presentSelectCard(.init(
            word: request.cardId,
            isTarget: true,
            targetSound: targetSound
        ))
    }

    // MARK: - ScoreNaming

    func scoreNaming(_ request: ARSoundHunterModels.ScoreNaming.Request) {
        let transcript = request.transcript
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let target = request.word.lowercased()

        // Молчание / шум: пустой transcript и неоценённое произношение → повтор,
        // без звёзд (правило «никаких звёзд за молчание»).
        let saidSomething = !transcript.isEmpty || request.pronunciationScore.isScored
        guard saidSomething else {
            presenter?.presentRetry(foundWord: request.word)
            return
        }

        let matchedWord = transcript.contains(target) || target.contains(transcript)
        let pronunciationOK = request.pronunciationScore.isScored
            && request.pronunciationScore.value >= pronunciationPassThreshold

        let stars: Int
        if matchedWord && pronunciationOK {
            stars = 3
        } else if matchedWord || pronunciationOK {
            stars = 2
        } else {
            stars = 1
        }
        totalFound += 1
        HSLogger.ar.info("SoundHunter: stars=\(stars) matchedWord=\(matchedWord) pronOK=\(pronunciationOK)")
        presenter?.presentScoreNaming(.init(
            stars: stars,
            matchedWord: matchedWord,
            foundWord: request.word
        ))
    }

    // MARK: - NextRound

    func nextRound(_ request: ARSoundHunterModels.NextRound.Request) {
        resetRoundState()
        presenter?.presentNextRound(.init(totalFound: totalFound))
    }

    // MARK: - Private

    private func resetRoundState() {
        lockedWord = nil
        lockCandidate = nil
        lockCount = 0
    }

    private func decayLock() {
        if lockCount > 0 { lockCount -= 1 }
        if lockCount == 0 { lockCandidate = nil }
    }

    private func lockProgress() -> Float {
        Float(lockCount) / Float(lockFramesRequired)
    }
}
