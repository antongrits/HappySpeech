import Foundation
import XCTest
@testable import HappySpeech

// MARK: - VideoPlayerServiceTests
//
// Тесты VideoPlayerServiceLive + MockVideoPlayerService.
// VideoPlayerServiceLive не воспроизводит реальное видео — это lookup-сервис
// по бандлу. Видеофайлы в тестовом бандле отсутствуют → videoURL возвращает nil,
// проверяется fallback-контракт (SwiftUI-анимация при отсутствии mp4).

final class VideoPlayerServiceTests: XCTestCase {

    // MARK: - VideoPlayerServiceLive

    @MainActor
    func testLiveInitDoesNotCrash() {
        let service = VideoPlayerServiceLive()
        // Манифест может отсутствовать в тестовом бандле — сервис не должен падать.
        XCTAssertNil(service.manifest(for: "nonexistent_id"))
    }

    @MainActor
    func testLiveVideoURLReturnsNilForMissingFile() {
        let service = VideoPlayerServiceLive()
        XCTAssertNil(service.videoURL(for: "definitely_missing_video"),
                     "Отсутствующий mp4 → nil → SwiftUI fallback")
    }

    @MainActor
    func testLiveManifestReturnsNilForUnknownID() {
        let service = VideoPlayerServiceLive()
        XCTAssertNil(service.manifest(for: "unknown"))
    }

    // MARK: - MockVideoPlayerService

    func testMockVideoURLAlwaysNil() {
        let mock = MockVideoPlayerService()
        XCTAssertNil(mock.videoURL(for: "celebration"))
        XCTAssertNil(mock.videoURL(for: ""))
    }

    func testMockManifestReturnsStubEntry() throws {
        let mock = MockVideoPlayerService()
        let entry = try XCTUnwrap(mock.manifest(for: "intro"))
        XCTAssertEqual(entry.id, "intro")
        XCTAssertEqual(entry.duration, 3.0, accuracy: 0.001)
        XCTAssertEqual(entry.description, "Mock intro")
    }

    func testMockManifestIDMatchesRequestedID() {
        let mock = MockVideoPlayerService()
        for id in ["transition", "celebration", "level_up"] {
            XCTAssertEqual(mock.manifest(for: id)?.id, id)
        }
    }

    // MARK: - VideoManifestEntry decoding

    func testManifestEntryDecodesFromJSON() throws {
        let json = #"{"id":"intro","duration":4.5,"description":"Вступление"}"#
        let entry = try JSONDecoder().decode(VideoManifestEntry.self, from: Data(json.utf8))
        XCTAssertEqual(entry.id, "intro")
        XCTAssertEqual(entry.duration, 4.5, accuracy: 0.001)
        XCTAssertEqual(entry.description, "Вступление")
    }

    func testManifestEntryDecodingFailsOnMissingField() {
        let json = #"{"id":"intro"}"#
        XCTAssertThrowsError(
            try JSONDecoder().decode(VideoManifestEntry.self, from: Data(json.utf8))
        )
    }
}
