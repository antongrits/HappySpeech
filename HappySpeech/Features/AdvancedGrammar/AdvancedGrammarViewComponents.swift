import SwiftUI

// MARK: - ModePickerView
//
// Стартовый экран выбора одного из трёх режимов. Тёплые карточки, крупные
// иконки, симметричные отступы. Маскот приглашает.

struct ModePickerView: View {

    let childId: String
    let onSelect: (AdvancedGrammarMode) -> Void
    let onExit: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct ModeCardData {
        let mode: AdvancedGrammarMode
        let icon: String
        let accent: Color
        let title: String
        let hint: String
    }

    private var modes: [ModeCardData] {
        [
            ModeCardData(
                mode: .complexPreposition,
                icon: "arrow.up.and.down.and.arrow.left.and.right",
                accent: ColorTokens.Brand.primary,
                title: String(localized: "advancedGrammar.mode.preposition.title", defaultValue: "Сложные предлоги"),
                hint: String(localized: "advancedGrammar.mode.preposition.card",
                             defaultValue: "Откуда выглянул котёнок? из-за / из-под")
            ),
            ModeCardData(
                mode: .possessive,
                icon: "pawprint.fill",
                accent: ColorTokens.Brand.rose,
                title: String(localized: "advancedGrammar.mode.possessive.title", defaultValue: "Чей? Чья? Чьё?"),
                hint: String(localized: "advancedGrammar.mode.possessive.card",
                             defaultValue: "Чей это хвост? Лисий хвост, заячьи уши")
            ),
            ModeCardData(
                mode: .agreement,
                icon: "text.append",
                accent: ColorTokens.Brand.lilac,
                title: String(localized: "advancedGrammar.mode.agreement.title", defaultValue: "Договори правильно"),
                hint: String(localized: "advancedGrammar.mode.agreement.card",
                             defaultValue: "Красн… машина — выбери окончание")
            )
        ]
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SpacingTokens.regular) {
                header
                VStack(spacing: SpacingTokens.small) {
                    ForEach(modes, id: \.mode) { data in
                        modeCard(data)
                    }
                }
                mascot
            }
            .padding(.horizontal, 22)
            .padding(.top, SpacingTokens.tiny)
            .padding(.bottom, SpacingTokens.large)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaPadding(.bottom, SpacingTokens.small)
    }

    private var header: some View {
        HStack(spacing: SpacingTokens.small) {
            Button { onExit() } label: {
                Image(systemName: "xmark")
                    .font(TypographyTokens.headline(16).weight(.bold))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(ColorTokens.Kid.surfaceAlt))
            }
            .accessibilityLabel(String(localized: "common.close", defaultValue: "Выйти"))

            VStack(spacing: 2) {
                Text(String(localized: "advancedGrammar.picker.title", defaultValue: "Грамматика+"))
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(String(localized: "advancedGrammar.picker.subtitle", defaultValue: "Выбери задание"))
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)

            Color.clear.frame(width: 44, height: 44)
        }
    }

    private func modeCard(_ data: ModeCardData) -> some View {
        Button { onSelect(data.mode) } label: {
            HStack(spacing: SpacingTokens.small) {
                Image(systemName: data.icon)
                    .font(TypographyTokens.headline(24))
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
                    .frame(width: 54, height: 54)
                    .background(Circle().fill(data.accent.opacity(0.92)))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    Text(data.title)
                        .font(TypographyTokens.headline(18).weight(.bold))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .multilineTextAlignment(.leading)
                    Text(data.hint)
                        .font(TypographyTokens.body(13).weight(.medium))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(TypographyTokens.caption(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .accessibilityHidden(true)
            }
            .padding(SpacingTokens.regular)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .fill(data.accent.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .strokeBorder(data.accent.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(data.title)
        .accessibilityHint(data.hint)
    }

    private var mascot: some View {
        HStack(alignment: .bottom, spacing: SpacingTokens.small) {
            LyalyaMascotView(state: reduceMotion ? .idle : .explaining, size: 64)
                .accessibilityHidden(true)
            HSSpeechBubble(
                String(localized: "advancedGrammar.picker.mascot",
                       defaultValue: "Давай построим сложные красивые фразы! Выбери, чем займёмся."),
                direction: .left, style: .lyalya, maxWidth: 250
            )
            Spacer(minLength: 0)
        }
        .padding(.top, SpacingTokens.tiny)
    }
}

// MARK: - PrepositionSceneCard
//
// Наглядная сцена: мебель (коралл) + персонаж выглядывает по-разному в
// зависимости от сцены (позади / снизу / внутри / рядом). Всё нарисовано
// SwiftUI-фигурами. Сверху — «фраза с пропуском» (qbadge).

struct PrepositionSceneCard: View {

    let imageName: String
    let prompt: String
    let scene: PrepositionScene
    let isAnswered: Bool
    let answeredPreposition: String?
    let reduceMotion: Bool

    var body: some View {
        VStack(spacing: SpacingTokens.small) {
            qbadge
            sceneCanvas
        }
        .padding(SpacingTokens.regular)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .fill(LinearGradient(
                    colors: [ColorTokens.Brand.butter.opacity(0.12), ColorTokens.Kid.surface],
                    startPoint: .top, endPoint: .bottom
                ))
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
        )
        .shadow(color: ColorTokens.Overlay.shadow.opacity(0.5), radius: 14, y: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(prompt)
    }

    private var qbadge: some View {
        Text(badgeText)
            .font(TypographyTokens.headline(16).weight(.bold))
            .foregroundStyle(ColorTokens.Kid.ink)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .multilineTextAlignment(.center)
            .padding(.horizontal, SpacingTokens.regular)
            .padding(.vertical, SpacingTokens.tiny)
            .background(Capsule().fill(ColorTokens.Kid.surface))
            .overlay(Capsule().strokeBorder(ColorTokens.Kid.line, lineWidth: 1))
            .shadow(color: ColorTokens.Overlay.shadow.opacity(0.4), radius: 6, y: 3)
    }

    private var badgeText: String {
        if let answeredPreposition {
            return prompt.replacingOccurrences(of: "…", with: answeredPreposition) + " ✓"
        }
        return prompt
    }

    private var sceneCanvas: some View {
        ZStack(alignment: .bottom) {
            // Пол
            VStack(spacing: 0) {
                Spacer()
                Rectangle()
                    .fill(ColorTokens.Kid.line)
                    .frame(height: 2)
                    .padding(.bottom, 30)
            }
            furnitureWithCharacter
        }
        .frame(height: 180)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var furnitureWithCharacter: some View {
        switch scene {
        case .under:
            ZStack(alignment: .bottom) {
                TableShape()
                // мяч/персонаж выкатился снизу-сбоку
                Circle()
                    .fill(RadialGradient(
                        colors: [ColorTokens.Brand.butter, ColorTokens.Brand.gold],
                        center: .topLeading, startRadius: 2, endRadius: 40
                    ))
                    .frame(width: 40, height: 40)
                    .offset(x: 70, y: -32)
                    .shadow(color: ColorTokens.Overlay.shadow, radius: 4, y: 3)
            }
        case .behind:
            ZStack(alignment: .bottom) {
                // персонаж выглядывает из-за левого края
                KittenHead()
                    .offset(x: -64, y: -34)
                ArmchairShape()
            }
        case .inside:
            ZStack(alignment: .bottom) {
                BoxShape()
                KittenHead()
                    .offset(x: 0, y: -56)
            }
        case .beside:
            ZStack(alignment: .bottom) {
                ArmchairShape()
                KittenHead()
                    .offset(x: 78, y: -30)
            }
        }
    }
}

// MARK: Scene shapes

private struct ArmchairShape: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            // спинка
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ColorTokens.Brand.primary.opacity(0.55))
                .frame(width: 92, height: 70)
                .offset(y: -44)
            // подлокотники
            HStack(spacing: 96) {
                Capsule().fill(ColorTokens.Brand.primary.opacity(0.7)).frame(width: 20, height: 52)
                Capsule().fill(ColorTokens.Brand.primary.opacity(0.7)).frame(width: 20, height: 52)
            }
            .offset(y: -14)
            // сиденье
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(ColorTokens.Brand.primaryLo)
                .frame(width: 116, height: 60)
        }
        .padding(.bottom, 30)
        .accessibilityHidden(true)
    }
}

private struct TableShape: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            // столешница
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(ColorTokens.Brand.primary.opacity(0.55))
                .frame(width: 130, height: 16)
                .offset(y: -64)
            // ножки
            HStack(spacing: 96) {
                Rectangle().fill(ColorTokens.Brand.primary.opacity(0.6)).frame(width: 12, height: 64)
                Rectangle().fill(ColorTokens.Brand.primary.opacity(0.6)).frame(width: 12, height: 64)
            }
        }
        .padding(.bottom, 30)
        .accessibilityHidden(true)
    }
}

private struct BoxShape: View {
    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(ColorTokens.Brand.primaryLo)
                .frame(width: 116, height: 74)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(ColorTokens.Brand.primary.opacity(0.5))
                .frame(width: 124, height: 16)
                .offset(y: -8)
        }
        .padding(.bottom, 30)
        .accessibilityHidden(true)
    }
}

/// Голова котёнка (тёплый абрикос) — выглядывает из-за/из-под/из мебели.
private struct KittenHead: View {
    var body: some View {
        ZStack {
            // ушки
            HStack(spacing: 16) {
                Triangle().fill(ColorTokens.Brand.primaryHi).frame(width: 16, height: 18)
                Triangle().fill(ColorTokens.Brand.primaryHi).frame(width: 16, height: 18)
            }
            .offset(y: -22)
            // голова
            Circle()
                .fill(ColorTokens.Brand.primaryHi)
                .frame(width: 46, height: 46)
                .overlay(
                    HStack(spacing: 10) {
                        Circle().fill(ColorTokens.Kid.ink).frame(width: 5, height: 5)
                        Circle().fill(ColorTokens.Kid.ink).frame(width: 5, height: 5)
                    }
                    .offset(y: 2)
                )
                .shadow(color: ColorTokens.Overlay.shadow, radius: 3, y: 2)
        }
        .accessibilityHidden(true)
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

// MARK: - PossessivePartCard
//
// Карточка части тела сверху + вопрос «Чей это?» с подсветкой части.

struct PossessivePartCard: View {

    let imageName: String
    let prompt: String
    let gender: GrammaticalGender?

    var body: some View {
        VStack(spacing: SpacingTokens.small) {
            Text(String(localized: "advancedGrammar.possessive.lbl", defaultValue: "ЧЬЁ ЭТО?"))
                .font(TypographyTokens.body(12).weight(.bold))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .tracking(1)

            HSContentSymbol(imageName, size: 76)
                .frame(width: 120, height: 120)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                        .fill(ColorTokens.Kid.surfaceAlt)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                        .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
                )
                .accessibilityLabel(prompt)

            Text(prompt)
                .font(TypographyTokens.title(24).weight(.black))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
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
}

// MARK: - AgreementObjectCard
//
// Карточка-предмет (картинка задаёт род) + build-фраза с пропуском окончания.

struct AgreementObjectCard: View {

    let imageName: String
    let noun: String
    let gender: GrammaticalGender
    let prompt: String
    let isAnswered: Bool
    let answeredPhrase: String?

    var body: some View {
        VStack(spacing: SpacingTokens.regular) {
            objectRow
            buildPhrase
        }
        .frame(maxWidth: .infinity)
        .padding(SpacingTokens.regular)
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

    private var objectRow: some View {
        HStack(spacing: SpacingTokens.regular) {
            HSContentSymbol(imageName, size: 52)
                .frame(width: 84, height: 84)
                .background(RoundedRectangle(cornerRadius: RadiusTokens.md).fill(ColorTokens.Kid.surfaceAlt))
                .overlay(RoundedRectangle(cornerRadius: RadiusTokens.md).strokeBorder(ColorTokens.Kid.line, lineWidth: 1))
                .accessibilityLabel(noun)

            VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                Text(noun)
                    .font(TypographyTokens.title(24).weight(.black))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                HStack(spacing: SpacingTokens.micro) {
                    Circle().fill(genderDotColor).frame(width: 8, height: 8)
                    Text(genderTag)
                        .font(TypographyTokens.body(12).weight(.bold))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .padding(.horizontal, SpacingTokens.small)
                .padding(.vertical, 5)
                .background(Capsule().fill(ColorTokens.Kid.surfaceAlt))
            }
            Spacer(minLength: 0)
        }
    }

    private var buildPhrase: some View {
        VStack(spacing: SpacingTokens.tiny) {
            Text(String(localized: "advancedGrammar.agreement.build.lbl", defaultValue: "СКАЖИ ВМЕСТЕ"))
                .font(TypographyTokens.body(11).weight(.bold))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .tracking(1)
            Text(phraseText)
                .font(TypographyTokens.title(26).weight(.black))
                .foregroundStyle(isAnswered ? ColorTokens.Brand.primary : ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(SpacingTokens.regular)
        .background(RoundedRectangle(cornerRadius: RadiusTokens.md).fill(ColorTokens.Kid.surfaceAlt))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(phraseText)
    }

    private var phraseText: String {
        if let answeredPhrase { return answeredPhrase + " ✓" }
        return prompt
    }

    private var genderTag: String {
        switch gender {
        case .masculine: return String(localized: "advancedGrammar.tag.he", defaultValue: "он · мужской род")
        case .feminine:  return String(localized: "advancedGrammar.tag.she", defaultValue: "она · женский род")
        case .neuter:    return String(localized: "advancedGrammar.tag.it", defaultValue: "оно · средний род")
        case .plural:    return String(localized: "advancedGrammar.tag.they", defaultValue: "они · их много")
        }
    }

    /// Гендер-точка — мелкий семантический акцент (он=coral, она=rose, оно=lilac, они=mint).
    private var genderDotColor: Color {
        switch gender {
        case .masculine: return ColorTokens.Brand.primary
        case .feminine:  return ColorTokens.Brand.rose
        case .neuter:    return ColorTokens.Brand.lilac
        case .plural:    return ColorTokens.Brand.mint
        }
    }
}

// MARK: - ChoiceCard
//
// Универсальная карточка-вариант. primary — крупный текст, secondary — пример.
// Гендер-акцент окрашивает primary (только притяжательные/согласование).
// Состояния: idle / correct (mint) / wrong (rose-приглушённо) / dimmed.

struct ChoiceCard: View {

    enum State { case idle, correct, wrong, dimmed }

    let choice: AdvancedGrammarChoice
    let state: State
    let compact: Bool
    let reduceMotion: Bool
    let onTap: () -> Void

    @SwiftUI.State private var pressed = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: SpacingTokens.micro) {
                Text(primaryText)
                    .font(TypographyTokens.headline(compact ? 18 : 20).weight(.black))
                    .foregroundStyle(primaryColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(choice.secondary)
                    .font(TypographyTokens.body(compact ? 10 : 11).weight(.bold))
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: compact ? 58 : 64)
            .padding(.vertical, SpacingTokens.small)
            .padding(.horizontal, SpacingTokens.tiny)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .fill(backgroundFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            )
            .opacity(state == .dimmed ? 0.45 : (state == .wrong ? 0.7 : 1))
            .scaleEffect(pressed && !reduceMotion && state == .idle ? 0.96 : 1)
            .shadow(color: ColorTokens.Overlay.shadow.opacity(0.4), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(state != .idle)
        .accessibilityLabel("\(choice.primary), \(choice.secondary)")
        .accessibilityAddTraits(state == .correct ? [.isSelected] : [])
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
    }

    private var primaryText: String {
        state == .correct ? choice.primary + " ✓" : choice.primary
    }

    /// Цвет primary-текста: при верном — mint; иначе гендер-акцент или ink.
    private var primaryColor: Color {
        if state == .correct { return ColorTokens.Brand.mint }
        guard let gender = choice.gender else { return ColorTokens.Kid.ink }
        switch gender {
        case .masculine: return ColorTokens.Brand.primary
        case .feminine:  return ColorTokens.Brand.rose
        case .neuter:    return ColorTokens.Brand.lilac
        case .plural:    return ColorTokens.Brand.mint
        }
    }

    private var backgroundFill: Color {
        switch state {
        case .correct: return ColorTokens.Brand.mint.opacity(0.10)
        case .wrong:   return ColorTokens.Kid.surface
        default:       return ColorTokens.Kid.surface
        }
    }

    private var borderColor: Color {
        switch state {
        case .correct: return ColorTokens.Brand.mint
        case .wrong:   return ColorTokens.Brand.rose.opacity(0.6)
        default:       return ColorTokens.Kid.line
        }
    }

    private var borderWidth: CGFloat {
        state == .correct ? 2.5 : 2
    }
}

// MARK: - AdvancedGrammarCTA

struct AdvancedGrammarCTA: View {
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
            .foregroundStyle(ColorTokens.Overlay.onAccent)
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
