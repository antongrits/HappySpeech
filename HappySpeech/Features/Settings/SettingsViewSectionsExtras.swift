import SwiftUI

// MARK: - SettingsView Sections + Bindings (extras)
//
// Вторая часть секций settings: content/model packs/data/performance/
// specialist/about + bindings + helpers. Извлечено из
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
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(ColorTokens.Parent.accent)
                }
            }
            .tint(ColorTokens.Brand.primary)
            .frame(minHeight: 44)

            HStack {
                Label {
                    Text(String(localized: "settings.content.quality"))
                        .font(TypographyTokens.body(15))
                } icon: {
                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundStyle(ColorTokens.Parent.accent)
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

    // MARK: Model Packs

    var modelPacksSection: some View {
        Section {
            if display.asrModelItems.isEmpty && display.llmModelItems.isEmpty {
                HStack {
                    ProgressView()
                        .tint(ColorTokens.Parent.accent)
                    Text(String(localized: "settings.models.loading"))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .padding(.leading, SpacingTokens.tiny)
                }
                .frame(minHeight: 44)
            } else {
                ForEach(display.asrModelItems) { item in
                    ModelPackRow(item: item) {
                        handleModelPackTap(item, isASR: true)
                    }
                }
                ForEach(display.llmModelItems) { item in
                    ModelPackRow(item: item) {
                        handleModelPackTap(item, isASR: false)
                    }
                }
            }
        } header: {
            Text(String(localized: "settings.section.models"))
                .font(TypographyTokens.caption(12).weight(.semibold))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .textCase(.uppercase)
        } footer: {
            Text(String(localized: "settings.models.footer"))
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
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
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(ColorTokens.Parent.accent)
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
                    Image(systemName: "gauge.with.dots.needle.67percent")
                        .foregroundStyle(ColorTokens.Parent.accent)
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
                        Image(systemName: "person.badge.shield.checkmark")
                            .foregroundStyle(display.settings.specialistConnected
                                             ? ColorTokens.Semantic.success
                                             : ColorTokens.Parent.accent)
                    }
                    Spacer()
                    if display.settings.specialistConnected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(ColorTokens.Semantic.success)
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

    // MARK: About

    var aboutSection: some View {
        Section {
            NavigationLink(destination: ChangelogView()) {
                Label {
                    Text(String(localized: "settings.about.whatsNew"))
                        .font(TypographyTokens.body(15))
                        .foregroundStyle(ColorTokens.Parent.ink)
                } icon: {
                    Image(systemName: "sparkles")
                        .foregroundStyle(ColorTokens.Brand.primary)
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
                    Image(systemName: "info.circle")
                        .foregroundStyle(ColorTokens.Parent.accent)
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
                    Image(systemName: "lock.shield")
                        .foregroundStyle(ColorTokens.Parent.accent)
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
                    Image(systemName: "doc.text")
                        .foregroundStyle(ColorTokens.Parent.accent)
                }
            }
            .frame(minHeight: 44)

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
                    Image(systemName: "doc.plaintext")
                        .foregroundStyle(ColorTokens.Parent.accent)
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

    // MARK: Model pack helpers

    func handleModelPackTap(_ item: ModelPackRowVM, isASR: Bool) {
        if item.isActive { return }
        if item.isDownloading { return }
        if item.isInstalled {
            pendingDeletePackId = item.id
        } else {
            if isASR, let pack = whisperPack(forId: item.id) {
                interactor?.downloadModelPack(.init(family: .asr(pack)))
            } else if !isASR, let pack = llmPack(forId: item.id) {
                interactor?.downloadModelPack(.init(family: .llm(pack)))
            }
        }
    }

    func whisperPack(forId id: String) -> WhisperKitModelPack? {
        let prefix = "whisper."
        guard id.hasPrefix(prefix) else { return nil }
        let raw = String(id.dropFirst(prefix.count))
        return WhisperKitModelPack(rawValue: raw)
    }

    func llmPack(forId id: String) -> LLMModelPack? {
        let prefix = "llm."
        guard id.hasPrefix(prefix) else { return nil }
        let raw = String(id.dropFirst(prefix.count))
        return LLMModelPack(rawValue: raw)
    }
}
