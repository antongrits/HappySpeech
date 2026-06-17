import OSLog
import SwiftUI

// MARK: - VoiceColorsView
//
// «Голосовые краски» — kid-модуль просодики в трёх режимах:
//   1. Интонация — phrase-card + дорожка мелодии (пунктир=образец Ляли,
//      сплошная=голос ребёнка) + три домика интонации (вопрос/восклицание/спокойно).
//   2. Логическое ударение — фраза-слова + пословные RMS-столбики + чипы выбора
//      главного слова + полоса записи.
//   3. Эмоции голоса — phrase-card + большое «зеркало» Ляли + три карточки эмоций.
//
// Open-design: kid-game-voice-colors-1/2/3.html (структура/отступы перенесены).
// Тёплая палитра; интонация/эмоция-акценты (lilac/coral/gold/rose) — ТОЛЬКО на
// крышах домиков, рамках карточек, контурах — НИКОГДА на фонах. Reduced Motion
// уважается во всех анимациях. CTA: lineLimit(nil) + minimumScaleFactor.
//
// Архитектура: Clean Swift VIP. interactor/presenter/router/display создаются
// один раз в bootstrap() и удерживаются как @State.

struct VoiceColorsView: View {

    // MARK: - Input

    let childId: String

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - VIP

    @State private var display = VoiceColorsDisplay()
    @State private var interactor: VoiceColorsInteractor?
    @State private var presenter: VoiceColorsPresenter?
    @State private var router: VoiceColorsRouter?
    @State private var bootstrapped = false
    @State private var celebrate = false

    private let logger = Logger(subsystem: "ru.happyspeech", category: "VoiceColorsView")

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
            localized: "voiceColors.screen.a11y",
            defaultValue: "Голосовые краски: интонация, главное слово и эмоции голоса"
        ))
    }

    // MARK: - Content switch

    @ViewBuilder
    private var content: some View {
        switch display.phase {
        case .loading:    loadingView
        case .intonation: intonationView
        case .stress:     stressView
        case .emotion:    emotionView
        case .completed:  completedView
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

            Button { interactor?.playModel() } label: {
                Image(systemName: display.isPlaying ? "waveform" : "speaker.wave.2.fill")
                    .font(TypographyTokens.headline(16).weight(.semibold))
                    .symbolEffect(.variableColor, isActive: display.isPlaying && !reduceMotion)
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(ColorTokens.Kid.surfaceAlt))
            }
            .accessibilityLabel(String(localized: "voiceColors.playModel.a11y",
                                       defaultValue: "Послушать Лялю"))
        }
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
            Text(String(localized: "voiceColors.loading", defaultValue: "Готовим краски…"))
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Mode 1: Intonation

    private var intonationView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SpacingTokens.regular) {
                topBar(title: display.title, subtitle: display.subtitle)

                phraseMelodyCard
                intonationHouses
                mascotRow(text: display.micDenied ? display.micDeniedMessage : display.mascotText)
                if display.micDenied { micDeniedBanner }

                recordCTA(
                    title: recordTitleIntonation,
                    accent: display.intonationMode.accent
                )
            }
            .padding(.horizontal, VoiceColorsMetrics.contentPadding)
            .padding(.top, SpacingTokens.tiny)
            .padding(.bottom, SpacingTokens.regular)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaPadding(.bottom, SpacingTokens.small)
    }

    /// phrase-card + дорожка мелодии (melody track).
    private var phraseMelodyCard: some View {
        VStack(spacing: SpacingTokens.small) {
            Text(display.showResult
                 ? display.subtitle
                 : String(localized: "voiceColors.intonation.listen",
                          defaultValue: "Послушай и повтори за Лялей"))
                .font(TypographyTokens.caption(12).weight(.bold))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .textCase(.uppercase)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.tiny) {
                Text(display.phraseText)
                    .font(TypographyTokens.display(30).weight(.black))
                    .foregroundStyle(ColorTokens.Kid.ink)
                Text(display.intonationMark)
                    .font(TypographyTokens.display(34).weight(.black))
                    .foregroundStyle(display.intonationMode.accent)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)

            MelodyTrackView(
                model: display.modelContour,
                live: display.showResult || display.isRecording ? display.liveContour : [],
                accent: display.intonationMode.accent,
                reduceMotion: reduceMotion
            )
            .frame(height: 78)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(
                localized: "voiceColors.melody.a11y",
                defaultValue: "Дорожка мелодии: пунктир — образец, сплошная — твой голос"
            ))

            Button { interactor?.playModel() } label: {
                HStack(spacing: SpacingTokens.tiny) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(TypographyTokens.body(14).weight(.semibold))
                    Text(String(localized: "voiceColors.replay",
                                defaultValue: "Послушать ещё раз"))
                        .font(TypographyTokens.headline(14))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(ColorTokens.Brand.primary)
                .padding(.horizontal, SpacingTokens.regular)
                .padding(.vertical, SpacingTokens.small)
                .background(Capsule().fill(ColorTokens.Brand.primaryLo.opacity(0.35)))
            }
            .accessibilityLabel(String(localized: "voiceColors.replay.a11y",
                                       defaultValue: "Послушать образец ещё раз"))
        }
        .frame(maxWidth: .infinity)
        .padding(SpacingTokens.regular)
        .background(cardBackground)
    }

    private var intonationHouses: some View {
        HStack(spacing: SpacingTokens.small) {
            ForEach(IntonationMode.allCases, id: \.self) { mode in
                IntonationHouse(
                    mode: mode,
                    isActive: display.intonationMode == mode,
                    isDone: display.doneIntonationModes.contains(mode)
                ) {
                    container.soundService.playUISound(.tap)
                    container.hapticService.selection()
                    interactor?.selectIntonation(.init(mode: mode))
                }
            }
        }
    }

    private var recordTitleIntonation: String {
        switch display.intonationMode {
        case .question:    return String(localized: "voiceColors.cta.question",
                                         defaultValue: "Сказать как вопрос")
        case .exclamation: return String(localized: "voiceColors.cta.exclamation",
                                         defaultValue: "Сказать с восторгом")
        case .calm:        return String(localized: "voiceColors.cta.calm",
                                         defaultValue: "Сказать спокойно")
        }
    }

    // MARK: - Mode 2: Stress

    private var stressView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SpacingTokens.regular) {
                topBar(title: display.title, subtitle: display.subtitle)
                stressQuestionCard
                stressPhraseCard
                stressPicker
                if display.isRecording { recordingStrip }
                mascotRow(text: display.micDenied ? display.micDeniedMessage : display.mascotText)
                if display.micDenied { micDeniedBanner }
                recordCTA(title: recordTitleStress, accent: ColorTokens.Brand.primary)
            }
            .padding(.horizontal, VoiceColorsMetrics.contentPadding)
            .padding(.top, SpacingTokens.tiny)
            .padding(.bottom, SpacingTokens.regular)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaPadding(.bottom, SpacingTokens.small)
    }

    private var stressQuestionCard: some View {
        HStack(spacing: SpacingTokens.small) {
            Text(display.stressQuestionEmoji)
                .font(.system(size: 24))
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                        .fill(ColorTokens.Kid.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                        .strokeBorder(ColorTokens.Brand.lilac.opacity(0.4), lineWidth: 1)
                )
            Text(display.stressQuestion)
                .font(TypographyTokens.headline(15).weight(.semibold))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(SpacingTokens.regular)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .fill(ColorTokens.Brand.lilac.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .strokeBorder(ColorTokens.Brand.lilac.opacity(0.3), lineWidth: 1)
        )
    }

    private var stressPhraseCard: some View {
        VStack(spacing: SpacingTokens.regular) {
            Text(display.showResult
                 ? display.subtitle
                 : String(
                    format: String(localized: "voiceColors.stress.say %@",
                                   defaultValue: "Скажи громче и протяжнее «%@»"),
                    targetWordLabel
                 ))
                .font(TypographyTokens.caption(12).weight(.bold))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .textCase(.uppercase)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            HStack(alignment: .bottom, spacing: SpacingTokens.small) {
                ForEach(Array(display.stressWords.enumerated()), id: \.offset) { idx, word in
                    StressWordColumn(
                        word: word,
                        isStress: stressIsHighlighted(idx),
                        height: display.perWordHeights.indices.contains(idx)
                            ? display.perWordHeights[idx]
                            : (stressIsHighlighted(idx) ? 0.84 : 0.36),
                        showMeter: display.showResult
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(SpacingTokens.regular)
        .background(cardBackground)
    }

    /// Подсветка слова: после записи — реально самое громкое; до записи —
    /// целевое (опора-подсказка).
    private func stressIsHighlighted(_ idx: Int) -> Bool {
        if display.showResult, display.loudestWordIndex >= 0 {
            return idx == display.loudestWordIndex
        }
        return idx == display.targetWordIndex
    }

    private var targetWordLabel: String {
        display.stressWords.indices.contains(display.targetWordIndex)
            ? display.stressWords[display.targetWordIndex].uppercased()
            : ""
    }

    private var stressPicker: some View {
        VStack(spacing: SpacingTokens.small) {
            Text(String(localized: "voiceColors.stress.picker",
                        defaultValue: "Какое слово сейчас главное?"))
                .font(TypographyTokens.headline(14).weight(.bold))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            HStack(spacing: SpacingTokens.small) {
                ForEach(Array(display.stressWords.enumerated()), id: \.offset) { idx, word in
                    StressChip(
                        word: word,
                        emoji: display.stressEmojis.indices.contains(idx) ? display.stressEmojis[idx] : "",
                        isSelected: display.targetWordIndex == idx
                    ) {
                        container.soundService.playUISound(.tap)
                        container.hapticService.selection()
                        interactor?.selectStressWord(.init(wordIndex: idx))
                    }
                }
            }
        }
    }

    private var recordingStrip: some View {
        HStack(spacing: SpacingTokens.small) {
            Circle()
                .fill(ColorTokens.Brand.primary)
                .frame(width: 13, height: 13)
                .scaleEffect(reduceMotion ? 1 : (display.isRecording ? 1.2 : 1))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                           value: display.isRecording)
            LiveWaveBars(amplitude: display.liveAmplitude, accent: ColorTokens.Brand.primary,
                         reduceMotion: reduceMotion)
                .frame(height: 24)
                .frame(maxWidth: .infinity)
            Text(String(localized: "voiceColors.listening", defaultValue: "Слушаю…"))
                .font(TypographyTokens.headline(13).weight(.bold))
                .foregroundStyle(ColorTokens.Brand.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, SpacingTokens.regular)
        .padding(.vertical, SpacingTokens.small)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .fill(ColorTokens.Brand.primaryLo.opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .strokeBorder(ColorTokens.Brand.primary.opacity(0.24), lineWidth: 1)
        )
        .accessibilityLabel(String(localized: "voiceColors.listening.a11y",
                                   defaultValue: "Идёт запись голоса"))
    }

    private var recordTitleStress: String {
        display.isRecording
            ? String(localized: "voiceColors.cta.speaking", defaultValue: "Говорю…")
            : String(localized: "voiceColors.cta.sayStress", defaultValue: "Выделить голосом")
    }

    // MARK: - Mode 3: Emotion

    private var emotionView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SpacingTokens.regular) {
                topBar(title: display.title, subtitle: display.subtitle)
                emotionPhraseCard
                emotionMirror
                emotionPicker
                mascotRow(text: display.micDenied ? display.micDeniedMessage : display.mascotText)
                if display.micDenied { micDeniedBanner }
                recordCTA(title: recordTitleEmotion, accent: display.chosenEmotion.accent)
            }
            .padding(.horizontal, VoiceColorsMetrics.contentPadding)
            .padding(.top, SpacingTokens.tiny)
            .padding(.bottom, SpacingTokens.regular)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaPadding(.bottom, SpacingTokens.small)
    }

    private var emotionPhraseCard: some View {
        VStack(spacing: SpacingTokens.tiny) {
            Text(display.showResult
                 ? display.subtitle
                 : String(
                    format: String(localized: "voiceColors.emotion.say %@",
                                   defaultValue: "Скажи эту фразу %@"),
                    display.chosenEmotion.name.lowercased()
                 ))
                .font(TypographyTokens.caption(12).weight(.bold))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .textCase(.uppercase)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            Text("«\(display.emotionPhrase)»")
                .font(TypographyTokens.display(26).weight(.black))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(SpacingTokens.regular)
        .background(cardBackground)
    }

    private var emotionMirror: some View {
        let emotion = display.reflectedEmotion ?? display.chosenEmotion
        return VStack(spacing: SpacingTokens.small) {
            LyalyaMascotView(state: reduceMotion ? .idle : emotion.lyalyaState, size: 116)
                .frame(width: 120, height: 120)
                .background(Circle().fill(ColorTokens.Kid.surface))
                .overlay(Circle().strokeBorder(emotion.accent.opacity(0.4), lineWidth: 2))
                .accessibilityHidden(true)
            Text(String(localized: "voiceColors.mirror.heard",
                        defaultValue: "Ляля услышала"))
                .font(TypographyTokens.caption(12).weight(.bold))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .textCase(.uppercase)
            Text("\(emotion.reflectionName) \(emotion.emoji)")
                .font(TypographyTokens.title(22).weight(.black))
                .foregroundStyle(emotion.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpacingTokens.regular)
        .padding(.horizontal, SpacingTokens.regular)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.xl, style: .continuous)
                .fill(emotion.accent.opacity(display.reflectedEmotion == nil ? 0.06 : 0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.xl, style: .continuous)
                .strokeBorder(emotion.accent.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: ColorTokens.Overlay.shadow.opacity(0.4), radius: 12, y: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(
            format: String(localized: "voiceColors.mirror.a11y %@",
                           defaultValue: "Ляля отражает настроение: %@"),
            emotion.reflectionName
        ))
    }

    private var emotionPicker: some View {
        HStack(spacing: SpacingTokens.small) {
            ForEach(VoiceEmotion.allCases, id: \.self) { emotion in
                EmotionCard(
                    emotion: emotion,
                    isSelected: display.chosenEmotion == emotion
                ) {
                    container.soundService.playUISound(.tap)
                    container.hapticService.selection()
                    interactor?.selectEmotion(.init(emotion: emotion))
                }
            }
        }
    }

    private var recordTitleEmotion: String {
        if display.isRecording {
            return String(localized: "voiceColors.cta.speaking", defaultValue: "Говорю…")
        }
        return String(
            format: String(localized: "voiceColors.cta.sayEmotion %@",
                           defaultValue: "Сказать %@"),
            display.chosenEmotion.name.lowercased()
        )
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
                .accessibilityLabel(String(localized: "voiceColors.retry.a11y",
                                           defaultValue: "Сказать ещё раз"))

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
                ? String(localized: "voiceColors.cta.stop.hint", defaultValue: "Остановить запись")
                : String(localized: "voiceColors.cta.record.hint", defaultValue: "Начать запись голоса"))
        }
    }

    private var advanceTitle: String {
        String(localized: "voiceColors.cta.next", defaultValue: "Дальше")
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
                format: String(localized: "voiceColors.stars.a11y %lld",
                               defaultValue: "Получено звёзд: %lld из трёх"),
                display.starsEarned
            ))

            Text(String(localized: "voiceColors.completed.title",
                        defaultValue: "Краски звучат!"))
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
                Text(String(localized: "voiceColors.completed.cta",
                            defaultValue: "Завершить краски"))
                    .font(TypographyTokens.headline(18).weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 58)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .background(ctaGradient(ColorTokens.Brand.primary))
                    .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous))
            }
            .padding(.horizontal, VoiceColorsMetrics.contentPadding)
            .padding(.bottom, SpacingTokens.regular)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, VoiceColorsMetrics.contentPadding)
    }

    // MARK: - Shared background

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
            .fill(ColorTokens.Kid.surface)
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
            )
            .shadow(color: ColorTokens.Overlay.shadow.opacity(0.4), radius: 12, y: 6)
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
        display.liveContour = []
        display.perWordHeights = []
        display.loudestWordIndex = -1
        display.reflectedEmotion = nil
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
        let presenter = VoiceColorsPresenter()
        let interactor = VoiceColorsInteractor(
            childId: childId,
            childAge: age,
            capture: VoiceColorsAudioCapture(),
            emotionService: container.emotionDetectionService,
            adaptivePlanner: container.adaptivePlannerService
        )
        let router = VoiceColorsRouter()

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

private enum VoiceColorsMetrics {
    /// Симметричный контентный отступ (open-design: 22pt).
    static let contentPadding: CGFloat = 22
}

// MARK: - MelodyTrackView (дорожка мелодии)

/// SVG-аналог melody track: пунктир = образец Ляли, сплошная = голос ребёнка.
private struct MelodyTrackView: View {
    let model: [PitchPoint]
    let live: [PitchPoint]
    let accent: Color
    let reduceMotion: Bool

    private let minF: Double = 80
    private let maxF: Double = 500

    var body: some View {
        Canvas(opaque: false) { ctx, size in
            // Сетка (2 линии, как в эталоне).
            var grid = Path()
            for frac in [0.33, 0.66] {
                let y = size.height * frac
                grid.move(to: CGPoint(x: 0, y: y))
                grid.addLine(to: CGPoint(x: size.width, y: y))
            }
            ctx.stroke(grid, with: .color(ColorTokens.Kid.line), lineWidth: 1)

            // Target (пунктир).
            drawContour(model, in: ctx, size: size, color: accent.opacity(0.85),
                        width: 3.4, dash: [6, 7])
            // Live (сплошная, поверх).
            drawContour(live, in: ctx, size: size, color: accent, width: 4, dash: [])
        }
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                .fill(ColorTokens.Kid.surfaceAlt)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous))
        .overlay(alignment: .bottomLeading) {
            HStack(spacing: SpacingTokens.small) {
                legendItem(text: String(localized: "voiceColors.legend.model",
                                        defaultValue: "Образец Ляли"), dashed: true)
                legendItem(text: String(localized: "voiceColors.legend.you",
                                        defaultValue: "Твой голос"), dashed: false)
            }
            .padding(.leading, SpacingTokens.small)
            .padding(.bottom, SpacingTokens.tiny)
        }
    }

    private func legendItem(text: String, dashed: Bool) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accent.opacity(dashed ? 0.55 : 1))
                .frame(width: 14, height: 3)
            Text(text)
                .font(TypographyTokens.caption(10).weight(.bold))
                .foregroundStyle(ColorTokens.Kid.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private func drawContour(
        _ points: [PitchPoint], in ctx: GraphicsContext, size: CGSize,
        color: Color, width: CGFloat, dash: [CGFloat]
    ) {
        var path = Path()
        var didStart = false
        for point in points {
            guard let f = point.frequencyHz, f >= minF, f <= maxF else { didStart = false; continue }
            let x = size.width * CGFloat(point.time)
            let normalised = (f - minF) / (maxF - minF)
            let y = size.height * (1.0 - CGFloat(normalised))
            if !didStart {
                path.move(to: CGPoint(x: x, y: y)); didStart = true
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        ctx.stroke(path, with: .color(color),
                   style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round, dash: dash))
    }
}

// MARK: - IntonationHouse (домик интонации)

private struct IntonationHouse: View {
    let mode: IntonationMode
    let isActive: Bool
    let isDone: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: SpacingTokens.tiny) {
                // Крыша-треугольник (цветной акцент).
                Triangle()
                    .fill(mode.accent)
                    .frame(width: 56, height: 18)
                Text(mode.mark)
                    .font(TypographyTokens.display(30).weight(.black))
                    .foregroundStyle(mode.accent)
                Text(mode.name)
                    .font(TypographyTokens.headline(13).weight(.black))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(mode.arrow)
                    .font(.system(size: 15))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.small)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .fill(isActive ? mode.accent.opacity(0.08) : ColorTokens.Kid.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .strokeBorder(isActive ? mode.accent : ColorTokens.Kid.line,
                                  lineWidth: isActive ? 2 : 1)
            )
            .overlay(alignment: .topTrailing) {
                if isDone {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(ColorTokens.Brand.mint)
                        .padding(SpacingTokens.tiny)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.name)
        .accessibilityAddTraits(isActive ? [.isSelected, .isButton] : .isButton)
        .accessibilityValue(isDone
            ? String(localized: "voiceColors.house.done.a11y", defaultValue: "выполнено")
            : "")
    }
}

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

// MARK: - StressWordColumn (слово + столбик громкости)

private struct StressWordColumn: View {
    let word: String
    let isStress: Bool
    let height: CGFloat
    let showMeter: Bool

    var body: some View {
        VStack(spacing: SpacingTokens.small) {
            Text(isStress ? word.uppercased() : word)
                .font(TypographyTokens.title(isStress ? 22 : 20).weight(isStress ? .black : .bold))
                .foregroundStyle(isStress ? Color.white : ColorTokens.Kid.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, SpacingTokens.small)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                        .fill(isStress
                              ? AnyShapeStyle(LinearGradient(
                                    colors: [ColorTokens.Brand.primaryHi, ColorTokens.Brand.primary],
                                    startPoint: .top, endPoint: .bottom))
                              : AnyShapeStyle(Color.clear))
                )

            if showMeter {
                MeterColumn(fill: height, isStress: isStress)
                    .frame(width: 30, height: 54)
                Text(isStress
                     ? String(localized: "voiceColors.meter.loud", defaultValue: "громко")
                     : String(localized: "voiceColors.meter.quiet", defaultValue: "тихо"))
                    .font(TypographyTokens.caption(10).weight(.bold))
                    .foregroundStyle(isStress ? ColorTokens.Brand.primary : ColorTokens.Kid.inkSoft)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(word)
    }
}

private struct MeterColumn: View {
    let fill: CGFloat
    let isStress: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: RadiusTokens.xs, style: .continuous)
                    .fill(ColorTokens.Kid.surfaceAlt)
                RoundedRectangle(cornerRadius: RadiusTokens.xs, style: .continuous)
                    .fill(isStress
                          ? AnyShapeStyle(LinearGradient(
                                colors: [ColorTokens.Brand.primary, ColorTokens.Brand.primaryHi],
                                startPoint: .bottom, endPoint: .top))
                          : AnyShapeStyle(ColorTokens.Kid.inkSoft.opacity(0.5)))
                    .frame(height: max(4, geo.size.height * min(max(fill, 0), 1)))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.xs, style: .continuous)
                .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
        )
    }
}

// MARK: - StressChip (выбор главного слова)

private struct StressChip: View {
    let word: String
    let emoji: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(emoji).font(.system(size: 20))
                Text(word)
                    .font(TypographyTokens.headline(14).weight(.bold))
                    .foregroundStyle(isSelected ? ColorTokens.Brand.primary : ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.small)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                    .fill(isSelected ? ColorTokens.Brand.primary.opacity(0.08) : ColorTokens.Kid.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                    .strokeBorder(isSelected ? ColorTokens.Brand.primary : ColorTokens.Kid.line,
                                  lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(word)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

// MARK: - EmotionCard (выбор эмоции)

private struct EmotionCard: View {
    let emotion: VoiceEmotion
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: SpacingTokens.tiny) {
                Text(emotion.emoji).font(.system(size: 34))
                Text(emotion.name)
                    .font(TypographyTokens.headline(13).weight(.bold))
                    .foregroundStyle(isSelected ? emotion.accent : ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.regular)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .fill(isSelected ? emotion.accent.opacity(0.1) : ColorTokens.Kid.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .strokeBorder(isSelected ? emotion.accent : ColorTokens.Kid.line,
                                  lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(emotion.name)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

// MARK: - LiveWaveBars (живая волна записи)

private struct LiveWaveBars: View {
    let amplitude: CGFloat
    let accent: Color
    let reduceMotion: Bool

    private let barCount = 7

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { idx in
                let phase = CGFloat(idx) / CGFloat(barCount)
                let h = reduceMotion
                    ? 0.4 + amplitude * 0.6
                    : 0.3 + amplitude * (0.5 + 0.5 * sin(phase * .pi))
                Capsule()
                    .fill(accent)
                    .frame(width: 3.5)
                    .scaleEffect(y: min(max(h, 0.2), 1), anchor: .center)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: amplitude)
    }
}
