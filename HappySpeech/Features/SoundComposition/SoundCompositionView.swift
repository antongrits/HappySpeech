import OSLog
import SwiftUI

// MARK: - SoundCompositionView
//
// «Мастерская звукового состава слова» — kid-игра эльконинского звукового
// анализа-синтеза. Три шага внутри каждого слова:
//   1. Слово-схема   — картинка предмета + пустой «домик» из клеток по числу
//      звуков + протяжная озвучка Ляли.
//   2. Раскладка     — звук за звуком: подсветка активной клетки, палитра из 3
//      цветных фишек (гласный/твёрдый/мягкий), постановка фишки.
//   3. Проверка/синтез — слово собрано, play-слияние звуков + бонус-цепочка
//      замены первого звука (мак→рак→лак).
//
// Архитектура: Clean Swift VIP. interactor/presenter/router/display создаются
// один раз в bootstrap() и удерживаются как @State.
// Палитра тёплая (cream-фон); цветные эльконинские фишки — ТОЛЬКО на круглых
// фишках/палитре/легенде. Reduced Motion уважается во всех анимациях.

struct SoundCompositionView: View {

    // MARK: - Input

    let childId: String

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - VIP

    @State private var display = SoundCompositionDisplay()
    @State private var interactor: SoundCompositionInteractor?
    @State private var presenter: SoundCompositionPresenter?
    @State private var router: SoundCompositionRouter?
    @State private var bootstrapped = false
    @State private var celebrate = false

    private let logger = Logger(subsystem: "ru.happyspeech", category: "SoundCompositionView")

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
        .task { await bootstrap() }
        .onDisappear { interactor?.cancel() }
        .onChange(of: display.pendingExit) { _, exit in
            if exit { router?.dismiss() }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(
            localized: "soundComposition.screen.a11y",
            defaultValue: "Мастерская звукового состава: разбери слово по звукам"
        ))
    }

    // MARK: - Content switch

    @ViewBuilder
    private var content: some View {
        switch display.phase {
        case .loading:
            loadingView
        case .scheme:
            schemeView
        case .placing:
            placingView
        case .synthesis:
            synthesisView
        case .completed:
            completedView
        }
    }

    // MARK: - Shared chrome

    private func topBar(title: String, subtitle: String) -> some View {
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
                Text(title)
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(subtitle)
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)

            Button { interactor?.playWord() } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(TypographyTokens.headline(16).weight(.semibold))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(ColorTokens.Kid.surfaceAlt))
            }
            .accessibilityLabel(String(localized: "soundComposition.replay.a11y", defaultValue: "Повторить слово"))
        }
    }

    private func stepDots(current: Int) -> some View {
        VStack(spacing: SpacingTokens.tiny) {
            HStack(spacing: SpacingTokens.small) {
                ForEach(1...3, id: \.self) { i in
                    Circle()
                        .fill(i <= current ? ColorTokens.Brand.primary : ColorTokens.Kid.line)
                        .frame(width: i == current ? 13 : 9, height: i == current ? 13 : 9)
                }
            }
            Text(stepLabel(current))
                .font(TypographyTokens.body(13).weight(.semibold))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stepLabel(current))
    }

    private func stepLabel(_ step: Int) -> String {
        switch step {
        case 1: return String(localized: "soundComposition.step.1", defaultValue: "Шаг 1 из 3 · Слушаем слово")
        case 2: return String(localized: "soundComposition.step.2", defaultValue: "Шаг 2 из 3 · Раскладываем фишки")
        default: return String(localized: "soundComposition.step.3", defaultValue: "Шаг 3 из 3 · Проверка и синтез")
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: SpacingTokens.medium) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(ColorTokens.Brand.primary)
                .scaleEffect(1.4)
            Text(String(localized: "soundComposition.loading", defaultValue: "Готовим звуки…"))
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Step 1: scheme

    private var schemeView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SpacingTokens.regular) {
                topBar(
                    title: String(localized: "soundComposition.title", defaultValue: "Звуковая мастерская"),
                    subtitle: String(localized: "soundComposition.subtitle", defaultValue: "Разберём слово по звукам")
                )
                stepDots(current: 1)
                objectCard
                houseHeader
                soundHouse(activeIndex: 0, showQuestionMarks: true)
                mascotRow(
                    text: String(
                        format: String(
                            localized: "soundComposition.mascot.scheme %@",
                            defaultValue: "Слушай, как я тяну звуки. Сколько звуков спряталось в слове «%@»?"
                        ),
                        display.wordText
                    ),
                    state: .explaining
                )
                SoundCompositionCTA(
                    title: String(localized: "soundComposition.cta.layout", defaultValue: "Разложить фишки"),
                    icon: "arrow.right"
                ) {
                    container.soundService.playUISound(.tap)
                    interactor?.beginPlacing()
                }
            }
            .padding(.horizontal, SoundCompositionMetrics.contentPadding)
            .padding(.top, SpacingTokens.tiny)
            .padding(.bottom, SpacingTokens.regular)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaPadding(.bottom, SpacingTokens.small)
    }

    private var objectCard: some View {
        VStack(spacing: SpacingTokens.small) {
            HSContentSymbol(display.imageAsset, size: 96)
                .frame(width: 150, height: 150)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                        .fill(ColorTokens.Kid.surfaceAlt)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                        .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
                )
                .scaleEffect(reduceMotion ? 1 : (display.isPlaying ? 1.03 : 1))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                           value: display.isPlaying)
                .accessibilityLabel(display.wordText)

            Text(display.wordText)
                .font(TypographyTokens.display(30).weight(.black))
                .foregroundStyle(ColorTokens.Kid.ink)
                .tracking(2)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Button { interactor?.playWord() } label: {
                HStack(spacing: SpacingTokens.tiny) {
                    Image(systemName: display.isPlaying ? "waveform" : "speaker.wave.2.fill")
                        .font(TypographyTokens.body(15).weight(.semibold))
                        .symbolEffect(.variableColor, isActive: display.isPlaying && !reduceMotion)
                    Text(String(
                        format: String(localized: "soundComposition.listen %@",
                                       defaultValue: "Послушай: %@"),
                        display.stretchedHint
                    ))
                    .font(TypographyTokens.headline(15))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                }
                .foregroundStyle(ColorTokens.Brand.primary)
                .padding(.horizontal, SpacingTokens.regular)
                .padding(.vertical, SpacingTokens.small)
                .background(
                    Capsule().fill(ColorTokens.Brand.primaryLo.opacity(0.35))
                )
            }
            .accessibilityLabel(String(localized: "soundComposition.listenWord.a11y", defaultValue: "Послушать слово протяжно"))
        }
        .frame(maxWidth: .infinity)
        .padding(SpacingTokens.large)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .fill(ColorTokens.Kid.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
        )
        .shadow(color: ColorTokens.Overlay.shadow.opacity(0.5), radius: 14, y: 8)
    }

    private var houseHeader: some View {
        HStack {
            Text(String(localized: "soundComposition.house.title", defaultValue: "Домик звуков"))
                .font(TypographyTokens.headline(15).weight(.bold))
                .foregroundStyle(ColorTokens.Kid.ink)
            Spacer()
            Text(String(
                format: String(localized: "soundComposition.house.count %lld",
                               defaultValue: "%lld клеток · %lld звуков"),
                display.soundCount, display.soundCount
            ))
            .font(TypographyTokens.body(13).weight(.semibold))
            .foregroundStyle(ColorTokens.Kid.inkMuted)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
    }

    // MARK: - Sound house (cells with roofs)

    private func soundHouse(activeIndex: Int?, showQuestionMarks: Bool) -> some View {
        HStack(spacing: SpacingTokens.tiny) {
            ForEach(0..<max(display.soundCount, 1), id: \.self) { idx in
                SoundCell(
                    index: idx,
                    chip: display.placedChips.indices.contains(idx) ? display.placedChips[idx] : nil,
                    isActive: idx == activeIndex,
                    showQuestionMark: showQuestionMarks,
                    reduceMotion: reduceMotion
                )
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "soundComposition.house.a11y", defaultValue: "Домик звуков"))
    }

    // MARK: - Step 2: placing

    private var placingView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SpacingTokens.regular) {
                topBar(
                    title: String(localized: "soundComposition.placing.title", defaultValue: "Раскладываем фишки"),
                    subtitle: activePromptSubtitle
                )
                stepDots(current: 2)
                wordStrip
                soundHouse(activeIndex: display.activeSoundIndex, showQuestionMarks: false)
                nowSoundCard
                palette
                if display.showFeedback, !display.feedbackText.isEmpty {
                    softHintBanner
                }
                mascotRow(text: placingMascotText, state: display.feedbackCorrect ? .encouraging : .explaining)
            }
            .padding(.horizontal, SoundCompositionMetrics.contentPadding)
            .padding(.top, SpacingTokens.tiny)
            .padding(.bottom, SpacingTokens.regular)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaPadding(.bottom, SpacingTokens.small)
        .onChange(of: display.activeSoundIndex) { _, newValue in
            // Слово собрано (активного звука больше нет) → переходим к синтезу.
            if newValue == nil, display.phase == .placing {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(600))
                    interactor?.enterSynthesis()
                }
            }
        }
    }

    private var wordStrip: some View {
        HStack(spacing: SpacingTokens.small) {
            HSContentSymbol(display.imageAsset, size: 36)
                .frame(width: 54, height: 54)
                .background(RoundedRectangle(cornerRadius: RadiusTokens.sm).fill(ColorTokens.Kid.surfaceAlt))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                HStack(spacing: 4) {
                    ForEach(Array(display.wordText.enumerated()), id: \.offset) { idx, ch in
                        Text(String(ch))
                            .font(TypographyTokens.title(24).weight(.black))
                            .foregroundStyle(letterColor(at: idx))
                    }
                }
                Text(String(localized: "soundComposition.trace.hint",
                            defaultValue: "Веди пальцем по слову — звук за звуком"))
                    .font(TypographyTokens.body(12).weight(.semibold))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(SpacingTokens.small)
        .background(RoundedRectangle(cornerRadius: RadiusTokens.lg).fill(ColorTokens.Kid.surface))
        .overlay(RoundedRectangle(cornerRadius: RadiusTokens.lg).strokeBorder(ColorTokens.Kid.line, lineWidth: 1))
    }

    private func letterColor(at idx: Int) -> Color {
        let active = display.activeSoundIndex ?? Int.max
        if idx < active { return ColorTokens.Kid.ink }
        if idx == active { return ColorTokens.Brand.primary }
        return ColorTokens.Kid.inkSoft
    }

    private var nowSoundCard: some View {
        VStack(spacing: SpacingTokens.tiny) {
            Text(String(localized: "soundComposition.nowSound", defaultValue: "ПОСЛУШАЙ ЗВУК"))
                .font(TypographyTokens.body(12).weight(.bold))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .tracking(1)
            Button { interactor?.playActiveSound() } label: {
                HStack(spacing: SpacingTokens.tiny) {
                    Text("[ \(display.activeSoundLetter) ]")
                        .font(TypographyTokens.display(34).weight(.black))
                        .foregroundStyle(ColorTokens.Kid.ink)
                    Image(systemName: "speaker.wave.2.fill")
                        .font(TypographyTokens.headline(18))
                        .foregroundStyle(ColorTokens.Brand.primary)
                }
            }
            .accessibilityLabel(String(
                format: String(localized: "soundComposition.playSound.a11y %@",
                               defaultValue: "Послушать звук %@"),
                display.activeSoundLetter
            ))
        }
        .frame(maxWidth: .infinity)
        .padding(SpacingTokens.regular)
        .background(RoundedRectangle(cornerRadius: RadiusTokens.lg).fill(ColorTokens.Kid.surfaceAlt))
        .overlay(RoundedRectangle(cornerRadius: RadiusTokens.lg).strokeBorder(ColorTokens.Kid.line, lineWidth: 1))
    }

    private var palette: some View {
        HStack(spacing: SpacingTokens.small) {
            ForEach(SoundType.allCases, id: \.self) { type in
                ChipPickButton(type: type, reduceMotion: reduceMotion) {
                    handlePick(type)
                }
            }
        }
    }

    private var softHintBanner: some View {
        HStack(spacing: SpacingTokens.small) {
            Image(systemName: display.feedbackCorrect ? "checkmark.circle.fill" : "lightbulb.fill")
                .font(TypographyTokens.title(20).weight(.semibold))
                .foregroundStyle(display.feedbackCorrect ? ColorTokens.Feedback.correct : ColorTokens.Brand.butter)
                .accessibilityHidden(true)
            Text(display.feedbackText)
                .font(TypographyTokens.body(14).weight(.semibold))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, SpacingTokens.regular)
        .padding(.vertical, SpacingTokens.small)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                .fill(display.feedbackCorrect
                      ? ColorTokens.Feedback.correct.opacity(0.14)
                      : ColorTokens.Brand.butter.opacity(0.18))
        )
        .transition(.opacity)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: display.feedbackText)
    }

    private var activePromptSubtitle: String {
        guard !display.activeSoundLetter.isEmpty else {
            return String(localized: "soundComposition.placing.subtitle.idle", defaultValue: "Какого цвета звук?")
        }
        return String(
            format: String(localized: "soundComposition.placing.subtitle %@",
                           defaultValue: "Какого цвета звук «%@»?"),
            display.activeSoundLetter
        )
    }

    private var placingMascotText: String {
        if display.showFeedback, !display.feedbackText.isEmpty {
            return display.feedbackText
        }
        return String(
            format: String(localized: "soundComposition.mascot.placing %@",
                           defaultValue: "Послушай звук «%@» и выбери цвет фишки."),
            display.activeSoundLetter
        )
    }

    private var synthesisMascotText: String {
        String(
            localized: "soundComposition.mascot.synth",
            defaultValue: "Ты разобрал слово на звуки и собрал обратно. Настоящий мастер звуков!"
        )
    }

    // MARK: - Step 3: synthesis

    private var synthesisView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SpacingTokens.regular) {
                topBar(
                    title: String(localized: "soundComposition.synth.header", defaultValue: "Собираем слово"),
                    subtitle: String(localized: "soundComposition.synth.sub", defaultValue: "Звуки сложились вместе")
                )
                stepDots(current: 3)
                winBanner
                synthesisHouseCard
                if let bonus = display.bonus {
                    bonusCard(bonus)
                }
                mascotRow(text: synthesisMascotText, state: .celebrating)
                SoundCompositionCTA(
                    title: display.wordIndex + 1 >= display.totalWords
                        ? String(localized: "soundComposition.cta.finish", defaultValue: "Завершить")
                        : String(localized: "soundComposition.cta.next", defaultValue: "Дальше"),
                    icon: "arrow.right"
                ) {
                    container.soundService.playUISound(.tap)
                    container.hapticService.selection()
                    Task { await interactor?.advanceWord() }
                }
            }
            .padding(.horizontal, SoundCompositionMetrics.contentPadding)
            .padding(.top, SpacingTokens.tiny)
            .padding(.bottom, SpacingTokens.regular)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaPadding(.bottom, SpacingTokens.small)
        .onAppear {
            if !reduceMotion { celebrate = true }
            container.hapticService.notification(.success)
        }
    }

    private var winBanner: some View {
        VStack(spacing: SpacingTokens.small) {
            HSContentSymbol(display.imageAsset, size: 40)
                .frame(width: 60, height: 60)
                .background(RoundedRectangle(cornerRadius: RadiusTokens.md).fill(ColorTokens.Brand.butter.opacity(0.35)))
                .accessibilityHidden(true)
            Text(display.synthesisTitle)
                .font(TypographyTokens.title(22).weight(.black))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
            Text(display.synthesisSummary)
                .font(TypographyTokens.body(13).weight(.semibold))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(SpacingTokens.large)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .fill(LinearGradient(
                    colors: [ColorTokens.Brand.primaryLo.opacity(0.55), ColorTokens.Kid.surface],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
        )
    }

    private var synthesisHouseCard: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            Button { interactor?.playSynthesis() } label: {
                HStack(spacing: SpacingTokens.tiny) {
                    Image(systemName: "play.circle.fill")
                        .font(TypographyTokens.headline(20))
                        .foregroundStyle(ColorTokens.Brand.primary)
                    Text(String(localized: "soundComposition.synth.play",
                                defaultValue: "Послушай, как звуки сливаются в слово"))
                        .font(TypographyTokens.headline(14).weight(.bold))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: 0)
                }
            }
            .accessibilityLabel(String(
                localized: "soundComposition.synth.play.a11y",
                defaultValue: "Прослушать слияние звуков в слово"
            ))

            soundHouse(activeIndex: nil, showQuestionMarks: false)
            legend
        }
        .padding(SpacingTokens.regular)
        .background(RoundedRectangle(cornerRadius: RadiusTokens.lg).fill(ColorTokens.Kid.surface))
        .overlay(RoundedRectangle(cornerRadius: RadiusTokens.lg).strokeBorder(ColorTokens.Kid.line, lineWidth: 1))
    }

    private var legend: some View {
        HStack(spacing: SpacingTokens.small) {
            ForEach(SoundType.allCases, id: \.self) { type in
                HStack(spacing: SpacingTokens.tiny) {
                    Circle().fill(type.chipColor).frame(width: 13, height: 13)
                    Text(type.displayName.lowercased())
                        .font(TypographyTokens.body(11).weight(.bold))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                }
                .padding(.horizontal, SpacingTokens.small)
                .padding(.vertical, 5)
                .background(Capsule().fill(ColorTokens.Kid.surfaceAlt))
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(
            localized: "soundComposition.legend.a11y",
            defaultValue: "Легенда: красный — гласный, синий — твёрдый, зелёный — мягкий"
        ))
    }

    private func bonusCard(_ bonus: SoundCompositionModels.BonusViewModel) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            HStack(spacing: SpacingTokens.tiny) {
                Image(systemName: "wand.and.stars")
                    .font(TypographyTokens.body(13).weight(.bold))
                Text(String(localized: "soundComposition.bonus.tag", defaultValue: "Цепочка слов"))
                    .font(TypographyTokens.body(12).weight(.bold))
            }
            .foregroundStyle(ColorTokens.Brand.lilac)
            .padding(.horizontal, SpacingTokens.small)
            .padding(.vertical, 5)
            .background(Capsule().fill(ColorTokens.Brand.lilac.opacity(0.16)))

            Text(bonus.prompt)
                .font(TypographyTokens.headline(16).weight(.bold))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SpacingTokens.small) {
                    WordPill(text: bonus.baseText, asset: bonus.baseAsset,
                             firstLetter: bonus.firstLetter, isSelected: false,
                             firstLetterColor: ColorTokens.Kid.inkMuted) {}
                        .disabled(true)
                    ForEach(bonus.variants) { variant in
                        Image(systemName: "arrow.right")
                            .font(TypographyTokens.body(14).weight(.bold))
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                        WordPill(
                            text: variant.text, asset: variant.asset,
                            firstLetter: variant.firstLetter,
                            isSelected: display.bonusSelectedIndex == variant.id,
                            firstLetterColor: ColorTokens.Brand.primary
                        ) {
                            container.soundService.playUISound(.tap)
                            interactor?.chooseBonus(.init(variantIndex: variant.id))
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            if !display.bonusFeedback.isEmpty {
                Text(display.bonusFeedback)
                    .font(TypographyTokens.body(13).weight(.semibold))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
            }
        }
        .padding(SpacingTokens.regular)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: RadiusTokens.lg).fill(ColorTokens.Kid.surface))
        .overlay(RoundedRectangle(cornerRadius: RadiusTokens.lg).strokeBorder(ColorTokens.Kid.line, lineWidth: 1))
    }

    // MARK: - Completed

    private var completedView: some View {
        VStack(spacing: SpacingTokens.large) {
            Spacer()
            starsRow
            Text(display.scoreLabel)
                .font(TypographyTokens.title(28))
                .foregroundStyle(ColorTokens.Kid.ink)
                .monospacedDigit()
            Text(display.completionMessage)
                .font(TypographyTokens.body(17))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, SpacingTokens.xLarge)
            Spacer()
        }
        .padding(.horizontal, SoundCompositionMetrics.contentPadding)
        .padding(.bottom, SpacingTokens.sp16)
        .safeAreaInset(edge: .bottom) {
            SoundCompositionCTA(
                title: String(localized: "soundComposition.cta.done", defaultValue: "Готово"),
                icon: "checkmark.circle.fill"
            ) {
                finalize()
            }
            .padding(.horizontal, SoundCompositionMetrics.contentPadding)
            .padding(.bottom, SpacingTokens.small)
            .accessibilityIdentifier("gameNextButton")
        }
        .onAppear {
            if !reduceMotion { celebrate = true }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "soundComposition.completed.a11y", defaultValue: "Игра завершена"))
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
            format: String(localized: "soundComposition.stars.a11y %lld", defaultValue: "Получено звёзд: %lld из 3"),
            display.starsEarned
        ))
    }

    // MARK: - Mascot row

    private func mascotRow(text: String, state: LyalyaState) -> some View {
        HStack(alignment: .bottom, spacing: SpacingTokens.small) {
            LyalyaMascotView(state: reduceMotion ? .idle : state, size: 64)
                .accessibilityHidden(true)
            HSSpeechBubble(text, direction: .left, style: .lyalya, maxWidth: 240)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Actions

    private func handlePick(_ type: SoundType) {
        container.soundService.playUISound(.tap)
        container.hapticService.selection()
        interactor?.placeChip(.init(chosenType: type))
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(140))
            if display.feedbackCorrect || display.activeSoundIndex == nil {
                container.soundService.playUISound(.correct)
                container.hapticService.notification(.success)
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
    private func bootstrap() async {
        guard !bootstrapped else { return }
        bootstrapped = true

        let age = await resolveChildAge()
        let presenter = SoundCompositionPresenter()
        let interactor = SoundCompositionInteractor(
            childId: childId,
            childAge: age,
            builder: SoundCompositionBuilder(),
            adaptivePlanner: container.adaptivePlannerService
        )
        let router = SoundCompositionRouter()

        interactor.presenter = presenter
        presenter.display = display

        self.presenter = presenter
        self.interactor = interactor
        self.router = router

        logger.info("bootstrap child=\(childId, privacy: .private) age=\(age, privacy: .private)")
        await interactor.start(.init(childId: childId))
    }

    private func resolveChildAge() async -> Int {
        do {
            let profile = try await container.childRepository.fetch(id: childId)
            return profile.age
        } catch {
            return 6
        }
    }
}

// MARK: - Metrics

private enum SoundCompositionMetrics {
    /// Симметричный контентный отступ (open-design: 22pt).
    static let contentPadding: CGFloat = 22
}

// MARK: - SoundCell

/// Клетка-«домик» с треугольной крышей. Активная — коралловый ободок.
private struct SoundCell: View {
    let index: Int
    let chip: PlacedChip?
    let isActive: Bool
    let showQuestionMark: Bool
    let reduceMotion: Bool

    var body: some View {
        VStack(spacing: 0) {
            Triangle()
                .fill(isActive ? ColorTokens.Brand.primary : ColorTokens.Kid.line)
                .frame(width: 34, height: 13)
            ZStack {
                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                    .strokeBorder(
                        isActive ? ColorTokens.Brand.primary : ColorTokens.Kid.line,
                        style: StrokeStyle(lineWidth: isActive ? 2.5 : 2,
                                           dash: chip == nil && !isActive ? [5, 4] : [])
                    )
                content
                VStack {
                    Spacer()
                    Text("\(index + 1)")
                        .font(TypographyTokens.body(10).weight(.bold))
                        .foregroundStyle(ColorTokens.Kid.inkSoft)
                        .padding(.bottom, 4)
                }
            }
            .aspectRatio(0.86, contentMode: .fit)
        }
        .frame(maxWidth: 66)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cellA11y)
    }

    @ViewBuilder
    private var content: some View {
        if let chip {
            ChipBadge(letter: chip.letter, type: chip.type, size: 40)
                .transition(reduceMotion ? .identity : .scale.combined(with: .opacity))
        } else if isActive {
            Text("?")
                .font(TypographyTokens.title(26).weight(.black))
                .foregroundStyle(ColorTokens.Brand.primary)
        } else if showQuestionMark {
            Text("?")
                .font(TypographyTokens.title(26).weight(.black))
                .foregroundStyle(ColorTokens.Kid.inkSoft)
        } else {
            Text("·")
                .font(TypographyTokens.title(22).weight(.black))
                .foregroundStyle(ColorTokens.Kid.inkSoft)
        }
    }

    private var cellA11y: String {
        if let chip {
            return String(
                format: String(localized: "soundComposition.cell.filled %lld %@",
                               defaultValue: "Клетка %lld: звук %@"),
                index + 1, chip.letter
            )
        }
        if isActive {
            return String(
                format: String(localized: "soundComposition.cell.active %lld",
                               defaultValue: "Клетка %lld: активная, выбери фишку"),
                index + 1
            )
        }
        return String(
            format: String(localized: "soundComposition.cell.empty %lld", defaultValue: "Клетка %lld: пустая"),
            index + 1
        )
    }
}

// MARK: - Triangle (roof)

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - ChipBadge

/// Круглая эльконинская фишка с буквой. Цвет — ТОЛЬКО на фишке.
private struct ChipBadge: View {
    let letter: String
    let type: SoundType
    let size: CGFloat

    var body: some View {
        Text(letter)
            .font(.system(size: size * 0.42, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(type.chipColor))
            .overlay(Circle().strokeBorder(.white.opacity(0.55), lineWidth: 2))
            .shadow(color: type.chipColor.opacity(0.35), radius: 4, y: 2)
            .accessibilityHidden(true)
    }
}

// MARK: - ChipPickButton (palette)

private struct ChipPickButton: View {
    let type: SoundType
    let reduceMotion: Bool
    let onTap: () -> Void

    @State private var pressed = false

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: SpacingTokens.tiny) {
                Circle()
                    .fill(type.chipColor)
                    .frame(width: 34, height: 34)
                    .overlay(Circle().strokeBorder(.white.opacity(0.55), lineWidth: 2))
                Text(type.displayName)
                    .font(TypographyTokens.headline(13).weight(.bold))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(type.example)
                    .font(TypographyTokens.body(10).weight(.semibold))
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.small)
            .background(RoundedRectangle(cornerRadius: RadiusTokens.lg).fill(ColorTokens.Kid.surface))
            .overlay(RoundedRectangle(cornerRadius: RadiusTokens.lg).strokeBorder(ColorTokens.Kid.line, lineWidth: 2))
            .scaleEffect(pressed && !reduceMotion ? 0.96 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(type.displayName)
        .accessibilityHint(String(localized: "soundComposition.pick.hint", defaultValue: "Поставить фишку этого цвета"))
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
    }
}

// MARK: - WordPill (bonus chain)

private struct WordPill: View {
    let text: String
    let asset: String
    let firstLetter: String
    let isSelected: Bool
    let firstLetterColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: SpacingTokens.tiny) {
                Text(coloredWord)
                    .font(TypographyTokens.headline(18).weight(.black))
                HSContentSymbol(asset, size: 18)
                    .frame(width: 26, height: 26)
            }
            .padding(.horizontal, SpacingTokens.small)
            .padding(.vertical, SpacingTokens.small)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.md)
                    .fill(isSelected ? ColorTokens.Brand.primaryLo.opacity(0.35) : ColorTokens.Kid.surfaceAlt)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.md)
                    .strokeBorder(isSelected ? ColorTokens.Brand.primary : ColorTokens.Kid.line, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(text)
    }

    private var coloredWord: AttributedString {
        var attr = AttributedString(text)
        attr.foregroundColor = ColorTokens.Kid.ink
        if let first = attr.characters.first {
            let range = attr.range(of: String(first))
            if let range { attr[range].foregroundColor = firstLetterColor }
        }
        return attr
    }
}

// MARK: - CTA

private struct SoundCompositionCTA: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SpacingTokens.small) {
                Text(title)
                    .font(TypographyTokens.cta())
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                Image(systemName: icon)
                    .font(TypographyTokens.headline(18).weight(.bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .fill(LinearGradient(
                        colors: [ColorTokens.Brand.primaryHi, ColorTokens.Brand.primary],
                        startPoint: .top, endPoint: .bottom
                    ))
            )
            .shadow(color: ColorTokens.Brand.primary.opacity(0.4), radius: 14, y: 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("SoundComposition") {
    SoundCompositionView(childId: "preview-child")
        .environment(AppContainer.preview())
}
