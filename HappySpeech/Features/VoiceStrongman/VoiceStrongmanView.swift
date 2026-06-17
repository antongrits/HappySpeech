import OSLog
import SwiftUI

// MARK: - VoiceStrongmanView
//
// «Силач-голос» — kid-модуль силы и высоты голоса (фонопедия) в двух режимах:
//   1. Громко-тихо — TargetLevelRow (мышка/котик/мишка) + VoiceBalloonMeter
//      (звуковой шар растёт от RMS) + золотая зона-полоса «удобная громкость»
//      (антикрик) + живые RMS-тики.
//   2. Лесенка голоса — DirectionRow (вверх/вниз) + PitchLadder (5 ступеней,
//      lit при достижении) + глиссандо-дорожка (lilac) + климбер-цыплёнок,
//      поднимающийся от высоты тона (reuse YINPitchTracker).
//
// Open-design: kid-game-voice-strongman-1/2.html (структура/отступы перенесены).
// Тёплая палитра; gold/lilac/mint акценты — ТОЛЬКО мелкие семантические
// (зона-полоса, дорожка, success-кольцо) — НИКОГДА на фонах. Reduced Motion
// уважается во всех анимациях. CTA: min-height 58, lineLimit(nil) + minScale.
//
// Архитектура: Clean Swift VIP. interactor/presenter/router/display создаются
// один раз в bootstrap() и удерживаются как @State.

struct VoiceStrongmanView: View {

    // MARK: - Input

    let childId: String

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - VIP

    @State private var display = VoiceStrongmanDisplay()
    @State private var interactor: VoiceStrongmanInteractor?
    @State private var presenter: VoiceStrongmanPresenter?
    @State private var router: VoiceStrongmanRouter?
    @State private var bootstrapped = false
    @State private var celebrate = false

    private let logger = Logger(subsystem: "ru.happyspeech", category: "VoiceStrongmanView")

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
        .onChange(of: display.phase) { _, phase in
            if phase == .completed, !reduceMotion { celebrate = true }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(
            localized: "voiceStrongman.screen.a11y",
            defaultValue: "Силач-голос: сила и высота голоса"
        ))
    }

    // MARK: - Content switch

    @ViewBuilder
    private var content: some View {
        switch display.phase {
        case .loading:   loadingView
        case .loudness:  loudnessView
        case .pitch:     pitchView
        case .completed: completedView
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
                    .font(TypographyTokens.body(13).weight(.semibold))
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)

            Button { interactor?.playPrompt() } label: {
                Image(systemName: display.isPlaying ? "waveform" : "speaker.wave.2.fill")
                    .font(TypographyTokens.headline(16).weight(.semibold))
                    .symbolEffect(.variableColor, isActive: display.isPlaying && !reduceMotion)
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(ColorTokens.Kid.surfaceAlt))
            }
            .accessibilityLabel(String(localized: "voiceStrongman.playPrompt.a11y",
                                       defaultValue: "Послушать подсказку Ляли"))
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
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(8, geo.size.width * progressFraction))
                }
            }
            .frame(height: 9)
            Text(progressLabel)
                .font(TypographyTokens.caption(12).weight(.bold))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(progressLabel)
    }

    private var progressFraction: CGFloat {
        let total = max(display.totalTasks, 1)
        return CGFloat(display.taskIndex + (display.showResult ? 1 : 0)) / CGFloat(total)
    }

    private var progressLabel: String {
        String(
            format: String(localized: "voiceStrongman.progress %lld %lld",
                           defaultValue: "Упражнение %lld из %lld · сила голоса"),
            display.taskIndex + 1, max(display.totalTasks, 1)
        )
    }

    private func mascotRow(text: String) -> some View {
        HStack(alignment: .bottom, spacing: SpacingTokens.small) {
            LyalyaMascotView(state: reduceMotion ? .idle : display.mascotState, size: 56)
                .accessibilityHidden(true)
            HSSpeechBubble(text, direction: .left, style: .lyalya, maxWidth: 250)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 2)
    }

    /// Баннер «нет доступа к микрофону» — показывается вместо тихого 1★, когда
    /// разрешение на запись не выдано. Тёплый surface + мелкий warning-акцент
    /// (рамка/иконка), без крупной off-theme заливки.
    private var micDeniedBanner: some View {
        HStack(alignment: .top, spacing: SpacingTokens.small) {
            Image(systemName: "mic.slash.fill")
                .font(TypographyTokens.headline(18).weight(.bold))
                .foregroundStyle(ColorTokens.Semantic.warning)
                .accessibilityHidden(true)
            Text(display.micDeniedMessage)
                .font(TypographyTokens.body(14).weight(.semibold))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(SpacingTokens.regular)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                .fill(ColorTokens.Kid.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                .strokeBorder(ColorTokens.Semantic.warning.opacity(0.5), lineWidth: 1.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(display.micDeniedMessage)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: SpacingTokens.medium) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(ColorTokens.Brand.primary)
                .scaleEffect(1.4)
            Text(String(localized: "voiceStrongman.loading", defaultValue: "Готовим силомер…"))
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Mode 1: Loudness (громко-тихо)

    private var loudnessView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SpacingTokens.regular) {
                topBar(title: display.title, subtitle: display.subtitle)
                progressBar
                targetLevelRow
                VoiceBalloonMeter(
                    animal: display.animal,
                    loudness: display.liveLoudness,
                    bandLower: display.bandLower,
                    bandUpper: display.bandUpper,
                    inBand: display.loudnessInBand,
                    showResult: display.showResult,
                    reduceMotion: reduceMotion
                )
                .frame(height: 300)
                mascotRow(text: display.micDenied ? display.micDeniedMessage : display.mascotText)
                if display.micDenied { micDeniedBanner }
                recordCTA(title: recordTitleLoudness, accent: display.loudnessLevel.accent)
            }
            .padding(.horizontal, VoiceStrongmanMetrics.contentPadding)
            .padding(.top, SpacingTokens.tiny)
            .padding(.bottom, SpacingTokens.regular)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaPadding(.bottom, SpacingTokens.small)
    }

    private var targetLevelRow: some View {
        HStack(spacing: SpacingTokens.small) {
            ForEach(LoudnessLevel.allCases, id: \.self) { level in
                TargetLevelCard(
                    level: level,
                    isActive: display.loudnessLevel == level
                ) {
                    container.soundService.playUISound(.tap)
                    container.hapticService.selection()
                    interactor?.selectLevel(.init(level: level))
                }
            }
        }
    }

    private var recordTitleLoudness: String {
        if display.isRecording {
            return String(localized: "voiceStrongman.cta.speaking", defaultValue: "Пою…")
        }
        switch display.loudnessLevel {
        case .quiet:  return String(localized: "voiceStrongman.cta.quiet",
                                    defaultValue: "Держи и пой тихо")
        case .medium: return String(localized: "voiceStrongman.cta.medium",
                                    defaultValue: "Держи и пой ровно")
        case .loud:   return String(localized: "voiceStrongman.cta.loud",
                                    defaultValue: "Держи и пой громко")
        }
    }

    // MARK: - Mode 2: Pitch (лесенка голоса)

    private var pitchView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SpacingTokens.regular) {
                topBar(title: display.title, subtitle: display.subtitle)
                progressBar
                directionRow
                PitchLadder(
                    vowel: display.vowel,
                    steps: display.ladderSteps,
                    reached: display.showResult ? display.ladderReached : display.livePitch,
                    direction: display.pitchDirection,
                    isSuccess: display.showResult && display.resultMatch,
                    reduceMotion: reduceMotion
                )
                .frame(height: 316)
                mascotRow(text: display.micDenied ? display.micDeniedMessage : display.mascotText)
                if display.micDenied { micDeniedBanner }
                recordCTA(title: recordTitlePitch, accent: ColorTokens.Brand.primary)
            }
            .padding(.horizontal, VoiceStrongmanMetrics.contentPadding)
            .padding(.top, SpacingTokens.tiny)
            .padding(.bottom, SpacingTokens.regular)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaPadding(.bottom, SpacingTokens.small)
    }

    private var directionRow: some View {
        HStack(spacing: SpacingTokens.small) {
            ForEach(PitchDirection.allCases, id: \.self) { direction in
                DirectionCard(
                    direction: direction,
                    isActive: display.pitchDirection == direction
                ) {
                    container.soundService.playUISound(.tap)
                    container.hapticService.selection()
                    interactor?.selectDirection(.init(direction: direction))
                }
            }
        }
    }

    private var recordTitlePitch: String {
        if display.isRecording {
            return String(localized: "voiceStrongman.cta.speaking", defaultValue: "Пою…")
        }
        switch display.pitchDirection {
        case .up:   return String(localized: "voiceStrongman.cta.up",
                                  defaultValue: "Держи и тяни вверх")
        case .down: return String(localized: "voiceStrongman.cta.down",
                                  defaultValue: "Держи и тяни вниз")
        }
    }

    // MARK: - Record CTA (shared)

    @ViewBuilder
    private func recordCTA(title: String, accent: Color) -> some View {
        if display.showResult {
            HStack(spacing: SpacingTokens.regular) {
                Button { retry() } label: {
                    Image(systemName: "mic.fill")
                        .font(TypographyTokens.headline(18).weight(.bold))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .frame(width: 60, height: 58)
                        .background(
                            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                                .fill(ColorTokens.Kid.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                                .strokeBorder(ColorTokens.Brand.primary, lineWidth: 1.5)
                        )
                }
                .accessibilityLabel(String(localized: "voiceStrongman.retry.a11y",
                                           defaultValue: "Спеть ещё раз"))

                Button { advance() } label: {
                    HStack(spacing: SpacingTokens.tiny) {
                        Text(advanceTitle)
                            .font(TypographyTokens.headline(18).weight(.bold))
                            .lineLimit(nil)
                            .minimumScaleFactor(0.85)
                            .multilineTextAlignment(.center)
                        Image(systemName: "arrow.right")
                            .font(TypographyTokens.headline(16).weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 58)
                    .background(ctaGradient(accent))
                    .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous))
                }
            }
        } else {
            Button { toggleRecord() } label: {
                HStack(spacing: SpacingTokens.small) {
                    Image(systemName: display.isRecording ? "stop.fill" : "mic.fill")
                        .font(TypographyTokens.headline(20).weight(.bold))
                    Text(title)
                        .font(TypographyTokens.headline(18).weight(.bold))
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 58)
                .background(ctaGradient(accent))
                .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous))
            }
            .accessibilityLabel(title)
            .accessibilityHint(display.isRecording
                ? String(localized: "voiceStrongman.cta.stop.hint", defaultValue: "Остановить запись")
                : String(localized: "voiceStrongman.cta.record.hint", defaultValue: "Начать запись голоса"))
        }
    }

    private var advanceTitle: String {
        String(localized: "voiceStrongman.cta.next", defaultValue: "Дальше")
    }

    private func ctaGradient(_ accent: Color) -> LinearGradient {
        LinearGradient(
            colors: [accent.opacity(0.85), accent],
            startPoint: .top, endPoint: .bottom
        )
    }

    // MARK: - Completed

    private var completedView: some View {
        VStack(spacing: SpacingTokens.large) {
            Spacer(minLength: SpacingTokens.large)
            LyalyaMascotView(state: reduceMotion ? .idle : .celebrating, size: 132)
                .accessibilityHidden(true)
            HStack(spacing: SpacingTokens.small) {
                ForEach(0..<3, id: \.self) { idx in
                    Image(systemName: idx < display.starsEarned ? "star.fill" : "star")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(idx < display.starsEarned
                                         ? ColorTokens.Brand.gold
                                         : ColorTokens.Kid.line)
                        .symbolEffect(.bounce, value: display.starsEarned)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(
                format: String(localized: "voiceStrongman.stars.a11y %lld",
                               defaultValue: "Получено звёзд: %lld из трёх"),
                display.starsEarned
            ))

            Text(String(localized: "voiceStrongman.completed.title",
                        defaultValue: "Голос окреп!"))
                .font(TypographyTokens.title(24).weight(.black))
                .foregroundStyle(ColorTokens.Kid.ink)

            Text(display.completionMessage)
                .font(TypographyTokens.body(16))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .padding(.horizontal, SpacingTokens.medium)

            Spacer()

            Button { finalize() } label: {
                Text(String(localized: "voiceStrongman.completed.cta",
                            defaultValue: "Завершить"))
                    .font(TypographyTokens.headline(18).weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 58)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .background(ctaGradient(ColorTokens.Brand.primary))
                    .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous))
            }
            .padding(.horizontal, VoiceStrongmanMetrics.contentPadding)
            .padding(.bottom, SpacingTokens.regular)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, VoiceStrongmanMetrics.contentPadding)
    }

    // MARK: - Actions

    private func toggleRecord() {
        if display.isRecording {
            container.soundService.playUISound(.tap)
            Task { await interactor?.stopRecording() }
        } else {
            container.soundService.playUISound(.tap)
            container.hapticService.impact(.medium)
            Task { await interactor?.startRecording() }
        }
    }

    private func retry() {
        container.soundService.playUISound(.tap)
        display.showResult = false
        display.liveLoudness = 0
        display.livePitch = 0
        display.ladderReached = 0
        display.liveContour = []
        display.loudnessInBand = false
        display.directionMatched = false
    }

    private func advance() {
        container.soundService.playUISound(.tap)
        if display.resultMatch {
            container.hapticService.notification(.success)
        }
        Task { await interactor?.advance() }
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
        let presenter = VoiceStrongmanPresenter()
        let interactor = VoiceStrongmanInteractor(
            childId: childId,
            childAge: age,
            capture: VoiceStrongmanAudioCapture(),
            adaptivePlanner: container.adaptivePlannerService
        )
        let router = VoiceStrongmanRouter()

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

private enum VoiceStrongmanMetrics {
    /// Симметричный контентный отступ (open-design: 22pt).
    static let contentPadding: CGFloat = 22
}

// MARK: - TargetLevelCard (зверёк-уровень громкости)

private struct TargetLevelCard: View {
    let level: LoudnessLevel
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: SpacingTokens.tiny) {
                Text(level.emoji).font(.system(size: 26))
                Text(level.name)
                    .font(TypographyTokens.headline(14).weight(.black))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(level.who)
                    .font(TypographyTokens.caption(10).weight(.bold))
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.small)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .fill(isActive ? level.accent.opacity(0.08) : ColorTokens.Kid.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .strokeBorder(isActive ? level.accent : ColorTokens.Kid.line,
                                  lineWidth: isActive ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(level.name), \(level.who)")
        .accessibilityAddTraits(isActive ? [.isSelected, .isButton] : .isButton)
    }
}

// MARK: - VoiceBalloonMeter (звуковой шар + зона + тики)

private struct VoiceBalloonMeter: View {
    let animal: String
    let loudness: CGFloat
    let bandLower: CGFloat
    let bandUpper: CGFloat
    let inBand: Bool
    let showResult: Bool
    let reduceMotion: Bool

    /// Диаметр шара 64…176 от громкости.
    private var balloonSize: CGFloat {
        64 + min(max(loudness, 0), 1) * 112
    }

    private var bandColor: Color {
        inBand ? ColorTokens.Brand.mint : ColorTokens.Brand.gold
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: RadiusTokens.xl, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: RadiusTokens.xl, style: .continuous)
                            .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
                    )

                // Зона комфортной громкости (золотая пунктир-полоса; mint при попадании).
                comfortBand(in: geo.size)

                // Звуковой шар (растёт от громкости).
                balloon
                    .padding(.bottom, geo.size.height * bandLower * 0.35 + 36)
                    .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7),
                               value: loudness)

                // Живые RMS-тики внизу.
                liveTicks
                    .frame(height: 30)
                    .padding(.horizontal, SpacingTokens.regular)
                    .padding(.bottom, SpacingTokens.small)
            }
        }
        .shadow(color: ColorTokens.Overlay.shadow.opacity(0.4), radius: 12, y: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(inBand
            ? String(localized: "voiceStrongman.balloon.a11y.in",
                     defaultValue: "Шар в зоне удобной громкости")
            : String(localized: "voiceStrongman.balloon.a11y.out",
                     defaultValue: "Звуковой шар растёт от громкости голоса"))
    }

    private func comfortBand(in size: CGSize) -> some View {
        let usable = size.height * 0.78
        let bandTop = size.height - usable * bandUpper - 36
        let bandHeight = max(40, usable * (bandUpper - bandLower))
        return RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
            .strokeBorder(bandColor.opacity(0.6),
                          style: StrokeStyle(lineWidth: 2, dash: inBand ? [] : [6, 5]))
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                    .fill(bandColor.opacity(0.12))
            )
            .frame(height: bandHeight)
            .overlay(alignment: .topLeading) {
                Text(inBand
                     ? String(localized: "voiceStrongman.band.hit", defaultValue: "Попал в цель!")
                     : String(localized: "voiceStrongman.band.label", defaultValue: "Удобная громкость"))
                    .font(TypographyTokens.caption(10).weight(.bold))
                    .foregroundStyle(bandColor)
                    .padding(.horizontal, SpacingTokens.small)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(ColorTokens.Kid.surface))
                    .overlay(Capsule().strokeBorder(bandColor.opacity(0.4), lineWidth: 1))
                    .offset(x: 10, y: -9)
            }
            .padding(.horizontal, SpacingTokens.regular)
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, bandTop)
    }

    private var balloon: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [ColorTokens.Brand.primaryHi, ColorTokens.Brand.primary],
                    center: .init(x: 0.35, y: 0.3), startRadius: 4, endRadius: balloonSize * 0.7))
            Text(animal)
                .font(.system(size: balloonSize * 0.4))
        }
        .frame(width: balloonSize, height: balloonSize)
        .overlay {
            if inBand {
                Circle().strokeBorder(ColorTokens.Brand.mint.opacity(0.5), lineWidth: 6)
                    .padding(-3)
            }
        }
        .shadow(color: ColorTokens.Brand.primary.opacity(0.5), radius: 12, y: 6)
    }

    private var liveTicks: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(0..<12, id: \.self) { idx in
                let base = 0.2 + 0.55 * abs(sin(CGFloat(idx) * 0.9))
                let h = min(1, base * (0.4 + loudness))
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(ColorTokens.Brand.primary.opacity(0.38))
                    .frame(maxWidth: .infinity)
                    .scaleEffect(y: max(0.12, h), anchor: .bottom)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: loudness)
    }
}

// MARK: - DirectionCard (вверх/вниз)

private struct DirectionCard: View {
    let direction: PitchDirection
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: SpacingTokens.tiny) {
                Text(direction.arrow)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(ColorTokens.Brand.primary)
                Text(direction.name)
                    .font(TypographyTokens.headline(14).weight(.black))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(direction.who)
                    .font(TypographyTokens.caption(10).weight(.bold))
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.small)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .fill(isActive ? ColorTokens.Brand.primary.opacity(0.08) : ColorTokens.Kid.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .strokeBorder(isActive ? ColorTokens.Brand.primary : ColorTokens.Kid.line,
                                  lineWidth: isActive ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(direction.name), \(direction.who)")
        .accessibilityAddTraits(isActive ? [.isSelected, .isButton] : .isButton)
    }
}

// MARK: - PitchLadder (лесенка + глиссандо + климбер)

private struct PitchLadder: View {
    let vowel: String
    let steps: Int
    /// Достигнутая доля высоты 0…1 (позиция климбера).
    let reached: CGFloat
    let direction: PitchDirection
    let isSuccess: Bool
    let reduceMotion: Bool

    private var litCount: Int {
        Int((min(max(reached, 0), 1) * CGFloat(steps)).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            HStack {
                Text(String(localized: "voiceStrongman.ladder.label",
                            defaultValue: "Веди голос по ступенькам"))
                    .font(TypographyTokens.caption(12).weight(.bold))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
                Text("\(vowel)-\(vowel)-\(vowel)\(isSuccess ? " ✓" : "")")
                    .font(TypographyTokens.headline(16).weight(.black))
                    .foregroundStyle(isSuccess ? ColorTokens.Brand.mint : ColorTokens.Brand.lilac)
                    .padding(.horizontal, SpacingTokens.small)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(ColorTokens.Kid.surface))
                    .overlay(Capsule().strokeBorder(
                        (isSuccess ? ColorTokens.Brand.mint : ColorTokens.Brand.lilac).opacity(0.4),
                        lineWidth: 1))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            GeometryReader { geo in
                ZStack(alignment: .bottomLeading) {
                    // Ступеньки (растут шириной и высотой; lit при достижении).
                    ForEach(0..<steps, id: \.self) { idx in
                        ladderStep(idx: idx, in: geo.size)
                    }
                    // Глиссандо-дорожка (lilac/mint) — целевая траектория + достигнутая.
                    glideTrack(in: geo.size)
                    // Климбер-цыплёнок.
                    climber(in: geo.size)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(SpacingTokens.regular)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.xl, style: .continuous)
                .fill(ColorTokens.Kid.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.xl, style: .continuous)
                        .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
                )
        )
        .shadow(color: ColorTokens.Overlay.shadow.opacity(0.4), radius: 12, y: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(
            format: String(localized: "voiceStrongman.ladder.a11y %lld %lld",
                           defaultValue: "Лесенка голоса: пройдено %lld из %lld ступеней"),
            litCount, steps))
    }

    private func ladderStep(idx: Int, in size: CGSize) -> some View {
        let stepHeight: CGFloat = 30
        let gap = (size.height - stepHeight) / CGFloat(max(steps - 1, 1))
        let bottom = CGFloat(idx) * gap
        let width = size.width * (0.44 + 0.5 * CGFloat(idx) / CGFloat(max(steps - 1, 1)))
        let isLit = idx < litCount
        let isTop = idx == steps - 1
        let litColor = (isSuccess && isTop) ? ColorTokens.Brand.mint : ColorTokens.Brand.lilac
        return RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
            .fill(isLit ? litColor.opacity(0.18) : ColorTokens.Kid.surfaceAlt)
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                    .strokeBorder(isLit ? litColor.opacity(0.5) : ColorTokens.Kid.line, lineWidth: 1)
            )
            .overlay(alignment: .leading) {
                if idx == 0 || idx == steps - 1 {
                    Text(idx == 0
                         ? String(localized: "voiceStrongman.ladder.low", defaultValue: "низко")
                         : String(localized: "voiceStrongman.ladder.high", defaultValue: "высоко"))
                        .font(TypographyTokens.caption(11).weight(.bold))
                        .foregroundStyle(isLit ? litColor : ColorTokens.Kid.inkMuted)
                        .padding(.leading, SpacingTokens.small)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(width: width, height: stepHeight)
            .offset(y: -bottom)
            .frame(maxHeight: .infinity, alignment: .bottom)
    }

    private func glideTrack(in size: CGSize) -> some View {
        let accent = isSuccess ? ColorTokens.Brand.mint : ColorTokens.Brand.lilac
        return ZStack {
            // Целевая пунктир-дорожка.
            GlidePath(progress: 1, direction: direction)
                .stroke(ColorTokens.Brand.lilac.opacity(0.5),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [6, 7]))
            // Достигнутая (сплошная).
            GlidePath(progress: min(max(reached, 0), 1), direction: direction)
                .stroke(accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }

    private func climber(in size: CGSize) -> some View {
        let p = min(max(reached, 0), 1)
        // Климбер идёт вдоль глиссандо-дорожки: слева-направо по мере прогресса,
        // по вертикали — вверх (up) или вниз (down) синхронно с дорожкой.
        let x = size.width * (0.12 + 0.7 * p)
        let lowY = size.height * 0.92
        let highY = size.height * 0.10
        let startY = direction == .up ? lowY : highY
        let endY = direction == .up ? highY : lowY
        let y = startY + (endY - startY) * p
        let accent = isSuccess ? ColorTokens.Brand.mint : ColorTokens.Brand.lilac
        return Text("🐤")
            .font(.system(size: 26))
            .frame(width: 48, height: 48)
            .background(Circle().fill(ColorTokens.Kid.surface))
            .overlay(Circle().strokeBorder(accent, lineWidth: 2))
            .overlay {
                if isSuccess {
                    Circle().strokeBorder(ColorTokens.Brand.mint.opacity(0.4), lineWidth: 6).padding(-3)
                }
            }
            .shadow(color: accent.opacity(0.5), radius: 8, y: 4)
            .position(x: min(max(x, 24), size.width - 24), y: min(max(y, 24), size.height - 24))
            .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.7), value: reached)
            .accessibilityHidden(true)
    }
}

// MARK: - GlidePath (глиссандо-дорожка)

private struct GlidePath: Shape {
    /// Доля пройденного пути 0…1.
    let progress: CGFloat
    let direction: PitchDirection

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let p = min(max(progress, 0), 1)
        guard p > 0 else { return path }
        let startX = rect.width * 0.12
        let endX = rect.width * 0.82
        // Вверх: слева-снизу → справа-вверх. Вниз: слева-вверх → справа-вниз.
        let lowY = rect.height * 0.92
        let highY = rect.height * 0.10
        let startY = direction == .up ? lowY : highY
        let endY = direction == .up ? highY : lowY
        let curX = startX + (endX - startX) * p
        let curY = startY + (endY - startY) * p
        path.move(to: CGPoint(x: startX, y: startY))
        path.addLine(to: CGPoint(x: curX, y: curY))
        return path
    }
}
