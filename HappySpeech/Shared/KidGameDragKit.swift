import SwiftUI

// MARK: - KidGameDragKit
//
// Общий визуальный язык класса «kid-game-drag» (перетащи · разложи · собери).
// Эталон: happyspeech-design/.../references/kid-game-drag.html.
//
// Используется семью экранами этого класса: DragAndMatch, Sorting,
// SyllableConstructor, SyllableSnail, WordFormation, SentenceBuilder,
// SentenceBuilderKid. Кит покрывает повторяющиеся элементы эталона:
//   • секционная подпись (uppercase, inkSoft);
//   • степ-чип «N из M» со звёздочкой;
//   • поднос (tray) перетаскиваемых плиток на фоне bgDeep;
//   • пустой drop-слот с пунктиром (порядковый номер опционален);
//   • мятная галочка-снап на верно размещённой плитке.
//
// Только View-слой: никаких сервисов, состояний или бизнес-логики.
// Все цвета — через ColorTokens (тёплая палитра; мятный — только как
// мелкий семантический акцент «верно», синий — только как мелкий чип).

// MARK: - Section Label

/// Секционная подпись над группой (эталон `.seclabel`): прописные, разреженные,
/// приглушённый тон. Помогает ребёнку различать «домики», «слова», «слоги».
struct KidSectionLabel: View {
    let title: String

    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title.uppercased())
            .font(TypographyTokens.labelRounded(13, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(ColorTokens.Kid.inkSoft)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Step Chip

/// Степ-чип прогресса «N из M» со звёздочкой (эталон `.step`).
/// Тёплая поверхность с тонкой линией — выглядит как мягкая «таблетка» статуса.
struct KidStepChip: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: SpacingTokens.micro) {
            Image(systemName: "star.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(ColorTokens.Brand.butter)
            Text(verbatim: "\(max(current, 0)) / \(max(total, 0))")
                .font(TypographyTokens.labelRounded(14, weight: .bold))
                .foregroundStyle(ColorTokens.Kid.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, SpacingTokens.small)
        .frame(height: 30)
        .background(
            Capsule(style: .continuous)
                .fill(ColorTokens.Kid.surface)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(ColorTokens.Kid.line, lineWidth: 1.5)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(
            String(format: String(localized: "kidDrag.step.a11y %lld %lld"), current, total)
        ))
    }
}

// MARK: - Tray Container

/// Поднос перетаскиваемых плиток (эталон `.tray` / `.syl-tray`): углублённая
/// тёплая подложка `bgDeep` с тонким контуром, выделяющая зону-источник тайлов
/// из общего фона. Контент передаётся билдером.
struct KidTrayContainer<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .padding(SpacingTokens.small)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .fill(ColorTokens.Kid.bgDeep)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .strokeBorder(ColorTokens.Kid.line, lineWidth: 1.5)
            )
    }
}

// MARK: - Empty Drop Slot

/// Пустой drop-слот (эталон `.empty-slot` / `.slot.empty`): мягкая подложка
/// `surfaceAlt` + коралловый пунктир — явное приглашение «положи сюда».
/// `order` рисует порядковый бейдж сверху (для сборки слова/предложения).
struct KidEmptyDropSlot: View {
    var order: Int?
    var isActive: Bool
    var minHeight: CGFloat

    init(order: Int? = nil, isActive: Bool = false, minHeight: CGFloat = 60) {
        self.order = order
        self.isActive = isActive
        self.minHeight = minHeight
    }

    var body: some View {
        RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
            .fill(ColorTokens.Kid.surfaceAlt)
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                    .strokeBorder(
                        isActive ? ColorTokens.Brand.primary : ColorTokens.Brand.primary.opacity(0.45),
                        style: StrokeStyle(lineWidth: isActive ? 2.5 : 2, dash: [6, 4])
                    )
            )
            .frame(minHeight: minHeight)
            .overlay(alignment: .top) {
                if let order {
                    KidSlotOrderBadge(order: order)
                        .offset(y: -9)
                }
            }
    }
}

// MARK: - Slot Order Badge

/// Круглый бейдж порядкового номера слота (эталон `.slot-order`).
struct KidSlotOrderBadge: View {
    let order: Int

    var body: some View {
        Text(verbatim: "\(order)")
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(ColorTokens.Kid.inkMuted)
            .monospacedDigit()
            .frame(width: 22, height: 22)
            .background(
                Circle().fill(ColorTokens.Kid.bgDeep)
            )
            .overlay(
                Circle().strokeBorder(ColorTokens.Kid.line, lineWidth: 1.5)
            )
            .accessibilityHidden(true)
    }
}

// MARK: - Mint Tick (correct snap)

/// Мятная галочка-снап в углу верно размещённой плитки (эталон `.tick`).
/// Мелкий семантический акцент «верно» — допустимое использование mint.
struct KidCorrectTick: View {
    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 12, weight: .heavy))
            .foregroundStyle(ColorTokens.Overlay.onAccent)
            .frame(width: 24, height: 24)
            .background(
                Circle().fill(ColorTokens.Brand.mint)
            )
            .shadow(color: ColorTokens.Brand.mint.opacity(0.5), radius: 6, y: 2)
            .accessibilityHidden(true)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("KidGameDragKit") {
    VStack(spacing: SpacingTokens.medium) {
        HStack {
            KidSectionLabel("Слоги")
            Spacer()
            KidStepChip(current: 2, total: 6)
        }
        HStack(spacing: SpacingTokens.small) {
            KidEmptyDropSlot(order: 1, isActive: true)
            KidEmptyDropSlot(order: 2)
            KidEmptyDropSlot(order: 3)
        }
        KidTrayContainer {
            HStack(spacing: SpacingTokens.small) {
                ForEach(["МА", "ЛИ", "НА"], id: \.self) { syl in
                    Text(syl)
                        .font(TypographyTokens.title(22))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .frame(width: 64, height: 64)
                        .background(
                            RoundedRectangle(cornerRadius: RadiusTokens.md)
                                .fill(ColorTokens.Kid.surface)
                        )
                        .overlay(alignment: .topTrailing) {
                            if syl == "МА" { KidCorrectTick().offset(x: 8, y: -8) }
                        }
                }
            }
        }
    }
    .padding(SpacingTokens.screenEdge)
    .background(ColorTokens.Kid.bg)
    .environment(\.circuitContext, .kid)
}
#endif
