import OSLog
import PencilKit
import Vision

// MARK: - HandwritingRecognitionWorker

/// Распознаёт рукописные буквы из `PKDrawing` через `VNRecognizeTextRequest`.
///
/// Алгоритм:
///   1. Рендерим PKDrawing в UIImage (масштаб 2x для качества Vision).
///   2. Запускаем VNRecognizeTextRequest с recognitionLanguages = ["ru-RU"].
///   3. Берём первый символ из топ-1 кандидата.
///
/// Actor-изоляция гарантирует что Vision-запрос не блокирует MainActor.
actor HandwritingRecognitionWorker {

    private let logger = Logger(subsystem: "ru.happyspeech", category: "HandwritingRecognition")

    // MARK: - Public

    /// Распознаёт первый символ из рисунка.
    /// - Returns: Буква в верхнем регистре (1 символ) или `nil` если распознать не удалось.
    func recognizeLetter(from drawing: PKDrawing) async -> String? {
        guard !drawing.strokes.isEmpty else {
            logger.debug("Recognition skipped — empty drawing")
            return nil
        }

        // Render с отступом чтобы Vision не обрезал края буквы.
        let bounds = drawing.bounds.insetBy(dx: -24, dy: -24)
        guard !bounds.isEmpty, bounds.width > 10, bounds.height > 10 else {
            logger.debug("Recognition skipped — drawing bounds too small: \(bounds.debugDescription, privacy: .public)")
            return nil
        }

        let image = drawing.image(from: bounds, scale: 2.0)
        guard let cgImage = image.cgImage else {
            logger.warning("Failed to get CGImage from PKDrawing render")
            return nil
        }

        return await performVisionRequest(on: cgImage)
    }

    // MARK: - Private

    private func performVisionRequest(on cgImage: CGImage) async -> String? {
        await withCheckedContinuation { continuation in
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNRecognizeTextRequest { request, _ in
                let raw = (request.results as? [VNRecognizedTextObservation])?
                    .first?
                    .topCandidates(1)
                    .first?
                    .string ?? ""
                let letter = raw.uppercased().first.map { String($0) }
                continuation.resume(returning: letter)
            }
            request.recognitionLanguages = ["ru-RU"]
            request.recognitionLevel = .accurate
            // Не корректируем — ищем одиночную букву, не слово.
            request.usesLanguageCorrection = false
            request.minimumTextHeight = 0.1

            do {
                try handler.perform([request])
            } catch {
                self.logger.warning("VNRecognizeTextRequest failed: \(error.localizedDescription)")
                continuation.resume(returning: nil)
            }
        }
    }
}
