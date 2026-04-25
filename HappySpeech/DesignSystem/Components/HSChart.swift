import SwiftUI
import Charts

// MARK: - SoundAccuracy

/// Data point for HSChart. Represents accuracy metric of one sound or session.
public struct SoundAccuracy: Identifiable, Sendable, Equatable {
    public let id: String
    public let label: String
    public let value: Double
    public let color: Color

    public init(id: String, label: String, value: Double, color: Color) {
        self.id = id
        self.label = label
        self.value = value
        self.color = color
    }
}

// MARK: - HSChartStyle

public enum HSChartStyle: Sendable {
    case bar
    case line
    case area
}

// MARK: - HSChart

/// Wrapper around Apple Swift Charts. Renders bar, line, or area chart.
/// Tint reflects accuracy: green ≥ 0.8, gold ≥ 0.6, coral < 0.6.
public struct HSChart: View {

    private let data: [SoundAccuracy]
    private let style: HSChartStyle
    private var title: String?

    public init(data: [SoundAccuracy], style: HSChartStyle = .bar) {
        self.data = data
        self.style = style
        self.title = nil
    }

    public var body: some View {
        if data.isEmpty {
            HSEmptyStateView(
                icon: "chart.bar",
                title: String(localized: "ds.hschart.empty.title"),
                message: String(localized: "ds.hschart.empty.message")
            )
        } else {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                if let title {
                    Text(title)
                        .font(TypographyTokens.headline())
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .accessibilityAddTraits(.isHeader)
                }
                chartBody
                    .frame(height: 200)
                    .accessibilityLabel(title ?? String(localized: "ds.hschart.default_label"))
            }
        }
    }

    @ViewBuilder
    private var chartBody: some View {
        switch style {
        case .bar:
            barChart
        case .line:
            lineChart
        case .area:
            areaChart
        }
    }

    // MARK: - Bar

    private var barChart: some View {
        Chart(data) { point in
            BarMark(
                x: .value("Label", point.label),
                y: .value("Value", point.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [Self.tint(for: point.value).opacity(0.85), Self.tint(for: point.value)],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .cornerRadius(RadiusTokens.xs)
            .accessibilityLabel(point.label)
            .accessibilityValue(Self.percentString(point.value))
        }
        .chartYScale(domain: 0...1)
    }

    // MARK: - Line

    private var lineChart: some View {
        Chart(data) { point in
            LineMark(
                x: .value("Label", point.label),
                y: .value("Value", point.value)
            )
            .foregroundStyle(ColorTokens.Brand.primary)
            .interpolationMethod(.catmullRom)

            PointMark(
                x: .value("Label", point.label),
                y: .value("Value", point.value)
            )
            .foregroundStyle(Self.tint(for: point.value))
            .accessibilityLabel(point.label)
            .accessibilityValue(Self.percentString(point.value))
        }
        .chartYScale(domain: 0...1)
    }

    // MARK: - Area

    private var areaChart: some View {
        Chart(data) { point in
            AreaMark(
                x: .value("Label", point.label),
                y: .value("Value", point.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        ColorTokens.Brand.primary.opacity(0.55),
                        ColorTokens.Brand.primary.opacity(0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)
            .accessibilityLabel(point.label)
            .accessibilityValue(Self.percentString(point.value))
        }
        .chartYScale(domain: 0...1)
    }

    // MARK: - Modifiers

    /// Add a chart title displayed above the chart.
    public func chartTitle(_ text: String) -> HSChart {
        var copy = self
        copy.title = text
        return copy
    }

    // MARK: - Helpers

    private static func tint(for value: Double) -> Color {
        switch value {
        case 0.8...:    return ColorTokens.Feedback.correct
        case 0.6..<0.8: return ColorTokens.Brand.gold
        default:        return ColorTokens.Feedback.incorrect
        }
    }

    private static func percentString(_ value: Double) -> String {
        let percent = Int((value * 100).rounded())
        return "\(percent)%"
    }
}

// MARK: - Preview

#Preview("HSChart Bar") {
    HSChart(
        data: [
            SoundAccuracy(id: "s",  label: "С", value: 0.92, color: ColorTokens.Brand.mint),
            SoundAccuracy(id: "z",  label: "З", value: 0.78, color: ColorTokens.Brand.gold),
            SoundAccuracy(id: "ts", label: "Ц", value: 0.55, color: ColorTokens.Brand.primary),
            SoundAccuracy(id: "sh", label: "Ш", value: 0.84, color: ColorTokens.Brand.mint)
        ],
        style: .bar
    )
    .chartTitle("Точность по звукам")
    .padding()
    .background(ColorTokens.Kid.bg)
}

#Preview("HSChart Line") {
    HSChart(
        data: (1...7).map { i in
            SoundAccuracy(id: "d\(i)", label: "Д\(i)", value: Double.random(in: 0.4...1.0),
                          color: ColorTokens.Brand.sky)
        },
        style: .line
    )
    .chartTitle("Прогресс по дням")
    .padding()
    .background(ColorTokens.Kid.bg)
}

#Preview("HSChart Area") {
    HSChart(
        data: (1...7).map { i in
            SoundAccuracy(id: "w\(i)", label: "Н\(i)", value: Double.random(in: 0.5...0.95),
                          color: ColorTokens.Brand.lilac)
        },
        style: .area
    )
    .chartTitle("Недельный охват")
    .padding()
    .background(ColorTokens.Kid.bg)
}

#Preview("HSChart Empty") {
    HSChart(data: [], style: .bar)
        .padding()
        .background(ColorTokens.Kid.bg)
}
