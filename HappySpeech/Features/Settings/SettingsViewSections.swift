import SwiftUI

// MARK: - SettingsIconLabel
//
// P1.1: тёплый кружок-иконка для строк настроек (заменяет голый Image в Label).
// Размер 32pt, тёплая заливка Brand.primaryLo.opacity(0.15) + символ в Brand.primary.

private struct SettingsIconLabel: View {
    let systemName: String
    let color: Color

    init(_ systemName: String, color: Color = ColorTokens.Brand.primary) {
        self.systemName = systemName
        self.color = color
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color.opacity(0.15))
                .frame(width: 32, height: 32)
            Image(systemName: systemName)
                .font(TypographyTokens.headline(15))
                .foregroundStyle(color)
        }
        .frame(width: 32, height: 32)
        .accessibilityHidden(true)
    }
}

// MARK: - SettingsView Sections + Bindings
//
// Секционные свойства и биндинги вынесены из `SettingsView.swift` для
// соответствия LOC-бюджету (≤700 строк на файл).

extension SettingsView {

    // MARK: Header
    //
    // Compact tip card — matches reference design: small mascot icon on left,
    // bold title + subtitle on right. No large hero mascot (120pt) in header.
    // The card uses the Parent.surface background with a subtle coral-star accent
    // on the title, identical to the reference "Время вышло на сегодня ⭐" layout.

    var settingsHeaderSection: some View {
        Section {
            HStack(alignment: .center, spacing: SpacingTokens.regular) {
                // Small mascot avatar circle — 56pt, matches reference icon size.
                ZStack {
                    Circle()
                        .fill(ColorTokens.Brand.primaryLo)
                        .frame(width: 56, height: 56)
                    LyalyaMascotView(state: .waving, size: 44)
                        .allowsHitTesting(false)
                }
                .accessibilityHidden(true)
                .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    HStack(spacing: SpacingTokens.micro) {
                        Text(String(localized: "settings.header.greeting"))
                            .font(TypographyTokens.headline(15))
                            .foregroundStyle(ColorTokens.Parent.ink)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .minimumScaleFactor(0.85)
                        // Gold star accent — matches reference "⭐" after title.
                        Image(systemName: "star.fill")
                            .font(TypographyTokens.caption(11))
                            .foregroundStyle(ColorTokens.Brand.gold)
                            .accessibilityHidden(true)
                    }
                    Text(String(localized: "settings.header.subtitle"))
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, SpacingTokens.small)
            .padding(.horizontal, SpacingTokens.regular)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                    .fill(ColorTokens.Parent.surface)
            )
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(
                top: SpacingTokens.small,
                leading: SpacingTokens.medium,
                bottom: SpacingTokens.small,
                trailing: SpacingTokens.medium
            ))
            .listRowSeparator(.hidden)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                String(localized: "settings.header.greeting") + ". " +
                String(localized: "settings.header.subtitle")
            )
        }
        .listSectionSeparator(.hidden, edges: .bottom)
    }

    // MARK: Appearance

    var appearanceSection: some View {
        Section {
            // Block J v18 — заменён системный Picker(.segmented) на HSSegmentedPicker
            // (kavsoft-style underline indicator для parent-контура).
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                // P1.1: тёплая иконка темы (lilac = оформление/кастомизация)
                Label {
                    Text(String(localized: "settings.theme.label"))
                        .font(TypographyTokens.body(15))
                        .foregroundStyle(ColorTokens.Parent.ink)
                } icon: {
                    SettingsIconLabel("paintpalette.fill", color: ColorTokens.Brand.lilac)
                }

                HSSegmentedPicker(
                    selection: themeBinding,
                    items: AppTheme.allCases,
                    style: .underline
                ) { theme in
                    switch theme {
                    case .system: return LocalizedStringKey("theme.system")
                    case .light:  return LocalizedStringKey("theme.light")
                    case .dark:   return LocalizedStringKey("theme.dark")
                    }
                }
                .environment(\.circuitContext, .parent)
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
                    // P1.1: тёплая иконка кастомизации Ляли (rose = маскот/персонаж)
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
                        SettingsIconLabel("face.smiling.inverse", color: ColorTokens.Brand.rose)
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
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .minimumScaleFactor(0.85)
                        Text(String(
                            format: String(localized: "settings.profile.agePattern"),
                            display.settings.childAge
                        ))
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.85)
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

            // Block R.1 v18 — Dialect Adaptation row.
            // Открывает DialectAdaptationView в large sheet.
            Button {
                showDialectAdaptationSheet = true
            } label: {
                HStack(spacing: SpacingTokens.regular) {
                    // P1.1: тёплая иконка диалекта (gold = речь/язык)
                    SettingsIconLabel("waveform.and.mic", color: ColorTokens.Brand.gold)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                        Text(String(localized: "settings.dialect.row.title"))
                            .font(TypographyTokens.body(15))
                            .foregroundStyle(ColorTokens.Parent.ink)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .minimumScaleFactor(0.85)
                        Text(String(localized: "settings.dialect.row.subtitle"))
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .minimumScaleFactor(0.85)
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
            .accessibilityLabel(String(localized: "settings.dialect.row.title"))
            .accessibilityHint(String(localized: "settings.dialect.row.hint"))
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
                    SettingsIconLabel("bell.fill", color: ColorTokens.Brand.butter)
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
                        SettingsIconLabel("bird.fill", color: ColorTokens.Brand.primary)
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
                        SettingsIconLabel("calendar.badge.checkmark", color: ColorTokens.Brand.rose)
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
                    SettingsIconLabel("iphone.radiowaves.left.and.right", color: ColorTokens.Brand.primary)
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
