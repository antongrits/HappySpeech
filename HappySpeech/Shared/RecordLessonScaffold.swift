import SwiftUI

// MARK: - RecordLessonScaffold
//
// Единый визуальный язык класса экранов «Слушай → Запиши → Оценка»
// (эталон `references/kid-game-record`). Один набор переиспользуемых
// View-примитивов, чтобы все record-and-score экраны выглядели одинаково:
//
//   • RecordLessonHeader   — шапка урока: бейдж звука + подзаголовок +
//                            прогресс-полоса в коралле.
//   • RecordLessonWordCard — крупная карточка задания: картинка/эмодзи +
//                            слово + слоги, мини-кнопка «произнести».
//   • RecordLessonListenRow — строка «Послушай Лялю» с круглой play-кнопкой.
//   • RecordMicButton      — большой центральный микрофон с состояниями
//                            idle / recording (pulse-ring + waveform) /
//                            processing.
//   • RecordLessonFeedbackCard — карточка результата: кольцо счёта + звёзды +
//                            ободряющий текст + Ляля + CTA «Дальше».
//
// Только View-слой. Тёплая палитра ColorTokens. Reduced Motion, VoiceOver,
// Dynamic Type, SE-safe, light/dark — учтены в каждом примитиве. Фон рисует
// сам экран (HSMeshGradientBackground), здесь — только контент.

// MARK: - Header

/// Шапка урока в стиле эталона: круглая кнопка выхода (рисует экран через
/// toolbar — здесь только заголовок-бейдж), бейдж целевого звука, подзаголовок
/// и прогресс-полоса.
struct RecordLessonHeader: View {

    /// Целевой звук, например «Р». Если пусто — бейдж скрыт.
    let sound: String
    /// Подзаголовок, например «Слово 3 из 8 · твёрдый звук».
    let subtitle: String
    /// Прогресс урока 0…1.
    let progress: Double
    /// Цвет акцента (по умолчанию коралл бренда).
    var tint: Color = ColorTokens.Brand.primary

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            HStack(alignment: .center, spacing: SpacingTokens.tiny) {
                if !sound.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(sound)
                        .font(TypographyTokens.headline(15).weight(.bold))
                        .foregroundStyle(tint)
                        .padding(.horizontal, SpacingTokens.small)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(ColorTokens.Brand.primaryLo.opacity(0.55))
                        )
                        .accessibilityLabel(Text(String(
                            localized: "record.lesson.sound.a11y",
                            defaultValue: "Звук \(sound)"
                        )))
                }
                Text(subtitle)
                    .font(TypographyTokens.caption(13).weight(.semibold))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }

            HSProgressBar(value: progress, style: .kid, tint: tint)
                .frame(height: 14)
                .accessibilityLabel(Text(String(
                    localized: "record.lesson.progress.a11y",
                    defaultValue: "Прогресс урока"
                )))
                .accessibilityValue(Text("\(Int((max(0, min(1, progress))) * 100))%"))
        }
    }
}

// MARK: - Word card

/// Крупная карточка задания: картинка/эмодзи в скруглённом слоте, слово,
/// разбивка на слоги. Опциональная мини-кнопка «произнести».
struct RecordLessonWordCard: View {

    /// Эмодзи или имя ассета для `HSContentSymbol`.
    let symbol: String
    /// Слово целиком, например «РЫБА».
    let word: String
    /// Разбивка на слоги: ["РЫ", "БА"]. Пустой массив — слоги скрыты.
    var syllables: [String] = []
    /// Действие мини-кнопки «произнести». Если nil — кнопка скрыта.
    var onSpeak: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HSLiquidGlassCard(style: .primary, padding: SpacingTokens.regular) {
            VStack(spacing: SpacingTokens.small) {
                HSContentSymbol(symbol, size: 84)
                    .frame(height: 88)
                    .accessibilityHidden(true)

                Text(word)
                    .font(TypographyTokens.kidDisplay(40).weight(.bold))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .tracking(2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .multilineTextAlignment(.center)

                if !syllables.isEmpty {
                    syllableRow
                }
            }
            .frame(maxWidth: .infinity)
        }
        .overlay(alignment: .topTrailing) {
            if let onSpeak {
                Button(action: onSpeak) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .frame(width: 34, height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                                .fill(ColorTokens.Kid.bgSoft)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                                .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .padding(SpacingTokens.small)
                .accessibilityLabel(Text(String(
                    localized: "record.lesson.speak.a11y",
                    defaultValue: "Произнести слово"
                )))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(word))
    }

    private var syllableRow: some View {
        HStack(spacing: SpacingTokens.tiny) {
            ForEach(Array(syllables.enumerated()), id: \.offset) { idx, syll in
                Text(syll)
                    .font(TypographyTokens.headline(16).weight(.bold))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .tracking(1)
                    .padding(.horizontal, SpacingTokens.small)
                    .padding(.vertical, SpacingTokens.micro + 2)
                    .background(
                        Capsule().fill(ColorTokens.Brand.primaryLo.opacity(0.5))
                    )
                if idx < syllables.count - 1 {
                    Text("·")
                        .font(TypographyTokens.headline(18).weight(.bold))
                        .foregroundStyle(ColorTokens.Kid.inkSoft)
                }
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityHidden(true)
    }
}

// MARK: - Listen row

/// Строка «Послушай Лялю» с маскотом, текстом и круглой коралловой
/// play-кнопкой справа.
struct RecordLessonListenRow: View {

    var title: String = String(
        localized: "record.lesson.listen.title",
        defaultValue: "Послушай Лялю"
    )
    var subtitle: String = String(
        localized: "record.lesson.listen.subtitle",
        defaultValue: "Как звучит слово целиком"
    )
    /// true — идёт воспроизведение образца (кнопка крутит спиннер/паузу).
    var isPlaying: Bool = false
    /// Лимит повторов достигнут — кнопка задизейблена.
    var isDisabled: Bool = false
    let onListen: () -> Void

    var body: some View {
        HStack(spacing: SpacingTokens.small) {
            HSMascotView(mood: isPlaying ? .singing : .explaining, size: 46)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(TypographyTokens.headline(15).weight(.bold))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(subtitle)
                    .font(TypographyTokens.caption(12).weight(.medium))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)

            Button(action: onListen) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [ColorTokens.Brand.primaryHi, ColorTokens.Brand.primary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                        .shadow(color: ColorTokens.Brand.primary.opacity(0.4), radius: 8, y: 4)
                    if isPlaying {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(ColorTokens.Overlay.onAccent)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(ColorTokens.Overlay.onAccent)
                            .offset(x: 1)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isDisabled || isPlaying)
            .opacity(isDisabled ? 0.5 : 1)
            .accessibilityLabel(Text(String(
                localized: "record.lesson.listen.a11y",
                defaultValue: "Послушать образец"
            )))
            .accessibilityHint(Text(subtitle))
        }
        .padding(SpacingTokens.small)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .fill(ColorTokens.Kid.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
        )
    }
}

// MARK: - Mic button states

/// Состояния большой центральной кнопки записи.
enum RecordMicState: Equatable {
    case idle        // готов к записи — крупный микрофон
    case recording   // идёт запись — pulse ring + waveform + red dot
    case processing  // обработка/анализ — спиннер
}

/// Большой центральный микрофон (эталон). ≥72pt для детей 5–8.
/// idle: коралловый круг с микрофоном. recording: мягкий пульсирующий ободок +
/// мини-waveform + красная точка. processing: спиннер.
struct RecordMicButton: View {

    let state: RecordMicState
    /// Подсказка под кнопкой, например «Повтори за Лялей».
    var hint: String?
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private var isRecording: Bool { state == .recording }
    private var isProcessing: Bool { state == .processing }

    var body: some View {
        VStack(spacing: SpacingTokens.small) {
            Button(action: onTap) {
                ZStack {
                    if isRecording && !reduceMotion {
                        Circle()
                            .strokeBorder(ColorTokens.Brand.primary.opacity(0.45), lineWidth: 3)
                            .frame(width: 128, height: 128)
                            .scaleEffect(pulse ? 1.35 : 1.0)
                            .opacity(pulse ? 0.0 : 0.6)
                            .animation(
                                .easeOut(duration: 1.6).repeatForever(autoreverses: false),
                                value: pulse
                            )
                    }
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [ColorTokens.Brand.primaryHi, ColorTokens.Brand.primary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 96, height: 96)
                        .shadow(color: ColorTokens.Brand.primary.opacity(0.45), radius: 12, y: 6)
                        .overlay(centerGlyph)
                        .overlay(alignment: .topTrailing) {
                            if isRecording {
                                Circle()
                                    .fill(ColorTokens.Brand.rose)
                                    .frame(width: 18, height: 18)
                                    .overlay(
                                        Circle().strokeBorder(ColorTokens.Kid.bg, lineWidth: 3)
                                    )
                                    .offset(x: -6, y: 6)
                                    .opacity(reduceMotion ? 1 : (pulse ? 0.35 : 1))
                                    .accessibilityHidden(true)
                            }
                        }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .disabled(isProcessing)
            .accessibilityLabel(Text(micA11yLabel))
            .accessibilityHint(Text(micA11yHint))

            if isRecording {
                HSAudioWaveform(style: .recording, tint: ColorTokens.Brand.primary)
                    .frame(height: 32)
                    .frame(maxWidth: 200)
                    .accessibilityHidden(true)
            }

            if let hint, !hint.isEmpty {
                HStack(spacing: SpacingTokens.micro + 2) {
                    if isRecording {
                        Circle()
                            .fill(ColorTokens.Brand.rose)
                            .frame(width: 7, height: 7)
                            .accessibilityHidden(true)
                    }
                    Text(hint)
                        .font(TypographyTokens.headline(14).weight(.bold))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .onAppear { if isRecording && !reduceMotion { pulse = true } }
        .onChange(of: state) { _, newValue in
            pulse = (newValue == .recording) && !reduceMotion
        }
        .onDisappear { pulse = false }
    }

    @ViewBuilder
    private var centerGlyph: some View {
        if isProcessing {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(ColorTokens.Overlay.onAccent)
                .scaleEffect(1.2)
        } else {
            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                .font(.system(size: isRecording ? 34 : 40, weight: .bold))
                .foregroundStyle(ColorTokens.Overlay.onAccent)
                .accessibilityHidden(true)
        }
    }

    private var micA11yLabel: String {
        switch state {
        case .idle:
            return String(localized: "a11y.button.record", defaultValue: "Записать")
        case .recording:
            return String(localized: "a11y.button.stop_record", defaultValue: "Остановить запись")
        case .processing:
            return String(localized: "record.lesson.processing.a11y", defaultValue: "Обработка")
        }
    }

    private var micA11yHint: String {
        switch state {
        case .idle:
            return String(localized: "repeat.button.record.hint", defaultValue: "Нажми и повтори за Лялей")
        case .recording:
            return String(localized: "repeat.button.stop.hint", defaultValue: "Нажми, когда закончишь")
        case .processing:
            return ""
        }
    }
}

// MARK: - Feedback card

/// Карточка результата (эталон): кольцо счёта + звёзды + ободряющий заголовок +
/// описание + маскот-Ляля + CTA. Полностью соответствует тёплой палитре.
struct RecordLessonFeedbackCard: View {

    /// Балл 0…1 для кольца.
    let scoreFraction: Double
    /// Метка под процентом, например «ТОЧНО» (опционально).
    var scoreCaption: String?
    /// Заработанные звёзды 0…3.
    let stars: Int
    /// Ободряющий заголовок, например «Отлично получилось!».
    let title: String
    /// Мягкое описание/подсказка (опционально).
    var detail: String?
    /// Прошёл ли порог (для настроения Ляли).
    let passed: Bool
    /// Текст CTA, например «Дальше».
    let ctaTitle: String
    var ctaIcon: String = "arrow.right"
    /// Accessibility identifier для CTA (для UI-тестов). nil — без идентификатора.
    var ctaIdentifier: String?
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var ringTint: Color {
        scoreFraction >= 0.9 ? ColorTokens.Brand.gold
            : (passed ? ColorTokens.Brand.mint : ColorTokens.Brand.primary)
    }

    var body: some View {
        VStack(spacing: SpacingTokens.small) {
            HStack(spacing: SpacingTokens.regular) {
                ZStack {
                    HSProgressRing(
                        value: scoreFraction,
                        size: 74,
                        lineWidth: 8,
                        color: ringTint,
                        label: " "
                    )
                    VStack(spacing: 0) {
                        Text("\(Int((max(0, min(1, scoreFraction))) * 100))%")
                            .font(TypographyTokens.headline(20).weight(.bold))
                            .foregroundStyle(ColorTokens.Kid.ink)
                            .monospacedDigit()
                        if let scoreCaption, !scoreCaption.isEmpty {
                            Text(scoreCaption)
                                .font(TypographyTokens.caption(9).weight(.bold))
                                .foregroundStyle(ringTint)
                        }
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(String(
                    localized: "record.lesson.score.a11y",
                    defaultValue: "Точность"
                )))
                .accessibilityValue(Text("\(Int((max(0, min(1, scoreFraction))) * 100))%"))

                VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                    Text(title)
                        .font(TypographyTokens.headline(17).weight(.bold))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    starsRow
                    if let detail, !detail.isEmpty {
                        Text(detail)
                            .font(TypographyTokens.caption(13).weight(.medium))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .lineLimit(3)
                            .minimumScaleFactor(0.8)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HSMascotView(mood: passed ? .celebrating : .encouraging, size: 44)
                    .accessibilityHidden(true)
            }

            HSButton(ctaTitle, style: .primary, size: .large, icon: ctaIcon, action: onContinue)
                .padding(.top, SpacingTokens.micro)
                .modifier(OptionalAccessibilityIdentifier(identifier: ctaIdentifier))
        }
        .padding(SpacingTokens.regular)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .fill(ColorTokens.Kid.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
        )
        .shadow(color: ColorTokens.Overlay.shadowMedium, radius: 14, y: 6)
        .accessibilityElement(children: .contain)
    }

    private var starsRow: some View {
        HStack(spacing: SpacingTokens.micro) {
            ForEach(0 ..< 3, id: \.self) { idx in
                Image(systemName: idx < stars ? "star.fill" : "star")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(idx < stars ? ColorTokens.Brand.butter : ColorTokens.Kid.line)
                    .scaleEffect(idx < stars && !reduceMotion ? 1.05 : 1.0)
                    .animation(
                        reduceMotion ? nil : .spring(duration: 0.35).delay(Double(idx) * 0.1),
                        value: stars
                    )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(String(
            localized: "record.lesson.stars.a11y",
            defaultValue: "Звёзд: \(stars) из 3"
        )))
    }
}

// MARK: - Optional accessibility identifier

/// Применяет `.accessibilityIdentifier` только если идентификатор задан.
/// Нужно, чтобы UI-тесты могли адресовать CTA внутри карточки результата.
private struct OptionalAccessibilityIdentifier: ViewModifier {
    let identifier: String?

    func body(content: Content) -> some View {
        if let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("RecordLessonScaffold") {
    ZStack {
        HSMeshGradientBackground(palette: .kidWarm).ignoresSafeArea()
        ScrollView {
            VStack(spacing: SpacingTokens.regular) {
                RecordLessonHeader(sound: "Р", subtitle: "Слово 3 из 8 · твёрдый звук", progress: 0.375)
                RecordLessonWordCard(symbol: "🐟", word: "РЫБА", syllables: ["РЫ", "БА"], onSpeak: {})
                RecordLessonListenRow(onListen: {})
                RecordMicButton(state: .recording, hint: "Повтори за Лялей", onTap: {})
                RecordLessonFeedbackCard(
                    scoreFraction: 0.85,
                    scoreCaption: "ТОЧНО",
                    stars: 3,
                    title: "Отлично получилось!",
                    detail: "Звук «Р» звонкий. Чуть растяни — и совсем как у Ляли.",
                    passed: true,
                    ctaTitle: "Дальше",
                    onContinue: {}
                )
            }
            .padding(SpacingTokens.screenEdge)
        }
    }
    .environment(\.circuitContext, .kid)
}
#endif
