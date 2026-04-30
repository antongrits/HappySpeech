import Foundation
import OSLog

// MARK: - CacheClearWorker
//
// Реальная очистка кэша: URLCache + NSCachesDirectory + tmp-директория.
// ML-модели (WhisperKit, PronunciationScorer, LLM) НЕ трогает —
// их повторная загрузка слишком дорога по трафику и времени.

struct CacheClearWorker: Sendable {

    private let logger = Logger(subsystem: "ru.happyspeech", category: "CacheClearWorker")

    init() {}

    /// Возвращает суммарное количество удалённых байт.
    func clearAll() async -> Int {
        var totalBytes: Int = 0

        // 1. URLCache — HTTP-ответы (аудио-файлы, контент-API).
        let urlCache = URLCache.shared
        totalBytes += urlCache.currentDiskUsage
        await MainActor.run { urlCache.removeAllCachedResponses() }
        logger.info("URLCache cleared")

        // 2. NSCachesDirectory — Realm-индексы, декодированные аудио, WhisperKit временные файлы.
        let fm = FileManager.default
        if let cachesURL = fm.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let (bytes, count) = clearDirectory(at: cachesURL, skipPrefixes: mlModelPrefixes, fm: fm)
            totalBytes += bytes
            logger.info("cachesDirectory cleared bytes=\(bytes, privacy: .public) files=\(count, privacy: .public)")
        }

        // 3. Временная директория приложения.
        let tmpURL = fm.temporaryDirectory
        let (tmpBytes, tmpCount) = clearDirectory(at: tmpURL, skipPrefixes: [], fm: fm)
        totalBytes += tmpBytes
        logger.info("tmpDirectory cleared bytes=\(tmpBytes, privacy: .public) files=\(tmpCount, privacy: .public)")

        logger.info("CacheClearWorker finished totalBytes=\(totalBytes, privacy: .public)")
        return totalBytes
    }

    // MARK: - Private

    /// Директории/файлы с этими префиксами пропускаются при очистке caches/.
    /// Это защищает дорогостоящие ML-модели (WhisperKit, LLM) от случайного удаления.
    private let mlModelPrefixes: [String] = [
        "com.argmaxinc.whisperkit",
        "huggingface",
        "mlc-llm",
        "qwen"
    ]

    /// Удаляет содержимое директории (не рекурсивно — верхний уровень).
    /// Пропускает элементы, чьи имена начинаются с `skipPrefixes`.
    /// Возвращает (суммарный размер в байтах, количество удалённых элементов).
    private func clearDirectory(at url: URL, skipPrefixes: [String], fm: FileManager) -> (Int, Int) {
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: .skipsHiddenFiles
        ) else {
            return (0, 0)
        }

        var totalSize = 0
        var deletedCount = 0

        for itemURL in contents {
            let name = itemURL.lastPathComponent

            // Пропустить ML-модели.
            let shouldSkip = skipPrefixes.contains { name.lowercased().hasPrefix($0.lowercased()) }
            if shouldSkip {
                logger.debug("skipping \(name, privacy: .public) (ML model)")
                continue
            }

            // Посчитать размер.
            if let attrs = try? itemURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]) {
                if attrs.isDirectory == true {
                    totalSize += directorySize(at: itemURL, fm: fm)
                } else {
                    totalSize += attrs.fileSize ?? 0
                }
            }

            // Удалить.
            do {
                try fm.removeItem(at: itemURL)
                deletedCount += 1
            } catch {
                logger.warning("failed to remove \(name, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }

        return (totalSize, deletedCount)
    }

    /// Рекурсивный подсчёт размера директории.
    private func directorySize(at url: URL, fm: FileManager) -> Int {
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: .skipsHiddenFiles
        ) else { return 0 }

        var size = 0
        for case let fileURL as URL in enumerator {
            if let attrs = try? fileURL.resourceValues(forKeys: [.fileSizeKey]) {
                size += attrs.fileSize ?? 0
            }
        }
        return size
    }
}
