import SwiftUI

// MARK: - ARStoryQuestView
//
// Полный VIP-обвязанный 8-шаговый нарративный квест.
// Ляля ведёт ребёнка через историю («Космическое приключение» по умолчанию),
// на каждом шаге произносится целевое слово, Interactor оценивает попытку и
// двигает прогресс. Игра не использует ARKit: это SwiftUI-экран с кнопкой
// записи и ASR-pipeline через `AppContainer`.

struct ARStoryQuestView: View {

    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var interactor: ARStoryQuestInteractor?
    @State private var presenter: ARStoryQuestPresenter?
    @State private var router: ARStoryQuestRouter?
    @State private var display = ARStoryQuestDisplay()

    /// Анимированный pulse для микрофона во время записи.
    @State private var micPulse = false

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()

            if display.isLoading {
                ProgressView()
                    .tint(ColorTokens.Brand.primary)
                    .scaleEffect(1.4)
            } else if display.isCompleted {
                completedOverlay
            } else {
                mainContent
            }

            if let error = display.errorMessage {
                errorOverlay(message: error)
            }
        }
        .task { await bootstrap() }
        .onDisappear {
            Task { await interactor?.handle(.dismiss) }
        }
        .navigationBarHidden(true)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Main content

    private var mainContent: some View {
        VStack(spacing: SpacingTokens.medium) {
            header
            progress
            narrationBubble
            targetWordCard
            hintText

            Spacer(minLength: SpacingTokens.medium)

            if display.showFeedback {
                feedbackBanner
            }

            recordButtonArea
            advanceButton
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.top, SpacingTokens.regular)
        .padding(.bottom, SpacingTokens.xLarge)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                Task { await interactor?.handle(.dismiss) }
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .padding(SpacingTokens.small)
                    .background(ColorTokens.Kid.surface, in: Circle())
            }
            .accessibilityLabel(Text("common.close"))

            Spacer()

            Text(display.questTitle)
                .font(TypographyTokens.headline(16))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer()

            // Balance the close-button width.
            Color.clear.frame(width: 40, height: 40)
        }
    }

    // MARK: - Progress

    private var progress: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
            HStack {
                Text(String(localized: "ar.quest.step.label.\(display.stepNumber).\(display.totalSteps)"))
                    .font(TypographyTokens.caption())
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                Spacer()
                Text(display.rewardEmoji)
                    .font(.system(size: 22))
                    .accessibilityHidden(true)
            }
            HSProgressBar(value: display.progressFraction)
                .frame(height: 8)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: display.progressFraction)
        }
    }

    // MARK: - Narration bubble

    private var narrationBubble: some View {
        HSCard(style: .elevated) {
            Text(display.narration)
                .font(TypographyTokens.body(17))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(Text(display.narration))
        }
    }

    // MARK: - Target word card

    private var targetWordCard: some View {
        HSCard(style: .tinted(ColorTokens.Brand.mint.opacity(0.22))) {
            VStack(spacing: SpacingTokens.tiny) {
                Text(String(localized: "ar.quest.targetWord.caption"))
                    .font(TypographyTokens.caption())
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .textCase(.uppercase)
                Text(display.targetWord)
                    .font(TypographyTokens.title(30))
                    .fontWeight(.bold)
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(String(localized: "ar.quest.a11y.targetWord \(display.targetWord)")))
    }

    // MARK: - Hint text

    private var hintText: some View {
        Text(display.hint)
            .font(TypographyTokens.body(14))
            .italic()
            .foregroundStyle(ColorTokens.Kid.inkMuted)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, SpacingTokens.small)
    }

    // MARK: - Feedback banner

    private var feedbackBanner: some View {
        HStack(spacing: SpacingTokens.small) {
            Text(display.canAdvance ? "✅" : "💬")
                .font(.system(size: 26))
                .accessibilityHidden(true)
            Text(display.feedbackText)
                .font(TypographyTokens.headline(15))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(SpacingTokens.regular)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                .fill(display.canAdvance
                      ? ColorTokens.Brand.mint.opacity(0.25)
                      : ColorTokens.Brand.butter.opacity(0.25))
        )
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .accessibilityAddTraits(.isStaticText)
    }

    // MARK: - Record button

    private var recordButtonArea: some View {
        VStack(spacing: SpacingTokens.tiny) {
            Button(action: toggleRecording) {
                ZStack {
                    Circle()
                        .fill(display.isListening ? ColorTokens.Brand.primary : ColorTokens.Brand.mint)
                        .frame(width: 96, height: 96)
                        .scaleEffect(display.isListening && !reduceMotion && micPulse ? 1.12 : 1.0)
                        .shadow(color: ColorTokens.Brand.primary.opacity(0.3), radius: 12, y: 6)
                    Image(systemName: display.isListening ? "stop.fill" : "mic.fill")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white)
                }
                .animation(
                    reduceMotion
                        ? nil
                        : .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                    value: micPulse
                )
            }
            .buttonStyle(.plain)
            .disabled(display.canAdvance || display.isCompleted)
            .accessibilityLabel(Text(display.isListening
                                     ? String(localized: "ar.quest.a11y.stop")
                                     : String(localized: "ar.quest.a11y.record")))
            .accessibilityHint(Text(String(localized: "ar.quest.a11y.recordHint")))
            .onChange(of: display.isListening) { _, listening in
                micPulse = listening
            }

            Text(display.isListening
                 ? String(localized: "ar.quest.listening")
                 : String(localized: "ar.quest.tapToSpeak"))
                .font(TypographyTokens.caption())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
    }

    // MARK: - Advance button

    @ViewBuilder
    private var advanceButton: some View {
        if display.canAdvance {
            HSButton(
                display.stepNumber >= display.totalSteps
                    ? String(localized: "ar.quest.finish")
                    : String(localized: "ar.quest.next"),
                style: .primary,
                icon: "arrow.right",
                action: { Task { await interactor?.handle(.advanceStep) } }
            )
        }
    }

    // MARK: - Completed overlay

    private var completedOverlay: some View {
        VStack(spacing: SpacingTokens.medium) {
            Spacer()

            Text("🎉")
                .font(.system(size: 72))
                .accessibilityHidden(true)

            Text(String(localized: "ar.quest.completed.title"))
                .font(TypographyTokens.title(28))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)

            Text(String(localized: "ar.quest.completed.subtitle"))
                .font(TypographyTokens.body(16))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.xLarge)

            starsRow

            Text(String(localized: "ar.quest.completed.score.\(Int(display.totalScore * 100))"))
                .font(TypographyTokens.headline(15))
                .foregroundStyle(ColorTokens.Kid.inkMuted)

            Spacer()

            VStack(spacing: SpacingTokens.small) {
                HSButton(
                    String(localized: "ar.quest.restart"),
                    style: .secondary,
                    icon: "arrow.clockwise",
                    action: { Task { await interactor?.handle(.restartQuest) } }
                )
                HSButton(
                    String(localized: "common.close"),
                    style: .primary,
                    action: {
                        Task { await interactor?.handle(.dismiss) }
                        dismiss()
                    }
                )
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.xLarge)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.Kid.bg)
        .accessibilityElement(children: .contain)
    }

    private var starsRow: some View {
        HStack(spacing: SpacingTokens.small) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < display.starsEarned ? "star.fill" : "star")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(index < display.starsEarned
                                     ? ColorTokens.Brand.butter
                                     : ColorTokens.Kid.inkSoft)
                    .scaleEffect(index < display.starsEarned ? 1.05 : 0.95)
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.7).delay(Double(index) * 0.15),
                        value: display.starsEarned
                    )
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text(String(localized: "ar.quest.a11y.stars.\(display.starsEarned)")))
    }

    // MARK: - Error overlay

    private func errorOverlay(message: String) -> some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: SpacingTokens.small) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(ColorTokens.Semantic.error)
                Text(String(localized: "ar.quest.error.title"))
                    .font(TypographyTokens.headline())
                    .foregroundStyle(ColorTokens.Kid.ink)
                Text(message)
                    .font(TypographyTokens.body(14))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                HSButton(String(localized: "common.close"), style: .primary) {
                    Task { await interactor?.handle(.dismiss) }
                    dismiss()
                }
            }
            .padding(SpacingTokens.large)
            .background(ColorTokens.Kid.surface, in: RoundedRectangle(cornerRadius: RadiusTokens.md))
            .padding(SpacingTokens.screenEdge)
        }
    }

    // MARK: - Wiring

    private func bootstrap() async {
        guard interactor == nil else { return }

        let presenter = ARStoryQuestPresenter()
        let router = ARStoryQuestRouter()
        let interactor = ARStoryQuestInteractor(
            presenter: presenter,
            router: router,
            container: container
        )

        presenter.onUpdate = { [weak presenterBox = WeakBox(value: presenter)] newDisplay in
            _ = presenterBox
            // Capture outside actor closure: reassign on main actor.
            Task { @MainActor in
                display = newDisplay
            }
        }

        router.dismiss = {
            dismiss()
        }

        self.presenter = presenter
        self.router = router
        self.interactor = interactor

        await interactor.handle(.loadQuest(script: .spaceAdventure))
    }

    // MARK: - Actions

    private func toggleRecording() {
        Task {
            if display.isListening {
                await interactor?.handle(.stopListening)
            } else {
                await interactor?.handle(.startListening)
            }
        }
    }
}

// MARK: - WeakBox helper

/// Lightweight weak wrapper used to keep presenter alive in closures without
/// creating retain cycles. Marked `@unchecked Sendable` because it only ever
/// crosses actor boundaries on the main actor.
@MainActor
private final class WeakBox<T: AnyObject> {
    weak var value: T?
    init(value: T?) { self.value = value }
}

// MARK: - Preview

#Preview("ARStoryQuest") {
    ARStoryQuestView()
        .environment(AppContainer.preview())
        .environment(\.circuitContext, .kid)
}
