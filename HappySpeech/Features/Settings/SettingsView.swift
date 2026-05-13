import OSLog
import SwiftUI

// MARK: - SettingsView
//
// Parent-контур. 8 секций: оформление, профиль ребёнка, уведомления,
// контент, данные, аналитика, специалист, о приложении.
//
// VIP: View → Interactor (запросы) → Presenter (форматирование) → Display.

struct SettingsView: View {

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    // MARK: - VIP State

    @State var display = SettingsDisplay()
    @State var interactor: SettingsInteractor?
    @State private var presenter: SettingsPresenter?
    @State private var router: SettingsRouter?
    @State private var bootstrapped = false

    // MARK: - Local UI state

    @State var showClearCacheConfirm = false
    @State var showExportConfirm = false
    @State var showProfileSheet = false
    @State var showSpecialistSheet = false
    @State var showPrivacyPolicySheet = false
    @State var showTermsSheet = false
    @State var showLicensesSheet = false
    @State var selectedLicense: OpenSourceLicenseVM?
    @State var showShareSheet = false
    @State var pendingDeletePackId: String?
    @State var showCustomizationSheet = false
    @State private var showParentalGate = false
    @State private var parentalGatePendingURL: URL?
    @State private var showChangelog = false
    /// Block R.1 v18 — sheet для DialectAdaptationView (Settings → Profile → Dialect).
    @State var showDialectAdaptationSheet = false

    private let logger = Logger(subsystem: "ru.happyspeech", category: "SettingsView")

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ColorTokens.Parent.bg.ignoresSafeArea()

                List {
                    settingsHeaderSection
                    appearanceSection
                    lyalyaCustomizationSection
                    profileSection
                    notificationsSection
                    hapticsSection
                    contentSection
                    modelPacksSection
                    dataSection
                    performanceSection
                    specialistSection
                    karaokeSection
                    aboutSection
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(ColorTokens.Parent.bg)

                if let toast = display.toastMessage {
                    HSToast(toast, type: display.toastIsError ? .error : .success)
                        .padding(.horizontal, SpacingTokens.regular)
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    LyalyaMascotView(state: .idle, size: 36)
                        .accessibilityHidden(true)
                }
            }
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
                Button(String(localized: "settings.export.format.pdf")) {
                    let childId = container.currentChildId.isEmpty ? "unknown" : container.currentChildId
                    interactor?.exportData(.init(format: .pdf, childId: childId))
                }
                Button(String(localized: "settings.export.format.csv")) {
                    let childId = container.currentChildId.isEmpty ? "unknown" : container.currentChildId
                    interactor?.exportData(.init(format: .csv, childId: childId))
                }
                Button(String(localized: "settings.export.format.json")) {
                    let childId = container.currentChildId.isEmpty ? "unknown" : container.currentChildId
                    interactor?.exportData(.init(format: .json, childId: childId))
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
                SettingsLicenseDetailSheet(license: license) { url in
                    selectedLicense = nil
                    parentalGatePendingURL = url
                    showParentalGate = true
                }
            }
            .sheet(
                isPresented: $showShareSheet,
                onDismiss: { display.clearShareFile() },
                content: {
                    if let url = display.shareFileURL {
                        SettingsShareSheet(items: [url])
                    }
                }
            )
            .onChange(of: display.shareFileURL) { _, newValue in
                if newValue != nil { showShareSheet = true }
            }
            .sheet(isPresented: $showCustomizationSheet) {
                NavigationStack {
                    CustomizationView()
                        .environment(container)
                        .environment(\.circuitContext, .parent)
                }
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showParentalGate) {
                if let url = parentalGatePendingURL {
                    ParentalGate(isPresented: $showParentalGate) {
                        UIApplication.shared.open(url)
                        parentalGatePendingURL = nil
                    }
                }
            }
            // Block R.1 v18 — DialectAdaptation sheet.
            .sheet(isPresented: $showDialectAdaptationSheet) {
                let childId = container.currentChildId.isEmpty ? "default" : container.currentChildId
                DialectAdaptationView(childId: childId)
                    .environment(container)
                    .presentationDetents([.large])
            }
        }
        .environment(\.circuitContext, .parent)
        // P0.4 fix v19: use onAppear (sync) instead of .task (async) so that
        // loadSettings() fires before the first screenshot frame is captured.
        .onAppear { bootstrap() }
    }

    // MARK: - Bootstrap

    @MainActor
    private func bootstrap() {
        guard !bootstrapped else { return }
        bootstrapped = true

        let interactor = SettingsInteractor(
            themeManager: container.themeManager,
            notificationService: container.notificationService,
            hapticService: container.hapticService,
            sessionRepository: container.sessionRepository,
            performanceMonitorService: container.performanceMonitorService,
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

// MARK: - Preview
#Preview("Settings – Parent") {
    SettingsView()
        .environment(AppContainer.preview())
        .environment(\.circuitContext, .parent)
}
