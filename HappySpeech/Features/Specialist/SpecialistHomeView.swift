import SwiftUI

// MARK: - SpecialistHomeView

struct SpecialistHomeView: View {
    @State private var selectedTab: SpecTab = .children
    @Environment(AppCoordinator.self) private var coordinator

    enum SpecTab: String, CaseIterable {
        case children  = "Дети"
        case sessions  = "Занятия"
        case reports   = "Отчёты"
        case settings  = "Настройки"

        var icon: String {
            switch self {
            case .children: return "person.2.fill"
            case .sessions: return "waveform.path"
            case .reports:  return "doc.text.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(SpecTab.allCases, id: \.self) { tab in
                specTabContent(for: tab)
                    .tabItem {
                        Label(tab.rawValue, systemImage: tab.icon)
                    }
                    .tag(tab)
            }
        }
        .tint(ColorTokens.Spec.accent)
        .environment(\.circuitContext, .specialist)
    }

    @ViewBuilder
    private func specTabContent(for tab: SpecTab) -> some View {
        switch tab {
        case .children: SpecChildListView()
        case .sessions: SpecSessionListView()
        case .reports:  SpecialistReportsView()
        case .settings: SettingsView()
        }
    }
}

// MARK: - SpecChildListView

private struct SpecChildListView: View {
    var body: some View {
        NavigationStack {
            List {
                ForEach(0..<3) { i in
                    SpecChildRow(name: ["Миша", "Соня", "Артём"][i], age: [6, 5, 7][i],
                                 targetSounds: [["Р", "Ш"], ["С", "З"], ["Л"]][i],
                                 lastSession: ["Сегодня", "Вчера", "3 дня назад"][i])
                        .listRowBackground(ColorTokens.Spec.surface)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(ColorTokens.Spec.bg.ignoresSafeArea())
            .navigationTitle(String(localized: "Мои дети"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Add child
                    } label: {
                        Image(systemName: "plus")
                            .accessibilityHidden(true)
                    }
                    .accessibilityLabel(String(localized: "Добавить ребёнка"))
                    .accessibilityHint(String(localized: "Открыть форму создания профиля"))
                }
            }
        }
    }
}

private struct SpecChildRow: View {
    let name: String
    let age: Int
    let targetSounds: [String]
    let lastSession: String

    var body: some View {
        HStack(spacing: SpacingTokens.sp4) {
            // Avatar
            ZStack {
                Circle()
                    .fill(ColorTokens.Spec.accent.opacity(0.12))
                    .frame(width: 48, height: 48)
                Text(String(name.prefix(1)))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(ColorTokens.Spec.accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Spec.ink)

                HStack(spacing: SpacingTokens.sp2) {
                    Text("\(age) лет")
                    Text("·")
                    ForEach(targetSounds, id: \.self) { sound in
                        HSBadge(sound, style: .filled(ColorTokens.Spec.accent))
                    }
                }
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Spec.inkMuted)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(lastSession)
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.Spec.inkMuted)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, SpacingTokens.sp2)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityRowLabel)
        .accessibilityHint(String(localized: "Открыть профиль ребёнка"))
        .accessibilityAddTraits(.isButton)
    }

    private var accessibilityRowLabel: String {
        let sounds = targetSounds.joined(separator: ", ")
        return "\(name), \(age) лет. Целевые звуки: \(sounds). Последнее занятие: \(lastSession)"
    }
}

// MARK: - SpecSessionListView

private struct SpecSessionListView: View {
    @Environment(AppContainer.self) private var container
    @State private var sessions: [SessionDTO] = []
    @State private var isLoading: Bool = true

    /// MVP: используем демо-id ребёнка из preview-сцены. Полноценная
    /// фильтрация по выбранному ребёнку добавляется в M6.16.
    private static let demoChildId = "preview-child-1"

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Spec.bg.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .controlSize(.large)
                        .tint(ColorTokens.Spec.accent)
                } else if sessions.isEmpty {
                    HSEmptyState(
                        icon: "waveform.path",
                        title: String(localized: "Записи занятий"),
                        message: String(localized: "Здесь будут отображаться аудиозаписи и результаты занятий с детьми")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(sessions) { session in
                            ZStack {
                                NavigationLink(value: session.id) {
                                    EmptyView()
                                }
                                .opacity(0)
                                SpecSessionRow(session: session)
                            }
                            .listRowBackground(ColorTokens.Spec.surface)
                            .listRowInsets(EdgeInsets(
                                top: SpacingTokens.tiny,
                                leading: SpacingTokens.regular,
                                bottom: SpacingTokens.tiny,
                                trailing: SpacingTokens.regular
                            ))
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle(String(localized: "Занятия"))
            .navigationDestination(for: String.self) { sessionId in
                SessionReviewView(sessionId: sessionId)
            }
            .task {
                await reload()
            }
        }
    }

    private func reload() async {
        isLoading = true
        do {
            let result = try await container.sessionRepository.fetchAll(childId: Self.demoChildId)
            sessions = result.sorted { $0.date > $1.date }
        } catch {
            HSLogger.app.error("SpecSessionList reload failed: \(error.localizedDescription, privacy: .public)")
            sessions = []
        }
        isLoading = false
    }
}

// MARK: - SpecSessionRow

private struct SpecSessionRow: View {
    let session: SessionDTO

    var body: some View {
        HStack(spacing: SpacingTokens.regular) {
            ZStack {
                Circle()
                    .fill(ColorTokens.Spec.accent.opacity(0.12))
                    .frame(width: 44, height: 44)
                Text(session.targetSound)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(ColorTokens.Spec.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(SessionReviewInteractor.gameName(for: session.templateType))
                    .font(TypographyTokens.body(14).weight(.semibold))
                    .foregroundStyle(ColorTokens.Spec.ink)
                    .lineLimit(1)

                HStack(spacing: SpacingTokens.tiny) {
                    Text(Self.dateFormatter.string(from: session.date))
                    Text("·")
                    Text(String(format: String(localized: "review.row.score"),
                                Int((session.successRate * 100).rounded())))
                }
                .font(TypographyTokens.caption(11))
                .foregroundStyle(ColorTokens.Spec.inkMuted)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.Spec.inkMuted)
                .accessibilityHidden(true)
        }
        .padding(.vertical, SpacingTokens.tiny)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rowAccessibilityLabel)
        .accessibilityHint(String(localized: "review.row.hint"))
        .accessibilityAddTraits(.isButton)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private var rowAccessibilityLabel: String {
        let percent = Int((session.successRate * 100).rounded())
        let date = Self.dateFormatter.string(from: session.date)
        let game = SessionReviewInteractor.gameName(for: session.templateType)
        return String(
            format: String(localized: "review.row.a11y"),
            game,
            session.targetSound,
            date,
            percent
        )
    }
}

// MARK: - Preview

#Preview("Specialist Home") {
    SpecialistHomeView()
        .environment(AppCoordinator())
}
