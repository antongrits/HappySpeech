import SwiftUI

// MARK: - SettingsView Sections + Bindings
//
// Секционные свойства и биндинги вынесены из `SettingsView.swift` для
// соответствия LOC-бюджету (≤700 строк на файл).

extension SettingsView {

    // MARK: Header

    var settingsHeaderSection: some View {
        Section {
            HStack(spacing: SpacingTokens.regular) {
                LyalyaMascotView(state: .idle, size: 72)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    Text(String(localized: "settings.header.greeting"))
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(2).minimumScaleFactor(0.85)
                    Text(String(localized: "settings.header.subtitle"))
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(2).minimumScaleFactor(0.85)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, SpacingTokens.tiny)
            .listRowBackground(Color.clear)
        }
        .listSectionSeparator(.hidden, edges: .bottom)
    }

    // MARK: Appearance

    var appearanceSection: some View {
        Section {
            HStack {
                Label {
                    Text(String(localized: "settings.theme.label"))
                        .font(TypographyTokens.body(15))
                        .foregroundStyle(ColorTokens.Parent.ink)
                } icon: {
                    Image(systemName: "paintpalette.fill")
                        .foregroundStyle(ColorTokens.Parent.accent)
                }
                Spacer()
                Picker("", selection: themeBinding) {
                    Text(AppTheme.system.displayName).tag(AppTheme.system)
                    Text(AppTheme.light.displayName).tag(AppTheme.light)
                    Text(AppTheme.dark.displayName).tag(AppTheme.dark)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
                .accessibilityLabel(String(localized: "settings.a11y.themePicker"))
                .accessibilityValue(display.settings.theme.displayName)
            }
            .frame(minHeight: 44)
        } header: {
            Text(String(localized: "settings.section.appearance"))
                .font(TypographyTokens.caption(12).weight(.semibold))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .textCase(.uppercase)
        }
    }

    // MARK: Lyalya Customization

    var lyalyaCustomizationSection: some View {
        Section {
            Button {
                showCustomizationSheet = true
            } label: {
                HStack(spacing: SpacingTokens.regular) {
                    Label {
                        VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                            Text(String(localized: "settings.customization.label"))
                                .font(TypographyTokens.body(15))
                                .foregroundStyle(ColorTokens.Parent.ink)
                            Text(LyalyaCustomizationStorage.shared.settingsSubtitle)
                                .font(TypographyTokens.caption(12))
                                .foregroundStyle(ColorTokens.Parent.inkMuted)
                        }
                    } icon: {
                        Image(systemName: "paintpalette.fill")
                            .foregroundStyle(ColorTokens.Brand.primary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(TypographyTokens.caption(13))
                        .foregroundStyle(ColorTokens.Parent.inkSoft)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 56)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "settings.customization.label"))
            .accessibilityHint(String(localized: "settings.customization.hint"))
        }
    }

    // MARK: Profile

    var profileSection: some View {
        Section {
            Button {
                showProfileSheet = true
            } label: {
                HStack(spacing: SpacingTokens.regular) {
                    ZStack {
                        Circle()
                            .fill(ColorTokens.Brand.primary.opacity(0.15))
                            .frame(width: 48, height: 48)
                        Image(display.settings.childAvatar)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(SpacingTokens.micro)
                            .frame(width: 48, height: 48)
                            .clipShape(Circle())
                            .accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                        Text(display.settings.childName)
                            .font(TypographyTokens.headline(17))
                            .foregroundStyle(ColorTokens.Parent.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Text(String(
                            format: String(localized: "settings.profile.agePattern"),
                            display.settings.childAge
                        ))
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(TypographyTokens.caption(13))
                        .foregroundStyle(ColorTokens.Parent.inkSoft)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 56)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(
                format: String(localized: "settings.a11y.profile"),
                display.settings.childName,
                display.settings.childAge
            ))
            .accessibilityHint(String(localized: "settings.a11y.profile.hint"))
        } header: {
            Text(String(localized: "settings.section.profile"))
                .font(TypographyTokens.caption(12).weight(.semibold))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .textCase(.uppercase)
        }
    }

    // MARK: Notifications

    var notificationsSection: some View {
        Section {
            Toggle(isOn: notificationsToggleBinding) {
                Label {
                    Text(String(localized: "settings.notifications.label"))
                        .font(TypographyTokens.body(15))
                } icon: {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(ColorTokens.Parent.accent)
                }
            }
            .tint(ColorTokens.Brand.primary)
            .frame(minHeight: 44)
            .accessibilityLabel(String(localized: "settings.notifications.label"))
            .accessibilityValue(display.settings.notificationsEnabled
                                ? String(localized: "settings.a11y.on")
                                : String(localized: "settings.a11y.off"))

            if display.settings.notificationsEnabled {
                DatePicker(
                    String(localized: "settings.notifications.timeLabel"),
                    selection: reminderTimeBinding,
                    displayedComponents: .hourAndMinute
                )
                .frame(minHeight: 44)
                .tint(ColorTokens.Parent.accent)
                .accessibilityHint(String(localized: "settings.a11y.reminderTime.hint"))

                Toggle(isOn: kidDailyReminderBinding) {
                    Label {
                        Text(String(localized: "notifications.toggle.daily"))
                            .font(TypographyTokens.body(15))
                    } icon: {
                        Image(systemName: "bird.fill")
                            .foregroundStyle(ColorTokens.Brand.primary)
                    }
                }
                .tint(ColorTokens.Brand.primary)
                .frame(minHeight: 44)
                .accessibilityLabel(String(localized: "notifications.toggle.daily"))
                .accessibilityValue(display.settings.kidDailyReminderEnabled
                                    ? String(localized: "settings.a11y.on")
                                    : String(localized: "settings.a11y.off"))

                Toggle(isOn: weeklyParentSummaryBinding) {
                    Label {
                        Text(String(localized: "notifications.toggle.weekly"))
                            .font(TypographyTokens.body(15))
                    } icon: {
                        Image(systemName: "calendar.badge.checkmark")
                            .foregroundStyle(ColorTokens.Parent.accent)
                    }
                }
                .tint(ColorTokens.Brand.primary)
                .frame(minHeight: 44)
                .accessibilityLabel(String(localized: "notifications.toggle.weekly"))
                .accessibilityValue(display.settings.weeklyParentSummaryEnabled
                                    ? String(localized: "settings.a11y.on")
                                    : String(localized: "settings.a11y.off"))
            }
        } header: {
            Text(String(localized: "settings.section.notifications"))
                .font(TypographyTokens.caption(12).weight(.semibold))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .textCase(.uppercase)
        } footer: {
            Text(String(localized: "settings.notifications.footer"))
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
        }
    }

    // MARK: Haptics

    var hapticsSection: some View {
        Section {
            HStack {
                Label {
                    VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                        Text(String(localized: "settings.haptics.title"))
                            .font(TypographyTokens.body(15))
                            .foregroundStyle(ColorTokens.Parent.ink)
                        Text(String(localized: "settings.haptics.subtitle"))
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                    }
                } icon: {
                    Image(systemName: "iphone.radiowaves.left.and.right")
                        .foregroundStyle(ColorTokens.Parent.accent)
                }
                Spacer()
                Picker("", selection: hapticsLevelBinding) {
                    Text(String(localized: "settings.haptics.off"))
                        .tag(HapticIntensityLevel.off)
                    Text(String(localized: "settings.haptics.subtle"))
                        .tag(HapticIntensityLevel.subtle)
                    Text(String(localized: "settings.haptics.full"))
                        .tag(HapticIntensityLevel.full)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 190)
                .accessibilityLabel(String(localized: "settings.haptics.title"))
                .accessibilityValue(display.settings.hapticsLevel.rawValue)
            }
            .frame(minHeight: 56)
        } header: {
            Text(String(localized: "settings.haptics.title"))
                .font(TypographyTokens.caption(12).weight(.semibold))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .textCase(.uppercase)
        }
    }
}
