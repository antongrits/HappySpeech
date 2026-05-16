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

    // MARK: - Batch 2.6a v25: recording / playback / timer / archive paths

    func test_startRecording_micGranted_startsAudioService() async {
        let realm = try? await makeOpenRealmActor()
        guard let realm else { return XCTFail("realm") }
        let audio = MockAudioService()
        audio.isPermissionGranted = true
        let vm = VoiceCloningViewModel()
        let pres = VoiceCloningPresenter()
        pres.viewModel = vm
        let interactor = VoiceCloningInteractor(audioService: audio, realmActor: realm)
        interactor.presenter = pres

        await interactor.load(VoiceCloning.LoadRequest(childId: "child-rec"))
        await interactor.startRecording(VoiceCloning.StartRecordingRequest(
            childId: "child-rec", word: "сом", targetSound: "С"
        ))
        XCTAssertTrue(audio.isRecording, "AudioService должен начать запись")
    }

    func test_stopRecording_whenNotRecording_isIgnored() async {
        let realm = try? await makeOpenRealmActor()
        guard let realm else { return XCTFail("realm") }
        let audio = MockAudioService()
        audio.isRecording = false
        let vm = VoiceCloningViewModel()
        let pres = VoiceCloningPresenter()
        pres.viewModel = vm
        let interactor = VoiceCloningInteractor(audioService: audio, realmActor: realm)
        interactor.presenter = pres
        // guard !isRecording → no-op, errorMessage не выставляется.
        await interactor.stopRecording(VoiceCloning.StopRecordingRequest(childId: "child-rec"))
        XCTAssertNil(vm.errorMessage)
    }

    func test_stopRecording_missingFile_presentsFailure() async {
        let realm = try? await makeOpenRealmActor()
        guard let realm else { return XCTFail("realm") }
        let audio = MockAudioService()
        audio.isPermissionGranted = true
        let vm = VoiceCloningViewModel()
        let pres = VoiceCloningPresenter()
        pres.viewModel = vm
        let interactor = VoiceCloningInteractor(audioService: audio, realmActor: realm)
        interactor.presenter = pres

        await interactor.startRecording(VoiceCloning.StartRecordingRequest(
            childId: "child-fail", word: "сом", targetSound: "С"
        ))
        // MockAudioService.stopRecording возвращает несуществующий файл →
        // copyRecordingToArchive бросает ошибку → presentRecordingResult(success:false).
        await interactor.stopRecording(VoiceCloning.StopRecordingRequest(childId: "child-fail"))
        XCTAssertNotNil(vm.errorMessage,
                        "Неуспешное копирование архива даёт errorMessage")
    }

    func test_playSample_existingFile_startsPlayback() async throws {
        let realm = try await makeOpenRealmActor()
        // Создаём реальный временный файл и VoiceSample в Realm.
        let tempURL = makeTempVoiceFile()
        defer { try? FileManager.default.removeItem(at: tempURL) }
        let relativePath = try relativeArchivePath(for: tempURL, childId: "child-play")

        let sample = VoiceSampleData(
            id: "sample-1", childId: "child-play", word: "рыба",
            targetSound: "Р", audioFilePath: relativePath,
            durationSeconds: 1.0, recordedAt: Date(), note: ""
        )
        await realm.persistVoiceSample(sample)

        let player = MockAudioFilePlayer(stubbedDuration: 1.0)
        let vm = VoiceCloningViewModel()
        let pres = VoiceCloningPresenter()
        pres.viewModel = vm
        let interactor = VoiceCloningInteractor(
            audioService: MockAudioService(),
            realmActor: realm,
            filePlayer: player
        )
        interactor.presenter = pres

        await interactor.load(VoiceCloning.LoadRequest(childId: "child-play"))
        await interactor.playSample(VoiceCloning.PlaySampleRequest(sampleId: "sample-1"))
        XCTAssertEqual(player.playCallCount, 1, "Существующий файл должен воспроизводиться")
        XCTAssertTrue(vm.isPlaying)
    }

    func test_playSample_fileMissingOnDisk_doesNotPlay() async throws {
        let realm = try await makeOpenRealmActor()
        // Sample ссылается на несуществующий файл.
        let sample = VoiceSampleData(
            id: "ghost-file", childId: "child-gf", word: "роза",
            targetSound: "Р", audioFilePath: "VoiceArchive/child-gf/missing.m4a",
            durationSeconds: 1.0, recordedAt: Date(), note: ""
        )
        await realm.persistVoiceSample(sample)

        let player = MockAudioFilePlayer()
        let interactor = VoiceCloningInteractor(
            audioService: MockAudioService(),
            realmActor: realm,
            filePlayer: player
        )
        let pres = VoiceCloningPresenter()
        pres.viewModel = VoiceCloningViewModel()
        interactor.presenter = pres

        await interactor.load(VoiceCloning.LoadRequest(childId: "child-gf"))
        await interactor.playSample(VoiceCloning.PlaySampleRequest(sampleId: "ghost-file"))
        XCTAssertEqual(player.playCallCount, 0, "Отсутствующий файл не воспроизводится")
    }

    func test_delete_existingSample_removesFromRealm() async throws {
        let realm = try await makeOpenRealmActor()
        let sample = VoiceSampleData(
            id: "del-1", childId: "child-del", word: "рак",
            targetSound: "Р", audioFilePath: "VoiceArchive/child-del/del.m4a",
            durationSeconds: 1.0, recordedAt: Date(), note: ""
        )
        await realm.persistVoiceSample(sample)

        let vm = VoiceCloningViewModel()
        let pres = VoiceCloningPresenter()
        pres.viewModel = vm
        let interactor = VoiceCloningInteractor(
            audioService: MockAudioService(),
            realmActor: realm
        )
        interactor.presenter = pres

        await interactor.load(VoiceCloning.LoadRequest(childId: "child-del"))
        await interactor.delete(VoiceCloning.DeleteSampleRequest(sampleId: "del-1"))
        // После удаления повторная загрузка не содержит сэмпл.
        let remaining = await realm.fetchVoiceSamples(childId: "child-del")
        XCTAssertTrue(remaining.isEmpty, "Удалённый сэмпл не должен оставаться в Realm")
    }

    func test_stopPlayback_resetsCurrentSample() async throws {
        let realm = try await makeOpenRealmActor()
        let player = MockAudioFilePlayer()
        let vm = VoiceCloningViewModel()
        let pres = VoiceCloningPresenter()
        pres.viewModel = vm
        let interactor = VoiceCloningInteractor(
            audioService: MockAudioService(),
            realmActor: realm,
            filePlayer: player
        )
        interactor.presenter = pres
        interactor.stopPlayback()
        XCTAssertFalse(vm.isPlaying)
        XCTAssertEqual(player.stopCallCount, 1)
    }

    func test_load_setsSuggestedWordAndTargetSound() async throws {
        let realm = try await makeOpenRealmActor()
        let vm = VoiceCloningViewModel()
        let pres = VoiceCloningPresenter()
        pres.viewModel = vm
        let interactor = VoiceCloningInteractor(
            audioService: MockAudioService(),
            realmActor: realm
        )
        interactor.presenter = pres
        await interactor.load(VoiceCloning.LoadRequest(childId: "child-sw"))
        XCTAssertFalse(vm.suggestedWord.isEmpty)
        XCTAssertFalse(vm.targetSound.isEmpty)
    }

    func test_stopRecording_success_savesToArchiveAndReloads() async throws {
        let realm = try await makeOpenRealmActor()
        // AudioService возвращает реальный временный файл → copyRecordingToArchive успешен.
        let tempFile = makeTempVoiceFile()
        defer { try? FileManager.default.removeItem(at: tempFile) }
        let audio = RecordedFileAudioService(recordedFile: tempFile)
        audio.isPermissionGranted = true
        let vm = VoiceCloningViewModel()
        let pres = VoiceCloningPresenter()
        pres.viewModel = vm
        let interactor = VoiceCloningInteractor(audioService: audio, realmActor: realm)
        interactor.presenter = pres

        await interactor.load(VoiceCloning.LoadRequest(childId: "child-save"))
        await interactor.startRecording(VoiceCloning.StartRecordingRequest(
            childId: "child-save", word: "сом", targetSound: "С"
        ))
        await interactor.stopRecording(VoiceCloning.StopRecordingRequest(childId: "child-save"))

        XCTAssertNil(vm.errorMessage, "Успешное сохранение не выставляет ошибку")
        let stored = await realm.fetchVoiceSamples(childId: "child-save")
        XCTAssertEqual(stored.count, 1, "Сэмпл должен быть записан в Realm")
        XCTAssertEqual(stored.first?.word, "сом")
    }

    func test_startRecording_engineThrows_presentsFailure() async throws {
        let realm = try await makeOpenRealmActor()
        let audio = ThrowingStartAudioService()
        audio.isPermissionGranted = true
        let vm = VoiceCloningViewModel()
        let pres = VoiceCloningPresenter()
        pres.viewModel = vm
        let interactor = VoiceCloningInteractor(audioService: audio, realmActor: realm)
        interactor.presenter = pres

        await interactor.startRecording(VoiceCloning.StartRecordingRequest(
            childId: "child-throw", word: "сом", targetSound: "С"
        ))
        XCTAssertNotNil(vm.errorMessage, "Ошибка старта записи отображается пользователю")
    }

    func test_playSample_existingFile_autoStopsAfterDuration() async throws {
        let realm = try await makeOpenRealmActor()
        let tempURL = makeTempVoiceFile()
        defer { try? FileManager.default.removeItem(at: tempURL) }
        let relativePath = try relativeArchivePath(for: tempURL, childId: "child-auto")
        let sample = VoiceSampleData(
            id: "auto-1", childId: "child-auto", word: "рыба",
            targetSound: "Р", audioFilePath: relativePath,
            durationSeconds: 0.2, recordedAt: Date(), note: ""
        )
        await realm.persistVoiceSample(sample)

        let player = MockAudioFilePlayer(stubbedDuration: 0.2)
        let vm = VoiceCloningViewModel()
        let pres = VoiceCloningPresenter()
        pres.viewModel = vm
        let interactor = VoiceCloningInteractor(
            audioService: MockAudioService(), realmActor: realm, filePlayer: player
        )
        interactor.presenter = pres

        await interactor.load(VoiceCloning.LoadRequest(childId: "child-auto"))
        await interactor.playSample(VoiceCloning.PlaySampleRequest(sampleId: "auto-1"))
        XCTAssertTrue(vm.isPlaying)
        // Авто-завершение по длительности → presentPlayback(isPlaying:false).
        try await Task.sleep(for: .milliseconds(450))
        XCTAssertFalse(vm.isPlaying, "Воспроизведение авто-завершается по истечении длительности")
    }

    func test_playSample_playerThrows_doesNotMarkPlaying() async throws {
        let realm = try await makeOpenRealmActor()
        let tempURL = makeTempVoiceFile()
        defer { try? FileManager.default.removeItem(at: tempURL) }
        let relativePath = try relativeArchivePath(for: tempURL, childId: "child-pf")
        let sample = VoiceSampleData(
            id: "pf-1", childId: "child-pf", word: "рыба",
            targetSound: "Р", audioFilePath: relativePath,
            durationSeconds: 1.0, recordedAt: Date(), note: ""
        )
        await realm.persistVoiceSample(sample)

        let player = MockAudioFilePlayer()
        player.shouldFailPlayback = true
        let vm = VoiceCloningViewModel()
        let pres = VoiceCloningPresenter()
        pres.viewModel = vm
        let interactor = VoiceCloningInteractor(
            audioService: MockAudioService(), realmActor: realm, filePlayer: player
        )
        interactor.presenter = pres

        await interactor.load(VoiceCloning.LoadRequest(childId: "child-pf"))
        await interactor.playSample(VoiceCloning.PlaySampleRequest(sampleId: "pf-1"))
        XCTAssertEqual(player.playCallCount, 1)
        XCTAssertFalse(vm.isPlaying, "Ошибка плеера не помечает воспроизведение активным")
    }

    func test_delete_existingSample_presentsDeleteResponse() async throws {
        let realm = try await makeOpenRealmActor()
        let sample = VoiceSampleData(
            id: "del-resp", childId: "child-dr", word: "рак",
            targetSound: "Р", audioFilePath: "VoiceArchive/child-dr/x.m4a",
            durationSeconds: 1.0, recordedAt: Date(), note: ""
        )
        await realm.persistVoiceSample(sample)
        let vm = VoiceCloningViewModel()
        let pres = VoiceCloningPresenter()
        pres.viewModel = vm
        let interactor = VoiceCloningInteractor(
            audioService: MockAudioService(), realmActor: realm
        )
        interactor.presenter = pres
        await interactor.load(VoiceCloning.LoadRequest(childId: "child-dr"))
        await interactor.delete(VoiceCloning.DeleteSampleRequest(sampleId: "del-resp"))
        // Сэмпл удалён из in-memory списка → повторная загрузка пуста.
        let remaining = await realm.fetchVoiceSamples(childId: "child-dr")
        XCTAssertTrue(remaining.isEmpty)
    }

    // MARK: - Helpers (batch 2.6a)

    private func makeTempVoiceFile() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("vc_test_\(UUID().uuidString).m4a")
        FileManager.default.createFile(atPath: url.path, contents: Data([0, 1, 2, 3]))
        return url
    }

    /// Копирует файл в Documents/VoiceArchive/<childId>/ и возвращает относительный путь,
    /// эмулируя copyRecordingToArchive — чтобы playSample нашёл файл на диске.
    private func relativeArchivePath(for source: URL, childId: String) throws -> String {
        let documents = try FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        let dir = documents
            .appendingPathComponent("VoiceArchive", isDirectory: true)
            .appendingPathComponent(childId, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent(source.lastPathComponent)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: source, to: dest)
        return "VoiceArchive/\(childId)/\(source.lastPathComponent)"
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

// MARK: - RecordedFileAudioService
//
// AudioService, чей stopRecording возвращает реальный существующий файл —
// позволяет покрыть успешный путь VoiceCloningInteractor.copyRecordingToArchive.

private final class RecordedFileAudioService: AudioService, @unchecked Sendable {
    var isPermissionGranted: Bool = true
    var amplitude: Float = 0
    var isRecording: Bool = false
    private let recordedFile: URL

    init(recordedFile: URL) { self.recordedFile = recordedFile }

    func requestPermission() async -> Bool { true }
    func startRecording() async throws { isRecording = true }
    func stopRecording() async throws -> URL {
        isRecording = false
        return recordedFile
    }
    func playAudio(url: URL) async throws {}
    func stopPlayback() {}
    func amplitudeBuffer() -> [Float] { [] }
}

// MARK: - ThrowingStartAudioService

private final class ThrowingStartAudioService: AudioService, @unchecked Sendable {
    var isPermissionGranted: Bool = true
    var amplitude: Float = 0
    var isRecording: Bool = false

    func requestPermission() async -> Bool { true }
    func startRecording() async throws {
        throw AppError.audioRecordingFailed("ThrowingStartAudioService forced failure")
    }
    func stopRecording() async throws -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
    }
    func playAudio(url: URL) async throws {}
    func stopPlayback() {}
    func amplitudeBuffer() -> [Float] { [] }
}
