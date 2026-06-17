import SwiftUI

// MARK: - ListenYourselfView · Compare-screen components
//
// Подвью экрана 2 «Сравни с Лялей» вынесены в расширение, чтобы тело основной
// `ListenYourselfView` оставалось обозримым (Clean Swift: View без логики).

extension ListenYourselfView {

    // MARK: - Compare rows (A/B)

    func compareRow(isLyalya: Bool) -> some View {
        HStack(spacing: SpacingTokens.small) {
            ZStack {
                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                    .fill(isLyalya ? ColorTokens.Kid.surface : ColorTokens.Kid.surfaceAlt)
                    .overlay(
                        RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                            .stroke(isLyalya ? ColorTokens.Brand.primaryLo : ColorTokens.Kid.line, lineWidth: 1)
                    )
                if isLyalya {
                    HSMascotView(mood: .happy, size: 38)
                } else {
                    Text("🧒").font(.system(size: 26))
                }
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                Text(isLyalya
                    ? String(localized: "listenYourself.compare.lyalya")
                    : String(localized: "listenYourself.compare.me"))
                    .font(TypographyTokens.kidCardTitle(15))
                    .foregroundStyle(isLyalya ? ColorTokens.Brand.primary : ColorTokens.Kid.ink)
                staticWaveform(tint: isLyalya ? ColorTokens.Brand.primary : ColorTokens.Kid.inkSoft, seed: isLyalya ? 7 : 3)
                    .frame(height: 22)
            }

            Spacer(minLength: 0)

            Button(action: { playCompareRow(isLyalya: isLyalya) }) {
                Image(systemName: "play.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isLyalya ? Color.white : ColorTokens.Kid.ink)
                    .frame(width: 46, height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                            .fill(isLyalya
                                ? AnyShapeStyle(LinearGradient(
                                    colors: [ColorTokens.Brand.primaryHi, ColorTokens.Brand.primary],
                                    startPoint: .top, endPoint: .bottom))
                                : AnyShapeStyle(ColorTokens.Kid.surfaceAlt))
                            .overlay(
                                RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                                    .stroke(isLyalya ? Color.clear : ColorTokens.Kid.line, lineWidth: 1.5)
                            )
                    )
            }
            .accessibilityLabel(isLyalya
                ? String(localized: "listenYourself.playReference.a11y")
                : String(localized: "listenYourself.playMine.a11y"))
        }
        .padding(SpacingTokens.small)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .fill(isLyalya ? ColorTokens.Brand.primaryLo.opacity(0.30) : ColorTokens.Kid.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                        .stroke(isLyalya ? ColorTokens.Brand.primaryLo : ColorTokens.Kid.line, lineWidth: 1.5)
                )
        )
        .accessibilityElement(children: .combine)
    }

    /// Декоративная статичная волна (детерминированная по seed) — НЕ данные оценки,
    /// просто визуальный маркер «запись есть» (как в эталоне).
    func staticWaveform(tint: Color, seed: Int) -> some View {
        HStack(spacing: 2.5) {
            ForEach(0..<10, id: \.self) { i in
                let h = CGFloat(6 + ((i * 5 + seed * 3) % 16))
                Capsule().fill(tint).frame(width: 3, height: h)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Reflect + judge

    var reflectSection: some View {
        VStack(spacing: SpacingTokens.micro) {
            Text(store.judgement == nil
                ? String(localized: "listenYourself.reflect.title")
                : String(format: String(localized: "listenYourself.reflect.chosen"), store.judgement?.title.replacingOccurrences(of: "\n", with: " ") ?? ""))
                .font(TypographyTokens.kidTitle(19))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
            Text(store.judgement == nil
                ? String(localized: "listenYourself.reflect.subtitle")
                : String(localized: "listenYourself.reflect.secretHint"))
                .font(TypographyTokens.kidBody(13))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, SpacingTokens.micro)
    }

    var judgeRow: some View {
        HStack(spacing: SpacingTokens.tiny) {
            ForEach(ListenYourselfModels.SelfJudgement.allCases) { option in
                judgeButton(option)
            }
        }
    }

    func judgeButton(_ option: ListenYourselfModels.SelfJudgement) -> some View {
        let selected = store.judgement == option
        return Button(action: { selfJudge(option) }) {
            VStack(spacing: SpacingTokens.micro) {
                Text(option.emoji).font(.system(size: 30))
                Text(option.title)
                    .font(TypographyTokens.kidCardTitle(12.5))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 84)
            .padding(.vertical, SpacingTokens.small)
            .padding(.horizontal, SpacingTokens.micro)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                            .stroke(selected ? ColorTokens.Brand.primary : ColorTokens.Kid.line,
                                    lineWidth: selected ? 2 : 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title.replacingOccurrences(of: "\n", with: " "))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Secret tip (lilac, опционально)

    var secretTipButton: some View {
        Button(action: { revealSecret() }) {
            HStack(spacing: SpacingTokens.tiny) {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                Text(String(localized: "listenYourself.secret.reveal"))
                    .font(TypographyTokens.kidBody(14))
                    .minimumScaleFactor(0.85)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down").font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(ColorTokens.Brand.lilac)
            .padding(SpacingTokens.small)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                    .fill(ColorTokens.Brand.lilac.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                            .stroke(ColorTokens.Brand.lilac.opacity(0.4), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "listenYourself.secret.reveal"))
        .accessibilityHint(String(localized: "listenYourself.secret.hint"))
    }

    func secretTipBox(_ tip: String) -> some View {
        HStack(alignment: .top, spacing: SpacingTokens.small) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(ColorTokens.Brand.lilac)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                        .fill(ColorTokens.Kid.surface)
                )
            Text(tip)
                .font(TypographyTokens.kidBody(13))
                .foregroundStyle(ColorTokens.Kid.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(SpacingTokens.small)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                .fill(ColorTokens.Brand.lilac.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                        .stroke(ColorTokens.Brand.lilac.opacity(0.4), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "listenYourself.secret.label") + ". " + tip)
    }

    // MARK: - Cues (опоры артикуляции)

    var cuesSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
            Text(String(format: String(localized: "listenYourself.cues.cap"), store.highlightLetter))
                .font(TypographyTokens.kidCardTitle(13))
                .foregroundStyle(ColorTokens.Kid.ink)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: SpacingTokens.tiny) {
                ForEach(store.cues) { cue in
                    VStack(spacing: SpacingTokens.micro) {
                        Text(cue.emoji)
                            .font(.system(size: 24))
                            .frame(width: 44, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                                    .fill(ColorTokens.Kid.surfaceAlt)
                            )
                        Text(cue.label)
                            .font(TypographyTokens.caption(11))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.8)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SpacingTokens.tiny)
                    .padding(.horizontal, SpacingTokens.micro)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                            .fill(ColorTokens.Kid.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                                    .stroke(ColorTokens.Kid.line, lineWidth: 1)
                            )
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(cue.label.replacingOccurrences(of: "\n", with: " "))
                }
            }
        }
    }
}
