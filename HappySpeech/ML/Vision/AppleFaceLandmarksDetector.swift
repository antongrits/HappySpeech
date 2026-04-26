import CoreVideo
import Foundation
import OSLog
import Vision

// MARK: - FaceLandmarks76

/// Структурированные данные 76 точек лица из VNDetectFaceLandmarksRequest.
/// Разбиты по регионам для удобства использования в артикуляционном анализе.
public struct FaceLandmarks76: Sendable {
    /// Внешние губы (outerLips) — до 12 точек.
    public let outerLips: [CGPoint]
    /// Внутренние губы (innerLips) — до 8 точек.
    public let innerLips: [CGPoint]
    /// Нос (nose) — 5 точек.
    public let nose: [CGPoint]
    /// Гребень носа (noseCrest) — 3 точки.
    public let noseCrest: [CGPoint]
    /// Левый глаз — до 8 точек.
    public let leftEye: [CGPoint]
    /// Правый глаз — до 8 точек.
    public let rightEye: [CGPoint]
    /// Левая бровь — до 7 точек.
    public let leftEyebrow: [CGPoint]
    /// Правая бровь — до 7 точек.
    public let rightEyebrow: [CGPoint]
    /// Контур лица / линия челюсти — до 17 точек.
    public let jaw: [CGPoint]
    /// Медиальная линия (medianLine) — центральные точки сверху вниз.
    public let medianLine: [CGPoint]
    /// Все точки в одном массиве (удобно для передачи в LipSymmetryAnalyzer).
    public let allPoints: [CGPoint]
    /// Ограничивающий прямоугольник лица в нормализованных координатах [0,1].
    public let boundingBox: CGRect
    /// Уверенность детектора (0.0–1.0).
    public let confidence: Float
}

// MARK: - AppleFaceLandmarksDetector

/// Thread-safe actor для детектирования 76 точек лица через Apple Vision framework.
/// Принимает `CVPixelBuffer` из `ARFrame.capturedImage` или `AVCaptureSession`.
/// Работает в фоне, не блокирует главный поток (< 10 ms на кадр, iPhone 12+).
///
/// Использование:
/// ```swift
/// let detector = AppleFaceLandmarksDetector()
/// if let landmarks = await detector.detect(pixelBuffer: frame.capturedImage) {
///     let symmetry = LipSymmetryAnalyzer.analyze(landmarks: landmarks)
/// }
/// ```
public actor AppleFaceLandmarksDetector {

    // MARK: - Private state

    private let landmarksRequest: VNDetectFaceLandmarksRequest
    private let logger = Logger(subsystem: "ru.happyspeech", category: "FaceLandmarks76")

    // MARK: - Init

    public init() {
        let request = VNDetectFaceLandmarksRequest()
        // iOS 15+ поддерживает 76-точечное созвездие; iOS 13–14 даёт 65 точек
        if #available(iOS 15, *) {
            request.constellation = .constellation76Points
        }
        self.landmarksRequest = request
    }

    // MARK: - Public API

    /// Детектирует 76 точек лица в заданном пиксельном буфере.
    /// - Parameter pixelBuffer: кадр 640×480 или выше, YCbCr / BGRA / RGB.
    /// - Returns: Заполненная структура `FaceLandmarks76` или `nil` если лицо не найдено.
    public func detect(pixelBuffer: CVPixelBuffer) -> FaceLandmarks76? {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try handler.perform([landmarksRequest])
        } catch {
            logger.error("VNDetectFaceLandmarks perform error: \(error.localizedDescription)")
            return nil
        }

        guard let observation = landmarksRequest.results?.first,
              let landmarks = observation.landmarks else {
            logger.debug("No face detected in pixelBuffer")
            return nil
        }

        func extract(_ region: VNFaceLandmarkRegion2D?) -> [CGPoint] {
            guard let r = region else { return [] }
            return r.normalizedPoints.map { CGPoint(x: $0.x, y: $0.y) }
        }

        let outerLips   = extract(landmarks.outerLips)
        let innerLips   = extract(landmarks.innerLips)
        let nose        = extract(landmarks.nose)
        let noseCrest   = extract(landmarks.noseCrest)
        let leftEye     = extract(landmarks.leftEye)
        let rightEye    = extract(landmarks.rightEye)
        let leftBrow    = extract(landmarks.leftEyebrow)
        let rightBrow   = extract(landmarks.rightEyebrow)
        let jaw         = extract(landmarks.faceContour)
        let medianLine  = extract(landmarks.medianLine)

        let allPoints = outerLips + innerLips + nose + noseCrest
            + leftEye + rightEye + leftBrow + rightBrow
            + jaw + medianLine

        return FaceLandmarks76(
            outerLips: outerLips,
            innerLips: innerLips,
            nose: nose,
            noseCrest: noseCrest,
            leftEye: leftEye,
            rightEye: rightEye,
            leftEyebrow: leftBrow,
            rightEyebrow: rightBrow,
            jaw: jaw,
            medianLine: medianLine,
            allPoints: allPoints,
            boundingBox: observation.boundingBox,
            confidence: observation.confidence
        )
    }

    // MARK: - AsyncSequence publisher

    /// Запускает асинхронный поток детектирования по буферам из переданной последовательности.
    /// Позволяет интегрировать детектор с `AsyncStream<CVPixelBuffer>` от ARKit / AVFoundation.
    /// - Parameter frames: входной поток кадров.
    /// - Returns: поток результатов (nil-кадры пропускаются).
    public func landmarksStream(
        from frames: AsyncStream<CVPixelBuffer>
    ) -> AsyncStream<FaceLandmarks76> {
        AsyncStream { continuation in
            Task {
                for await buffer in frames {
                    if let result = self.detect(pixelBuffer: buffer) {
                        continuation.yield(result)
                    }
                }
                continuation.finish()
            }
        }
    }
}
