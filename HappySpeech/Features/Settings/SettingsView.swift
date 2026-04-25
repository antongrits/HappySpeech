import SwiftUI
import OSLog

// MARK: - SettingsView
//
// Parent-контур. 7 секций настроек: оформление, профиль ребёнка, уведомления,
// контент, данные, специалист, о приложении. Каждая ячейка управляется через
// Interactor; `SettingsDisplay` хранит производное состояние, View использует
// биндинги через специальные накладки (`localBindings`).
//
// VIP: View → Interactor (запросы) → Presenter (форматирование) → Display.

struct SettingsView: View {

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    // MARK: - VIP State

    @State private var display = SettingsDisplay()
    @State private var interactor: SettingsInteractor?
    @State private var presenter: SettingsPresenter?
    @State private var router: SettingsRouter?
    @State private var bootstrapped = false

    // MARK: - Local UI state

    @State private var showClearCacheConfirm = false
    @State private var showExportConfirm = false
    @State private var showProfileSheet = false
    @State private var showSpecialistSheet = false
    @State private var showPrivacyPolicySheet = false
    @State private var showTermsSheet = false
    @State private var showLicensesSheet = false
    @State private var selectedLicense: OpenSourceLicenseVM?
    @State private var showShareSheet = false
    @State private var pendingDeletePackId: String?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "SettingsView")

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ColorTokens.Parent.bg.ignoresSafeArea()

                List {
                    appearanceSection
                    profileSection
                    notificationsSection
                    contentSection
                    modelPacksSection
                    dataSection
                    specialistSection
                    aboutSection
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(ColorTokens.Parent.bg)

                if let toast = display.toastMessage {
                    HSToast(toast, type: display.toastIsError ? .error : .success)
                        .padding(.bottom, SpacingTokens.large)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task {
                            try? await Task.sleep(for: .seconds(2.6))
                            withAnimation(.easeInOut(duration: 0.25)) {
                                display.clearToast()
                            }
                        }
                }
            }
            .navigationTitle(String(localized: "settings.navTitle"))
            .navigationBarTitleDisplayMode(.large)
            .confirmationDialog(
                String(localized: "settings.cache.confirm.title"),
                isPresented: $showClearCacheConfirm,
                titleVisibility: .visible
            ) {
                Button(String(localized: "settings.cache.confirm.action"), role: .destructive) {
                    interactor?.clearCache(.init())
                }
                Button(String(localized: "settings.cache.confirm.cancel"), role: .cancel) {}
            } message: {
                Text(String(localized: "settings.cache.confirm.message"))
            }
            .confirmationDialog(
                String(localized: "settings.export.confirm.title"),
                isPresented: $showExportConfirm,
                titleVisibility: .visible
            ) {
                Button(String(localized: "settings.export.confirm.action")) {
                    let userId = display.settings.specialistConnected
                        ? display.settings.specialistCode
                        : "anonymous"
                    interactor?.exportShare(.init(userId: userId))
                }
                Button(String(localized: "settings.export.confirm.cancel"), role: .cancel) {}
            } message: {
                Text(String(localized: "settings.export.confirm.message"))
            }
            .confirmationDialog(
                String(localized: "settings.models.delete.confirm.title"),
                isPresented: Binding(
                    get: { pendingDeletePackId != nil },
                    set: { if !$0 { pendingDeletePackId = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(String(localized: "settings.models.delete.confirm.action"), role: .destructive) {
                    if let id = pendingDeletePackId {
                        if let pack = whisperPack(forId: id) {
                            interactor?.deleteModelPack(.init(family: .asr(pack)))
                        } else if let pack = llmPack(forId: id) {
                            interactor?.deleteModelPack(.init(family: .llm(pack)))
                        }
                    }
                    pendingDeletePackId = nil
                }
                Button(String(localized: "settings.models.delete.confirm.cancel"), role: .cancel) {
                    pendingDeletePackId = nil
                }
            } message: {
                Text(String(localized: "settings.models.delete.confirm.message"))
            }
            .sheet(isPresented: $showProfileSheet) {
                SettingsProfileEditor(
                    name: display.settings.childName,
                    age: display.settings.childAge,
                    avatar: display.settings.childAvatar,
                    availableAvatars: display.availableAvatars,
                    availableAges: display.availableAges
                ) { name, age, avatar in
                    showProfileSheet = false
                    interactor?.updateProfile(.init(name: name, age: age, avatar: avatar))
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showSpecialistSheet) {
                SettingsSpecialistConnectSheet(
                    initialCode: display.settings.specialistCode,
                    isConnected: display.settings.specialistConnected
                ) { code in
                    showSpecialistSheet = false
                    interactor?.connectSpecialist(.init(code: code))
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showPrivacyPolicySheet) {
                SettingsLegalSheet(
                    title: String(localized: "settings.about.privacyPolicy"),
                    bodyText: String(localized: "settings.about.privacyPolicy.body")
                )
            }
            .sheet(isPresented: $showTermsSheet) {
                SettingsLegalSheet(
                    title: String(localized: "settings.about.terms"),
                    bodyText: String(localized: "settings.about.terms.body")
                )
            }
            .sheet(isPresented: $showLicensesSheet) {
                SettingsLicensesListSheet(
                    licenses: display.licenses,
                    onSelect: { license in
                        selectedLicense = license
                    }
                )
            }
            .sheet(item: $selectedLicense) { license in
                SettingsLicenseDetailSheet(license: license)
            }
            .sheet(isPresented: $showShareSheet, onDismiss: {
                display.clearShareFile()
            }) {
                if let url = display.shareFileURL {
                    SettingsShareSheet(items: [url])
                }
            }
            .onChange(of: display.shareFileURL) { _, newValue in
                if newValue != nil { showShareSheet = true }
            }
        }
        .environment(\.circuitContext, .parent)
        .task { await bootstrap() }
    }

    // MARK: - Section 1: Appearance

    private var appearanceSection: some View {
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

    // MARK: - Section 2: Profile

    private var profileSection: some View {
        Section {
            Button {
                showProfileSheet = true
            } label: {
                HStack(spacing: SpacingTokens.regular) {
                    ZStack {
                        Circle()
                            .fill(ColorTokens.Brand.primary.opacity(0.15))
                            .frame(width: 48, height: 48)
                        Text(verbatim: display.settings.childAvatar)
                            .font(.system(size: 26))
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
                        .font(.system(size: 13, weight: .semibold))
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

    // MARK: - Section 3: Notifications

    private var notificationsSection: some View {
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
            }
        } header: {
            Text(String(localized: "settings.section.notifications"))
                .font(TypographyTokens.caption(12).weight(.semibold))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .textCase(.uppercase)
        } footer: {
            Text(String(localized: "settings.notifications.footer"))
                .font(TypographyTokens.caption(11))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
        }
    }

    // MARK: - Section 4: Content

    private var contentSection: some View {
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

    // MARK: - Section 4.5: Model Packs

    private var modelPacksSection: some View {
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
                .font(TypographyTokens.caption(11))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
        }
    }

    private func handleModelPackTap(_ item: ModelPackRowVM, isASR: Bool) {
        if item.isActive { return }                 // активный — ничего не делаем
        if item.isDownloading { return }            // в процессе — игнор
        if item.isInstalled {
            // Удаление с подтверждением.
            pendingDeletePackId = item.id
        } else {
            // Скачивание.
            if isASR, let pack = whisperPack(forId: item.id) {
                interactor?.downloadModelPack(.init(family: .asr(pack)))
            } else if !isASR, let pack = llmPack(forId: item.id) {
                interactor?.downloadModelPack(.init(family: .llm(pack)))
            }
        }
    }

    private func whisperPack(forId id: String) -> WhisperKitModelPack? {
        let prefix = "whisper."
        guard id.hasPrefix(prefix) else { return nil }
        let raw = String(id.dropFirst(prefix.count))
        return WhisperKitModelPack(rawValue: raw)
    }

    private func llmPack(forId id: String) -> LLMModelPack? {
        let prefix = "llm."
        guard id.hasPrefix(prefix) else { return nil }
        let raw = String(id.dropFirst(prefix.count))
        return LLMModelPack(rawValue: raw)
    }

    // MARK: - Section 5: Data

    private var dataSection: some View {
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
                .font(TypographyTokens.caption(11))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
        }
    }

    // MARK: - Section 6: Specialist

    private var specialistSection: some View {
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
                            .font(.system(size: 13, weight: .semibold))
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

    // MARK: - Section 7: About

    private var aboutSection: some View {
        Section {
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

    // MARK: - Bindings

    private var themeBinding: Binding<AppTheme> {
        Binding(
            get: { display.settings.theme },
            set: { newValue in
                interactor?.updateTheme(.init(theme: newValue))
            }
        )
    }

    private var notificationsToggleBinding: Binding<Bool> {
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

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: { display.settings.reminderTime },
            set: { newDate in
                interactor?.toggleNotifications(.init(
                    enabled: true,
                    reminderTime: newDate
                ))
            }
        )
    }

    private var autoDownloadBinding: Binding<Bool> {
        Binding(
            get: { display.settings.autoDownload },
            set: { newValue in
                interactor?.updateContent(.init(autoDownload: newValue, audioQuality: nil))
            }
        )
    }

    private var audioQualityBinding: Binding<AudioQuality> {
        Binding(
            get: { display.settings.audioQuality },
            set: { newValue in
                interactor?.updateContent(.init(autoDownload: nil, audioQuality: newValue))
            }
        )
    }

    // MARK: - Bootstrap

    @MainActor
    private func bootstrap() async {
        guard !bootstrapped else { return }
        bootstrapped = true

        let interactor = SettingsInteractor(
            themeManager: container.themeManager,
            notificationService: container.notificationService,
            whisperKitModelManager: container.whisperKitModelManager,
            llmModelManager: container.llmModelManager
        )
        let presenter = SettingsPresenter()
        let router = SettingsRouter()

        interactor.presenter = presenter
        presenter.display = display

        self.interactor = interactor
        self.presenter = presenter
        self.router = router

        interactor.loadSettings(.init())
        interactor.loadModelPacks(.init())
        interactor.loadLicenses(.init())
    }
}

// MARK: - SettingsProfileEditor

private struct SettingsProfileEditor: View {

    @Environment(\.dismiss) private var dismiss

    let availableAvatars: [String]
    let availableAges: [Int]

    @State private var name: String
    @State private var age: Int
    @State private var avatar: String

    private let onSave: (String, Int, String) -> Void

    init(
        name: String,
        age: Int,
        avatar: String,
        availableAvatars: [String],
        availableAges: [Int],
        onSave: @escaping (String, Int, String) -> Void
    ) {
        self._name = State(initialValue: name)
        self._age = State(initialValue: age)
        self._avatar = State(initialValue: avatar)
        self.availableAvatars = availableAvatars
        self.availableAges = availableAges
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.large) {
                    avatarPicker
                    nameField
                    agePicker
                    Spacer(minLength: SpacingTokens.large)
                    HSButton(
                        String(localized: "settings.profile.save"),
                        style: .primary,
                        size: .large,
                        icon: "checkmark"
                    ) {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(
                            trimmed.isEmpty ? String(localized: "settings.profile.defaultName") : trimmed,
                            age,
                            avatar
                        )
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.vertical, SpacingTokens.large)
            }
            .background(ColorTokens.Parent.bg.ignoresSafeArea())
            .navigationTitle(String(localized: "settings.profile.editorTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "settings.profile.cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var avatarPicker: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
            Text(String(localized: "settings.profile.avatarHeader"))
                .font(TypographyTokens.caption(12).weight(.semibold))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .textCase(.uppercase)
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.tiny), count: 6),
                spacing: SpacingTokens.tiny
            ) {
                ForEach(availableAvatars, id: \.self) { item in
                    Button {
                        avatar = item
                    } label: {
                        Text(verbatim: item)
                            .font(.system(size: 28))
                            .frame(width: 48, height: 48)
                            .background(
                                Circle().fill(
                                    avatar == item
                                        ? ColorTokens.Brand.primary.opacity(0.18)
                                        : ColorTokens.Parent.surface
                                )
                            )
                            .overlay(
                                Circle().strokeBorder(
                                    avatar == item ? ColorTokens.Brand.primary : ColorTokens.Parent.line,
                                    lineWidth: avatar == item ? 2 : 1
                                )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(
                        format: String(localized: "settings.a11y.avatar"),
                        item
                    ))
                    .accessibilityAddTraits(avatar == item ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
            Text(String(localized: "settings.profile.nameHeader"))
                .font(TypographyTokens.caption(12).weight(.semibold))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .textCase(.uppercase)
            TextField(
                String(localized: "settings.profile.namePlaceholder"),
                text: $name
            )
            .textFieldStyle(.plain)
            .font(TypographyTokens.body(16))
            .padding(SpacingTokens.regular)
            .frame(minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.md)
                    .fill(ColorTokens.Parent.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.md)
                    .strokeBorder(ColorTokens.Parent.line, lineWidth: 1)
            )
        }
    }

    private var agePicker: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
            Text(String(localized: "settings.profile.ageHeader"))
                .font(TypographyTokens.caption(12).weight(.semibold))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .textCase(.uppercase)
            Picker(
                String(localized: "settings.profile.ageHeader"),
                selection: $age
            ) {
                ForEach(availableAges, id: \.self) { value in
                    Text(String(
                        format: String(localized: "settings.profile.ageOptionPattern"),
                        value
                    )).tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxHeight: 140)
        }
    }
}

// MARK: - SettingsSpecialistConnectSheet

private struct SettingsSpecialistConnectSheet: View {

    @Environment(\.dismiss) private var dismiss
    @State private var code: String
    private let initialCode: String
    private let isConnected: Bool
    private let onConnect: (String) -> Void

    init(
        initialCode: String,
        isConnected: Bool,
        onConnect: @escaping (String) -> Void
    ) {
        self.initialCode = initialCode
        self.isConnected = isConnected
        self._code = State(initialValue: initialCode)
        self.onConnect = onConnect
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: SpacingTokens.large) {
                VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                    Text(String(localized: "settings.specialist.sheetTitle"))
                        .font(TypographyTokens.headline(20))
                        .foregroundStyle(ColorTokens.Parent.ink)
                    Text(String(localized: "settings.specialist.sheetSubtitle"))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(nil)
                }

                TextField(
                    String(localized: "settings.specialist.codePlaceholder"),
                    text: $code
                )
                .keyboardType(.numberPad)
                .font(TypographyTokens.mono(20))
                .padding(SpacingTokens.regular)
                .frame(minHeight: 56)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.md)
                        .fill(ColorTokens.Parent.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.md)
                        .strokeBorder(ColorTokens.Parent.line, lineWidth: 1)
                )
                .accessibilityLabel(String(localized: "settings.a11y.specialistCode"))

                if isConnected {
                    HStack(spacing: SpacingTokens.tiny) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(ColorTokens.Semantic.success)
                        Text(String(localized: "settings.specialist.connected"))
                            .font(TypographyTokens.body(14))
                            .foregroundStyle(ColorTokens.Semantic.success)
                    }
                }

                Spacer()

                HSButton(
                    String(localized: "settings.specialist.connectButton"),
                    style: .primary,
                    size: .large,
                    icon: "link"
                ) {
                    onConnect(code)
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.vertical, SpacingTokens.large)
            .background(ColorTokens.Parent.bg.ignoresSafeArea())
            .navigationTitle(String(localized: "settings.specialist.navTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "settings.profile.cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - SettingsLegalSheet

private struct SettingsLegalSheet: View {

    @Environment(\.dismiss) private var dismiss
    let title: String
    let bodyText: String

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(bodyText)
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineSpacing(TypographyTokens.LineSpacing.normal)
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.vertical, SpacingTokens.large)
            }
            .background(ColorTokens.Parent.bg.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "settings.profile.cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - ModelPackRow

private struct ModelPackRow: View {

    let item: ModelPackRowVM
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: SpacingTokens.regular) {
                ZStack {
                    Circle()
                        .fill(iconBackground)
                        .frame(width: 38, height: 38)
                    Image(systemName: iconName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(iconForeground)
                }

                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    HStack(spacing: SpacingTokens.tiny) {
                        Text(item.title)
                            .font(TypographyTokens.headline(15))
                            .foregroundStyle(ColorTokens.Parent.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        if item.isActive {
                            Text(String(localized: "settings.models.badge.active"))
                                .font(TypographyTokens.caption(10).weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(ColorTokens.Semantic.success)
                                )
                        }
                    }
                    Text(item.subtitle)
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    if item.isDownloading {
                        ProgressView(value: max(0.02, item.progress))
                            .tint(ColorTokens.Brand.primary)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(item.sizeText)
                            .font(TypographyTokens.caption(11))
                            .foregroundStyle(ColorTokens.Parent.inkSoft)
                    }
                }
                Spacer()
                Text(item.actionTitle)
                    .font(TypographyTokens.caption(12).weight(.semibold))
                    .foregroundStyle(actionColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.title)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(item.canDelete
                           ? String(localized: "settings.a11y.modelPack.delete.hint")
                           : (item.isInstalled
                              ? String(localized: "settings.a11y.modelPack.active.hint")
                              : String(localized: "settings.a11y.modelPack.download.hint")))
    }

    private var iconName: String {
        item.id.hasPrefix("llm.") ? "brain.head.profile" : "waveform"
    }

    private var iconBackground: Color {
        if item.isActive { return ColorTokens.Semantic.success.opacity(0.15) }
        if item.isInstalled { return ColorTokens.Brand.primary.opacity(0.15) }
        return ColorTokens.Parent.line.opacity(0.6)
    }

    private var iconForeground: Color {
        if item.isActive { return ColorTokens.Semantic.success }
        if item.isInstalled { return ColorTokens.Brand.primary }
        return ColorTokens.Parent.inkMuted
    }

    private var actionColor: Color {
        if item.isActive { return ColorTokens.Semantic.success }
        if item.isInstalled { return ColorTokens.Semantic.error }
        if item.isDownloading { return ColorTokens.Parent.inkMuted }
        return ColorTokens.Brand.primary
    }

    private var accessibilityValue: String {
        if item.isActive { return String(localized: "settings.a11y.modelPack.active") }
        if item.isDownloading {
            let percent = Int(item.progress * 100)
            return String(format: String(localized: "settings.a11y.modelPack.progress"), percent)
        }
        if item.isInstalled { return String(localized: "settings.a11y.modelPack.installed") }
        return item.sizeText
    }
}

// MARK: - SettingsLicensesListSheet

private struct SettingsLicensesListSheet: View {

    @Environment(\.dismiss) private var dismiss
    let licenses: [OpenSourceLicenseVM]
    let onSelect: (OpenSourceLicenseVM) -> Void

    var body: some View {
        NavigationStack {
            List(licenses) { license in
                Button {
                    onSelect(license)
                } label: {
                    VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                        Text(license.title)
                            .font(TypographyTokens.headline(15))
                            .foregroundStyle(ColorTokens.Parent.ink)
                        Text(license.subtitle)
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                    }
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityHint(String(localized: "settings.a11y.licenseRow.hint"))
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(ColorTokens.Parent.bg)
            .navigationTitle(String(localized: "settings.about.licenses"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "settings.profile.cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - SettingsLicenseDetailSheet

private struct SettingsLicenseDetailSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let license: OpenSourceLicenseVM

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.regular) {
                    VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                        Text(license.title)
                            .font(TypographyTokens.headline(20))
                            .foregroundStyle(ColorTokens.Parent.ink)
                        Text(license.subtitle)
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                    }

                    if let url = license.url {
                        Button {
                            openURL(url)
                        } label: {
                            Label {
                                Text(String(localized: "settings.licenses.openRepo"))
                                    .font(TypographyTokens.body(14))
                            } icon: {
                                Image(systemName: "arrow.up.right.square")
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(ColorTokens.Brand.primary)
                    }

                    Text(license.bodyText)
                        .font(TypographyTokens.mono(12))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineSpacing(TypographyTokens.LineSpacing.normal)
                        .padding(SpacingTokens.regular)
                        .background(
                            RoundedRectangle(cornerRadius: RadiusTokens.md)
                                .fill(ColorTokens.Parent.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: RadiusTokens.md)
                                .strokeBorder(ColorTokens.Parent.line, lineWidth: 1)
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.vertical, SpacingTokens.large)
            }
            .background(ColorTokens.Parent.bg.ignoresSafeArea())
            .navigationTitle(license.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "settings.profile.cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - SettingsShareSheet

/// UIKit-обёртка вокруг `UIActivityViewController` для GDPR-экспорта.
private struct SettingsShareSheet: UIViewControllerRepresentable {

    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview("Settings – Parent") {
    SettingsView()
        .environment(AppContainer.preview())
        .environment(\.circuitContext, .parent)
}
