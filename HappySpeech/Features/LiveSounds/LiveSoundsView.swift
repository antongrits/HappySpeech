import OSLog
import SwiftUI

// MARK: - LiveSoundsView
//
// «Живые звуки» — устный фонематический синтез (kid). Два режима внутри сессии:
//   • collect (экран 1, kid-game-live-sounds-1.html) — Ляля произносит слово ПО
//     ЗВУКАМ с управляемой паузой; кружочки-звуки (SoundBeadRow) подпрыгивают по
//     очереди, между ними pause-dots. Скорость пауз переключается (SpeedSegment).
//     Ребёнок сливает звуки и выбирает картинку из 4 (PictureGrid 2×2). На верный
//     ответ кружочки сдвигаются вплотную и появляется слитное слово — синтез.
//   • bench (экран 2, kid-game-live-sounds-2.html) — звуки-человечки
//     (SoundCharacterRow: голова + ножки, hop) встают в ряд; ребёнок выбирает их
//     со «скамейки» (SoundBench) по порядку звучания. Полный ряд → слияние в слово.
//
// БЕЗ ASR — рецептивно-выборочный ответ, стабильно офлайн. Гласный — rose,
// согласный — lilac (тёплые токены). Тёплый cream-фон, Reduced Motion уважается.
//
// Архитектура: Clean Swift VIP. interactor/presenter/router/display создаются
// один раз в bootstrap() и удерживаются как @State.

struct LiveSoundsView: View {

    // MARK: - Input

    let childId: String

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - VIP

    @State private var display = LiveSoundsDisplay()
    @State private var interactor: LiveSoundsInteractor?
    @State private var presenter: LiveSoundsPresenter?
    @State private var router: LiveSoundsRouter?
    @State private var bootstrapped = false
    @State private var celebrate = false

    private let logger = Logger(subsystem: "ru.happyspeech", category: "LiveSoundsView")

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
            localized: "liveSounds.screen.a11y",
            defaultValue: "Живые звуки: слушай звуки и собери слово"
        ))
    }

    // MARK: - Content switch

    @ViewBuilder
    private var content: some View {
        switch display.phase {
        case .loading:
            loadingView
        case .collect:
            collectView
        case .bench:
            benchView
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

            Button { interactor?.playSoundsSequence() } label: {
                Image(systemName: "arrow.clockwise")
                    .font(TypographyTokens.headline(16).weight(.semibold))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(ColorTokens.Kid.surfaceAlt))
            }
            .accessibilityLabel(String(localized: "liveSounds.replay.a11y", defaultValue: "Повторить звуки"))
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
                        .frame(width: max(8, geo.size.width * progressFraction))
                }
            }
            .frame(height: 9)
            Text(progressLabel)
                .font(TypographyTokens.body(12).weight(.bold))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(progressLabel)
    }

    private var progressFraction: CGFloat {
        let total = max(display.totalRounds, 1)
        return CGFloat(display.roundIndex + 1) / CGFloat(total)
    }

    private var progressLabel: String {
        String(
            format: String(localized: "liveSounds.progress %lld %lld %lld",
                           defaultValue: "Слово %lld из %lld · %lld звука"),
            display.roundIndex + 1, display.totalRounds, display.sounds.count
        )
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: SpacingTokens.medium) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(ColorTokens.Brand.primary)
                .scaleEffect(1.4)
            Text(String(localized: "liveSounds.loading", defaultValue: "Оживляем звуки…"))
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Collect (экран 1)

    private var collectView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SpacingTokens.regular) {
                topBar(
                    title: display.solved
                        ? String(localized: "liveSounds.collect.titleDone", defaultValue: "Получилось слово!")
                        : String(localized: "liveSounds.collect.title", defaultValue: "Какое слово спрятано?"),
                    subtitle: display.solved
                        ? String(localized: "liveSounds.collect.subDone", defaultValue: "Звуки слились вместе")
                        : String(localized: "liveSounds.collect.sub", defaultValue: "Слушай звуки и собери слово")
                )
                progressBar
                heroCard
                speedControl
                pictureGrid
                mascotRow(text: collectMascotText, state: display.solved ? .celebrating : .explaining)
                if display.solved {
                    nextCTA
                }
            }
            .padding(.horizontal, LiveSoundsMetrics.contentPadding)
            .padding(.top, SpacingTokens.tiny)
            .padding(.bottom, SpacingTokens.regular)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaPadding(.bottom, SpacingTokens.small)
    }

    private var heroCard: some View {
        VStack(spacing: SpacingTokens.small) {
            Text(display.solved
                 ? String(localized: "liveSounds.hero.merged", defaultValue: "ЗВУКИ СЛИЛИСЬ В СЛОВО")
                 : String(localized: "liveSounds.hero.speaking", defaultValue: "ЛЯЛЯ ГОВОРИТ ПО ЗВУКАМ"))
                .font(TypographyTokens.body(12).weight(.bold))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .tracking(1)

            LyalyaMascotView(state: reduceMotion ? .idle : (display.isPlaying ? .explaining : .idle), size: 88)
                .accessibilityHidden(true)

            SoundBeadRow(
                sounds: display.sounds,
                nowIndex: display.isPlaying ? display.nowSoundIndex : nil,
                merged: display.solved,
                reduceMotion: reduceMotion
            )

            if display.solved {
                Text(display.word)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .tracking(2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .transition(reduceMotion ? .identity : .scale.combined(with: .opacity))
            } else {
                replayButton
            }
        }
        .frame(maxWidth: .infinity)
        .padding(SpacingTokens.regular)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .fill(LinearGradient(
                    colors: [ColorTokens.Brand.primaryLo.opacity(0.22), ColorTokens.Kid.surface],
                    startPoint: .top, endPoint: .bottom
                ))
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
        )
        .shadow(color: ColorTokens.Overlay.shadow.opacity(0.5), radius: 14, y: 8)
        .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.7), value: display.solved)
    }

    private var replayButton: some View {
        Button { interactor?.playSoundsSequence() } label: {
            HStack(spacing: SpacingTokens.tiny) {
                Image(systemName: display.isPlaying ? "waveform" : "play.circle.fill")
                    .font(TypographyTokens.headline(16).weight(.semibold))
                    .symbolEffect(.variableColor, isActive: display.isPlaying && !reduceMotion)
                Text(String(localized: "liveSounds.replay", defaultValue: "Послушать ещё раз"))
                    .font(TypographyTokens.headline(14).weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(ColorTokens.Brand.primary)
            .padding(.horizontal, SpacingTokens.regular)
            .padding(.vertical, SpacingTokens.small)
            .background(Capsule().fill(ColorTokens.Brand.primaryLo.opacity(0.35)))
            .overlay(Capsule().strokeBorder(ColorTokens.Brand.primary.opacity(0.28), lineWidth: 1.5))
        }
        .accessibilityLabel(String(localized: "liveSounds.replay.a11y", defaultValue: "Повторить звуки"))
    }

    private var speedControl: some View {
        HStack(spacing: SpacingTokens.small) {
            Text(String(localized: "liveSounds.speed.label", defaultValue: "Паузы:"))
                .font(TypographyTokens.body(12).weight(.bold))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
            SpeedSegment(selected: display.pace) { pace in
                container.soundService.playUISound(.tap)
                container.hapticService.selection()
                interactor?.setPace(.init(pace: pace))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var pictureGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: SpacingTokens.small),
            GridItem(.flexible(), spacing: SpacingTokens.small)
        ]
        return LazyVGrid(columns: columns, spacing: SpacingTokens.small) {
            ForEach(display.options) { option in
                PictureOptionCard(
                    option: option,
                    isSelected: display.selectedOptionIndex == option.id,
                    isCorrectHighlight: display.correctOptionIndex == option.id,
                    dimmed: display.solved && display.correctOptionIndex != option.id,
                    disabled: display.solved
                ) {
                    handlePick(option.id)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "liveSounds.grid.a11y", defaultValue: "Картинки-ответы"))
    }

    private var collectMascotText: String {
        if display.solved {
            return String(
                format: String(localized: "liveSounds.mascot.collectDone %@",
                               defaultValue: "Точно — %@! Ты слепил звуки в одно слово. Молодец!"),
                display.word
            )
        }
        if display.showFeedback, !display.feedbackText.isEmpty {
            return display.feedbackText
        }
        return String(
            format: String(localized: "liveSounds.mascot.collect %@",
                           defaultValue: "Слушай: %@. Слей звуки вместе — какое слово получилось?"),
            spacedLetters
        )
    }

    /// «К… О… Т» — буквы слова через многоточие (для подсказки маскота).
    private var spacedLetters: String {
        display.sounds.map { $0.letter }.joined(separator: "… ")
    }

    // MARK: - Bench (экран 2)

    private var benchView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SpacingTokens.regular) {
                topBar(
                    title: display.rowComplete
                        ? String(localized: "liveSounds.bench.titleDone", defaultValue: "Человечки подружились!")
                        : String(localized: "liveSounds.bench.title", defaultValue: "Звуки-человечки"),
                    subtitle: display.rowComplete
                        ? String(localized: "liveSounds.bench.subDone", defaultValue: "Взялись за руки — вышло слово")
                        : String(localized: "liveSounds.bench.sub", defaultValue: "Поставь их по порядку звучания")
                )
                progressBar
                floorCard
                if !display.rowComplete {
                    benchPickTitle
                    benchPicker
                } else {
                    benchAllPlacedTag
                }
                mascotRow(text: benchMascotText, state: display.rowComplete ? .celebrating : .explaining)
                if display.rowComplete {
                    nextCTA
                }
            }
            .padding(.horizontal, LiveSoundsMetrics.contentPadding)
            .padding(.top, SpacingTokens.tiny)
            .padding(.bottom, SpacingTokens.regular)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaPadding(.bottom, SpacingTokens.small)
    }

    private var floorCard: some View {
        VStack(spacing: SpacingTokens.regular) {
            Text(display.rowComplete
                 ? String(localized: "liveSounds.floor.merged", defaultValue: "ЗВУКИ СЛИЛИСЬ В СЛОВО")
                 : String(localized: "liveSounds.floor.lbl", defaultValue: "ПОСТАВЬ ЧЕЛОВЕЧКОВ В РЯД"))
                .font(TypographyTokens.body(12).weight(.bold))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .tracking(1)

            SoundCharacterRow(
                sounds: display.sounds,
                placedCount: display.placedLetters.count,
                activeSlot: display.activeSlotIndex,
                merged: display.rowComplete,
                nowIndex: display.isPlaying ? display.nowSoundIndex : nil,
                reduceMotion: reduceMotion
            )

            if display.rowComplete {
                VStack(spacing: SpacingTokens.tiny) {
                    Text(display.word)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .tracking(2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    HSContentSymbol(display.imageAsset, size: 34)
                        .frame(width: 52, height: 52)
                        .accessibilityHidden(true)
                }
                .transition(reduceMotion ? .identity : .scale.combined(with: .opacity))
            } else {
                replayButton
            }
        }
        .frame(maxWidth: .infinity)
        .padding(SpacingTokens.regular)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .fill(LinearGradient(
                    colors: [ColorTokens.Brand.primaryLo.opacity(0.18), ColorTokens.Kid.surfaceAlt],
                    startPoint: .top, endPoint: .bottom
                ))
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
        )
        .shadow(color: ColorTokens.Overlay.shadow.opacity(0.5), radius: 14, y: 8)
        .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.7), value: display.rowComplete)
    }

    private var benchPickTitle: some View {
        Text(String(
            format: String(localized: "liveSounds.bench.pickTitle %lld",
                           defaultValue: "Какого человечка поставить %lld-м?"),
            (display.activeSlotIndex ?? 0) + 1
        ))
        .font(TypographyTokens.headline(15).weight(.bold))
        .foregroundStyle(ColorTokens.Kid.ink)
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .minimumScaleFactor(0.85)
        .frame(maxWidth: .infinity)
    }

    private var benchPicker: some View {
        HStack(spacing: SpacingTokens.small) {
            ForEach(Array(display.benchLetters.enumerated()), id: \.offset) { idx, unit in
                BenchCharacter(
                    unit: unit,
                    used: display.usedBenchIndices.contains(idx),
                    reduceMotion: reduceMotion
                ) {
                    handlePlaceCharacter(idx)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "liveSounds.bench.picker.a11y", defaultValue: "Скамейка человечков-звуков"))
    }

    private var benchAllPlacedTag: some View {
        Text(String(localized: "liveSounds.bench.rowDone", defaultValue: "Все человечки на месте — ряд собран!"))
            .font(TypographyTokens.headline(14).weight(.bold))
            .foregroundStyle(ColorTokens.Brand.mint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.small)
    }

    private var benchMascotText: String {
        if display.rowComplete {
            return String(
                format: String(localized: "liveSounds.mascot.benchDone %@",
                               defaultValue: "Человечки взялись за ручки — получилось %@! Здорово слепил!"),
                display.word
            )
        }
        if display.showFeedback, !display.feedbackText.isEmpty {
            return display.feedbackText
        }
        if display.placedLetters.isEmpty {
            return String(localized: "liveSounds.mascot.benchStart",
                          defaultValue: "Послушай слово по звукам — кто стоит первым?")
        }
        return String(
            format: String(localized: "liveSounds.mascot.bench %@",
                           defaultValue: "Уже стоят %@. Послушай слово до конца — кто следующий?"),
            display.placedLetters.joined(separator: ", ")
        )
    }

    // MARK: - Next CTA

    private var nextCTA: some View {
        LiveSoundsCTA(
            title: display.roundIndex + 1 >= display.totalRounds
                ? String(localized: "liveSounds.cta.finish", defaultValue: "Завершить")
                : String(localized: "liveSounds.cta.next", defaultValue: "Дальше"),
            icon: "arrow.right"
        ) {
            container.soundService.playUISound(.tap)
            container.hapticService.selection()
            Task { await interactor?.advanceRound() }
        }
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
        .padding(.horizontal, LiveSoundsMetrics.contentPadding)
        .padding(.bottom, SpacingTokens.sp16)
        .safeAreaInset(edge: .bottom) {
            LiveSoundsCTA(
                title: String(localized: "liveSounds.cta.done", defaultValue: "Готово"),
                icon: "checkmark.circle.fill"
            ) {
                finalize()
            }
            .padding(.horizontal, LiveSoundsMetrics.contentPadding)
            .padding(.bottom, SpacingTokens.small)
            .accessibilityIdentifier("gameNextButton")
        }
        .onAppear {
            if !reduceMotion { celebrate = true }
            container.hapticService.notification(.success)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "liveSounds.completed.a11y", defaultValue: "Игра завершена"))
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
            format: String(localized: "liveSounds.stars.a11y %lld", defaultValue: "Получено звёзд: %lld из 3"),
            display.starsEarned
        ))
    }

    // MARK: - Mascot row

    private func mascotRow(text: String, state: LyalyaState) -> some View {
        HStack(alignment: .bottom, spacing: SpacingTokens.small) {
            LyalyaMascotView(state: reduceMotion ? .idle : state, size: 56)
                .accessibilityHidden(true)
            HSSpeechBubble(text, direction: .left, style: .lyalya, maxWidth: 240)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Actions

    private func handlePick(_ optionId: Int) {
        guard !display.solved else { return }
        container.soundService.playUISound(.tap)
        container.hapticService.selection()
        interactor?.choosePicture(.init(optionIndex: optionId))
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            if display.solved {
                container.soundService.playUISound(.correct)
                container.hapticService.notification(.success)
                if !reduceMotion { celebrate = true }
            } else {
                container.soundService.playUISound(.incorrect)
                container.hapticService.notification(.warning)
            }
        }
    }

    private func handlePlaceCharacter(_ benchIndex: Int) {
        guard !display.rowComplete else { return }
        container.soundService.playUISound(.tap)
        container.hapticService.selection()
        interactor?.placeCharacter(.init(benchIndex: benchIndex))
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            if display.feedbackCorrect {
                container.soundService.playUISound(.correct)
                container.hapticService.notification(.success)
                if display.rowComplete, !reduceMotion { celebrate = true }
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
        let presenter = LiveSoundsPresenter()
        let interactor = LiveSoundsInteractor(
            childId: childId,
            childAge: age,
            builder: LiveSoundsBuilder(),
            adaptivePlanner: container.adaptivePlannerService,
            sessionPersistence: container.sessionPersistenceCoordinator
        )
        let router = LiveSoundsRouter()

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

private enum LiveSoundsMetrics {
    /// Симметричный контентный отступ (open-design: 22pt).
    static let contentPadding: CGFloat = 22
}

// MARK: - SoundBeadRow (кружочки-звуки)

/// Ряд кружочков-звуков 54pt: гласный rose, согласный lilac. Между ними
/// pause-dots. Текущий `.now` подпрыгивает. На `merged` — gap→0, без точек.
private struct SoundBeadRow: View {
    let sounds: [LiveSoundUnit]
    let nowIndex: Int?
    let merged: Bool
    let reduceMotion: Bool

    var body: some View {
        HStack(spacing: merged ? 2 : 10) {
            ForEach(Array(sounds.enumerated()), id: \.offset) { idx, unit in
                bead(unit, index: idx)
                if !merged, idx < sounds.count - 1 {
                    Circle()
                        .fill(ColorTokens.Kid.inkSoft.opacity(0.5))
                        .frame(width: 6, height: 6)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(beadA11y)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.7), value: merged)
    }

    private func bead(_ unit: LiveSoundUnit, index: Int) -> some View {
        let isNow = nowIndex == index
        return Text(unit.letter)
            .font(.system(size: 26, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 54, height: 54)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(unit.type.beadColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.45), lineWidth: 3)
            )
            .shadow(color: unit.type.beadColor.opacity(0.35), radius: isNow ? 8 : 4, y: isNow ? 4 : 2)
            .scaleEffect(isNow && !reduceMotion ? 1.1 : 1)
            .offset(y: isNow && !reduceMotion ? -6 : 0)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.55), value: isNow)
    }

    private var beadA11y: String {
        sounds.map { $0.letter }.joined(separator: ", ")
    }
}

// MARK: - SpeedSegment (3-сегмент управление паузами)

private struct SpeedSegment: View {
    let selected: LiveSoundsPace
    let onSelect: (LiveSoundsPace) -> Void

    var body: some View {
        HStack(spacing: 5) {
            ForEach(LiveSoundsPace.allCases, id: \.self) { pace in
                let isOn = pace == selected
                Button { onSelect(pace) } label: {
                    Text(pace.displayName)
                        .font(TypographyTokens.headline(13).weight(.bold))
                        .foregroundStyle(isOn ? ColorTokens.Brand.primary : ColorTokens.Kid.inkMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, SpacingTokens.small)
                        .padding(.vertical, SpacingTokens.tiny)
                        .background(
                            RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                                .fill(isOn ? ColorTokens.Kid.surface : .clear)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(pace.displayName)
                .accessibilityAddTraits(isOn ? [.isSelected] : [])
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                .fill(ColorTokens.Kid.surfaceAlt)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "liveSounds.speed.a11y", defaultValue: "Скорость пауз между звуками"))
    }
}

// MARK: - PictureOptionCard (2×2)

private struct PictureOptionCard: View {
    let option: PictureOption
    let isSelected: Bool
    let isCorrectHighlight: Bool
    let dimmed: Bool
    let disabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: SpacingTokens.tiny) {
                HSContentSymbol(option.imageAsset, size: 46)
                    .frame(width: 70, height: 70)
                    .accessibilityHidden(true)
                Text(option.word)
                    .font(TypographyTokens.headline(16).weight(.black))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(SpacingTokens.small)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            )
            .shadow(color: ColorTokens.Overlay.shadow.opacity(0.4), radius: 8, y: 4)
            .opacity(dimmed ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(option.word)
        .accessibilityAddTraits(isCorrectHighlight ? [.isSelected] : [])
    }

    private var borderColor: Color {
        if isCorrectHighlight { return ColorTokens.Brand.primary }
        if isSelected { return ColorTokens.Brand.primary }
        return ColorTokens.Kid.line
    }

    private var borderWidth: CGFloat {
        (isCorrectHighlight || isSelected) ? 3 : 2
    }
}

// MARK: - SoundCharacterRow (человечки в ряду)

/// Ряд звуков-человечков (голова + ножки). Уже поставленные — цветные; активное
/// место — пунктирный «?»; будущие — пустые. На `merged` — придвинуты вплотную.
private struct SoundCharacterRow: View {
    let sounds: [LiveSoundUnit]
    let placedCount: Int
    let activeSlot: Int?
    let merged: Bool
    let nowIndex: Int?
    let reduceMotion: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: merged ? 0 : 14) {
            ForEach(Array(sounds.enumerated()), id: \.offset) { idx, unit in
                character(unit, index: idx)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 96)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rowA11y)
        .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.7), value: merged)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.7), value: placedCount)
    }

    @ViewBuilder
    private func character(_ unit: LiveSoundUnit, index: Int) -> some View {
        let placed = merged || index < placedCount
        let isActive = !merged && index == activeSlot
        let isNow = merged && nowIndex == index
        VStack(spacing: 7) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(placed ? unit.type.beadColor : ColorTokens.Kid.surface)
                if placed {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.white.opacity(0.45), lineWidth: 3)
                    Text(unit.letter)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    // глазки
                    HStack(spacing: 18) {
                        Circle().fill(.white).frame(width: 7, height: 7)
                        Circle().fill(.white).frame(width: 7, height: 7)
                    }
                    .offset(y: -12)
                } else {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            isActive ? ColorTokens.Brand.primary : ColorTokens.Kid.line,
                            style: StrokeStyle(lineWidth: isActive ? 2.5 : 2, dash: [5, 4])
                        )
                    Text("?")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(isActive ? ColorTokens.Brand.primary : ColorTokens.Kid.inkSoft)
                }
            }
            .frame(width: 60, height: 60)
            // ножки
            HStack(spacing: 8) {
                ForEach(0..<2, id: \.self) { _ in
                    Capsule()
                        .fill(placed ? unit.type.beadColor : ColorTokens.Kid.line.opacity(0.001))
                        .frame(width: 6, height: 16)
                }
            }
            .opacity(placed ? 1 : 0)
        }
        .scaleEffect(isNow && !reduceMotion ? 1.06 : 1)
        .offset(y: isNow && !reduceMotion ? -8 : 0)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.55), value: isNow)
    }

    private var rowA11y: String {
        let placed = sounds.prefix(merged ? sounds.count : placedCount).map { $0.letter }
        if placed.isEmpty {
            return String(localized: "liveSounds.row.empty.a11y", defaultValue: "Ряд пуст")
        }
        return placed.joined(separator: ", ")
    }
}

// MARK: - BenchCharacter (человечек на скамейке)

private struct BenchCharacter: View {
    let unit: LiveSoundUnit
    let used: Bool
    let reduceMotion: Bool
    let onTap: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(unit.type.beadColor)
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.white.opacity(0.45), lineWidth: 3)
                    Text(unit.letter)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
                .frame(width: 62, height: 62)
                // «ручка-хваталка»
                Capsule()
                    .fill(.white.opacity(0.6))
                    .frame(width: 26, height: 6)
            }
            .opacity(used ? 0.35 : 1)
            .scaleEffect(pressed && !reduceMotion ? 0.94 : 1)
        }
        .buttonStyle(.plain)
        .disabled(used)
        .accessibilityLabel(unit.letter)
        .accessibilityHint(String(localized: "liveSounds.bench.pick.hint", defaultValue: "Поставить этого человечка в ряд"))
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
    }
}

// MARK: - CTA

private struct LiveSoundsCTA: View {
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
            .frame(maxWidth: .infinity, minHeight: 58)
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
