import AVKit
import OSLog
import SwiftUI

// MARK: - VideoManifestEntry

/// Одна запись из video-manifest.json.
struct VideoManifestEntry: Decodable, Sendable {
    let id: String
    let duration: Double
    let description: String
}

// MARK: - VideoPlayerServiceProtocol

/// Протокол сервиса воспроизведения видео-роликов (celebration, intro, transitions).
///
/// Стратегия:
/// - Если `.mp4` с соответствующим `id` найден в бандле (`Resources/Videos/`) → AVPlayer
/// - Если файл отсутствует → SwiftUI-анимация из `CelebrationOverlayView`
protocol VideoPlayerServiceProtocol: Sendable {

    /// URL видеофайла если он присутствует в бандле (nil → нужен SwiftUI fallback).
    func videoURL(for id: String) -> URL?

    /// Метаданные из манифеста (длительность и т.д.).
    func manifest(for id: String) -> VideoManifestEntry?
}

// MARK: - VideoPlayerServiceLive

@MainActor
final class VideoPlayerServiceLive: VideoPlayerServiceProtocol {

    // MARK: Private

    private let logger = Logger(subsystem: "ru.happyspeech", category: "VideoPlayerService")
    private let manifestEntries: [String: VideoManifestEntry]

    /// Относительные пути файлов внутри каталога `Videos/` по их `id`.
    ///
    /// `Videos` подключён в проекте как folder-reference, поэтому в бандле
    /// сохраняется структура каталогов (`Videos/stories/...`, `Videos/lessons/...`).
    /// Карта строится из секций манифеста с явным полем `path`.
    private let relativePaths: [String: String]

    // MARK: Init

    init() {
        var loaded: [String: VideoManifestEntry] = [:]
        var paths: [String: String] = [:]
        if let url = Bundle.main.url(
            forResource: "video-manifest",
            withExtension: "json",
            subdirectory: "Videos"
        ) {
            do {
                let data = try Data(contentsOf: url)
                let root = try JSONDecoder().decode(VideoManifestRoot.self, from: data)
                for entry in root.videos {
                    loaded[entry.id] = entry
                }
                for section in [root.stories, root.lessons, root.achievements, root.tutorials] {
                    for item in section ?? [] {
                        paths[item.id] = item.path
                    }
                }
            } catch {
                Logger(subsystem: "ru.happyspeech", category: "VideoPlayerService")
                    .error("Ошибка чтения video-manifest.json: \(error.localizedDescription, privacy: .public)")
            }
        }
        manifestEntries = loaded
        relativePaths = paths
    }

    // MARK: VideoPlayerServiceProtocol

    nonisolated func videoURL(for id: String) -> URL? {
        // 1. Категорийные ролики (stories/lessons/...) — путь известен из манифеста.
        if let relativePath = relativePaths[id] {
            let withoutExtension = (relativePath as NSString).deletingPathExtension
            let subdirectory = "Videos/" + (withoutExtension as NSString).deletingLastPathComponent
            let name = (withoutExtension as NSString).lastPathComponent
            if let url = Bundle.main.url(
                forResource: name,
                withExtension: "mp4",
                subdirectory: subdirectory
            ) {
                return url
            }
        }
        // 2. Плоские ролики (intro, trailer, onboarding_hero, celebrate_*, transition_*)
        //    без явного пути — пробуем корень `Videos/` и известные подкаталоги.
        for subdirectory in ["Videos", "Videos/celebrations", "Videos/transitions"] {
            if let url = Bundle.main.url(
                forResource: id,
                withExtension: "mp4",
                subdirectory: subdirectory
            ) {
                return url
            }
        }
        return nil
    }

    nonisolated func manifest(for id: String) -> VideoManifestEntry? {
        manifestEntries[id]
    }

    // MARK: Private helpers

    private struct VideoManifestRoot: Decodable {
        let videos: [VideoManifestEntry]
        let stories: [PathItem]?
        let lessons: [PathItem]?
        let achievements: [PathItem]?
        let tutorials: [PathItem]?
    }

    private struct PathItem: Decodable {
        let id: String
        let path: String
    }
}

// MARK: - MockVideoPlayerService

/// Мок для Preview и тестов.
struct MockVideoPlayerService: VideoPlayerServiceProtocol {
    nonisolated func videoURL(for id: String) -> URL? { nil }
    nonisolated func manifest(for id: String) -> VideoManifestEntry? {
        VideoManifestEntry(id: id, duration: 3.0, description: "Mock \(id)")
    }
}
