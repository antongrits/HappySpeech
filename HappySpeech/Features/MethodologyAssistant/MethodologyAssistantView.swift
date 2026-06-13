import OSLog
import SwiftUI

// MARK: - MethodologyAssistantView

/// Экран «Помощник по методике» (локальный офлайн-поиск по корпусу).
///
/// Доступен только во взрослых контурах (родитель / специалист) **за parental
/// gate** (COPPA — это инструмент для взрослого, не для ребёнка). Взрослый
/// задаёт методический вопрос, получает markdown-ответ из методического
/// корпуса и список источников. Полностью офлайн, без облачных затрат.
///
/// Clean Swift: View → Interactor → Presenter (observable display) → View.
struct MethodologyAssistantView: View {

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.exitToParentHome) private var exitToParentHome
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.circuitContext) private var circuit

    // MARK: - VIP

    @State private var interactor: MethodologyAssistantInteractor?
    @State private var presenter = MethodologyAssistantPresenter()
    @State private var bootstrapped = false

    // MARK: - Local UI state

    @State private var questionText: String = ""
    @State private var didPassGate = false
    @State private var showGate = true

    @FocusState private var inputFocused: Bool

    private let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "MethodologyAssistant.View"
    )

    // MARK: - Convenience

    private var viewModel: MethodologyAssistant.ViewModel { presenter.viewModel }
    private var inkColor: Color { circuit == .specialist ? ColorTokens.Spec.ink : ColorTokens.Parent.ink }
    private var mutedColor: Color { circuit == .specialist ? ColorTokens.Spec.inkMuted : ColorTokens.Parent.inkMuted }
    private var accentColor: Color { circuit == .specialist ? ColorTokens.Spec.accent : ColorTokens.Parent.accent }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                HSMeshGradientBackground(palette: .calm, animated: !reduceMotion)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)

                if didPassGate {
                    content
                } else {
                    gatePlaceholder
                }
            }
            .navigationTitle(Text(String(localized: "methodologyAssistant.nav.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        exitToParentHome()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(mutedColor)
                    }
                    .accessibilityLabel(Text(String(localized: "action.close")))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !viewModel.turns.isEmpty {
                        Button {
                            interactor?.reset(.init())
                            questionText = ""
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundStyle(accentColor)
                        }
                        .accessibilityLabel(Text(String(localized: "methodologyAssistant.reset")))
                    }
                }
            }
            .sheet(isPresented: $showGate) {
                ParentalGate(isPresented: $showGate) {
                    didPassGate = true
                }
            }
            .task { await bootstrap() }
        }
        .environment(\.circuitContext, circuit == .specialist ? .specialist : .parent)
    }

    // MARK: - Gate placeholder (до прохождения parental gate)

    private var gatePlaceholder: some View {
        VStack(spacing: SpacingTokens.medium) {
            Image(systemName: "person.fill.questionmark")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(accentColor)
                .accessibilityHidden(true)
            Text(String(localized: "methodologyAssistant.gate.title"))
                .font(TypographyTokens.title(20))
                .foregroundStyle(inkColor)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
            Text(String(localized: "methodologyAssistant.gate.subtitle"))
                .font(TypographyTokens.body(15))
                .foregroundStyle(mutedColor)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .padding(.horizontal, SpacingTokens.large)
            HSButton(
                String(localized: "methodologyAssistant.gate.cta"),
                style: .primary,
                size: .large,
                icon: "lock.open.fill"
            ) {
                showGate = true
            }
            .padding(.horizontal, SpacingTokens.large)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
    }

    // MARK: - Main content

    private var content: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: SpacingTokens.medium) {
                        if viewModel.turns.isEmpty && !viewModel.isLoading {
                            emptyState
                        } else {
                            ForEach(viewModel.turns) { turn in
                                turnView(turn)
                                    .id(turn.id)
                            }
                        }

                        if viewModel.isLoading {
                            loadingRow
                                .id("loading")
                        }

                        if let error = viewModel.errorMessage {
                            errorRow(error)
                        }
                    }
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.top, SpacingTokens.regular)
                    .padding(.bottom, SpacingTokens.large)
                }
                .onChange(of: viewModel.turns.count) { _, _ in
                    scrollToBottom(proxy)
                }
                .onChange(of: viewModel.isLoading) { _, isLoading in
                    if isLoading { scrollToBottom(proxy) }
                }
            }

            inputBar
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.regular) {
            HSLiquidGlassCard(style: .elevated) {
                VStack(alignment: .leading, spacing: SpacingTokens.small) {
                    HStack(spacing: SpacingTokens.small) {
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(accentColor)
                            .accessibilityHidden(true)
                        Text(String(localized: "methodologyAssistant.empty.title"))
                            .font(TypographyTokens.title(18))
                            .foregroundStyle(inkColor)
                            .lineLimit(nil)
                            .minimumScaleFactor(0.85)
                    }
                    Text(String(localized: "methodologyAssistant.empty.subtitle"))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(mutedColor)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(String(localized: "methodologyAssistant.empty.tryAsking"))
                .font(TypographyTokens.caption(13))
                .foregroundStyle(mutedColor)
                .padding(.top, SpacingTokens.tiny)

            ForEach(Array(viewModel.suggestions.enumerated()), id: \.offset) { _, suggestion in
                suggestionChip(suggestion)
            }
        }
    }

    private func suggestionChip(_ text: String) -> some View {
        Button {
            questionText = text
            send()
        } label: {
            HStack(spacing: SpacingTokens.small) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13))
                    .foregroundStyle(accentColor)
                Text(text)
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(inkColor)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(SpacingTokens.small)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                    .fill(accentColor.opacity(0.10))
            )
        }
        .accessibilityLabel(Text(text))
        .accessibilityHint(Text(String(localized: "methodologyAssistant.suggestion.a11yHint")))
    }

    // MARK: - Turn views

    @ViewBuilder
    private func turnView(_ turn: MethodologyAssistant.Turn) -> some View {
        switch turn.kind {
        case .question:
            questionBubble(turn.text)
        case .answer:
            answerCard(turn)
        }
    }

    private func questionBubble(_ text: String) -> some View {
        HStack {
            Spacer(minLength: SpacingTokens.xLarge)
            Text(text)
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Overlay.onAccent)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, SpacingTokens.regular)
                .padding(.vertical, SpacingTokens.small)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                        .fill(accentColor)
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(String(localized: "methodologyAssistant.a11y.yourQuestion") + ": " + text))
    }

    private func answerCard(_ turn: MethodologyAssistant.Turn) -> some View {
        HSLiquidGlassCard(style: .elevated) {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                HStack(spacing: SpacingTokens.tiny) {
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(accentColor)
                        .accessibilityHidden(true)
                    Text(String(localized: "methodologyAssistant.answer.label"))
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(mutedColor)
                }

                HSMarkdownView(markdown: turn.text)
                    .accessibilityLabel(Text(turn.text))

                if !turn.citations.isEmpty {
                    Divider().background(mutedColor.opacity(0.3))
                    Text(String(localized: "methodologyAssistant.sources.title"))
                        .font(TypographyTokens.caption(12).weight(.semibold))
                        .foregroundStyle(mutedColor)
                    ForEach(turn.citations) { citation in
                        citationRow(citation)
                    }
                }

                disclaimerRow
            }
        }
    }

    /// Честная подпись: педагогические рекомендации, не мед-консультация (COPPA / §11).
    private var disclaimerRow: some View {
        HStack(alignment: .top, spacing: SpacingTokens.tiny) {
            Image(systemName: "info.circle")
                .font(.system(size: 12))
                .foregroundStyle(mutedColor)
                .padding(.top, 1)
                .accessibilityHidden(true)
            Text(String(localized: "methodologyAssistant.disclaimer"))
                .font(TypographyTokens.caption(11))
                .foregroundStyle(mutedColor)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, SpacingTokens.tiny)
        .accessibilityElement(children: .combine)
    }

    private func citationRow(_ citation: MethodologyCitation) -> some View {
        HStack(alignment: .top, spacing: SpacingTokens.tiny) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 12))
                .foregroundStyle(accentColor)
                .padding(.top, 2)
                .accessibilityHidden(true)
            Text(citation.title)
                .font(TypographyTokens.caption(13))
                .foregroundStyle(inkColor)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            Text(String(localized: "methodologyAssistant.a11y.source") + ": " + citation.title)
        )
    }

    // MARK: - Loading / Error rows

    private var loadingRow: some View {
        HStack(spacing: SpacingTokens.small) {
            ProgressView()
                .tint(accentColor)
            Text(String(localized: "methodologyAssistant.loading"))
                .font(TypographyTokens.body(14))
                .foregroundStyle(mutedColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SpacingTokens.small)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(String(localized: "methodologyAssistant.loading")))
    }

    private func errorRow(_ message: String) -> some View {
        HStack(alignment: .top, spacing: SpacingTokens.small) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(ColorTokens.Semantic.warning)
                .accessibilityHidden(true)
            Text(message)
                .font(TypographyTokens.body(14))
                .foregroundStyle(inkColor)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(SpacingTokens.small)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                .fill(ColorTokens.Semantic.warning.opacity(0.12))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(message))
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(spacing: SpacingTokens.small) {
            TextField(
                String(localized: "methodologyAssistant.input.placeholder"),
                text: $questionText,
                axis: .vertical
            )
            .font(TypographyTokens.body(15))
            .foregroundStyle(inkColor)
            .lineLimit(1...4)
            .focused($inputFocused)
            .submitLabel(.send)
            .padding(.horizontal, SpacingTokens.regular)
            .padding(.vertical, SpacingTokens.small)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .fill(circuit == .specialist ? ColorTokens.Spec.surface : ColorTokens.Parent.surface)
            )
            .accessibilityLabel(Text(String(localized: "methodologyAssistant.input.placeholder")))

            Button {
                send()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(canSend ? accentColor : mutedColor.opacity(0.5))
            }
            .disabled(!canSend)
            .accessibilityLabel(Text(String(localized: "methodologyAssistant.send")))
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.vertical, SpacingTokens.small)
        .background(.ultraThinMaterial)
    }

    // MARK: - Helpers

    private var canSend: Bool {
        !viewModel.isLoading &&
        questionText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
    }

    private func send() {
        let question = questionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        inputFocused = false
        interactor?.ask(.init(question: question))
        questionText = ""
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
            if viewModel.isLoading {
                proxy.scrollTo("loading", anchor: .bottom)
            } else if let lastId = viewModel.turns.last?.id {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }

    // MARK: - Bootstrap

    @MainActor
    private func bootstrap() async {
        guard !bootstrapped else { return }
        bootstrapped = true

        let newInteractor = MethodologyAssistantInteractor(
            client: container.methodologyAssistantClient
        )
        newInteractor.presenter = presenter
        interactor = newInteractor
        logger.info("methodologyAssistant: bootstrapped")
    }
}

// MARK: - Preview

#Preview("MethodologyAssistant — parent") {
    MethodologyAssistantView()
        .environment(AppContainer.preview())
        .environment(AppCoordinator())
        .environment(\.circuitContext, .parent)
}

#Preview("MethodologyAssistant — specialist dark") {
    MethodologyAssistantView()
        .environment(AppContainer.preview())
        .environment(AppCoordinator())
        .environment(\.circuitContext, .specialist)
        .preferredColorScheme(.dark)
}
