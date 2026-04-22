import Foundation
import Observation
import OSLog

// MARK: - LLMModelDownloadManager
// ==================================================================================
// Manages the lazy, Wi-Fi-only download of the on-device LLM (Qwen2.5-1.5B ~950 MB).
// Observable (SwiftUI views can bind progress). Serialized (no parallel downloads).
//
// Rules:
//  * Never auto-download on cellular.
//  * User must explicitly trigger (Settings → "Скачать ИИ" button).
//  * If download fails, app continues with rule-based fallback — no blocking UI.
// ==================================================================================

@Observable
@MainActor
public final class LLMModelDownloadManager {

    public enum State: Equatable, Sendable {
        case idle
        case notOnWifi
        case downloading(progress: Double)
        case downloaded
        case failed(String)
    }

    // MARK: - State
    public private(set) var state: State = .idle
    public private(set) var progress: Double = 0

    private let localLLM: any LocalLLMService
    private let networkMonitor: any NetworkMonitorService
    private var currentTask: Task<Void, Never>?

    public init(localLLM: any LocalLLMService, networkMonitor: any NetworkMonitorService) {
        self.localLLM = localLLM
        self.networkMonitor = networkMonitor
        self.state = localLLM.isModelDownloaded ? .downloaded : .idle
    }

    // MARK: - Public API

    public var isReady: Bool { localLLM.isModelDownloaded && localLLM.isModelLoaded }

    /// Start the download — Wi-Fi only. Silent no-op if already downloaded.
    public func startDownloadIfNeeded() {
        guard !localLLM.isModelDownloaded else {
            state = .downloaded
            return
        }
        guard networkMonitor.connectionType == .wifi else {
            HSLogger.llm.info("LLM download blocked — not on Wi-Fi")
            state = .notOnWifi
            return
        }
        guard currentTask == nil else {
            HSLogger.llm.debug("LLM download already in progress")
            return
        }

        state = .downloading(progress: 0)
        progress = 0
        currentTask = Task { [weak self] in
            await self?.runDownload()
        }
    }

    public func cancel() {
        currentTask?.cancel()
        currentTask = nil
        state = .idle
    }

    // MARK: - Private

    private func runDownload() async {
        HSLogger.llm.info("Starting LLM download")
        do {
            // Drive progress updates while the underlying download runs.
            let progressTask = Task { [weak self] in
                var fake: Double = 0
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    fake = min(0.97, fake + 0.02)
                    await MainActor.run { [weak self] in
                        guard let self, case .downloading = self.state else { return }
                        self.progress = fake
                        self.state = .downloading(progress: fake)
                    }
                }
            }

            try await localLLM.downloadModel()
            progressTask.cancel()
            progress = 1.0
            state = .downloaded
            HSLogger.llm.info("LLM download complete")
        } catch {
            HSLogger.llm.error("LLM download failed: \(error.localizedDescription)")
            state = .failed(error.localizedDescription)
        }
        currentTask = nil
    }
}
