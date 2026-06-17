import SwiftUI

// MARK: - SettingsIconLabelExtras (private, only for this file)
// Зеркальная копия из SettingsViewSections.swift — нужна т.к. оба файла
// являются extensions одного типа в разных файлах; private scope не распространяется.

private struct SettingsIconLabelX: View {
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

// MARK: - SettingsView Sections + Bindings (extras)
//
// Вторая часть секций settings: content/data/performance/calm-mode/
// specialist/karaoke/about + bindings. Извлечено из
// `SettingsViewSections.swift` (Block K.11 v16) для удержания LOC ≤500.

extension SettingsView {

    // MARK: Content

    var contentSection: some View {
        Section {
            Toggle(isOn: autoDownloadBinding) {
                Label {
                    Text(String(localized: "settings.content.autoDownload"))
                        .font(TypographyTokens.body(15))
                } icon: {
                    SettingsIconLabelX("arrow.down.circle.fill", color: ColorTokens.Brand.primary)
                }
            }
            .tint(ColorTokens.Brand.primary)
            .frame(minHeight: 44)

            HStack {
                Label {
                    Text(String(localized: "settings.content.quality"))
                        .font(TypographyTokens.body(15))
                } icon: {
                    SettingsIconLabelX("speaker.wave.3.fill", color: ColorTokens.Brand.butter)
                }
                Spacer()
                Picker("", selection: audioQualityBinding) {
                    ForEach(AudioQuality.allCases, id: \.self) { quality in
                        Text(quality.displayName).tag(quality)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel(String(localized: "settings.a11y.audioQualityPicker"))
                .accessibilityValue(display.settings.audioQuality.displayName)
            }
            .frame(minHeight: 44)
        } header: {
            Text(String(localized: "settings.section.content"))
                .font(TypographyTokens.caption(12).weight(.semibold))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .textCase(.uppercase)
        }
    }

    // MARK: Data

    var dataSection: some View {
        Section {
            Button {
                showExportConfirm = true
            } label: {
                Label {
                    Text(String(localized: "settings.data.export"))
                        .font(TypographyTokens.body(15))
                        .foregroundStyle(ColorTokens.Parent.ink)
                } icon: {
                    SettingsIconLabelX("square.and.arrow.up", color: ColorTokens.Brand.primary)
                }
            }
            .frame(minHeight: 44)
            .accessibilityLabel(String(localized: "settings.data.export"))
            .accessibilityHint(String(localized: "settings.a11y.export.hint"))

            Button(role: .destructive) {
                showClearCacheConfirm = true
            } label: {
                Label {
                    Text(String(localized: "settings.data.clearCache"))
                        .font(TypographyTokens.body(15))
                        .foregroundStyle(ColorTokens.Semantic.error)
                } icon: {
                    Image(systemName: "trash")
                        .foregroundStyle(ColorTokens.Semantic.error)
                }
            }
            .frame(minHeight: 44)
            .accessibilityHint(String(localized: "settings.a11y.clearCache.hint"))
        } header: {
            Text(String(localized: "settings.section.data"))
                .font(TypographyTokens.caption(12).weight(.semibold))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .textCase(.uppercase)
        } footer: {
            Text(String(localized: "settings.data.footer"))
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
        }
    }

    // MARK: Performance

    var performanceSection: some View {
        Section {
            Toggle(isOn: performanceMonitoringBinding) {
                Label {
                    VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                        Text(String(localized: "settings.performance.label"))
                            .font(TypographyTokens.body(15))
                            .foregroundStyle(ColorTokens.Parent.ink)
                        Text(String(localized: "settings.performance.subtitle"))
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                            .lineLimit(nil)
                            .minimumScaleFactor(0.85)
                    }
                } icon: {
                    SettingsIconLabelX("gauge.with.dots.needle.67percent", color: ColorTokens.Brand.rose)
                }
            }
            .tint(ColorTokens.Brand.primary)
            .frame(minHeight: 56)
            .accessibilityLabel(String(localized: "settings.performance.label"))
            .accessibilityValue(display.settings.performanceMonitoringEnabled
                                ? String(localized: "settings.a11y.on")
                                : String(localized: "settings.a11y.off"))
            .accessibilityHint(String(localized: "settings.performance.a11y.hint"))
        } header: {
            Text(String(localized: "settings.section.performance"))
                .font(TypographyTokens.caption(12).weight(.semibold))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .textCase(.uppercase)
        } footer: {
            Text(String(localized: "settings.performance.footer"))
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
        }
    }

    // MARK: Accessibility — Calm Mode (A-08)

    var calmModeSection: some View {
        Section {
            Toggle(isOn: calmModeBinding) {
                Label {
                    VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                        Text(String(localized: "settings.calmMode.label"))
                            .font(TypographyTokens.body(15))
                            .foregroundStyle(ColorTokens.Parent.ink)
                            .lineLimit(nil)
                            .minimumScaleFactor(0.85)
                        Text(String(localized: "settings.calmMode.subtitle"))
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                            .lineLimit(nil)
                            .minimumScaleFactor(0.85)
                    }
                } icon: {
                    // Тёплая иконка (lilac) — спокойствие/мягкость, без off-palette.
                    SettingsIconLabelX("leaf.fill", color: ColorTokens.Brand.lilac)
                }
            }
            .tint(ColorTokens.Brand.primary)
            .frame(minHeight: 56)
            .accessibilityLabel(String(localized: "settings.calmMode.label"))
            .accessibilityValue(display.settings.calmModeEnabled
                                ? String(localized: "settings.a11y.on")
                                : String(localized: "settings.a11y.off"))
            .accessibilityHint(String(localized: "settings.calmMode.a11y.hint"))
        } header: {
            Text(String(localized: "settings.section.accessibility"))
                .font(TypographyTokens.caption(12).weight(.semibold))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .textCase(.uppercase)
        } footer: {
            Text(String(localized: "settings.calmMode.footer"))
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
        }
    }

    // MARK: Specialist

    var specialistSection: some View {
        Section {
            Button {
                showSpecialistSheet = true
            } label: {
                HStack {
                    Label {
                        Text(display.settings.specialistConnected
                             ? String(localized: "settings.specialist.manage")
                             : String(localized: "settings.specialist.connect"))
                            .font(TypographyTokens.body(15))
                            .foregroundStyle(ColorTokens.Parent.ink)
                    } icon: {
                        // P1.1: gold — специалист/доверие вместо зелёного success
                        SettingsIconLabelX(
                            "person.badge.shield.checkmark",
                            color: display.settings.specialistConnected
                                ? ColorTokens.Brand.gold
                                : ColorTokens.Brand.primary
                        )
                    }
                    Spacer()
                    if display.settings.specialistConnected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(ColorTokens.Brand.gold)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(TypographyTokens.caption(13))
                            .foregroundStyle(ColorTokens.Parent.inkSoft)
                    }
                }
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        } header: {
            Text(String(localized: "settings.section.specialist"))
                .font(TypographyTokens.caption(12).weight(.semibold))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .textCase(.uppercase)
        }
    }

    // MARK: Karaoke Mode (S.3 v16)

    var karaokeSection: some View {
        Section {
            NavigationLink(destination: SpeechVisualizationView(word: "сова", targetSound: "С")) {
                Label {
                    Text(String(localized: "settings.karaoke.label"))
                        .font(TypographyTokens.body(15))
                        .foregroundStyle(ColorTokens.Parent.ink)
                } icon: {
                    SettingsIconLabelX("waveform.and.mic", color: ColorTokens.Brand.rose)
                }
            }
            .frame(minHeight: 44)
            .accessibilityLabel(String(localized: "settings.karaoke.label"))
            .accessibilityHint(String(localized: "settings.karaoke.hint"))
        } header: {
            Text(String(localized: "settings.section.karaoke"))
                .font(TypographyTokens.caption(12).weight(.semibold))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .textCase(.uppercase)
        }
    }

    // MARK: About

    var aboutSection: some View {
        Section {
            NavigationLink(destination: ChangelogView()) {
                Label {
                    Text(String(localized: "settings.about.whatsNew"))
                        .font(TypographyTokens.body(15))
                        .foregroundStyle(ColorTokens.Parent.ink)
                } icon: {
                    SettingsIconLabelX("sparkles", color: ColorTokens.Brand.gold)
                }
            }
            .frame(minHeight: 44)
            .accessibilityLabel(String(localized: "settings.about.whatsNew"))
            .accessibilityHint(String(localized: "settings.about.whatsNew.hint"))

            HStack {
                Label {
                    Text(String(localized: "settings.about.version"))
                        .font(TypographyTokens.body(15))
                } icon: {
                    SettingsIconLabelX("info.circle", color: ColorTokens.Brand.primary)
                }
                Spacer()
                Text(display.appVersionLine)
                    .font(TypographyTokens.mono(13))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
            }
            .frame(minHeight: 44)

            Button {
                showPrivacyPolicySheet = true
            } label: {
                Label {
                    Text(String(localized: "settings.about.privacyPolicy"))
                        .font(TypographyTokens.body(15))
                        .foregroundStyle(ColorTokens.Parent.ink)
                } icon: {
                    SettingsIconLabelX("lock.shield", color: ColorTokens.Brand.lilac)
                }
            }
            .frame(minHeight: 44)

            Button {
                showTermsSheet = true
            } label: {
                Label {
                    Text(String(localized: "settings.about.terms"))
                        .font(TypographyTokens.body(15))
                        .foregroundStyle(ColorTokens.Parent.ink)
                } icon: {
                    SettingsIconLabelX("doc.text", color: ColorTokens.Brand.primary)
                }
            }
            .frame(minHeight: 44)

            Button {
                // Перезапуск обзорного тура. Закрываем Settings, чтобы spotlight-overlay
                // лёг поверх основного экрана. exitToParentHome() работает в обоих
                // режимах (top-level и tab), dismiss() — no-op при route-замене.
                container.guidedTourCoordinator.start(force: true)
                exitToParentHome()
            } label: {
                Label {
                    Text(String(localized: "settings.about.tour"))
                        .font(TypographyTokens.body(15))
                        .foregroundStyle(ColorTokens.Parent.ink)
                } icon: {
                    SettingsIconLabelX("lightbulb", color: ColorTokens.Brand.butter)
                }
            }
            .frame(minHeight: 44)
            .accessibilityLabel(String(localized: "settings.about.tour"))
            .accessibilityHint(String(localized: "settings.about.tour.hint"))

            Button {
                if display.licenses.isEmpty {
                    interactor?.loadLicenses(.init())
                }
                showLicensesSheet = true
            } label: {
                Label {
                    Text(String(localized: "settings.about.licenses"))
                        .font(TypographyTokens.body(15))
                        .foregroundStyle(ColorTokens.Parent.ink)
                } icon: {
                    SettingsIconLabelX("doc.plaintext", color: ColorTokens.Brand.primary)
                }
            }
            .frame(minHeight: 44)
            .accessibilityHint(String(localized: "settings.a11y.licenses.hint"))
        } header: {
            Text(String(localized: "settings.section.about"))
                .font(TypographyTokens.caption(12).weight(.semibold))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .textCase(.uppercase)
        }
    }

    // MARK: Bindings

    var themeBinding: Binding<AppTheme> {
        Binding(
            get: { display.settings.theme },
            set: { newValue in interactor?.updateTheme(.init(theme: newValue)) }
        )
    }

    var notificationsToggleBinding: Binding<Bool> {
        Binding(
            get: { display.settings.notificationsEnabled },
            set: { newValue in
                interactor?.toggleNotifications(.init(
                    enabled: newValue,
                    reminderTime: display.settings.reminderTime
                ))
            }
        )
    }

    var reminderTimeBinding: Binding<Date> {
        Binding(
            get: { display.settings.reminderTime },
            set: { newDate in
                interactor?.toggleNotifications(.init(enabled: true, reminderTime: newDate))
            }
        )
    }

    var kidDailyReminderBinding: Binding<Bool> {
        Binding(
            get: { display.settings.kidDailyReminderEnabled },
            set: { newValue in interactor?.toggleKidDailyReminder(.init(enabled: newValue)) }
        )
    }

    var weeklyParentSummaryBinding: Binding<Bool> {
        Binding(
            get: { display.settings.weeklyParentSummaryEnabled },
            set: { newValue in interactor?.toggleWeeklyParentSummary(.init(enabled: newValue)) }
        )
    }

    var autoDownloadBinding: Binding<Bool> {
        Binding(
            get: { display.settings.autoDownload },
            set: { newValue in
                interactor?.updateContent(.init(autoDownload: newValue, audioQuality: nil))
            }
        )
    }

    var audioQualityBinding: Binding<AudioQuality> {
        Binding(
            get: { display.settings.audioQuality },
            set: { newValue in
                interactor?.updateContent(.init(autoDownload: nil, audioQuality: newValue))
            }
        )
    }

    var hapticsLevelBinding: Binding<HapticIntensityLevel> {
        Binding(
            get: { display.settings.hapticsLevel },
            set: { newValue in interactor?.updateHaptics(.init(level: newValue)) }
        )
    }

    var performanceMonitoringBinding: Binding<Bool> {
        Binding(
            get: { display.settings.performanceMonitoringEnabled },
            set: { newValue in
                interactor?.togglePerformanceMonitoring(.init(enabled: newValue))
            }
        )
    }

    var calmModeBinding: Binding<Bool> {
        Binding(
            get: { display.settings.calmModeEnabled },
            set: { newValue in interactor?.toggleCalmMode(.init(enabled: newValue)) }
        )
    }
}
