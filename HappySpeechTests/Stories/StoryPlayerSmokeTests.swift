import AVKit
import XCTest

@testable import HappySpeech

// MARK: - StoryPlayerSmokeTests

/// Smoke-тесты для AnimatedStoryPlayerView.
/// Проверяют наличие bundle-ресурсов, целостность данных StoryLibrary
/// и базовую инициализацию AVPlayer — без рендеринга SwiftUI и без play().
final class StoryPlayerSmokeTests: XCTestCase {

    // MARK: - Helpers

    /// Воспроизводит логику mp4URL(for:) из AnimatedStoryPlayerView,
    /// которая объявлена private. Тест обращается к Bundle напрямую
    /// (smoke-уровень: ищем ресурс в том же bundle, что и production-код).
    ///
    /// Тесты выполняются hosted в `HappySpeech.app` (TEST_HOST), поэтому
    /// `Bundle.main` указывает на бандл приложения. xcodegen добавляет
    /// `Resources` как `type: group` → ресурсы кладутся плоской структурой,
    /// поэтому помимо поиска по subdirectory есть flat-fallback.
    private func mp4URL(for storyId: String) -> URL? {
        let bundles = [Bundle.main, Bundle(for: type(of: self))]
        for bundle in bundles {
            if let url = bundle.url(
                forResource: storyId,
                withExtension: "mp4",
                subdirectory: "stories"
            ) {
                return url
            }
            if let url = bundle.url(forResource: storyId, withExtension: "mp4") {
                return url
            }
        }
        return nil
    }

    // MARK: - Тест 1: MP4 для существующей истории находится в bundle

    /// Smoke: "shustray-shishka" — первая история из video-manifest.json.
    /// AnimatedStoryPlayerView выбирает AVPlayer-режим именно по этому id.
    func test_mp4URL_existsForKnownStory_returnsBundleURL() {
        let storyId = "shustray-shishka"
        let url = mp4URL(for: storyId)
        XCTAssertNotNil(
            url,
            "MP4 для '\(storyId)' должен быть в bundle (Videos/stories/\(storyId).mp4)"
        )
    }

    // MARK: - Тест 2: Несуществующий id возвращает nil → fallback

    /// Несуществующий id должен вернуть nil, чтобы AnimatedStoryPlayerView
    /// переключился на native SwiftUI fallback-режим.
    func test_mp4URL_doesNotExistForUnknownStory_returnsNil() {
        let url = mp4URL(for: "nonexistent_story_999")
        XCTAssertNil(
            url,
            "Несуществующий story id должен вернуть nil → fallback на native SwiftUI mode"
        )
    }

    // MARK: - Тест 3: AVPlayer не крашится при инициализации с валидным URL

    /// Smoke: AVPlayer(url:) не должен крашиться для реального bundle-URL.
    /// play() намеренно не вызывается — требует UI runtime.
    func test_avPlayerInit_doesNotCrash_forValidURL() throws {
        let storyId = "sinyaya-sobaka"
        let url = try XCTUnwrap(
            mp4URL(for: storyId),
            "MP4 для '\(storyId)' должен быть в bundle"
        )
        let player = AVPlayer(url: url)
        XCTAssertNotNil(player, "AVPlayer должен успешно инициализироваться с bundle URL")
        // play() не вызываем — smoke только на init
    }

    // MARK: - Тест 4: Все 20 историй в StoryLibrary имеют непустой id

    /// Data integrity: каждая история из StoryLibrary.shared.allStories
    /// должна иметь непустой id (иначе mp4URL(for:) гарантированно сломается).
    func test_storyLibrary_allStoriesHaveValidIds() {
        let stories = StoryLibrary.shared.allStories
        XCTAssertFalse(stories.isEmpty, "StoryLibrary должна содержать хотя бы одну историю")
        for story in stories {
            XCTAssertFalse(
                story.id.isEmpty,
                "История '\(story.title)' имеет пустой id — это недопустимо"
            )
        }
    }

    // MARK: - Тест 5: video-manifest.json синхронен с bundle — все 20 MP4 findable

    /// Открывает video-manifest.json из bundle, для каждой записи в "stories"
    /// проверяет, что MP4-файл реально находится через Bundle.main.url.
    /// Цель: 20 историй из manifest — все должны быть найдены.
    func test_videoManifest_allStoriesHaveCorrespondingMP4() throws {
        // Ищем манифест в bundle теста или в main bundle
        let manifestURL = Bundle(for: type(of: self)).url(
            forResource: "video-manifest",
            withExtension: "json"
        ) ?? Bundle.main.url(
            forResource: "video-manifest",
            withExtension: "json"
        )
        let resolvedURL = try XCTUnwrap(
            manifestURL,
            "video-manifest.json должен быть в bundle"
        )

        let data = try Data(contentsOf: resolvedURL)

        struct ManifestStory: Decodable {
            let id: String
            let path: String
        }
        struct Manifest: Decodable {
            let stories: [ManifestStory]
        }

        let manifest = try JSONDecoder().decode(Manifest.self, from: data)
        XCTAssertEqual(
            manifest.stories.count, 20,
            "video-manifest.json должен содержать ровно 20 историй"
        )

        var missing: [String] = []
        for story in manifest.stories {
            let found = mp4URL(for: story.id)
            if found == nil {
                missing.append(story.id)
            }
        }
        XCTAssertTrue(
            missing.isEmpty,
            "Следующие MP4 из manifest не найдены в bundle: \(missing.joined(separator: ", "))"
        )
    }
}
