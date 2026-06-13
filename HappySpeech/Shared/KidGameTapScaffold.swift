import SwiftUI

// MARK: - KidGameTapScaffold
//
// Единый каркас для игр класса «выбери картинку/вариант» (kid-game-tap).
// Реализует эталон `references/kid-game-tap`:
//   • шапка — sound-chip (буква-кружок + «Звук Ш») + шаг «3 из 8» + тонкий
//     коралловый прогресс-бар + круглая кнопка закрытия;
//   • строка «маскот Ляля + коралловый речевой пузырь-вопрос»;
//   • слот контента (сетка карточек / зоны / любой game-specific UI);
//   • опциональная строка обратной связи (мятная «верно» / коралловая «почти»);
//   • нижняя панель действий — капсула «Послушать» + основной CTA «Дальше».
//
// Каркас НЕ содержит бизнес-логики: всё состояние передаётся снаружи через
// конфиг и слоты. Так 16 экранов делят один визуальный язык, сохраняя свои
// VIP-холдеры, данные и оценку.
//
// Инварианты эталона зашиты здесь: тёплая палитра (ColorTokens), симметричные
// отступы (`SpacingTokens.screenEdge` слева=справа), без обрезки текста
// (`lineLimit(nil)` + `minimumScaleFactor`), SE-375 safe, light+dark,
// Dynamic Type, VoiceOver, Reduced Motion (без shake/scale при reduce).

// MARK: - Config types

/// Тон строки обратной связи под сеткой.
enum KidGameFeedbackTone: Equatable {
    /// Верный ответ — мятный семантический акцент (мелкий, по эталону).
    case correct
    /// Неверный / почти — мягкий коралл-error, ободряюще, не резко.
    case incorrect
    /// Нейтральная подсказка — лиловая.
    case hint

    var icon: String {
        switch self {
        case .correct:   return "checkmark.circle.fill"
        case .incorrect: return "arrow.uturn.left.circle.fill"
        case .hint:      return "lightbulb.fill"
        }
    }

    var tint: Color {
        switch self {
        case .correct:   return ColorTokens.Semantic.success
        case .incorrect: return ColorTokens.Semantic.error
        case .hint:      return ColorTokens.Brand.lilac
        }
    }

    var background: Color {
        switch self {
        case .correct:   return ColorTokens.Semantic.successBg
        case .incorrect: return ColorTokens.Semantic.errorBg
        case .hint:      return ColorTokens.Brand.lilac.opacity(0.15)
        }
    }
}

/// Содержимое строки обратной связи.
struct KidGameFeedback: Equatable {
    let tone: KidGameFeedbackTone
    let text: String

    init(_ tone: KidGameFeedbackTone, _ text: String) {
        self.tone = tone
        self.text = text
    }
}

/// Описание основного CTA нижней панели.
struct KidGamePrimaryAction {
    let title: String
    let icon: String
    let isEnabled: Bool
    let action: () -> Void

    init(
        title: String,
        icon: String = "arrow.right",
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isEnabled = isEnabled
        self.action = action
    }
}

/// Описание капсулы «Послушать» (опционально).
struct KidGameListenAction {
    let title: String
    let isPlaying: Bool
    let action: () -> Void

    init(
        title: String = String(localized: "kidGame.listen"),
        isPlaying: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isPlaying = isPlaying
        self.action = action
    }
}

// MARK: - Scaffold

/// Каркас экрана kid-game-tap. Размещает chrome эталона вокруг произвольного
/// контента (`content`), переданного слотом.
struct KidGameTapScaffold<Content: View>: View {

    // MARK: Header
    /// Буква звука в кружке («Ш»). Если nil — sound-chip скрыт.
    let soundLetter: String?
    /// Подпись чипа («Звук Ш»). Используется если задана `soundLetter`.
    let soundTitle: String?
    /// Шаг урока («3 из 8»). Если nil — скрыт.
    let stepLabel: String?
    /// Доля прогресса 0…1. Если nil — прогресс-бар скрыт.
    let progress: Double?

    // MARK: Prompt
    /// Текст вопроса в коралловом пузыре.
    let promptText: String
    /// Маленький kicker над вопросом («Ляля спрашивает»).
    let promptKicker: String
    /// Состояние маскота Ляли.
    let mascotState: LyalyaState

    // MARK: Feedback
    let feedback: KidGameFeedback?

    // MARK: Actions
    let listen: KidGameListenAction?
    let primary: KidGamePrimaryAction?

    // MARK: Close
    /// Действие закрытия (крестик справа сверху). Если nil — кнопка скрыта.
    let onClose: (() -> Void)?

    // MARK: Content slot
    @ViewBuilder let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        soundLetter: String? = nil,
        soundTitle: String? = nil,
        stepLabel: String? = nil,
        progress: Double? = nil,
        promptText: String,
        promptKicker: String = String(localized: "kidGame.prompt.kicker"),
        mascotState: LyalyaState = .pointing,
        feedback: KidGameFeedback? = nil,
        listen: KidGameListenAction? = nil,
        primary: KidGamePrimaryAction? = nil,
        onClose: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.soundLetter = soundLetter
        self.soundTitle = soundTitle
        self.stepLabel = stepLabel
        self.progress = progress
        self.promptText = promptText
        self.promptKicker = promptKicker
        self.mascotState = mascotState
        self.feedback = feedback
        self.listen = listen
        self.primary = primary
        self.onClose = onClose
        self.content = content()
    }

    // MARK: Body

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: SpacingTokens.large) {
                        header
                        promptRow
                        content
                        if let feedback {
                            feedbackRow(feedback)
                        }
                        Spacer(minLength: SpacingTokens.regular)
                    }
                    .frame(minHeight: geo.size.height - bottomBarReserve, alignment: .top)
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.top, SpacingTokens.tiny)
                }
                .scrollBounceBehavior(.basedOnSize)

                if primary != nil || listen != nil {
                    actionBar
                }
            }
        }
    }

    /// Резерв высоты под нижнюю панель (чтобы контент не уходил под неё).
    private var bottomBarReserve: CGFloat {
        (primary != nil || listen != nil) ? 96 : 0
    }

    // MARK: Header

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .center, spacing: SpacingTokens.regular) {
            VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                if soundLetter != nil || stepLabel != nil {
                    HStack(spacing: SpacingTokens.tiny) {
                        if let soundLetter {
                            soundChip(soundLetter)
                        }
                        if let stepLabel {
                            Text(stepLabel)
                                .font(TypographyTokens.caption(13).weight(.bold))
                                .foregroundStyle(ColorTokens.Kid.inkMuted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                                .accessibilityLabel(stepLabel)
                        }
                        Spacer(minLength: 0)
                    }
                }
                if let progress {
                    progressBar(progress)
                }
            }

            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(ColorTokens.Kid.surface))
                        .kidTileShadow()
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "kidGame.close.a11y"))
                .accessibilityAddTraits(.isButton)
            }
        }
        .padding(.top, SpacingTokens.tiny)
    }

    private func soundChip(_ letter: String) -> some View {
        HStack(spacing: SpacingTokens.tiny) {
            Text(letter)
                .font(TypographyTokens.labelRounded(14, weight: .bold))
                .foregroundStyle(ColorTokens.Overlay.onAccent)
                .frame(width: 24, height: 24)
                .background(Circle().fill(ColorTokens.Brand.primary))
            if let soundTitle {
                Text(soundTitle)
                    .font(TypographyTokens.labelRounded(14, weight: .bold))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
        .padding(.leading, SpacingTokens.tiny)
        .padding(.trailing, soundTitle == nil ? SpacingTokens.tiny : SpacingTokens.small)
        .padding(.vertical, SpacingTokens.micro + 2)
        .background(Capsule().fill(ColorTokens.Brand.primaryLo))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(soundTitle ?? String(localized: "Звук \(letter)"))
    }

    private func progressBar(_ value: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(ColorTokens.Kid.line)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [ColorTokens.Brand.primaryHi, ColorTokens.Brand.primary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, geo.size.width * min(1, max(0, value))))
            }
        }
        .frame(height: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "kidGame.progress.a11y"))
        .accessibilityValue(Text("\(Int((min(1, max(0, value))) * 100))%"))
    }

    // MARK: Prompt

    private var promptRow: some View {
        HStack(alignment: .bottom, spacing: SpacingTokens.small) {
            LyalyaMascotView(state: mascotState, size: 64)
                .accessibilityHidden(true)
            promptBubble
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var promptBubble: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.micro) {
            Text(promptKicker.uppercased())
                .font(TypographyTokens.caption(11).weight(.bold))
                .tracking(0.5)
                .foregroundStyle(ColorTokens.Overlay.onAccent.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(promptText)
                .font(TypographyTokens.kidCardTitle(19))
                .foregroundStyle(ColorTokens.Overlay.onAccent)
                .lineLimit(nil)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, SpacingTokens.regular)
        .padding(.vertical, SpacingTokens.small)
        .background(
            UnevenRoundedRectangle(
                cornerRadii: .init(
                    topLeading: RadiusTokens.md,
                    bottomLeading: RadiusTokens.xs / 2,
                    bottomTrailing: RadiusTokens.md,
                    topTrailing: RadiusTokens.md
                ),
                style: .continuous
            )
            .fill(
                LinearGradient(
                    colors: [ColorTokens.Brand.primaryHi, ColorTokens.Brand.primary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(color: ColorTokens.Brand.primary.opacity(0.30), radius: 10, y: 5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(promptKicker). \(promptText)")
    }

    // MARK: Feedback

    private func feedbackRow(_ feedback: KidGameFeedback) -> some View {
        HStack(spacing: SpacingTokens.small) {
            Image(systemName: feedback.tone.icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(ColorTokens.Overlay.onAccent)
                .frame(width: 30, height: 30)
                .background(Circle().fill(feedback.tone.tint))
                .accessibilityHidden(true)
            Text(feedback.text)
                .font(TypographyTokens.body(14).weight(.medium))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, SpacingTokens.regular)
        .padding(.vertical, SpacingTokens.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                .fill(feedback.tone.background)
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                        .strokeBorder(feedback.tone.tint.opacity(0.35), lineWidth: 1)
                )
        )
        .transition(reduceMotion ? .opacity : .scale(scale: 0.96).combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(feedback.text)
    }

    // MARK: Action bar

    private var actionBar: some View {
        HStack(spacing: SpacingTokens.small) {
            if let listen {
                listenButton(listen)
            }
            if let primary {
                primaryButton(primary)
            }
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.top, SpacingTokens.small)
        .padding(.bottom, SpacingTokens.tiny)
        .background(
            ColorTokens.Kid.bg
                .opacity(0.92)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func listenButton(_ listen: KidGameListenAction) -> some View {
        Button(action: listen.action) {
            HStack(spacing: SpacingTokens.tiny) {
                Image(systemName: listen.isPlaying ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 18, weight: .semibold))
                Text(listen.title)
                    .font(TypographyTokens.labelRounded(16, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(ColorTokens.Brand.primary)
            .padding(.horizontal, SpacingTokens.regular)
            .frame(minHeight: 58)
            .background(
                Capsule(style: .continuous)
                    .fill(ColorTokens.Kid.surface)
                    .overlay(Capsule().strokeBorder(ColorTokens.Brand.primary, lineWidth: 1.5))
            )
            .kidTileShadow()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(listen.title)
        .accessibilityAddTraits(.isButton)
    }

    private func primaryButton(_ primary: KidGamePrimaryAction) -> some View {
        Button(action: primary.action) {
            HStack(spacing: SpacingTokens.tiny) {
                Text(primary.title)
                    .font(TypographyTokens.cta())
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                Image(systemName: primary.icon)
                    .font(.system(size: 19, weight: .bold))
            }
            .foregroundStyle(ColorTokens.Overlay.onAccent)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 58)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [ColorTokens.Brand.primaryHi, ColorTokens.Brand.primary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: ColorTokens.Brand.primary.opacity(0.35), radius: 10, y: 5)
            )
            .opacity(primary.isEnabled ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!primary.isEnabled)
        .accessibilityLabel(primary.title)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - KidGameTapCard
//
// Карточка-вариант сетки эталона: квадрат с картинкой/символом в скруглённом
// слоте + подпись + бейдж состояния. Состояния — neutral / correct (мятная
// галочка + мятная обводка, мелкий семантический акцент) / wrong (мягкая
// коралл-error обводка + лёгкий «дрожащий» намёк) / selected.

/// Состояние карточки-варианта.
enum KidGameCardState: Equatable {
    case neutral
    case selected
    case correct
    case wrong
    /// Снижённая яркость (например «улетевшая лишняя» карта).
    case dimmed

    var borderColor: Color {
        switch self {
        case .neutral, .dimmed: return ColorTokens.Kid.line
        case .selected:         return ColorTokens.Brand.primary
        case .correct:          return ColorTokens.Semantic.success
        case .wrong:            return ColorTokens.Semantic.error
        }
    }

    var borderWidth: CGFloat {
        switch self {
        case .neutral, .dimmed: return 1.5
        default:                return 2.5
        }
    }

    var picBackground: Color {
        switch self {
        case .correct: return ColorTokens.Semantic.success.opacity(0.14)
        case .wrong:   return ColorTokens.Semantic.error.opacity(0.10)
        default:       return ColorTokens.Kid.surfaceAlt
        }
    }

    var badgeIcon: String? {
        switch self {
        case .correct: return "checkmark"
        case .wrong:   return "xmark"
        default:       return nil
        }
    }

    var badgeColor: Color {
        self == .correct ? ColorTokens.Semantic.success : ColorTokens.Semantic.error
    }

    var a11ySuffix: String {
        switch self {
        case .correct: return ", " + String(localized: "kidGame.card.correct.a11y")
        case .wrong:   return ", " + String(localized: "kidGame.card.wrong.a11y")
        case .selected: return ", " + String(localized: "kidGame.card.selected.a11y")
        case .neutral, .dimmed: return ""
        }
    }
}

/// Карточка-вариант для сетки kid-game-tap.
struct KidGameTapCard: View {

    /// Имя SF Symbol или asset (`word_*`) — рендерится через `HSContentSymbol`.
    let symbol: String
    /// Подпись (слово). Если nil — показывается только картинка.
    let word: String?
    let state: KidGameCardState
    /// Карточка отключена для нажатий (после раскрытия ответа).
    let isLocked: Bool
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.calmMode) private var calmMode
    @State private var shake = false

    private var calmReduce: Bool { reduceMotion || calmMode }

    init(
        symbol: String,
        word: String? = nil,
        state: KidGameCardState = .neutral,
        isLocked: Bool = false,
        onTap: @escaping () -> Void
    ) {
        self.symbol = symbol
        self.word = word
        self.state = state
        self.isLocked = isLocked
        self.onTap = onTap
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: SpacingTokens.small) {
                HSContentSymbol(symbol, size: 56, tint: ColorTokens.Brand.primary)
                    .frame(width: 84, height: 84)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                            .fill(state.picBackground)
                    )
                    .accessibilityHidden(true)
                if let word {
                    Text(word)
                        .font(TypographyTokens.kidCardTitle(18))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.8)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 148)
            .padding(.horizontal, SpacingTokens.small)
            .padding(.vertical, SpacingTokens.regular)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
            )
            .overlay(alignment: .topTrailing) {
                if let icon = state.badgeIcon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(state.badgeColor))
                        .padding(SpacingTokens.tiny)
                        .accessibilityHidden(true)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .strokeBorder(state.borderColor, lineWidth: state.borderWidth)
            )
            .opacity(state == .dimmed ? 0.5 : 1)
            .kidTileShadow()
            .offset(x: shake ? 6 : 0)
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .scaleEffect(state == .selected && !calmReduce ? 0.97 : 1)
        .animation(calmReduce ? nil : .spring(response: 0.25, dampingFraction: 0.7), value: state)
        .onChange(of: state) { _, newState in
            guard newState == .wrong, !calmReduce else { return }
            withAnimation(.spring(response: 0.12, dampingFraction: 0.35)) { shake = true }
            withAnimation(.spring(response: 0.12, dampingFraction: 0.35).delay(0.12)) { shake = false }
        }
        .accessibilityLabel((word ?? symbol) + state.a11ySuffix)
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(state == .selected || state == .correct ? .isSelected : [])
    }
}

// MARK: - Grid columns helper

extension KidGameTapScaffold {
    /// Стандартная 2-колоночная сетка эталона с симметричными gap'ами.
    static var twoColumnGrid: [GridItem] {
        [
            GridItem(.flexible(), spacing: SpacingTokens.small),
            GridItem(.flexible(), spacing: SpacingTokens.small)
        ]
    }
}

// MARK: - Preview

#if DEBUG
#Preview("KidGameTapScaffold") {
    KidGameTapScaffold(
        soundLetter: "Ш",
        soundTitle: String(localized: "Звук Ш"),
        stepLabel: "3 из 8",
        progress: 0.375,
        promptText: "Найди слово, которое начинается на Ш",
        mascotState: .pointing,
        feedback: KidGameFeedback(.correct, "Молодец! Шапка начинается со звука Ш."),
        listen: KidGameListenAction(action: {}),
        primary: KidGamePrimaryAction(title: String(localized: "Дальше"), action: {}),
        onClose: {}
    ) {
        LazyVGrid(columns: KidGameTapScaffold<EmptyView>.twoColumnGrid, spacing: SpacingTokens.small) {
            KidGameTapCard(symbol: "graduationcap.fill", word: "шапка", state: .correct) {}
            KidGameTapCard(symbol: "cat.fill", word: "кошка", state: .wrong) {}
            KidGameTapCard(symbol: "hare.fill", word: "мышка") {}
            KidGameTapCard(symbol: "car.fill", word: "машина") {}
        }
    }
    .background(ColorTokens.Kid.bg.ignoresSafeArea())
    .environment(\.circuitContext, .kid)
}
#endif
