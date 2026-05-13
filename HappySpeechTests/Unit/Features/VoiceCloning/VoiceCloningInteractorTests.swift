import XCTest
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
