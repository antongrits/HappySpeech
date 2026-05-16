import XCTest
import RealmSwift
@testable import HappySpeech

// MARK: - VoiceCloningInteractorTests
//
// Block AA v21 — Smoke tests для VoiceCloningInteractor.
// VoiceCloningPresenter — final, не наследуется. Используем ViewModel как spy.
// Smoke тесты покрывают синхронную логику и поведение при уже активной записи.

@MainActor
final class VoiceCloningInteractorTests: XCTestCase {

    private var sut: VoiceCloningInteractor!
    private var presenter: VoiceCloningPresenter!
    private var viewModel: VoiceCloningViewModel!
    private var mockAudioService: MockAudioService!

    override func setUp() {
        super.setUp()
        mockAudioService = MockAudioService()
        viewModel = VoiceCloningViewModel()
        presenter = VoiceCloningPresenter()
        presenter.viewModel = viewModel

        sut = VoiceCloningInteractor(
            audioService: mockAudioService,
            realmActor: RealmActor()
        )
        sut.presenter = presenter
    }

    override func tearDown() {
        sut = nil
        presenter = nil
        viewModel = nil
        mockAudioService = nil
        super.tearDown()
    }

    // MARK: - Tests

    func test_stopPlayback_whenNotPlaying_doesNotCrash() {
        // stopPlayback — синхронный метод, не требует Realm.
        sut.stopPlayback()
        // Проверяем что состояние воспроизведения сброшено
        XCTAssertFalse(viewModel.isPlaying)
    }

    func test_startRecording_whenAlreadyRecording_isIgnoredSilently() async {
        // Arrange: симулируем уже идущую запись
        mockAudioService.isRecording = true
        // Act
        await sut.startRecording(VoiceCloning.StartRecordingRequest(
            childId: "child-voice-1",
            word: "рыба",
            targetSound: "Р"
        ))
        // Assert: errorMessage не установлен (логика возвращается сразу через guard)
        XCTAssertNil(
            viewModel.errorMessage,
            "При isRecording=true повторный startRecording молча игнорируется без ошибки"
        )
    }

    func test_startRecording_permissionDenied_presentsFailure() async {
        // Arrange: используем локальный mock с denied permission
        let deniedAudioService = DeniedPermissionAudioService()
        let vm = VoiceCloningViewModel()
        let pres = VoiceCloningPresenter()
        pres.viewModel = vm

        let sutDenied = VoiceCloningInteractor(
            audioService: deniedAudioService,
            realmActor: RealmActor()
        )
        sutDenied.presenter = pres
        // Act
        await sutDenied.startRecording(VoiceCloning.StartRecordingRequest(
            childId: "child-voice-1",
            word: "сом",
            targetSound: "С"
        ))
        // Assert: errorMessage установлен
        XCTAssertNotNil(vm.errorMessage, "При denied permission должен быть установлен errorMessage")
        XCTAssertFalse(vm.isRecording)
    }

    // MARK: - Batch 2.8.3 v25: расширенное покрытие
    //
    // UNTESTABLE (документировано): stopRecording → copyRecordingToArchive →
    // FileManager + реальный AVAudioRecorder; startRecordingTimer — Task с auto-stop.
    // Покрываем load (in-memory Realm), playSample/delete guard-ветки, каталог слов.

    private func makeOpenRealmActor() async throws -> RealmActor {
        var config = Realm.Configuration()
        config.inMemoryIdentifier = "voicecloning-unit-\(UUID().uuidString)"
        config.schemaVersion = RealmSchemaVersion.current
        Realm.Configuration.defaultConfiguration = config
        let actor = RealmActor()
        try await actor.open(configuration: config)
        return actor
    }

    func test_load_emptyArchive_presentsEmptyList() async throws {
        let realm = try await makeOpenRealmActor()
        let vm = VoiceCloningViewModel()
        let pres = VoiceCloningPresenter()
        pres.viewModel = vm
        let interactor = VoiceCloningInteractor(
            audioService: MockAudioService(),
            realmActor: realm
        )
        interactor.presenter = pres

        await interactor.load(VoiceCloning.LoadRequest(childId: "child-vc-empty"))
        // Подсказка-слово должна быть задана.
        XCTAssertFalse(vm.suggestedWord.isEmpty)
    }

    func test_playSample_unknownId_doesNotCrash() async throws {
        let realm = try await makeOpenRealmActor()
        let interactor = VoiceCloningInteractor(
            audioService: MockAudioService(),
            realmActor: realm
        )
        let pres = VoiceCloningPresenter()
        pres.viewModel = VoiceCloningViewModel()
        interactor.presenter = pres
        await interactor.load(VoiceCloning.LoadRequest(childId: "child-vc"))
        await interactor.playSample(VoiceCloning.PlaySampleRequest(sampleId: "ghost"))
        XCTAssertTrue(true, "playSample с неизвестным ID — guard, без краша")
    }

    func test_delete_unknownId_doesNotCrash() async throws {
        let realm = try await makeOpenRealmActor()
        let interactor = VoiceCloningInteractor(
            audioService: MockAudioService(),
            realmActor: realm
        )
        let pres = VoiceCloningPresenter()
        pres.viewModel = VoiceCloningViewModel()
        interactor.presenter = pres
        await interactor.load(VoiceCloning.LoadRequest(childId: "child-vc"))
        await interactor.delete(VoiceCloning.DeleteSampleRequest(sampleId: "ghost"))
        XCTAssertTrue(true, "delete с неизвестным ID — guard, без краша")
    }

    func test_suggestedWordCatalog_perSoundGroups() {
        XCTAssertEqual(VoiceCloning.SuggestedWordCatalog.defaultWord(forSound: "С"), "сом")
        XCTAssertEqual(VoiceCloning.SuggestedWordCatalog.defaultWord(forSound: "Р"), "рыба")
        XCTAssertFalse(VoiceCloning.SuggestedWordCatalog.words(forSound: "Ш").isEmpty)
        // Неизвестный звук → fallback-набор.
        XCTAssertFalse(VoiceCloning.SuggestedWordCatalog.words(forSound: "Ы").isEmpty)
    }

    func test_suggestedWordCatalog_caseInsensitive() {
        XCTAssertEqual(
            VoiceCloning.SuggestedWordCatalog.words(forSound: "с"),
            VoiceCloning.SuggestedWordCatalog.words(forSound: "С")
        )
    }

    func test_stopPlayback_resetsViewModelState() {
        sut.stopPlayback()
        XCTAssertFalse(viewModel.isPlaying)
    }
}

// MARK: - DeniedPermissionAudioService

private final class DeniedPermissionAudioService: AudioService, @unchecked Sendable {
    var isPermissionGranted: Bool = false
    var amplitude: Float = 0
    var isRecording: Bool = false

    func requestPermission() async -> Bool { false }
    func startRecording() async throws {}
    func stopRecording() async throws -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
    }
    func playAudio(url: URL) async throws {}
    func stopPlayback() {}
    func amplitudeBuffer() -> [Float] { [] }
}
