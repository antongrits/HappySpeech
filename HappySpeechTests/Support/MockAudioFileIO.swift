import Foundation
@testable import HappySpeech

// MARK: - MockAudioFilePlayer

/// Тестовый дубль ``AudioFilePlaying`` со spy-счётчиками.
///
/// Plan v25 Block 1.2 — позволяет unit-тестировать Interactor'ы с аудио-воспроизведением
/// (`SessionHistoryInteractor`, `VoiceCloningInteractor`) без `AVAudioPlayer`.
///
/// Пример:
/// ```swift
/// let player = MockAudioFilePlayer(stubbedDuration: 4.0)
/// let sut = SessionHistoryInteractor(audioPlayer: player)
/// // ...
/// XCTAssertEqual(player.playCallCount, 1)
/// XCTAssertEqual(player.lastPlayedURL?.lastPathComponent, "session.m4a")
/// ```
public final class MockAudioFilePlayer: AudioFilePlaying, @unchecked Sendable {

    /// Подставная длительность, возвращаемая `duration`.
    public var stubbedDuration: TimeInterval

    /// Если `true` — `play(contentsOf:)` бросает ошибку.
    public var shouldFailPlayback: Bool = false

    // Spy state
    public private(set) var isPlaying: Bool = false
    public private(set) var playCallCount: Int = 0
    public private(set) var stopCallCount: Int = 0
    public private(set) var lastPlayedURL: URL?

    public init(stubbedDuration: TimeInterval = 1.0) {
        self.stubbedDuration = stubbedDuration
    }

    public var duration: TimeInterval { isPlaying ? stubbedDuration : 0 }

    public func play(contentsOf url: URL) throws {
        playCallCount += 1
        lastPlayedURL = url
        if shouldFailPlayback {
            throw AppError.audioPlaybackFailed("MockAudioFilePlayer forced failure")
        }
        isPlaying = true
    }

    public func stop() {
        stopCallCount += 1
        isPlaying = false
    }
}

// MARK: - MockAudioFileRecorder

/// Тестовый дубль ``AudioFileRecording`` со spy-счётчиками.
///
/// Plan v25 Block 1.2 — позволяет unit-тестировать `FluencyDiaryInteractor`
/// без `AVAudioRecorder`.
///
/// Пример:
/// ```swift
/// let recorder = MockAudioFileRecorder()
/// let sut = FluencyDiaryInteractor(storageWorker: ..., fileRecorder: recorder)
/// // ...
/// XCTAssertEqual(recorder.startCallCount, 1)
/// XCTAssertTrue(recorder.didStop)
/// ```
public final class MockAudioFileRecorder: AudioFileRecording, @unchecked Sendable {

    /// Если `true` — `startRecording(to:)` возвращает `false` (имитация ошибки).
    public var shouldFailStart: Bool = false

    // Spy state
    public private(set) var isRecording: Bool = false
    public private(set) var fileURL: URL?
    public private(set) var startCallCount: Int = 0
    public private(set) var stopCallCount: Int = 0
    public private(set) var didStop: Bool = false

    public init() {}

    @discardableResult
    public func startRecording(to url: URL) -> Bool {
        startCallCount += 1
        if shouldFailStart {
            fileURL = nil
            isRecording = false
            return false
        }
        fileURL = url
        isRecording = true
        return true
    }

    public func stopRecording() {
        stopCallCount += 1
        didStop = true
        isRecording = false
    }
}
