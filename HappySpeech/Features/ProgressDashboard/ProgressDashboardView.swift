import SwiftUI
import Charts

// MARK: - ProgressDashboardView

struct ProgressDashboardView: View {
    @Environment(AppContainer.self) private var container
    let childId: String
    @State private var selectedSound: String = "Р"
    @State private var progressData: [ProgressPoint] = ProgressPoint.sample
    @State private var streakDays: Int = 5
    @State private var totalMinutes: Int = 127

    private let sounds = ["Р", "Рь", "Л", "Ль", "С", "З", "Ш", "Ж"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SpacingTokens.large) {
                    statsRow
                    soundPicker
                    progressChart
                    stageGrid
                }
                .padding(SpacingTokens.medium)
            }
            .navigationTitle("Прогресс")
        }
    }

    private var statsRow: some View {
        HStack(spacing: SpacingTokens.medium) {
            StatCard(icon: "flame.fill", value: "\(streakDays)", label: "дней подряд", color: .orange)
            StatCard(icon: "clock.fill", value: "\(totalMinutes)", label: "минут всего", color: .blue)
            StatCard(icon: "star.fill", value: "87%", label: "точность", color: .yellow)
        }
    }

    private var soundPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SpacingTokens.small) {
                ForEach(sounds, id: \.self) { sound in
                    Button(sound) { selectedSound = sound }
                        .buttonStyle(SoundChipButtonStyle(isSelected: selectedSound == sound))
                }
            }
            .padding(.horizontal, SpacingTokens.medium)
        }
    }

    private var progressChart: some View {
        Chart(progressData) { point in
            LineMark(
                x: .value("Дата", point.date),
                y: .value("Точность", point.accuracy)
            )
            .foregroundStyle(ColorTokens.Brand.primary)
            .interpolationMethod(.catmullRom)
            AreaMark(
                x: .value("Дата", point.date),
                y: .value("Точность", point.accuracy)
            )
            .foregroundStyle(ColorTokens.Brand.primary.opacity(0.15))
        }
        .chartYScale(domain: 0...1)
        .chartYAxis {
            AxisMarks(values: [0, 0.5, 1.0]) { value in
                AxisValueLabel {
                    if let d = value.as(Double.self) {
                        Text("\(Int(d * 100))%")
                            .font(TypographyTokens.caption())
                    }
                }
            }
        }
        .frame(height: 180)
        .hsCard()
        .padding(.horizontal, SpacingTokens.medium)
    }

    private var stageGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: SpacingTokens.small) {
            ForEach(CorrectionStage.allCases, id: \.self) { stage in
                StageProgressCard(stage: stage, completion: Double.random(in: 0...1))
            }
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: SpacingTokens.tiny) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(TypographyTokens.headline())
                .bold()
            Text(label)
                .font(TypographyTokens.caption())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(SpacingTokens.medium)
        .hsCard()
    }
}

struct SoundChipButtonStyle: ButtonStyle {
    let isSelected: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TypographyTokens.headline())
            .padding(.horizontal, SpacingTokens.medium)
            .padding(.vertical, SpacingTokens.small)
            .background(isSelected ? ColorTokens.Brand.primary : Color(.secondarySystemFill))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(MotionTokens.spring, value: configuration.isPressed)
    }
}

struct StageProgressCard: View {
    let stage: CorrectionStage
    let completion: Double

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            Text(stage.displayName)
                .font(TypographyTokens.caption())
                .foregroundStyle(.secondary)
            HSProgressBar(value: completion)
            Text("\(Int(completion * 100))%")
                .font(TypographyTokens.caption())
                .bold()
        }
        .padding(SpacingTokens.medium)
        .hsCard()
    }
}

// MARK: - Data Models

struct ProgressPoint: Identifiable {
    let id = UUID()
    let date: Date
    let accuracy: Double

    static let sample: [ProgressPoint] = (0..<14).map { i in
        ProgressPoint(date: Calendar.current.date(byAdding: .day, value: -i, to: Date())!,
                      accuracy: Double.random(in: 0.5...0.95))
    }.reversed()
}
