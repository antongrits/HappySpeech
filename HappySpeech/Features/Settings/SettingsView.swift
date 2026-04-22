import SwiftUI

// MARK: - SettingsView

struct SettingsView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppCoordinator.self) private var coordinator
    @State private var showDeleteAlert = false
    @State private var notificationsEnabled = true
    @State private var notificationHour = 18
    @State private var notificationMinute = 0

    var body: some View {
        NavigationStack {
            List {
                // Appearance
                appearanceSection

                // Notifications
                notificationsSection

                // Account
                accountSection

                // Support
                supportSection

                // Danger zone
                dangerSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(ColorTokens.Parent.bg.ignoresSafeArea())
            .navigationTitle(String(localized: "Настройки"))
        }
        .environment(\.circuitContext, .parent)
    }

    // MARK: - Sections

    private var appearanceSection: some View {
        Section {
            // Theme picker
            @Bindable var binder = themeManager
            Picker(String(localized: "Тема оформления"), selection: $binder.selectedTheme) {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    Text(theme.displayName).tag(theme)
                }
            }
            .accessibilityLabel(String(localized: "Тема: \(themeManager.selectedTheme.displayName)"))
        } header: {
            Text(String(localized: "Внешний вид"))
        }
    }

    private var notificationsSection: some View {
        Section {
            Toggle(String(localized: "Напоминания о занятиях"), isOn: $notificationsEnabled)
                .tint(ColorTokens.Parent.accent)

            if notificationsEnabled {
                HStack {
                    Text(String(localized: "Время напоминания"))
                    Spacer()
                    DatePicker(
                        "",
                        selection: Binding(
                            get: {
                                var c = DateComponents()
                                c.hour = notificationHour
                                c.minute = notificationMinute
                                return Calendar.current.date(from: c) ?? Date()
                            },
                            set: { date in
                                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                                notificationHour = c.hour ?? 18
                                notificationMinute = c.minute ?? 0
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                }
            }
        } header: {
            Text(String(localized: "Уведомления"))
        }
    }

    private var accountSection: some View {
        Section {
            // Sync status
            HStack {
                Label(String(localized: "Синхронизация"), systemImage: "icloud")
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(ColorTokens.Semantic.success)
            }

            // Sign out
            Button {
                // Sign out action
            } label: {
                Label(String(localized: "Выйти из аккаунта"), systemImage: "rectangle.portrait.and.arrow.right")
                    .foregroundStyle(ColorTokens.Parent.ink)
            }
        } header: {
            Text(String(localized: "Аккаунт"))
        }
    }

    private var supportSection: some View {
        Section {
            NavigationLink {
                Text(String(localized: "Раздел помощи"))
            } label: {
                Label(String(localized: "Справка и поддержка"), systemImage: "questionmark.circle")
            }

            NavigationLink {
                PrivacyPolicyView()
            } label: {
                Label(String(localized: "Политика конфиденциальности"), systemImage: "lock.shield")
            }

            HStack {
                Label(String(localized: "Версия приложения"), systemImage: "info.circle")
                Spacer()
                Text("1.0.0")
                    .font(TypographyTokens.mono(12))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
            }
        } header: {
            Text(String(localized: "Поддержка"))
        }
    }

    private var dangerSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Label(String(localized: "Удалить все данные ребёнка"), systemImage: "trash")
            }
        } header: {
            Text(String(localized: "Данные"))
        } footer: {
            Text(String(localized: "Удаление необратимо. Все записи занятий и прогресс будут удалены с устройства и из облака."))
                .font(TypographyTokens.caption(11))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
        }
        .alert(String(localized: "Удалить все данные?"), isPresented: $showDeleteAlert) {
            Button(String(localized: "Удалить"), role: .destructive) {
                // Delete all data
            }
            Button(String(localized: "Отмена"), role: .cancel) {}
        } message: {
            Text(String(localized: "Это действие нельзя отменить. Все данные о занятиях и прогрессе будут удалены."))
        }
    }
}

// MARK: - PrivacyPolicyView

private struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.sp5) {
                Text(String(localized: "Политика конфиденциальности"))
                    .font(TypographyTokens.title())
                    .foregroundStyle(ColorTokens.Parent.ink)

                Text(String(localized: "HappySpeech не передаёт данные третьим лицам и не использует рекламные сети. Все данные хранятся на устройстве и синхронизируются только с вашим аккаунтом Firebase."))
                    .font(TypographyTokens.body())
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
            }
            .padding(SpacingTokens.screenEdge)
        }
        .background(ColorTokens.Parent.bg.ignoresSafeArea())
        .navigationTitle(String(localized: "Конфиденциальность"))
    }
}

// MARK: - Preview

#Preview("Settings") {
    SettingsView()
        .environment(ThemeManager())
        .environment(AppCoordinator())
}
