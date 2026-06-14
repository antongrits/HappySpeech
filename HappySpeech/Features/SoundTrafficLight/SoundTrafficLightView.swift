import OSLog
import SwiftUI

// MARK: - SoundTrafficLightViewModelHolder

@MainActor
@Observable
final class SoundTrafficLightViewModelHolder: SoundTrafficLightDisplayLogic {

    var startVM: SoundTrafficLightModels.Start.ViewModel?
    var currentRound: SoundTrafficLightModels.Start.RoundViewModel?
    var currentPhrase: SoundTrafficLightModels.Start.PhraseViewModel?
    var currentText: SoundTrafficLightModels.Start.TextViewModel?
    var lastFeedback: String?
    var lastWasCorrect: Bool?
    var summary: SoundTrafficLightModels.Sort.SummaryViewModel?
    var isFinished: Bool = false

    func displayStart(viewModel: SoundTrafficLightModels.Start.ViewModel) async {
        self.startVM = viewModel
        self.currentRound = viewModel.firstRound
        self.currentPhrase = viewModel.firstPhrase
        self.currentText = viewModel.firstText
        self.isFinished = false
        self.summary = nil
        self.lastFeedback = nil
        self.lastWasCorrect = nil
    }

    func displaySort(viewModel: SoundTrafficLightModels.Sort.ViewModel) async {
        self.isFinished = viewModel.isFinished
        self.summary = viewModel.summary
        if let next = viewModel.nextRound {
            self.currentRound = next
            self.lastFeedback = nil
            self.lastWasCorrect = nil
        } else {
            self.lastFeedback = viewModel.feedbackText
            self.lastWasCorrect = viewModel.wasCorrect
        }
    }

    func displayChoosePhrase(viewModel: SoundTrafficLightModels.ChoosePhrase.ViewModel) async {
        self.isFinished = viewModel.isFinished
        self.summary = viewModel.summary
        if let next = viewModel.nextPhrase {
            self.currentPhrase = next
            self.lastFeedback = nil
            self.lastWasCorrect = nil
        } else {
            self.lastFeedback = viewModel.feedbackText
            self.lastWasCorrect = viewModel.wasCorrect
        }
    }

    func displayCountText(viewModel: SoundTrafficLightModels.CountText.ViewModel) async {
        self.isFinished = viewModel.isFinished
        self.summary = viewModel.summary
        if let next = viewModel.nextText {
            self.currentText = next
            self.lastFeedback = nil
            self.lastWasCorrect = nil
        } else {
            self.lastFeedback = viewModel.feedbackText
            self.lastWasCorrect = viewModel.isFinished ? nil : viewModel.correctA && viewModel.correctB
        }
    }
}

// MARK: - SoundTrafficLightView (Clean Swift: View)
//
// v29 Фаза 8, Функция 5 «Звуковой светофор».
//
// Детская игра дифференциации с полной методической лестницей:
//   • СЛОГ / СЛОВО — сортировка карточки в один из двух «гаражей» по звуку.
//   • ФРАЗА — определить доминирующий звук фразы (А / Б / оба), слова
//     подсвечены по целевым звукам.
//   • ТЕКСТ — «посчитай слова со звуком А и со звуком Б» степперами.
// По завершении уровня — сводка с подсказкой о новом разблокированном уровне.
//
// Accessibility / стиль:
//   • Тёплая палитра ColorTokens (coral/butter/rose/lilac/gold), без off-theme.
//   • Текст не обрезается: .lineLimit(nil) + .minimumScaleFactor(0.85).
//   • Симметричные отступы (screenEdge с обеих сторон), безопасно на SE 375pt.
//   • VoiceOver: материал и кнопки — описательные labels.
//   • Dynamic Type: VStack + minimumScaleFactor + ScrollView на длинном тексте.
//   • Reduced Motion: анимации гейтятся reduceMotion.
//   • Light + Dark.

struct SoundTrafficLightView: View {

    let childId: String

    @State private var holder = SoundTrafficLightViewModelHolder()
    @State private var interactor: SoundTrafficLightInteractor?
    @State private var presenter: SoundTrafficLightPresenter?
    @State private var router: SoundTrafficLightRouter?

    @Environment(\.exitGame) private var exitGame
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppContainer.self) private var container

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SoundTrafficLight.View"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                HSMeshGradientBackground(palette: .kidWarm, animated: !reduceMotion)
                    .ignoresSafeArea()
                    .opacity(colorScheme == .dark ? 0.18 : 0.30)
                    .blendMode(.softLight)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)

                if holder.isFinished, let summary = holder.summary {
                    summarySection(summary)
                } else if let startVM = holder.startVM {
                    content(for: startVM)
                } else {
                    loadingSection
                }
            }
            .navigationTitle(Text("soundTrafficLight.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        exitGame()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    .accessibilityLabel(Text("soundTrafficLight.close.a11y"))
                }
            }
            .task {
                await setupAndStart()
            }
        }
        .environment(\.circuitContext, .kid)
    }

    // MARK: - Level routing

    @ViewBuilder
    private func content(for startVM: SoundTrafficLightModels.Start.ViewModel) -> some View {
        switch startVM.level {
        case .syllable, .word:
            if let round = holder.currentRound {
                sortSection(startVM: startVM, round: round)
            } else {
                loadingSection
            }
        case .phrase:
            if let phrase = holder.currentPhrase {
                phraseSection(startVM: startVM, phrase: phrase)
            } else {
                loadingSection
            }
        case .text:
            if let text = holder.currentText {
                textSection(startVM: startVM, text: text)
            } else {
                loadingSection
            }
        }
    }

    // MARK: - Header (общий для всех уровней)

    private func header(
        startVM: SoundTrafficLightModels.Start.ViewModel,
        progressLabel: String,
        progressFraction: Double
    ) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            HStack {
                Text(startVM.levelLabel)
                    .font(TypographyTokens.caption(12).weight(.semibold))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .padding(.horizontal, SpacingTokens.sp3)
                    .padding(.vertical, SpacingTokens.sp1)
                    .background(Capsule().fill(ColorTokens.Brand.primaryLo.opacity(0.35)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer()
                Text(progressLabel)
                    .font(TypographyTokens.caption(12).monospacedDigit())
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(ColorTokens.Kid.surfaceAlt)
                    Capsule()
                        .fill(ColorTokens.Brand.primary)
                        .frame(width: max(0, geo.size.width * progressFraction))
                }
            }
            .frame(height: 10)
            .accessibilityHidden(true)

            Text(startVM.instruction)
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.top, SpacingTokens.sp4)
    }

    // MARK: - Feedback banner (общий)

    @ViewBuilder
    private func feedbackIfPresent() -> some View {
        if let feedback = holder.lastFeedback,
           let wasCorrect = holder.lastWasCorrect {
            feedbackBanner(text: feedback, isCorrect: wasCorrect)
        }
    }

    private func feedbackBanner(text: String, isCorrect: Bool) -> some View {
        HStack(spacing: SpacingTokens.sp2) {
            Image(systemName: isCorrect
                ? "checkmark.circle.fill"
                : "arrow.counterclockwise.circle.fill")
                .font(.title3)
                .hsSymbolEffect(.bounce, value: text)
            Text(text)
                .font(TypographyTokens.body(15).weight(.medium))
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(ColorTokens.Overlay.onAccent)
        .padding(.horizontal, SpacingTokens.sp4)
        .padding(.vertical, SpacingTokens.sp2)
        .background(
            Capsule().fill(isCorrect ? ColorTokens.Brand.mint : ColorTokens.Brand.butter)
        )
        .padding(.horizontal, SpacingTokens.screenEdge)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(text))
    }

    // MARK: - Garages (слог / слово / фраза)

    private func garageButton(
        label: String,
        tint: Color,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: SpacingTokens.sp2) {
                Image(systemName: symbol)
                    .font(.system(size: 32))
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
                Text(label)
                    .font(TypographyTokens.headline(18))
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 112)
            .padding(SpacingTokens.sp4)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(tint)
            )
            .depthShadow(ShadowTokens.kidDepth)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
        .accessibilityHint(Text("soundTrafficLight.garage.hint"))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Level: SORT (слог / слово)

    private func sortSection(
        startVM: SoundTrafficLightModels.Start.ViewModel,
        round: SoundTrafficLightModels.Start.RoundViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp5) {
            header(
                startVM: startVM,
                progressLabel: round.progressLabel,
                progressFraction: round.progressFraction
            )

            Spacer(minLength: SpacingTokens.sp4)

            HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp8) {
                Text(round.word)
                    .font(TypographyTokens.title(40))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, SpacingTokens.sp6)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .id(round.id)
            .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
            .accessibilityLabel(Text(round.accessibilityLabel))
            .accessibilityAddTraits(.isStaticText)

            feedbackIfPresent()

            Spacer(minLength: SpacingTokens.sp4)

            HStack(spacing: SpacingTokens.sp3) {
                garageButton(
                    label: startVM.garageALabel,
                    tint: ColorTokens.Brand.primary,
                    symbol: "tray.full.fill"
                ) {
                    Task { await sort(pickedGarageA: true) }
                }
                garageButton(
                    label: startVM.garageBLabel,
                    tint: ColorTokens.Brand.lilac,
                    symbol: "tray.full.fill"
                ) {
                    Task { await sort(pickedGarageA: false) }
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.sp6)
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.35), value: round.id)
    }

    // MARK: - Level: PHRASE

    private func phraseSection(
        startVM: SoundTrafficLightModels.Start.ViewModel,
        phrase: SoundTrafficLightModels.Start.PhraseViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp5) {
            header(
                startVM: startVM,
                progressLabel: phrase.progressLabel,
                progressFraction: phrase.progressFraction
            )

            Spacer(minLength: SpacingTokens.sp3)

            HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp6) {
                PhraseTokensFlow(tokens: phrase.tokens, reduceMotion: reduceMotion)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .id(phrase.id)
            .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(phrase.accessibilityLabel))

            // Легенда: какой звук какой краской подсвечен.
            HStack(spacing: SpacingTokens.sp4) {
                legendChip(label: startVM.garageALabel, color: ColorTokens.Brand.primary)
                legendChip(label: startVM.garageBLabel, color: ColorTokens.Brand.lilac)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)

            feedbackIfPresent()

            Spacer(minLength: SpacingTokens.sp3)

            // Светофор: какой звук доминирует во фразе.
            VStack(spacing: SpacingTokens.sp3) {
                HStack(spacing: SpacingTokens.sp3) {
                    garageButton(
                        label: startVM.garageALabel,
                        tint: ColorTokens.Brand.primary,
                        symbol: "speaker.wave.2.fill"
                    ) {
                        Task { await choosePhrase(side: .soundA) }
                    }
                    garageButton(
                        label: startVM.garageBLabel,
                        tint: ColorTokens.Brand.lilac,
                        symbol: "speaker.wave.2.fill"
                    ) {
                        Task { await choosePhrase(side: .soundB) }
                    }
                }
                Button {
                    Task { await choosePhrase(side: .both) }
                } label: {
                    Label {
                        Text("soundTrafficLight.phrase.both")
                            .lineLimit(nil)
                            .minimumScaleFactor(0.85)
                    } icon: {
                        Image(systemName: "circle.lefthalf.filled")
                    }
                    .font(TypographyTokens.headline(17))
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.card)
                            .fill(ColorTokens.Brand.gold)
                    )
                    .depthShadow(ShadowTokens.kidDepth)
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("soundTrafficLight.phrase.both.hint"))
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.sp6)
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.35), value: phrase.id)
    }

    private func legendChip(label: String, color: Color) -> some View {
        HStack(spacing: SpacingTokens.sp1) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.85)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Level: TEXT

    private func textSection(
        startVM: SoundTrafficLightModels.Start.ViewModel,
        text: SoundTrafficLightModels.Start.TextViewModel
    ) -> some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: SpacingTokens.sp5) {
                    header(
                        startVM: startVM,
                        progressLabel: text.progressLabel,
                        progressFraction: text.progressFraction
                    )

                    HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp6) {
                        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                            Text(text.title)
                                .font(TypographyTokens.title(22))
                                .foregroundStyle(ColorTokens.Kid.ink)
                                .lineLimit(nil)
                                .minimumScaleFactor(0.85)
                                .fixedSize(horizontal: false, vertical: true)
                            ForEach(Array(text.lines.enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(TypographyTokens.body(16))
                                    .foregroundStyle(ColorTokens.Kid.ink)
                                    .lineLimit(nil)
                                    .minimumScaleFactor(0.85)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .id(text.id)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text(text.accessibilityLabel))

                    counterRow(
                        label: startVM.garageALabel,
                        color: ColorTokens.Brand.primary,
                        value: $countA,
                        maxValue: text.maxCount
                    )
                    counterRow(
                        label: startVM.garageBLabel,
                        color: ColorTokens.Brand.lilac,
                        value: $countB,
                        maxValue: text.maxCount
                    )

                    feedbackIfPresent()

                    Button {
                        Task { await countText() }
                    } label: {
                        Text("soundTrafficLight.text.check")
                            .font(TypographyTokens.headline(17))
                            .foregroundStyle(ColorTokens.Overlay.onAccent)
                            .lineLimit(nil)
                            .minimumScaleFactor(0.85)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(
                                RoundedRectangle(cornerRadius: RadiusTokens.card)
                                    .fill(ColorTokens.Brand.primary)
                            )
                            .depthShadow(ShadowTokens.kidDepth)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.bottom, SpacingTokens.sp6)
                }
                .frame(minHeight: geo.size.height, alignment: .top)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func counterRow(
        label: String,
        color: Color,
        value: Binding<Int>,
        maxValue: Int
    ) -> some View {
        HStack(spacing: SpacingTokens.sp3) {
            HStack(spacing: SpacingTokens.sp2) {
                Circle().fill(color).frame(width: 14, height: 14)
                Text(label)
                    .font(TypographyTokens.headline(17))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Stepper(
                value: value,
                in: 0 ... maxValue
            ) {
                Text(value.wrappedValue, format: .number)
                    .font(TypographyTokens.headline(20).monospacedDigit())
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .frame(minWidth: 28)
            }
            .labelsHidden()
            .accessibilityLabel(Text(label))
            .accessibilityValue(Text(value.wrappedValue, format: .number))
        }
        .padding(SpacingTokens.sp4)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Kid.surface)
        )
        .padding(.horizontal, SpacingTokens.screenEdge)
    }

    // MARK: - Summary

    private func summarySection(
        _ summary: SoundTrafficLightModels.Sort.SummaryViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp5) {
            Spacer()

            Image(systemName: summary.accuracyFraction >= 0.8
                ? "star.circle.fill"
                : "hand.thumbsup.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(ColorTokens.Brand.butter)
                .hsSymbolEffect(.bounce, value: summary.scoreText)
                .accessibilityHidden(true)

            Text(summary.title)
                .font(TypographyTokens.title(26))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)

            Text(summary.scoreText)
                .font(TypographyTokens.headline(20).monospacedDigit())
                .foregroundStyle(ColorTokens.Brand.primary)

            if let nextLevelLabel = summary.nextLevelLabel {
                Text(nextLevelLabel)
                    .font(TypographyTokens.body(15).weight(.medium))
                    .foregroundStyle(ColorTokens.Brand.gold)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal, SpacingTokens.sp6)
                    .padding(.vertical, SpacingTokens.sp2)
                    .background(
                        Capsule().fill(ColorTokens.Brand.butter.opacity(0.30))
                    )
            }

            Text(summary.encouragement)
                .font(TypographyTokens.body(16))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, SpacingTokens.sp6)

            Spacer()

            VStack(spacing: SpacingTokens.sp3) {
                Button {
                    Task { await setupAndStart(forceRestart: true) }
                } label: {
                    Text("soundTrafficLight.summary.again")
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            RoundedRectangle(cornerRadius: RadiusTokens.card)
                                .fill(ColorTokens.Brand.primary)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("soundTrafficLight.summary.again.hint"))

                Button {
                    exitGame()
                } label: {
                    Text("soundTrafficLight.summary.done")
                        .font(TypographyTokens.body(16).weight(.medium))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
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
            Text("soundTrafficLight.loading")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Wiring

    @State private var countA = 0
    @State private var countB = 0

    private func setupAndStart(forceRestart: Bool = false) async {
        if interactor == nil {
            let presenter = SoundTrafficLightPresenter(displayLogic: holder)
            let worker = SoundTrafficLightWorker(childRepository: container.childRepository)
            let interactor = SoundTrafficLightInteractor(
                childId: childId,
                worker: worker,
                hapticService: container.hapticService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = SoundTrafficLightRouter(dismissAction: { exitGame() })
        }
        _ = forceRestart
        countA = 0
        countB = 0
        await interactor?.start(request: .init(childId: childId))
    }

    private func sort(pickedGarageA: Bool) async {
        await interactor?.sort(request: .init(pickedGarageA: pickedGarageA))
    }

    private func choosePhrase(side: TrafficLightPhrase.Dominant) async {
        await interactor?.choosePhrase(request: .init(pickedSide: side))
    }

    private func countText() async {
        await interactor?.countText(request: .init(answerA: countA, answerB: countB))
        countA = 0
        countB = 0
    }
}

// MARK: - PhraseTokensFlow
//
// Лёгкий wrap-layout слов фразы: переносит токены на новую строку при нехватке
// ширины. Слова-носители звука A/B подсвечиваются тёплой заливкой. Безопасно
// на узком SE — переносит, не обрезает.

private struct PhraseTokensFlow: View {

    let tokens: [SoundTrafficLightModels.Start.PhraseTokenViewModel]
    let reduceMotion: Bool

    var body: some View {
        FlowLayout(spacing: SpacingTokens.sp2, lineSpacing: SpacingTokens.sp2) {
            ForEach(tokens) { token in
                Text(token.text)
                    .font(TypographyTokens.headline(20))
                    .foregroundStyle(foreground(for: token))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal, SpacingTokens.sp2)
                    .padding(.vertical, SpacingTokens.sp1)
                    .background(background(for: token))
            }
        }
    }

    private func foreground(
        for token: SoundTrafficLightModels.Start.PhraseTokenViewModel
    ) -> Color {
        token.containsA || token.containsB
            ? ColorTokens.Overlay.onAccent
            : ColorTokens.Kid.ink
    }

    @ViewBuilder
    private func background(
        for token: SoundTrafficLightModels.Start.PhraseTokenViewModel
    ) -> some View {
        if token.containsA && token.containsB {
            // Слово-носитель обоих звуков — двухцветная заливка.
            Capsule().fill(
                LinearGradient(
                    colors: [ColorTokens.Brand.primary, ColorTokens.Brand.lilac],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        } else if token.containsA {
            Capsule().fill(ColorTokens.Brand.primary)
        } else if token.containsB {
            Capsule().fill(ColorTokens.Brand.lilac)
        } else {
            Capsule().fill(Color.clear)
        }
    }
}

// MARK: - FlowLayout
//
// Простой переносящий Layout: укладывает subviews слева-направо, перенося на
// новую строку при превышении доступной ширины. Используется для слов фразы,
// чтобы текст никогда не обрезался и не уходил за край на узких устройствах.

private struct FlowLayout: Layout {

    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows = layoutRows(maxWidth: maxWidth, subviews: subviews)
        let height = rows.reduce(CGFloat.zero) { partial, row in
            partial + row.height
        } + lineSpacing * CGFloat(max(0, rows.count - 1))
        let width = rows.map(\.width).max() ?? 0
        rows.removeAll()
        return CGSize(width: min(width, maxWidth), height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        let rows = layoutRows(maxWidth: bounds.width, subviews: subviews)
        var originY = bounds.minY
        for row in rows {
            var originX = bounds.minX
            for element in row.elements {
                let size = subviews[element.index].sizeThatFits(.unspecified)
                subviews[element.index].place(
                    at: CGPoint(x: originX, y: originY),
                    proposal: ProposedViewSize(width: size.width, height: size.height)
                )
                originX += size.width + spacing
            }
            originY += row.height + lineSpacing
        }
    }

    private struct RowElement {
        let index: Int
        let width: CGFloat
    }

    private struct Row {
        var elements: [RowElement] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func layoutRows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let projected = current.width == 0
                ? size.width
                : current.width + spacing + size.width
            if projected > maxWidth, !current.elements.isEmpty {
                rows.append(current)
                current = Row()
                current.elements.append(RowElement(index: index, width: size.width))
                current.width = size.width
                current.height = size.height
            } else {
                current.elements.append(RowElement(index: index, width: size.width))
                current.width = current.elements.count == 1
                    ? size.width
                    : current.width + spacing + size.width
                current.height = max(current.height, size.height)
            }
        }
        if !current.elements.isEmpty { rows.append(current) }
        return rows
    }
}

// MARK: - SoundTrafficLightLevelPreview
//
// Детерминированный рендер одного уровня лестницы из заранее собранного
// `Start.ViewModel` — без async-воркера и random-выборки. Используется в
// превью и snapshot-тестах (каждый уровень в light/dark стабильно).

#if DEBUG
struct SoundTrafficLightLevelPreview: View {

    let viewModel: SoundTrafficLightModels.Start.ViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()
            HSMeshGradientBackground(palette: .kidWarm, animated: !reduceMotion)
                .ignoresSafeArea()
                .opacity(colorScheme == .dark ? 0.18 : 0.30)
                .blendMode(.softLight)
                .allowsHitTesting(false)

            VStack(spacing: SpacingTokens.sp5) {
                HStack {
                    Text(viewModel.levelLabel)
                        .font(TypographyTokens.caption(12).weight(.semibold))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .padding(.horizontal, SpacingTokens.sp3)
                        .padding(.vertical, SpacingTokens.sp1)
                        .background(Capsule().fill(ColorTokens.Brand.primaryLo.opacity(0.35)))
                    Spacer()
                }
                Text(viewModel.instruction)
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)

                levelContent

                Spacer()
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.sp6)
        }
    }

    @ViewBuilder
    private var levelContent: some View {
        switch viewModel.level {
        case .syllable, .word:
            if let round = viewModel.firstRound {
                Text(round.word)
                    .font(TypographyTokens.title(40))
                    .foregroundStyle(ColorTokens.Kid.ink)
                HStack(spacing: SpacingTokens.sp3) {
                    garageChip(viewModel.garageALabel, ColorTokens.Brand.primary)
                    garageChip(viewModel.garageBLabel, ColorTokens.Brand.lilac)
                }
            }
        case .phrase:
            if let phrase = viewModel.firstPhrase {
                Text(phrase.text)
                    .font(TypographyTokens.headline(20))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                HStack(spacing: SpacingTokens.sp3) {
                    garageChip(viewModel.garageALabel, ColorTokens.Brand.primary)
                    garageChip(viewModel.garageBLabel, ColorTokens.Brand.lilac)
                }
            }
        case .text:
            if let text = viewModel.firstText {
                VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                    Text(text.title)
                        .font(TypographyTokens.title(22))
                        .foregroundStyle(ColorTokens.Kid.ink)
                    ForEach(Array(text.lines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(TypographyTokens.body(15))
                            .foregroundStyle(ColorTokens.Kid.ink)
                    }
                }
            }
        }
    }

    private func garageChip(_ label: String, _ color: Color) -> some View {
        Text(label)
            .font(TypographyTokens.headline(17))
            .foregroundStyle(ColorTokens.Overlay.onAccent)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(RoundedRectangle(cornerRadius: RadiusTokens.card).fill(color))
    }
}
#endif

// MARK: - Preview

#if DEBUG
#Preview("SoundTrafficLight / game") {
    SoundTrafficLightView(childId: "preview-child-1")
        .environment(AppContainer.preview())
}
#endif
