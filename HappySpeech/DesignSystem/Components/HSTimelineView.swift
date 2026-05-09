import SwiftUI

// MARK: - HSTimelineItem

/// Элемент таймлайна: дата, заголовок, опциональная подпись и иконка.
///
/// `HSTimelineItem` — generic-friendly value type, который ``HSTimelineView`` принимает
/// в виде массива. Соответствие `Identifiable` позволяет использовать `ForEach`
/// без явного `id:` — каждая запись имеет стабильный `UUID`.
public struct HSTimelineItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let date: Date
    public let title: String
    public let subtitle: String?
    public let symbol: String?

    public init(
        id: UUID = UUID(),
        date: Date,
        title: String,
        subtitle: String? = nil,
        symbol: String? = nil
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
    }
}

// MARK: - HSTimelineView

/// Вертикальный таймлайн событий — для progress dashboard и истории достижений.
///
/// `HSTimelineView` рендерит вертикальную линию с node-кружками, на которых сидят
/// иконки или порядковый номер. Каждый узел сопровождает дата, заголовок и опциональная
/// подпись. Анимация появления — staggered spring (нода за нодой), выключается через
/// `accessibilityReduceMotion`.
///
/// ## Пример
/// ```swift
/// HSTimelineView(items: [
///     HSTimelineItem(date: .now, title: "Открыта серия 5 дней", symbol: "flame.fill"),
///     HSTimelineItem(date: .now - 86_400, title: "Завершён урок «Звук С»", symbol: "checkmark.seal.fill")
/// ])
/// ```
///
/// ## See Also
/// - ``HSTimelineItem``
/// - ``ColorTokens``
@available(iOS 17.0, *)
public struct HSTimelineView: View {

    private let items: [HSTimelineItem]
    private let dateFormatter: DateFormatter

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.circuitContext) private var circuit
    @State private var visibleCount: Int = 0

    public init(items: [HSTimelineItem]) {
        self.items = items
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM"
        self.dateFormatter = formatter
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                row(for: item, index: index, isLast: index == items.count - 1)
                    .opacity(reduceMotion || index < visibleCount ? 1 : 0)
                    .offset(y: reduceMotion || index < visibleCount ? 0 : 12)
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.78)
                            .delay(Double(index) * 0.06),
                        value: visibleCount
                    )
            }
        }
        .onAppear {
            if reduceMotion {
                visibleCount = items.count
            } else {
                visibleCount = items.count
            }
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func row(for item: HSTimelineItem, index: Int, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: SpacingTokens.regular) {
            railColumn(symbol: item.symbol, isLast: isLast)
            content(for: item)
                .padding(.bottom, isLast ? 0 : SpacingTokens.regular)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: item))
    }

    @ViewBuilder
    private func railColumn(symbol: String?, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(nodeFill)
                    .frame(width: 28, height: 28)
                Image(systemName: symbol ?? "circle.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
            }
            .accessibilityHidden(true)

            if !isLast {
                Rectangle()
                    .fill(railColor)
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: 28)
    }

    @ViewBuilder
    private func content(for item: HSTimelineItem) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.micro) {
            Text(dateFormatter.string(from: item.date))
                .font(TypographyTokens.caption(12))
                .foregroundStyle(.secondary)
            Text(item.title)
                .font(TypographyTokens.headline(16))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
            if let subtitle = item.subtitle {
                Text(subtitle)
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Colors

    private var nodeFill: Color {
        switch circuit {
        case .kid:        return ColorTokens.Brand.primary
        case .parent:     return ColorTokens.Parent.accent
        case .specialist: return ColorTokens.Spec.accent
        }
    }

    private var railColor: Color {
        switch circuit {
        case .kid:        return ColorTokens.Kid.line
        case .parent:     return ColorTokens.Parent.line
        case .specialist: return ColorTokens.Spec.line
        }
    }

    // MARK: - Accessibility

    private func accessibilityLabel(for item: HSTimelineItem) -> String {
        let datePart = dateFormatter.string(from: item.date)
        if let subtitle = item.subtitle {
            return "\(datePart). \(item.title). \(subtitle)"
        }
        return "\(datePart). \(item.title)"
    }
}

// MARK: - Preview

#if DEBUG
@available(iOS 17.0, *)
#Preview("HSTimelineView Light") {
    let items: [HSTimelineItem] = [
        HSTimelineItem(
            date: Date(),
            title: "Серия 5 дней",
            subtitle: "Так держать!",
            symbol: "flame.fill"
        ),
        HSTimelineItem(
            date: Date().addingTimeInterval(-86_400),
            title: "Урок «Звук С» завершён",
            subtitle: "92% точности — отличный результат",
            symbol: "checkmark.seal.fill"
        ),
        HSTimelineItem(
            date: Date().addingTimeInterval(-86_400 * 2),
            title: "Получена награда «Первый шаг»",
            symbol: "star.fill"
        )
    ]
    return ScrollView {
        HSTimelineView(items: items)
            .padding(SpacingTokens.large)
    }
    .background(ColorTokens.Kid.bg)
    .environment(\.circuitContext, .kid)
}

@available(iOS 17.0, *)
#Preview("HSTimelineView Dark") {
    let items: [HSTimelineItem] = [
        HSTimelineItem(
            date: Date(),
            title: "Серия 5 дней",
            subtitle: "Так держать!",
            symbol: "flame.fill"
        ),
        HSTimelineItem(
            date: Date().addingTimeInterval(-86_400),
            title: "Урок «Звук С» завершён",
            subtitle: "92% точности",
            symbol: "checkmark.seal.fill"
        )
    ]
    return ScrollView {
        HSTimelineView(items: items)
            .padding(SpacingTokens.large)
    }
    .background(ColorTokens.Kid.bg)
    .environment(\.circuitContext, .kid)
    .preferredColorScheme(.dark)
}
#endif
