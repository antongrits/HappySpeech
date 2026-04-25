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
    var body: some View {
        NavigationStack {
            HSEmptyState(
                icon: "waveform.path",
                title: String(localized: "Записи занятий"),
                message: String(localized: "Здесь будут отображаться аудиозаписи и результаты занятий с детьми")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ColorTokens.Spec.bg.ignoresSafeArea())
            .navigationTitle(String(localized: "Занятия"))
        }
    }
}

// MARK: - Preview

#Preview("Specialist Home") {
    SpecialistHomeView()
        .environment(AppCoordinator())
}
