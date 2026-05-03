@testable import HappySpeech
import XCTest

// MARK: - CustomizationInteractorTests
//
// 10 тестов для CustomizationInteractor (F2-011).
// Паттерн: Interactor → реальный Presenter → SpyDisplay.
//
// Realm-тесты (load, save) НЕ открывают Realm явно из теста:
// - Worker.load() при отсутствии открытого Realm бросает AppError.realmReadFailed → ловит catch → возвращает дефолт.
// - Worker.saveLocal() бросает realmWriteFailed → Interactor ловит → presentSaveResult(error).
// Это позволяет избежать RLMException "Realm accessed from incorrect thread" (Realm queue:nil — thread-bound,
// а RealmActor выполняется на actor executor, который может меняться между suspension points).

@MainActor
final class CustomizationInteractorTests: XCTestCase {

    // MARK: - Spy Display

    @MainActor
    private final class SpyDisplay: CustomizationDisplayLogic {
        var displayLoadedCalled              = false
        var displaySaveResultCalled          = false
        var displaySelectionChangedCalled    = false
        var displayVoicePreviewStateCalled   = false

        var lastViewModel: CustomizationViewModel?
        var lastPlayingVoice: LyalyaVoice?
        var allViewModels: [CustomizationViewModel] = []

        func displayLoadedCustomization(viewModel: CustomizationViewModel) {
            displayLoadedCalled = true
            lastViewModel = viewModel
            allViewModels.append(viewModel)
        }
        func displaySaveResult(viewModel: CustomizationViewModel) {
            displaySaveResultCalled = true
            lastViewModel = viewModel
            allViewModels.append(viewModel)
        }
        func displaySelectionChanged(viewModel: CustomizationViewModel) {
            displaySelectionChangedCalled = true
            lastViewModel = viewModel
            allViewModels.append(viewModel)
        }
        func displayVoicePreviewState(playingVoice: LyalyaVoice?) {
            displayVoicePreviewStateCalled = true
            lastPlayingVoice = playingVoice
        }
        func displayLockedItemAttempt(viewModel: CustomizationViewModel) {}
    }

    // MARK: - Stub AuthService

    private final class StubAuthService: AuthService, @unchecked Sendable {
        var stubbedUser: AuthUser?
        var currentUser: AuthUser? { stubbedUser }

        func signIn(email: String, password: String) async throws -> AuthUser { stubbedUser! }
        func signUp(email: String, password: String, displayName: String) async throws -> AuthUser { stubbedUser! }
        func sendPasswordReset(email: String) async throws {}
        func sendEmailVerification() async throws {}
        func reloadCurrentUser() async throws -> AuthUser? { stubbedUser }
        func signInWithGoogle() async throws -> AuthUser { stubbedUser! }
        func signInAnonymously() async throws -> AuthUser { stubbedUser! }
        func linkAnonymousWithEmail(email: String, password: String) async throws -> AuthUser { stubbedUser! }
        func signOut() throws {}
        func deleteAccount() async throws {}
        @discardableResult
        func addAuthStateListener(_ listener: @escaping @Sendable (AuthUser?) -> Void) -> Any { NSObject() }
        func removeAuthStateListener(_ handle: Any) {}
    }

    // MARK: - Factory

    /// Создаёт SUT + реальный Presenter + SpyDisplay.
    /// Realm НЕ открывается — Worker.load() вернёт дефолт через catch (realmReadFailed),
    /// Worker.saveLocal() вернёт realmWriteFailed → Interactor вызовет presentSaveResult(error).
    private func makeSUT(
        user: AuthUser? = nil,
        storage: LyalyaCustomizationStorage = LyalyaCustomizationStorage.shared
    ) -> (
        sut: CustomizationInteractor,
        display: SpyDisplay,
        auth: StubAuthService,
        realm: RealmActor
    ) {
        let realm = RealmActor()

        let auth = StubAuthService()
        auth.stubbedUser = user

        let spy = SpyDisplay()
        let presenter = CustomizationPresenter()
        presenter.display = spy

        let sut = CustomizationInteractor(
            realmActor: realm,
            authService: auth,
            storage: storage
        )
        sut.presenter = presenter

        return (sut, spy, auth, realm)
    }

    // MARK: - 1. loadInitialState → дефолты classic / warm / classic
    //
    // Realm не открыт → Worker.load() возвращает дефолт → Presenter выдаёт дефолтный VM.

    func test_loadInitialState_returnsDefaults() async throws {
        let (sut, display, _, _) = makeSUT()

        sut.loadCustomization(.init())
        try await Task.sleep(nanoseconds: 600_000_000)

        XCTAssertTrue(display.displayLoadedCalled, "displayLoadedCustomization должен вызываться")
        XCTAssertEqual(display.lastViewModel?.selectedSkin,   .classic, "Дефолтный скин — classic")
        XCTAssertEqual(display.lastViewModel?.selectedColor,  .warm,    "Дефолтный цвет — warm")
        XCTAssertEqual(display.lastViewModel?.selectedVoice,  .classic, "Дефолтный голос — classic")
    }

    // MARK: - 2. selectSkin .princess → displaySelectionChanged с skin=.princess

    func test_selectSkin_princess_updatesViewModel() {
        let (sut, display, _, _) = makeSUT()

        sut.selectSkin(.init(skin: .princess))

        XCTAssertTrue(display.displaySelectionChangedCalled, "displaySelectionChanged должен вызываться")
        XCTAssertEqual(display.lastViewModel?.selectedSkin, .princess,
                       "ViewModel должен содержать выбранный скин .princess")
    }

    // MARK: - 3. selectColor .cool → displaySelectionChanged с color=.cool

    func test_selectColor_cool_updatesViewModel() {
        let (sut, display, _, _) = makeSUT()

        sut.selectColor(.init(color: .cool))

        XCTAssertTrue(display.displaySelectionChangedCalled)
        XCTAssertEqual(display.lastViewModel?.selectedColor, .cool)
    }

    // MARK: - 4. selectVoice .cheerful → displaySelectionChanged с voice=.cheerful

    func test_selectVoice_cheerful_updatesViewModel() {
        let (sut, display, _, _) = makeSUT()

        sut.selectVoice(.init(voice: .cheerful))

        XCTAssertTrue(display.displaySelectionChangedCalled)
        XCTAssertEqual(display.lastViewModel?.selectedVoice, .cheerful)
    }

    // MARK: - 5. save → displaySaveResult вызывается (Realm нет → save вернёт error-result)
    //
    // Проверяем что: a) Presenter получает вызов (isSaving true → потом результат),
    // b) isSaving false после завершения (в error-path presenter тоже ставит isSaving=false).

    func test_save_callsPresenter() async throws {
        let (sut, display, _, _) = makeSUT()

        sut.saveCustomization(.init(skin: .scientist, color: .nature, voice: .soft))
        try await Task.sleep(nanoseconds: 2_000_000_000)

        XCTAssertTrue(display.displaySaveResultCalled, "displaySaveResult должен вызываться")
        let lastVM = display.allViewModels.last
        XCTAssertEqual(lastVM?.isSaving, false, "isSaving должен сброситься после save")
    }

    // MARK: - 6. save + anonymous → нет cloud toast ("облак"/"синхрон")

    func test_save_anonymous_skipsCloudSync() async throws {
        let anonUser = AuthUser(uid: "anon-001", isAnonymous: true)
        let (sut, display, _, _) = makeSUT(user: anonUser)

        sut.saveCustomization(.init(skin: .classic, color: .warm, voice: .classic))
        try await Task.sleep(nanoseconds: 2_000_000_000)

        XCTAssertTrue(display.displaySaveResultCalled)
        let cloudToastVMs = display.allViewModels.filter {
            $0.toastMessage?.contains("облак") == true ||
            $0.toastMessage?.contains("синхрон") == true
        }
        XCTAssertTrue(cloudToastVMs.isEmpty,
                      "Для anonymous пользователя cloud toast не должен появляться")
    }

    // MARK: - 7. save + authenticated → displaySaveResult вызывается

    func test_save_authenticated_saveCallsPresenter() async throws {
        let authUser = AuthUser(uid: "user-001", email: "t@t.ru", isAnonymous: false)
        let (sut, display, _, _) = makeSUT(user: authUser)

        sut.saveCustomization(.init(skin: .athlete, color: .cool, voice: .cheerful))
        try await Task.sleep(nanoseconds: 2_000_000_000)

        XCTAssertTrue(display.displaySaveResultCalled,
                      "displaySaveResult должен вызываться для authenticated user")
        let saveVMs = display.allViewModels.filter { !$0.isSaving }
        XCTAssertFalse(saveVMs.isEmpty,
                       "Должен быть хотя бы один VM с isSaving=false после save")
    }

    // MARK: - 8. voicePreview classic → display получает playingVoice=.classic

    func test_voicePreview_classic_displaysPlayingState() {
        let (sut, display, _, _) = makeSUT()

        sut.previewVoice(.init(voice: .classic))

        XCTAssertTrue(display.displayVoicePreviewStateCalled,
                      "displayVoicePreviewState должен вызываться при запуске preview")
        XCTAssertEqual(display.lastPlayingVoice, .classic,
                       "playingVoice должен быть .classic")
    }

    // MARK: - 9. voicePreview stop → display получает playingVoice=nil

    func test_voicePreview_stop_clearsPlayingState() {
        let (sut, display, _, _) = makeSUT()

        sut.previewVoice(.init(voice: .soft))
        sut.stopVoicePreview()

        XCTAssertNil(display.lastPlayingVoice,
                     "После stopVoicePreview playingVoice должен быть nil")
    }

    // MARK: - 10. LyalyaCustomizationStorage.apply обновляет shared state
    //
    // Проверяем LyalyaCustomizationStorage.shared.apply(dto:) напрямую —
    // это публичный метод, вызываемый Interactor в loadCustomization и saveCustomization.
    // Тест изолирован от Realm: проверяет только apply() логику.

    func test_storage_apply_updatesSharedState() {
        let storage = LyalyaCustomizationStorage.shared

        let dto = CustomizationDTO(
            skin: LyalyaSkin.artist.rawValue,
            colorVariant: LyalyaColorVariant.nature.rawValue,
            voice: LyalyaVoice.soft.rawValue,
            updatedAt: Date()
        )
        storage.apply(dto: dto)

        XCTAssertEqual(storage.skin, .artist,
                       "LyalyaCustomizationStorage.skin должен обновиться до .artist")
        XCTAssertEqual(storage.colorVariant, .nature,
                       "LyalyaCustomizationStorage.colorVariant должен обновиться до .nature")
        XCTAssertEqual(storage.voice, .soft,
                       "LyalyaCustomizationStorage.voice должен обновиться до .soft")
    }
}
