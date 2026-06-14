import OSLog
import SwiftUI

// MARK: - SettingsView
//
// Parent-контур. Сгруппированные inset-секции: оформление, кастомизация Ляли,
// профиль ребёнка, уведомления, тактильная отдача, спокойный режим, контент,
// данные, производительность, со-родительство, специалист, караоке-режим,
// о приложении.
//
// Модели речи (ASR/LLM) встроены в бандл и заранее настроены на лучшее
// качество — экран выбора/закачки моделей удалён намеренно.
//
// VIP: View → Interactor (запросы) → Presenter (форматирование) → Display.

/// Identifiable-обёртка для внешней ссылки, открываемой после Parental Gate.
/// Используется как `item` у `.sheet(item:)`, чтобы устранить race пустого
/// шита (URL и флаг показа ранее ставились в одном тике).
private struct ParentalGateURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

struct SettingsView: View {

    // MARK: - Environment

    // Видимость internal (не private) — секции в SettingsViewSectionsExtras.swift
    // обращаются к container и dismiss из extension того же типа.
    @Environment(AppContainer.self) var container
    @Environment(AppCoordinator.self) var coordinator
    @Environment(\.dismiss) var dismiss

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
    @State var showCustomizationSheet = false
    @State private var parentalGatePendingURL: ParentalGateURL?
    @State private var showChangelog = false

    // Со-родительство (FamilyInvite). Каждая поверхность открывается через
    // ParentalGate — после прохождения биометрии/математики показывается sheet.
    @State var pendingFamilyInviteAction: FamilyInviteEntryAction?
    @State var showCreateInviteSheet = false
    @State var showRedeemInviteSheet = false
    /// Block R.1 v18 — sheet для DialectAdaptationView (Settings → Profile → Dialect).
    @State var showDialectAdaptationSheet = false

    private let logger = Logger(subsystem: "ru.happyspeech", category: "SettingsView")

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Parent-контур: спокойный однотонный холст #F0EFF6 (light) /
                // #181820 (dark). Без кремового mesh-оверлея — фон статичный
                // и соответствует эталону «Настройки» (parent-палитра).
                ColorTokens.Parent.bg
                    .ignoresSafeArea()

                List {
                    settingsHeaderSection
                    appearanceSection
                    lyalyaCustomizationSection
                    profileSection
                    notificationsSection
                    hapticsSection
                    calmModeSection
                    contentSection
                    dataSection
                    performanceSection
                    coParentSection
                    specialistSection
                    karaokeSection
                    aboutSection
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .accessibilityIdentifier("SettingsRoot")

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
            .modifier(SettingsThemeTipModifier())
            // D-26 v27 — убран дублирующий маленький маскот из toolbar:
            // крупная Ляля уже присутствует в settingsHeaderSection.
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
                    parentalGatePendingURL = ParentalGateURL(url: url)
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
            .sheet(item: $parentalGatePendingURL) { pending in
                ParentalGate(
                    isPresented: Binding(
                        get: { parentalGatePendingURL != nil },
                        set: { if !$0 { parentalGatePendingURL = nil } }
                    )
                ) {
                    UIApplication.shared.open(pending.url)
                    parentalGatePendingURL = nil
                }
            }
            // Block R.1 v18 — DialectAdaptation sheet.
            .sheet(isPresented: $showDialectAdaptationSheet) {
                let childId = container.currentChildId.isEmpty ? "default" : container.currentChildId
                DialectAdaptationView(childId: childId)
                    .environment(container)
                    .presentationDetents([.large])
            }
            // Со-родительство: ParentalGate перед открытием create/redeem.
            .sheet(item: $pendingFamilyInviteAction) { action in
                ParentalGate(
                    isPresented: Binding(
                        get: { pendingFamilyInviteAction != nil },
                        set: { if !$0 { pendingFamilyInviteAction = nil } }
                    )
                ) {
                    switch action {
                    case .create: showCreateInviteSheet = true
                    case .redeem: showRedeemInviteSheet = true
                    }
                    pendingFamilyInviteAction = nil
                }
            }
            .sheet(isPresented: $showCreateInviteSheet) {
                CreateInviteView()
                    .environment(container)
                    .environment(\.circuitContext, .parent)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showRedeemInviteSheet) {
                RedeemInviteView()
                    .environment(container)
                    .environment(coordinator)
                    .environment(\.circuitContext, .parent)
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
            calmModeManager: container.calmModeManager
        )
        let presenter = SettingsPresenter()
        let router = SettingsRouter()

        interactor.presenter = presenter
        presenter.display = display

        self.interactor = interactor
        self.presenter = presenter
        self.router = router

        interactor.loadSettings(.init())
        interactor.loadLicenses(.init())
    }
}

// MARK: - Preview
#Preview("Settings – Parent") {
    SettingsView()
        .environment(AppContainer.preview())
        .environment(AppCoordinator())
        .environment(\.circuitContext, .parent)
}
