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
                    interactor?.exportData(.init())
                }
                Button(String(localized: "settings.export.confirm.cancel"), role: .cancel) {}
            } message: {
                Text(String(localized: "settings.export.confirm.message"))
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
            notificationService: container.notificationService
        )
        let presenter = SettingsPresenter()
        let router = SettingsRouter()

        interactor.presenter = presenter
        presenter.display = display

        self.interactor = interactor
        self.presenter = presenter
        self.router = router

        interactor.loadSettings(.init())
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

// MARK: - Preview

#Preview("Settings – Parent") {
    SettingsView()
        .environment(AppContainer.preview())
        .environment(\.circuitContext, .parent)
}
