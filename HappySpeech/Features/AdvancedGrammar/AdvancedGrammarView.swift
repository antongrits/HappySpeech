import OSLog
import SwiftUI

// MARK: - AdvancedGrammarView
//
// «Грамматический конструктор-2» — kid-игра сложных грамматических конструкций
// (расширение GrammarGame). Три режима выбираются на старте:
//   • Сложные предлоги (из-за / из-под) — наглядная сцена SwiftUI-фигурами
//     (мебель + персонаж выглядывает) + выбор предлога 2×2.
//   • Притяжательные (чей / чья / чьё / чьи) — карточка части тела + выбор
//     формы по роду/числу (цвет по роду: он=coral, она=rose, оно=lilac).
//   • Согласование (-ый/-ая/-ое/-ые) — карточка-предмет задаёт род + выбор
//     окончания 2×2.
//
// Архитектура: Clean Swift VIP. Палитра тёплая (cream-фон); гендер-акценты —
// мелкие семантические (на бордерах/тексте вариантов, не на фоне). Reduced
// Motion уважается. CTA min-height 58. Текст без обрезки.

struct AdvancedGrammarView: View {

    // MARK: - Input

    let childId: String

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - VIP

    @State private var display = AdvancedGrammarDisplay()
    @State private var interactor: AdvancedGrammarInteractor?
    @State private var presenter: AdvancedGrammarPresenter?
    @State private var router: AdvancedGrammarRouter?
    @State private var selectedMode: AdvancedGrammarMode?
    @State private var bootstrapped = false
    @State private var celebrate = false

    private let logger = Logger(subsystem: "ru.happyspeech", category: "AdvancedGrammarView")

    // MARK: - Body

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()
            content
            if celebrate {
                HSConfettiView(preset: .celebration, isActive: $celebrate)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .onChange(of: display.pendingExit) { _, exit in
            if exit { router?.dismiss() }
        }
        .onDisappear { interactor?.cancel() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(
            localized: "advancedGrammar.screen.a11y",
            defaultValue: "Грамматический конструктор: строим сложные фразы"
        ))
    }

    @ViewBuilder
    private var content: some View {
        if selectedMode == nil {
            ModePickerView(childId: childId) { mode in
                container.soundService.playUISound(.tap)
                selectedMode = mode
                Task { await bootstrap(mode: mode) }
            } onExit: {
                container.soundService.playUISound(.tap)
                display.pendingExit = true
            }
        } else {
            switch display.phase {
            case .loading:
                loadingView
            case .question:
                questionView
            case .completed:
                completedView
            }
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: SpacingTokens.medium) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(ColorTokens.Brand.primary)
                .scaleEffect(1.4)
            Text(String(localized: "advancedGrammar.loading", defaultValue: "Готовим задания…"))
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Question

    private var questionView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SpacingTokens.regular) {
                topBar
                progressBar
                primaryCard
                choiceGrid
                if display.isAnswered, !display.fullPhrase.isEmpty {
                    fullPhraseBanner
                }
                mascotRow
                if display.isAnswered {
                    nextCTA
                }
            }
            .padding(.horizontal, Metrics.contentPadding)
            .padding(.top, SpacingTokens.tiny)
            .padding(.bottom, SpacingTokens.regular)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaPadding(.bottom, SpacingTokens.small)
    }

    // MARK: TopBar

    private var topBar: some View {
        HStack(spacing: SpacingTokens.small) {
            Button { exit() } label: {
                Image(systemName: "xmark")
                    .font(TypographyTokens.headline(16).weight(.bold))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(ColorTokens.Kid.surfaceAlt))
            }
            .accessibilityLabel(String(localized: "common.close", defaultValue: "Выйти"))

            VStack(spacing: 2) {
                Text(display.title)
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(display.subtitle)
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)

            Button { interactor?.playPrompt() } label: {
                Image(systemName: display.isPlaying ? "waveform" : "speaker.wave.2.fill")
                    .font(TypographyTokens.headline(16).weight(.semibold))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .symbolEffect(.variableColor, isActive: display.isPlaying && !reduceMotion)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(ColorTokens.Kid.surfaceAlt))
            }
            .accessibilityLabel(String(localized: "advancedGrammar.replay.a11y", defaultValue: "Повторить"))
        }
    }

    private var progressBar: some View {
        VStack(spacing: SpacingTokens.tiny) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(ColorTokens.Kid.line)
                    Capsule()
                        .fill(LinearGradient(
                            colors: [ColorTokens.Brand.primaryHi, ColorTokens.Brand.primary],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: max(0, geo.size.width * progressFraction))
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: progressFraction)
                }
            }
            .frame(height: 9)

            Text(String(
                format: String(localized: "advancedGrammar.progress %lld %lld",
                               defaultValue: "Задание %lld из %lld"),
                display.roundIndex + 1, max(display.totalRounds, 1)
            ))
            .font(TypographyTokens.body(13).weight(.semibold))
            .foregroundStyle(ColorTokens.Kid.inkMuted)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(
            format: String(localized: "advancedGrammar.progress.a11y %lld %lld",
                           defaultValue: "Задание %lld из %lld"),
            display.roundIndex + 1, max(display.totalRounds, 1)
        ))
    }

    private var progressFraction: CGFloat {
        guard display.totalRounds > 0 else { return 0 }
        return CGFloat(display.roundIndex + 1) / CGFloat(display.totalRounds)
    }

    // MARK: Primary card (mode-specific)

    @ViewBuilder
    private var primaryCard: some View {
        switch display.mode {
        case .complexPreposition:
            PrepositionSceneCard(
                imageName: display.imageName,
                prompt: display.promptTemplate,
                scene: display.scene ?? .behind,
                isAnswered: display.isAnswered,
                answeredPreposition: display.isAnswered ? display.correctChoiceId : nil,
                reduceMotion: reduceMotion
            )
        case .possessive:
            PossessivePartCard(
                imageName: display.imageName,
                prompt: display.promptTemplate,
                gender: display.gender
            )
        case .agreement:
            AgreementObjectCard(
                imageName: display.imageName,
                noun: nounFromPrompt,
                gender: display.gender ?? .feminine,
                prompt: display.promptTemplate,
                isAnswered: display.isAnswered,
                answeredPhrase: display.isAnswered ? display.fullPhrase : nil
            )
        }
    }

    /// Существительное для AgreementObjectCard вытаскиваем из правильной фразы
    /// (последнее слово), чтобы не дублировать в данных.
    private var nounFromPrompt: String {
        display.fullPhrase.split(separator: " ").last.map(String.init)
            ?? display.promptTemplate
    }

    // MARK: Choice grid

    @ViewBuilder
    private var choiceGrid: some View {
        if display.mode == .possessive {
            // Притяжательные — горизонтальный ряд форм (как в референсе).
            HStack(spacing: SpacingTokens.small) {
                ForEach(display.choices) { choice in
                    ChoiceCard(
                        choice: choice,
                        state: state(for: choice),
                        compact: true,
                        reduceMotion: reduceMotion
                    ) { handlePick(choice) }
                }
            }
        } else {
            // Предлоги / согласование — сетка 2×2.
            let columns = [GridItem(.flexible(), spacing: SpacingTokens.small),
                           GridItem(.flexible(), spacing: SpacingTokens.small)]
            LazyVGrid(columns: columns, spacing: SpacingTokens.small) {
                ForEach(display.choices) { choice in
                    ChoiceCard(
                        choice: choice,
                        state: state(for: choice),
                        compact: false,
                        reduceMotion: reduceMotion
                    ) { handlePick(choice) }
                }
            }
        }
    }

    private func state(for choice: AdvancedGrammarChoice) -> ChoiceCard.State {
        guard display.isAnswered || display.selectedChoiceId != nil else { return .idle }
        if choice.id == display.correctChoiceId, display.isAnswered { return .correct }
        if choice.id == display.selectedChoiceId, !display.isCorrect { return .wrong }
        if display.isAnswered { return .dimmed }
        return .idle
    }

    // MARK: Full phrase banner

    private var fullPhraseBanner: some View {
        HStack(spacing: SpacingTokens.small) {
            Image(systemName: "checkmark.circle.fill")
                .font(TypographyTokens.title(20).weight(.semibold))
                .foregroundStyle(ColorTokens.Feedback.correct)
                .accessibilityHidden(true)
            Text(display.fullPhrase.capitalizedFirstWord)
                .font(TypographyTokens.headline(18).weight(.bold))
                .foregroundStyle(ColorTokens.Brand.primary)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, SpacingTokens.regular)
        .padding(.vertical, SpacingTokens.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                .fill(ColorTokens.Feedback.correct.opacity(0.12))
        )
        .transition(.opacity)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.7), value: display.fullPhrase)
        .accessibilityLabel(String(
            format: String(localized: "advancedGrammar.fullPhrase.a11y %@",
                           defaultValue: "Правильно: %@"),
            display.fullPhrase
        ))
    }

    // MARK: Mascot

    private var mascotRow: some View {
        HStack(alignment: .bottom, spacing: SpacingTokens.small) {
            LyalyaMascotView(state: mascotState, size: 64)
                .accessibilityHidden(true)
            HSSpeechBubble(displayMascotText, direction: .left, style: .lyalya, maxWidth: 250)
            Spacer(minLength: 0)
        }
    }

    private var mascotState: LyalyaState {
        if reduceMotion { return .idle }
        if display.isAnswered { return .celebrating }
        if !display.correctionText.isEmpty { return .encouraging }
        return .explaining
    }

    private var displayMascotText: String {
        display.mascotText.isEmpty ? display.hint : display.mascotText
    }

    // MARK: Next CTA

    private var nextCTA: some View {
        AdvancedGrammarCTA(
            title: display.roundIndex + 1 >= display.totalRounds
                ? String(localized: "advancedGrammar.cta.finish", defaultValue: "Завершить")
                : String(localized: "advancedGrammar.cta.next", defaultValue: "Дальше"),
            icon: "arrow.right"
        ) {
            container.soundService.playUISound(.tap)
            container.hapticService.selection()
            Task { await interactor?.advance() }
        }
        .accessibilityIdentifier("gameNextButton")
    }

    // MARK: - Completed

    private var completedView: some View {
        VStack(spacing: SpacingTokens.large) {
            Spacer()
            starsRow
            Text(display.completionTitle)
                .font(TypographyTokens.title(26))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
            Text(display.completionMessage)
                .font(TypographyTokens.body(17))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, SpacingTokens.xLarge)
            Spacer()
        }
        .padding(.horizontal, Metrics.contentPadding)
        .padding(.bottom, SpacingTokens.sp16)
        .safeAreaInset(edge: .bottom) {
            AdvancedGrammarCTA(
                title: String(localized: "advancedGrammar.cta.done", defaultValue: "Готово"),
                icon: "checkmark.circle.fill"
            ) {
                finalize()
            }
            .padding(.horizontal, Metrics.contentPadding)
            .padding(.bottom, SpacingTokens.small)
            .accessibilityIdentifier("gameNextButton")
        }
        .onAppear {
            if !reduceMotion { celebrate = true }
            container.hapticService.notification(.success)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "advancedGrammar.completed.a11y", defaultValue: "Задания завершены"))
    }

    private var starsRow: some View {
        HStack(spacing: SpacingTokens.small) {
            ForEach(0..<3, id: \.self) { idx in
                Image(systemName: idx < display.starsEarned ? "star.fill" : "star")
                    .font(TypographyTokens.display(44).weight(.semibold))
                    .foregroundStyle(idx < display.starsEarned ? ColorTokens.Brand.butter : ColorTokens.Kid.line)
                    .scaleEffect(idx < display.starsEarned ? 1.0 : 0.85)
                    .animation(reduceMotion ? nil
                               : .spring(response: 0.5, dampingFraction: 0.65).delay(Double(idx) * 0.12),
                               value: display.starsEarned)
            }
        }
        .accessibilityLabel(String(
            format: String(localized: "advancedGrammar.stars.a11y %lld", defaultValue: "Получено звёзд: %lld из 3"),
            display.starsEarned
        ))
    }

    // MARK: - Actions

    private func handlePick(_ choice: AdvancedGrammarChoice) {
        guard !display.isAnswered else { return }
        container.soundService.playUISound(.tap)
        container.hapticService.selection()
        display.selectedChoiceId = choice.id
        interactor?.evaluate(.init(selectedChoiceId: choice.id))
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            if display.isCorrect {
                container.soundService.playUISound(.correct)
                container.hapticService.notification(.success)
                if !reduceMotion { celebrate = true }
            } else {
                container.soundService.playUISound(.incorrect)
                container.hapticService.notification(.warning)
            }
        }
    }

    private func exit() {
        container.soundService.playUISound(.tap)
        display.pendingExit = true
    }

    private func finalize() {
        guard !display.pendingExit else { return }
        container.soundService.playUISound(.complete)
        container.hapticService.notification(.success)
        display.pendingExit = true
    }

    // MARK: - Bootstrap

    @MainActor
    private func bootstrap(mode: AdvancedGrammarMode) async {
        guard !bootstrapped else { return }
        bootstrapped = true
        display.mode = mode
        display.phase = .loading

        let presenter = AdvancedGrammarPresenter()
        let interactor = AdvancedGrammarInteractor(
            childId: childId,
            mode: mode,
            content: AdvancedGrammarContentWorker(),
            feedback: AdvancedGrammarFeedbackWorker(),
            adaptivePlanner: container.adaptivePlannerService
        )
        let router = AdvancedGrammarRouter()

        interactor.presenter = presenter
        presenter.display = display

        self.presenter = presenter
        self.interactor = interactor
        self.router = router

        logger.info("bootstrap child=\(childId, privacy: .public) mode=\(mode.rawValue, privacy: .public)")
        await interactor.start(.init(childId: childId))
    }
}

// MARK: - Metrics

private enum Metrics {
    static let contentPadding: CGFloat = 22
}

// MARK: - String helper

private extension String {
    /// Капитализирует только первую букву всей строки/первого слова.
    var capitalizedFirstWord: String {
        guard let first else { return self }
        return String(first).uppercased() + dropFirst()
    }
}

// MARK: - Preview

#Preview("AdvancedGrammar") {
    AdvancedGrammarView(childId: "preview-child")
        .environment(AppContainer.preview())
}
