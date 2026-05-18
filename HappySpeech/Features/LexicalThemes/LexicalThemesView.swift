import OSLog
import SwiftUI

// MARK: - LexicalThemesViewModelHolder

@MainActor
@Observable
final class LexicalThemesViewModelHolder: LexicalThemesDisplayLogic {

    var hubVM: LexicalThemesModels.LoadThemes.ViewModel?
    var themeStartVM: LexicalThemesModels.StartTheme.ViewModel?
    var currentRound: LexicalThemesModels.StartTheme.RoundViewModel?
    var lastFeedback: String?
    var lastWasCorrect: Bool?
    var summary: LexicalThemesModels.Answer.SummaryViewModel?
    var isInGame: Bool = false
    var isFinished: Bool = false

    func displayThemes(viewModel: LexicalThemesModels.LoadThemes.ViewModel) async {
        self.hubVM = viewModel
        self.isInGame = false
        self.isFinished = false
    }

    func displayThemeStart(viewModel: LexicalThemesModels.StartTheme.ViewModel) async {
        self.themeStartVM = viewModel
        self.currentRound = viewModel.firstRound
        self.isInGame = true
        self.isFinished = false
        self.summary = nil
        self.lastFeedback = nil
        self.lastWasCorrect = nil
    }

    func displayAnswer(viewModel: LexicalThemesModels.Answer.ViewModel) async {
        self.lastFeedback = viewModel.feedbackText
        self.lastWasCorrect = viewModel.wasCorrect
        self.isFinished = viewModel.isFinished
        self.summary = viewModel.summary
        if let next = viewModel.nextRound {
            self.currentRound = next
        }
    }
}

// MARK: - LexicalThemesView (Clean Swift: View)
//
// v29 Фаза 8, Функция 7 «Мир слов».
//
// Контентный хаб лексических тем: ребёнок выбирает тему и проходит
// мини-игры (называние, обобщение, «четвёртый лишний», действия).
//
// Accessibility:
//   • Kid circuit: карточки и кнопки ≥ 56pt
//   • VoiceOver: описательные labels тем и вариантов
//   • Dynamic Type: minimumScaleFactor
//   • Reduced Motion: переходы гейтятся reduceMotion
//   • Light + Dark: ColorTokens.Kid адаптируются

struct LexicalThemesView: View {

    let childId: String

    @State private var holder = LexicalThemesViewModelHolder()
    @State private var interactor: LexicalThemesInteractor?
    @State private var presenter: LexicalThemesPresenter?
    @State private var router: LexicalThemesRouter?
    /// Порядок отображения вариантов текущего раунда (id перемешан, чтобы
    /// правильный вариант не всегда был первым на экране).
    @State private var optionOrder: [Int] = []

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "LexicalThemes.View"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()

                if holder.isInGame {
                    if holder.isFinished, let summary = holder.summary {
                        summarySection(summary)
                    } else if let round = holder.currentRound {
                        gameSection(round: round)
                    } else {
                        loadingSection
                    }
                } else if let hub = holder.hubVM {
                    hubSection(hub)
                } else {
                    loadingSection
                }
            }
            .navigationTitle(Text("lexicalThemes.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if holder.isInGame {
                            Task { await backToHub() }
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    .accessibilityLabel(Text("lexicalThemes.close.a11y"))
                }
            }
            .task {
                await setup()
            }
        }
        .environment(\.circuitContext, .kid)
    }

    // MARK: - Hub

    private func hubSection(
        _ hub: LexicalThemesModels.LoadThemes.ViewModel
    ) -> some View {
        ScrollView {
            VStack(spacing: SpacingTokens.sp4) {
                Text(hub.masteredCountLabel)
                    .font(TypographyTokens.headline(17).monospacedDigit())
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .padding(.top, SpacingTokens.sp4)

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: SpacingTokens.sp3
                ) {
                    ForEach(hub.themes) { theme in
                        themeCard(theme)
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.sp6)
            }
        }
    }

    private func themeCard(
        _ theme: LexicalThemesModels.LoadThemes.ThemeCardViewModel
    ) -> some View {
        Button {
            Task { await startTheme(themeId: theme.id) }
        } label: {
            VStack(spacing: SpacingTokens.sp2) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: theme.symbolName)
                        .font(.system(size: 38))
                        .foregroundStyle(ColorTokens.Brand.sky)
                        .frame(maxWidth: .infinity)
                    if theme.isMastered {
                        Image(systemName: "star.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Brand.gold)
                            .accessibilityHidden(true)
                    }
                }
                Text(theme.title)
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center)
                Text(theme.wordCountLabel)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }
            .frame(maxWidth: .infinity, minHeight: 130)
            .padding(SpacingTokens.sp3)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(ColorTokens.Kid.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .strokeBorder(ColorTokens.Kid.line, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(theme.accessibilityLabel))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Game

    private func gameSection(
        round: LexicalThemesModels.StartTheme.RoundViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp5) {
            progressBar(round)

            Spacer()

            VStack(spacing: SpacingTokens.sp3) {
                Text(round.prompt)
                    .font(TypographyTokens.headline(19))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .padding(.horizontal, SpacingTokens.sp4)

                Image(systemName: round.kind.symbolName)
                    .font(.system(size: 52))
                    .foregroundStyle(ColorTokens.Brand.lilac)
                    .accessibilityHidden(true)
            }
            .id(round.id)
            .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))

            if let feedback = holder.lastFeedback,
               let wasCorrect = holder.lastWasCorrect {
                feedbackBanner(text: feedback, isCorrect: wasCorrect)
            }

            Spacer()

            VStack(spacing: SpacingTokens.sp3) {
                ForEach(displayedOptions(round)) { option in
                    optionButton(option) {
                        Task { await answer(optionIndex: option.id) }
                    }
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.sp6)
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.35), value: round.id)
    }

    private func progressBar(
        _ round: LexicalThemesModels.StartTheme.RoundViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            Text(round.progressLabel)
                .font(TypographyTokens.caption(12).monospacedDigit())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(ColorTokens.Kid.surfaceAlt)
                    Capsule()
                        .fill(ColorTokens.Brand.primary)
                        .frame(width: max(0, geo.size.width * round.progressFraction))
                }
            }
            .frame(height: 10)
            .accessibilityHidden(true)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.top, SpacingTokens.sp4)
    }

    private func optionButton(
        _ option: LexicalThemesModels.StartTheme.OptionViewModel,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(option.label)
                .font(TypographyTokens.headline(19))
                .foregroundStyle(ColorTokens.Overlay.onAccent)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 64)
                .padding(SpacingTokens.sp3)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.card)
                        .fill(ColorTokens.Brand.sky)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(option.label))
        .accessibilityHint(Text("lexicalThemes.option.hint"))
    }

    private func feedbackBanner(text: String, isCorrect: Bool) -> some View {
        HStack(spacing: SpacingTokens.sp2) {
            Image(systemName: isCorrect
                ? "checkmark.circle.fill"
                : "arrow.counterclockwise.circle.fill")
                .font(.title3)
            Text(text)
                .font(TypographyTokens.body(15).weight(.medium))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(ColorTokens.Overlay.onAccent)
        .padding(.horizontal, SpacingTokens.sp4)
        .padding(.vertical, SpacingTokens.sp2)
        .background(
            Capsule().fill(isCorrect ? ColorTokens.Brand.mint : ColorTokens.Brand.butter)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(text))
    }

    // MARK: - Summary

    private func summarySection(
        _ summary: LexicalThemesModels.Answer.SummaryViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp5) {
            Spacer()

            Image(systemName: summary.isThemeMastered
                ? "star.circle.fill"
                : "hand.thumbsup.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(ColorTokens.Brand.gold)
                .accessibilityHidden(true)

            Text(summary.title)
                .font(TypographyTokens.title(26))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Text(summary.scoreText)
                .font(TypographyTokens.headline(20).monospacedDigit())
                .foregroundStyle(ColorTokens.Brand.primary)

            Text(summary.encouragement)
                .font(TypographyTokens.body(16))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .padding(.horizontal, SpacingTokens.sp6)

            Spacer()

            VStack(spacing: SpacingTokens.sp3) {
                Button {
                    Task { await backToHub() }
                } label: {
                    Text("lexicalThemes.summary.backToThemes")
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            RoundedRectangle(cornerRadius: RadiusTokens.card)
                                .fill(ColorTokens.Brand.primary)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("lexicalThemes.summary.backToThemes.hint"))

                Button {
                    dismiss()
                } label: {
                    Text("lexicalThemes.summary.done")
                        .font(TypographyTokens.body(16).weight(.medium))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.sp6)
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Loading

    private var loadingSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            ProgressView()
                .controlSize(.large)
            Text("lexicalThemes.loading")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Option ordering

    /// Возвращает варианты в перемешанном порядке отображения; `id` остаётся
    /// оригинальным индексом (для проверки в Interactor).
    private func displayedOptions(
        _ round: LexicalThemesModels.StartTheme.RoundViewModel
    ) -> [LexicalThemesModels.StartTheme.OptionViewModel] {
        guard optionOrder.count == round.options.count else {
            return round.options
        }
        return optionOrder.compactMap { idx in
            round.options.first { $0.id == idx }
        }
    }

    private func refreshOptionOrder(for round: LexicalThemesModels.StartTheme.RoundViewModel?) {
        guard let round else { return }
        optionOrder = round.options.map(\.id).shuffled()
    }

    // MARK: - Wiring

    private func setup() async {
        if interactor == nil {
            let presenter = LexicalThemesPresenter(displayLogic: holder)
            let worker = LexicalThemesWorker(childRepository: container.childRepository)
            let interactor = LexicalThemesInteractor(
                childId: childId,
                worker: worker,
                hapticService: container.hapticService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = LexicalThemesRouter(dismissAction: { dismiss() })
        }
        await interactor?.loadThemes(request: .init(childId: childId))
    }

    private func startTheme(themeId: String) async {
        await interactor?.startTheme(request: .init(themeId: themeId))
        refreshOptionOrder(for: holder.currentRound)
    }

    private func answer(optionIndex: Int) async {
        await interactor?.answer(request: .init(optionIndex: optionIndex))
        refreshOptionOrder(for: holder.currentRound)
    }

    private func backToHub() async {
        await interactor?.loadThemes(request: .init(childId: childId))
    }
}

// MARK: - Preview

#if DEBUG
#Preview("LexicalThemes / hub") {
    LexicalThemesView(childId: "preview-child-1")
        .environment(AppContainer.preview())
}
#endif
