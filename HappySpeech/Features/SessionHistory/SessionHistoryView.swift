import SwiftUI

// MARK: - SessionHistoryView

struct SessionHistoryView: View {
    @Environment(AppContainer.self) private var container
    let childId: String
    @State private var sessions: [SessionSummary] = SessionSummary.sample
    @State private var selectedFilter: HistoryFilter = .all

    var filteredSessions: [SessionSummary] {
        switch selectedFilter {
        case .all:    return sessions
        case .today:
            return sessions.filter { Calendar.current.isDateInToday($0.date) }
        case .week:
            let week = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
            return sessions.filter { $0.date >= week }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterPicker
                List(filteredSessions) { session in
                    SessionHistoryRow(session: session)
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("История занятий")
        }
    }

    private var filterPicker: some View {
        Picker("Фильтр", selection: $selectedFilter) {
            ForEach(HistoryFilter.allCases, id: \.self) { filter in
                Text(filter.displayName).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding(SpacingTokens.medium)
    }
}

// MARK: - HistoryFilter

enum HistoryFilter: CaseIterable {
    case all, today, week
    var displayName: String {
        switch self {
        case .all:   return "Все"
        case .today: return "Сегодня"
        case .week:  return "Неделя"
        }
    }
}

// MARK: - SessionSummary

struct SessionSummary: Identifiable {
    let id: String
    let date: Date
    let targetSound: String
    let template: String
    let successRate: Double
    let durationSec: Int

    static let sample: [SessionSummary] = (0..<10).map { i in
        SessionSummary(
            id: UUID().uuidString,
            date: Calendar.current.date(byAdding: .day, value: -i, to: Date())!,
            targetSound: ["Р", "Л", "С", "Ш"][i % 4],
            template: TemplateType.allCases[i % TemplateType.allCases.count].displayName,
            successRate: Double.random(in: 0.5...0.95),
            durationSec: Int.random(in: 300...900)
        )
    }
}

// MARK: - SessionHistoryRow

struct SessionHistoryRow: View {
    let session: SessionSummary

    var body: some View {
        HStack(spacing: SpacingTokens.medium) {
            ZStack {
                Circle()
                    .fill(scoreColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(session.targetSound)
                    .font(TypographyTokens.headline())
                    .foregroundStyle(scoreColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(session.template)
                    .font(TypographyTokens.body())
                Text(session.date.formatted(date: .abbreviated, time: .shortened))
                    .font(TypographyTokens.caption())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(session.successRate * 100))%")
                    .font(TypographyTokens.headline())
                    .foregroundStyle(scoreColor)
                Text("\(session.durationSec / 60) мин")
                    .font(TypographyTokens.caption())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, SpacingTokens.tiny)
    }

    private var scoreColor: Color {
        session.successRate >= 0.8 ? .green : session.successRate >= 0.5 ? .orange : .red
    }
}
