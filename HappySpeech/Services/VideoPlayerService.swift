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

    // MARK: Init

    init() {
        var loaded: [String: VideoManifestEntry] = [:]
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
            } catch {
                Logger(subsystem: "ru.happyspeech", category: "VideoPlayerService")
                    .error("Ошибка чтения video-manifest.json: \(error.localizedDescription, privacy: .public)")
            }
        }
        manifestEntries = loaded
    }

    // MARK: VideoPlayerServiceProtocol

    nonisolated func videoURL(for id: String) -> URL? {
        Bundle.main.url(forResource: id, withExtension: "mp4", subdirectory: "Videos")
    }

    nonisolated func manifest(for id: String) -> VideoManifestEntry? {
        manifestEntries[id]
    }

    // MARK: Private helpers

    private struct VideoManifestRoot: Decodable {
        let videos: [VideoManifestEntry]
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
