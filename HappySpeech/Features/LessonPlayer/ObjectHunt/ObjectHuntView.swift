import AVFoundation
import SwiftUI

// MARK: - ObjectHuntView
//
// Игра «Найди предметы на звук» (ObjectHunt).
//
// Поток:
//   1. Загрузка сцены (.loading) — VIP loadScene
//   2. Ляля: "Найди что начинается на Ш!" (.playing)
//   3. Сцена: 9 предметов — ребёнок нажимает правильные
//   4. Каждый тап → ObjectHuntInteractor.tapObject
//   5. Таймер 60 сек — ObjectHuntInteractor.timerTick
//   6. Найдены все → .sceneComplete → следующая сцена
//   7. 5 сцен пройдены → .gameComplete → onComplete(score)
//
// Camera: не используется — предметы отображаются иконками SF Symbols
// на цветном фоне с декором сцены. Чистый tap-режим.

struct ObjectHuntView: View {

    // MARK: - Input

    let activity: SessionActivity
    let onComplete: (Float) -> Void

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - VIP

    @State private var interactor: ObjectHuntInteractor?
    @State private var presenter: ObjectHuntPresenter?
    @State private var router: ObjectHuntRouter?
    @State private var display = ObjectHuntViewDisplay()
    @State private var adapter: ObjectHuntDisplayAdapter?

    // MARK: - Timer

    @State private var timerTask: Task<Void, Never>?
    @State private var bootstrapped = false

    // MARK: - Body

    var body: some View {
        ZStack {
            sceneBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.top, SpacingTokens.small)

                Spacer(minLength: SpacingTokens.small)

                switch display.phase {
                case .loading:
                    loadingView
                case .playing:
                    itemsGrid
                        .padding(.horizontal, SpacingTokens.screenEdge)
                case .sceneComplete:
                    sceneCompleteCard
                        .padding(.horizontal, SpacingTokens.screenEdge)
                case .gameComplete:
                    gameCompleteCard
                        .padding(.horizontal, SpacingTokens.screenEdge)
                }

                Spacer(minLength: SpacingTokens.medium)
            }
        }
        .task { await bootstrap() }
        .onDisappear { teardown() }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Scene background

    private var sceneBackground: some View {
        LinearGradient(
            colors: [ColorTokens.Brand.sky.opacity(0.28), ColorTokens.Kid.bgSoft],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: SpacingTokens.small) {
            HSMascotView(mood: .explaining, size: 48)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(display.roundBadge)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)

                Text(display.promptText.isEmpty
                    ? String(localized: "object_hunt.find_sound \(display.targetSoundLabel)")
                    : display.promptText)
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 2) {
                if !display.targetSoundLabel.isEmpty {
                    Text(display.targetSoundLabel)
                        .font(TypographyTokens.kidDisplay(32))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(ColorTokens.Brand.lilac.opacity(0.25)))
                        .accessibilityLabel(
                            String(localized: "object_hunt.target_sound_a11y \(display.targetSoundLabel)")
                        )
                }
                Text(display.timerLabel)
                    .font(TypographyTokens.caption(13).monospacedDigit())
                    .foregroundStyle(
                        display.isTimerWarning ? ColorTokens.Semantic.error : ColorTokens.Kid.inkMuted
                    )
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: display.isTimerWarning)
            }
        }
        .padding(SpacingTokens.small)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(ColorTokens.Kid.surface.opacity(0.88))
        )
        .accessibilityElement(children: .contain)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: SpacingTokens.medium) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(ColorTokens.Brand.primary)
                .scaleEffect(1.4)
            Text(String(localized: "object_hunt.loading"))
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.ink)
        }
    }

    // MARK: - Items grid

    private var itemsGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: SpacingTokens.small),
            GridItem(.flexible(), spacing: SpacingTokens.small),
            GridItem(.flexible(), spacing: SpacingTokens.small)
        ]
        return LazyVGrid(columns: columns, spacing: SpacingTokens.small) {
            ForEach(display.items) { item in
                SceneItemCell(
                    item: item,
                    reduceMotion: reduceMotion
                ) {
                    interactor?.tapObject(.init(itemId: item.id))
                }
                .frame(minWidth: 56, minHeight: 56)
            }
        }
    }

    // MARK: - Scene complete card

    private var sceneCompleteCard: some View {
        VStack(spacing: SpacingTokens.medium) {
            HSMascotView(mood: .celebrating, size: 80)
                .scaleEffect(reduceMotion ? 1.0 : 1.06)
                .animation(
                    reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.55),
                    value: display.phase
                )
                .accessibilityHidden(true)

            Text(display.sceneResultText)
                .font(TypographyTokens.title(20))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)

            if !display.sceneTimeText.isEmpty {
                Text(display.sceneTimeText)
                    .font(TypographyTokens.body())
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }

            if !display.sceneStreakBonusText.isEmpty {
                Text(display.sceneStreakBonusText)
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Brand.gold)
            }

            HSButton(
                String(localized: "object_hunt.next_scene"),
                style: .primary,
                icon: "arrow.right.circle.fill"
            ) {
                interactor?.advanceToNextScene()
            }
            .padding(.top, SpacingTokens.tiny)
        }
        .padding(SpacingTokens.large)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(ColorTokens.Kid.surface.opacity(0.94))
        )
        .accessibilityElement(children: .contain)
    }

    // MARK: - Game complete card

    private var gameCompleteCard: some View {
        VStack(spacing: SpacingTokens.large) {
            HSMascotView(mood: .celebrating, size: 100)
                .accessibilityHidden(true)

            starsRow

            Text(display.finalScoreLabel)
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Kid.ink)

            Text(display.accuracyLabel)
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.inkMuted)

            Text(display.summaryText)
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.screenEdge)

            HSButton(
                String(localized: "object_hunt.finish"),
                style: .primary,
                icon: "checkmark.circle.fill"
            ) {
                onComplete(display.lastScore)
            }
            .accessibilityHint(String(localized: "object_hunt.finish_a11y"))
        }
        .padding(SpacingTokens.large)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(ColorTokens.Kid.surface.opacity(0.94))
        )
        .accessibilityElement(children: .contain)
    }

    private var starsRow: some View {
        HStack(spacing: SpacingTokens.small) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < display.starsEarned ? "star.fill" : "star")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(
                        index < display.starsEarned ? ColorTokens.Brand.gold : ColorTokens.Kid.line
                    )
                    .scaleEffect(index < display.starsEarned ? 1.0 : 0.85)
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.6)
                            .delay(Double(index) * 0.1),
                        value: display.starsEarned
                    )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "object_hunt.stars_a11y \(display.starsEarned)"))
    }

    // MARK: - Bootstrap

    private func bootstrap() async {
        guard !bootstrapped else { return }
        bootstrapped = true

        let haptic = container.hapticService
        let sound = container.soundService
        let planner = container.adaptivePlannerService

        let interactor = ObjectHuntInteractor(
            targetSound: activity.soundTarget,
            childId: container.currentChildId.isEmpty ? "default" : container.currentChildId,
            hapticService: haptic,
            soundService: sound,
            adaptivePlanner: planner
        )
        let presenter = ObjectHuntPresenter()
        let router = ObjectHuntRouter()
        let adapter = ObjectHuntDisplayAdapter(display: display)

        interactor.presenter = presenter
        interactor.router = router
        presenter.display = adapter

        router.onComplete = { [weak adapter] score in
            adapter?.updateLastScore(score)
        }

        self.interactor = interactor
        self.presenter = presenter
        self.router = router
        self.adapter = adapter

        let group = ObjectHuntInteractor.resolveSoundGroup(for: activity.soundTarget)
        interactor.loadScene(.init(
            soundGroup: group,
            targetSound: activity.soundTarget,
            sceneIndex: 0
        ))

        startTimer()
    }

    // MARK: - Timer

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { @MainActor [weak interactor] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { break }
                interactor?.timerTick(.init())
            }
        }
    }

    // MARK: - Teardown

    private func teardown() {
        timerTask?.cancel()
        timerTask = nil
    }
}

// MARK: - SceneItemCell

private struct SceneItemCell: View {

    let item: SceneItem
    let reduceMotion: Bool
    let onTap: () -> Void

    @State private var isAnimating = false

    var body: some View {
        Button(action: {
            triggerTapAnimation()
            onTap()
        }) {
            VStack(spacing: SpacingTokens.tiny) {
                Image(systemName: item.icon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(width: 44, height: 44)

                Text(item.word)
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.small)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.button, style: .continuous)
                    .fill(cellBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: RadiusTokens.button, style: .continuous)
                            .strokeBorder(borderColor, lineWidth: borderWidth)
                    )
            )
            .scaleEffect(isAnimating && !reduceMotion ? (item.tapState == .wrong ? 0.92 : 1.05) : 1.0)
            .animation(
                reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.55),
                value: isAnimating
            )
        }
        .buttonStyle(.plain)
        .disabled(item.tapState == .correct)
        .accessibilityLabel(item.word)
        .accessibilityHint(
            item.tapState == .correct
                ? String(localized: "object_hunt.item_found_a11y")
                : String(localized: "object_hunt.item_hint_a11y")
        )
        .accessibilityAddTraits(item.tapState == .correct ? .isStaticText : [])
    }

    private func triggerTapAnimation() {
        guard !reduceMotion else { return }
        isAnimating = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            isAnimating = false
        }
    }

    private var iconColor: Color {
        switch item.tapState {
        case .correct: return ColorTokens.Semantic.success
        case .wrong:   return ColorTokens.Semantic.error
        case .hinted:  return ColorTokens.Brand.primary
        case .idle:    return ColorTokens.Kid.ink
        }
    }

    private var cellBackground: Color {
        switch item.tapState {
        case .correct: return ColorTokens.Semantic.success.opacity(0.15)
        case .wrong:   return ColorTokens.Semantic.error.opacity(0.12)
        case .hinted:  return ColorTokens.Brand.lilac.opacity(0.20)
        case .idle:    return ColorTokens.Kid.surface.opacity(0.85)
        }
    }

    private var borderColor: Color {
        switch item.tapState {
        case .correct: return ColorTokens.Semantic.success.opacity(0.6)
        case .wrong:   return ColorTokens.Semantic.error.opacity(0.5)
        case .hinted:  return ColorTokens.Brand.primary.opacity(0.5)
        case .idle:    return ColorTokens.Kid.line.opacity(0.3)
        }
    }

    private var borderWidth: CGFloat {
        item.tapState == .idle ? 1 : 2
    }
}

// MARK: - ObjectHuntDisplayAdapter

@MainActor
final class ObjectHuntDisplayAdapter: ObjectHuntDisplayLogic {

    private let display: ObjectHuntViewDisplay

    init(display: ObjectHuntViewDisplay) {
        self.display = display
    }

    func updateLastScore(_ score: Float) {
        display.lastScore = score
    }

    func displayLoadScene(_ viewModel: ObjectHuntModels.LoadScene.ViewModel) {
        display.items = viewModel.items
        display.targetSoundLabel = viewModel.targetSoundLabel
        display.sceneName = viewModel.sceneName
        display.sceneBackground = viewModel.sceneBackground
        display.roundBadge = viewModel.roundBadge
        display.promptText = viewModel.promptText
        display.targetCount = viewModel.targetCount
        display.correctCount = 0
        display.streakCount = 0
        display.timerLabel = timerString(viewModel.timeLimitSec)
        display.isTimerWarning = false
        display.hintsRemaining = 2
        display.isHintAvailable = true
        display.phase = .playing
    }

    func displayTapObject(_ viewModel: ObjectHuntModels.TapObject.ViewModel) {
        guard let index = display.items.firstIndex(where: { $0.id == viewModel.itemId }) else { return }
        display.items[index].tapState = viewModel.newState
        display.items[index].isHintActive = false
        display.correctCount = viewModel.correctCount
        display.streakCount = viewModel.streakCount
        display.scoreLabel = viewModel.scoreLabel
    }

    func displayUseHint(_ viewModel: ObjectHuntModels.UseHint.ViewModel) {
        display.hintsRemaining = viewModel.hintsRemaining
        display.isHintAvailable = viewModel.isHintAvailable
        if let hintId = viewModel.hintedItemId,
           let index = display.items.firstIndex(where: { $0.id == hintId }) {
            display.items[index].tapState = .hinted
            display.items[index].isHintActive = true
        }
    }

    func displayTimerTick(_ viewModel: ObjectHuntModels.TimerTick.ViewModel) {
        display.timerLabel = viewModel.timerLabel
        display.isTimerWarning = viewModel.isWarning
        if viewModel.isExpired && display.phase == .playing {
            display.phase = .sceneComplete
        }
    }

    func displayCompleteScene(_ viewModel: ObjectHuntModels.CompleteScene.ViewModel) {
        display.sceneResultText = viewModel.summaryText
        display.sceneTimeText = viewModel.timeText
        display.sceneStreakBonusText = viewModel.streakBonusText
        display.phase = .sceneComplete
    }

    func displayCompleteGame(_ viewModel: ObjectHuntModels.CompleteGame.ViewModel) {
        display.starsEarned = viewModel.starsEarned
        display.finalScoreLabel = viewModel.scoreLabel
        display.accuracyLabel = viewModel.accuracyLabel
        display.summaryText = viewModel.summaryText
        display.lastScore = Float(viewModel.starsEarned) / 3.0
        display.phase = .gameComplete
    }

    // MARK: - Helper

    private func timerString(_ totalSec: Int) -> String {
        let m = totalSec / 60
        let s = totalSec % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - ObjectHuntCameraError (legacy — kept for compatibility)

enum ObjectHuntCameraError: LocalizedError {
    case deviceNotAvailable

    var errorDescription: String? {
        String(localized: "object_hunt.permission")
    }
}

// MARK: - Preview

#Preview("ObjectHunt") {
    ObjectHuntView(
        activity: SessionActivity(
            id: "object-hunt-demo",
            gameType: .objectHunt,
            lessonId: "Ш-wordInit",
            soundTarget: "Ш",
            difficulty: 3,
            isCompleted: false,
            score: nil
        ),
        onComplete: { _ in }
    )
    .environment(AppContainer.preview())
}
