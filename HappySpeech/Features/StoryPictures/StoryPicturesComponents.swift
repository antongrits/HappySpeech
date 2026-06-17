import SwiftUI

// MARK: - StoryPictures sub-components
//
// Переиспользуемые подвью «Рассказа по серии картинок»: слот ленты, карточка
// подноса, кадр плёнки, опора-вопрос, сегмент радар-арки, сцена кадра, CTA.
// Тёплая палитра; mint/gold — только мелкие семантические акценты.

// MARK: - StorySceneView (кадр сцены: вектор + опц. предметный ассет)

struct StorySceneView: View {
    let scene: StoryPictureScene
    let imageAsset: String?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            StoryScenePainter(scene: scene)
            if let imageAsset, !imageAsset.isEmpty {
                // Предметный word_*-ассет накладывается как фокус кадра.
                HSContentSymbol(imageAsset, size: 44)
                    .padding(8)
                    .background(Circle().fill(.ultraThinMaterial))
                    .padding(10)
            }
        }
    }
}

// MARK: - StorySlotView (слот ленты событий)

struct StorySlotView: View {
    let slot: StoryPicturesModels.SlotViewModel
    let reduceMotion: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                    .fill(ColorTokens.Kid.surfaceAlt)
                    .aspectRatio(0.85, contentMode: .fit)
                    .overlay(
                        RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                            .strokeBorder(borderColor, style: StrokeStyle(lineWidth: 2, dash: slot.frame == nil && !slot.isNext ? [4] : []))
                    )
                    .overlay {
                        if let frame = slot.frame {
                            StorySceneView(scene: frame.scene, imageAsset: frame.imageAsset)
                                .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous))
                                .padding(2)
                        } else {
                            Image(systemName: slot.isNext ? "plus" : "circle.fill")
                                .font(.system(size: slot.isNext ? 22 : 8))
                                .foregroundStyle(ColorTokens.Kid.inkSoft.opacity(0.5))
                        }
                    }

                Text("\(slot.number)")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(ColorTokens.Kid.surface))
                    .overlay(Circle().strokeBorder(ColorTokens.Kid.line, lineWidth: 1))
                    .padding(6)
            }
        }
        .buttonStyle(.plain)
        .dropDestination(for: String.self) { items, _ in
            // Drag-drop кадра в слот обрабатывается через onTap-выбор; здесь —
            // дополнительный путь для перетаскивания (handled by parent via selection).
            _ = items
            onTap()
            return true
        }
        .accessibilityLabel(slotA11y)
    }

    private var borderColor: Color {
        if slot.isCorrect { return ColorTokens.Brand.mint }
        if slot.isNext { return ColorTokens.Brand.primary }
        return ColorTokens.Kid.line
    }

    private var slotA11y: String {
        if slot.frame != nil {
            return String(
                format: String(localized: "storyPictures.slot.filled %lld", defaultValue: "Клетка %lld: картинка стоит, нажми чтобы убрать"),
                slot.number
            )
        }
        if slot.isNext {
            return String(
                format: String(localized: "storyPictures.slot.next %lld", defaultValue: "Клетка %lld: сюда следующая картинка"),
                slot.number
            )
        }
        return String(
            format: String(localized: "storyPictures.slot.empty %lld", defaultValue: "Клетка %lld: пустая"),
            slot.number
        )
    }
}

// MARK: - StoryTrayCard (карточка подноса)

struct StoryTrayCard: View {
    let frame: StoryPicturesModels.FrameViewModel
    let isSelected: Bool
    let reduceMotion: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            StorySceneView(scene: frame.scene, imageAsset: frame.imageAsset)
                .aspectRatio(0.9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                        .strokeBorder(ColorTokens.Brand.primary, lineWidth: isSelected ? 3 : 2)
                )
                .overlay(alignment: .bottom) {
                    Capsule()
                        .fill(ColorTokens.Brand.primary.opacity(0.45))
                        .frame(width: 26, height: 5)
                        .padding(.bottom, 6)
                }
                .shadow(color: ColorTokens.Brand.primary.opacity(isSelected ? 0.5 : 0.3), radius: isSelected ? 12 : 8, y: 4)
                .rotationEffect(.degrees(isSelected && !reduceMotion ? -4 : 0))
                .scaleEffect(isSelected && !reduceMotion ? 1.04 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "storyPictures.tray.card.a11y", defaultValue: "Картинка истории, поставь её в нужную клетку"))
    }
}

// MARK: - StoryFilmFrame (кадр плёнки на экране рассказа)

struct StoryFilmFrame: View {
    let frame: StoryPicturesModels.FrameViewModel
    let isCurrent: Bool
    let isTold: Bool

    var body: some View {
        StorySceneView(scene: frame.scene, imageAsset: frame.imageAsset)
            .aspectRatio(1.2, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                    .strokeBorder(isCurrent ? ColorTokens.Brand.primary : ColorTokens.Kid.line, lineWidth: isCurrent ? 2 : 1)
            )
            .overlay(alignment: .topTrailing) {
                if isTold {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(ColorTokens.Brand.mint))
                        .padding(3)
                }
            }
            .opacity(isCurrent ? 1 : (isTold ? 0.85 : 0.55))
            .accessibilityHidden(true)
    }
}

// MARK: - StorySupportCard (опора-вопрос)

struct StorySupportCard: View {
    let support: StoryPicturesModels.SupportViewModel

    var body: some View {
        VStack(spacing: SpacingTokens.tiny) {
            Text(support.question)
                .font(TypographyTokens.headline(12).weight(.bold))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            HStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(support.isNamed ? ColorTokens.Brand.mint : Color.clear)
                        .frame(width: 13, height: 13)
                        .overlay(
                            Circle().strokeBorder(support.isNamed ? Color.clear : ColorTokens.Kid.inkSoft, lineWidth: 2)
                        )
                    if support.isNamed {
                        Image(systemName: "checkmark")
                            .font(.system(size: 7, weight: .black))
                            .foregroundStyle(.white)
                    }
                }
                Text(support.answerHint)
                    .font(TypographyTokens.body(11).weight(.bold))
                    .foregroundStyle(support.isNamed ? ColorTokens.Brand.mint : ColorTokens.Kid.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpacingTokens.small)
        .padding(.horizontal, SpacingTokens.tiny)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.sm)
                .fill(support.isNamed ? ColorTokens.Brand.mint.opacity(0.08) : ColorTokens.Kid.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.sm)
                .strokeBorder(support.isNamed ? ColorTokens.Brand.mint.opacity(0.45) : ColorTokens.Kid.line, lineWidth: 1.5)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(supportA11y)
    }

    private var supportA11y: String {
        let status = support.isNamed
            ? String(localized: "storyPictures.support.named", defaultValue: "названо")
            : String(localized: "storyPictures.support.pending", defaultValue: "ещё не названо")
        return "\(support.question) \(support.answerHint), \(status)"
    }
}

// MARK: - StoryArcSegment (сегмент радар-арки полноты)

struct StoryArcSegment: View {
    let segment: StoryPicturesModels.ArcViewModel.Segment
    let reduceMotion: Bool

    var body: some View {
        VStack(spacing: SpacingTokens.tiny) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(ColorTokens.Kid.line)
                    Capsule()
                        .fill(barFill)
                        .frame(width: max(0, geo.size.width * CGFloat(segment.fill)))
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.5), value: segment.fill)
                }
            }
            .frame(height: 9)

            VStack(spacing: 1) {
                Text(segment.title)
                    .font(TypographyTokens.headline(12).weight(.bold))
                    .foregroundStyle(segment.isComplete ? ColorTokens.Kid.ink : ColorTokens.Brand.gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(segment.summary)
                    .font(TypographyTokens.body(11).weight(.semibold))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(segment.title): \(segment.summary)")
    }

    private var barFill: LinearGradient {
        let colors = segment.isComplete
            ? [ColorTokens.Brand.mint, ColorTokens.Brand.mint.opacity(0.7)]
            : [ColorTokens.Brand.gold, ColorTokens.Brand.gold.opacity(0.7)]
        return LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
    }
}

// MARK: - StoryPicturesCTA

struct StoryPicturesCTA: View {
    let title: String
    let icon: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SpacingTokens.small) {
                Text(title)
                    .font(TypographyTokens.cta())
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)
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
            .opacity(enabled ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: - FlexibleHStack (перенос пилюль на узких экранах)

/// Простой wrap-layout для ряда пилюль-достижений: переносит на новую строку,
/// если не помещается. Без обрезки текста на узком SE.
struct FlexibleHStack: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[CGSize]] = [[]]
        var rowWidth: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if rowWidth + size.width + (rows[rows.count - 1].isEmpty ? 0 : spacing) > maxWidth {
                rows.append([size])
                rowWidth = size.width
            } else {
                rowWidth += size.width + (rows[rows.count - 1].isEmpty ? 0 : spacing)
                rows[rows.count - 1].append(size)
            }
        }
        var height: CGFloat = 0
        for row in rows {
            let rowHeight: CGFloat = row.map { $0.height }.max() ?? 0
            height += rowHeight + (height == 0 ? 0 : spacing)
        }
        return CGSize(width: maxWidth == .infinity ? rowWidth : maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
