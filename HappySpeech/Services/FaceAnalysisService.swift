import Vision
@preconcurrency import AVFoundation
import Accelerate
import OSLog

// MARK: - Domain Types

/// Результат анализа лица через VNDetectFaceLandmarksRequest.
public struct FaceLandmarkResult: Sendable {
    /// Все найденные точки лица в нормализованных координатах [0,1].
    public let allPoints: [CGPoint]
    /// Точки внешних и внутренних губ.
    public let mouthPoints: [CGPoint]
    /// Точки левого глаза.
    public let leftEyePoints: [CGPoint]
    /// Точки правого глаза.
    public let rightEyePoints: [CGPoint]
    /// Точки контура лица (jawline).
    public let jawPoints: [CGPoint]
    /// Ограничивающий прямоугольник лица в нормализованных координатах.
    public let boundingBox: CGRect
    /// Уверенность детектора (0.0–1.0).
    public let confidence: Float
}

/// Результат анализа симметрии губ через vDSP.
public struct LipSymmetryResult: Sendable {
    /// Оценка симметрии 0.0–1.0; 1.0 = идеальная симметрия.
    public let symmetryScore: Float
    /// Левый угол рта в нормализованных координатах.
    public let leftCorner: CGPoint
    /// Правый угол рта в нормализованных координатах.
    public let rightCorner: CGPoint
    /// Отношение высоты рта к ширине рта.
    public let mouthOpenRatio: Float
    /// Рот открыт (mouthOpenRatio > порог).
    public let isOpen: Bool
}

/// Результат детектирования выдоха через RMS.
public struct FaceAirStreamResult: Sendable {
    /// Нормализованный RMS-уровень 0.0–1.0.
    public let rmsLevel: Float
    /// Обнаружен ли выдох (не тишина и не крик).
    public let isBreathing: Bool
    /// Уверенность детектора 0.0–1.0.
    public let confidence: Float
}

// MARK: - Protocol

/// Сервис Vision-анализа артикуляции:
///   - landmarks через VNDetectFaceLandmarksRequest (76 точек, Apple Vision)
///   - симметрия губ через vDSP
///   - детектирование выдоха через RMS
///
/// Не конкурирует с ARSessionService: тот даёт blendshapes через ARKit;
/// этот работает с сырым CVPixelBuffer (вне AR-сессии, например из AVCaptureSession).
public protocol FaceAnalysisService: Sendable {
    /// Анализирует кадр через VNDetectFaceLandmarksRequest.
    /// - Parameter pixelBuffer: кадр из AVCaptureSession или AVAsset.
    func analyzeFaceLandmarks(pixelBuffer: CVPixelBuffer) async -> FaceLandmarkResult?

    /// Вычисляет симметрию губ из результата landmarks.
    func analyzeLipSymmetry(landmarks: FaceLandmarkResult) -> LipSymmetryResult

    /// Детектирует выдох через RMS PCM-буфера.
    /// - Parameter buffer: буфер из AVAudioEngine @ 16kHz mono.
    func detectAirStream(buffer: AVAudioPCMBuffer) async -> FaceAirStreamResult
}

// MARK: - Live Implementation

/// Реализация Vision ML stack:
///   - VNDetectFaceLandmarksRequest: constellation .constellation76Points (iOS 15+)
///   - LipSymmetryAnalyzer: vDSP mean + геометрический анализ
///   - AirStreamDetector: vDSP_rmsqv с нормализацией к типичному дыхательному диапазону
///
/// `@unchecked Sendable` — VNDetectFaceLandmarksRequest не является Sendable,
/// но мутации защищены внутренним NSLock (один запрос за раз через await).
public final class LiveFaceAnalysisService: FaceAnalysisService, @unchecked Sendable {

    private let logger = Logger(subsystem: "ru.happyspeech", category: "FaceAnalysis")

    // VNDetectFaceLandmarksRequest создаётся один раз; NSLock гарантирует
    // отсутствие одновременного доступа при concurrent вызовах.
    private let landmarksRequest: VNDetectFaceLandmarksRequest
    private let lock = NSLock()

    public init() {
        let request = VNDetectFaceLandmarksRequest()
        request.constellation = .constellation76Points
        self.landmarksRequest = request
    }

    // MARK: - Face Landmarks

    public func analyzeFaceLandmarks(pixelBuffer: CVPixelBuffer) async -> FaceLandmarkResult? {
        // Vision handler выполняется синхронно на вызывающем контексте.
        // Вызов через async позволяет caller'у отменять задачу; сам вызов не блокирует Event Loop,
        // т.к. VNImageRequestHandler возвращается быстро (< 10 ms для 76-точечных landmarks).
        performLandmarksRequest(pixelBuffer: pixelBuffer)
    }

    private func performLandmarksRequest(pixelBuffer: CVPixelBuffer) -> FaceLandmarkResult? {
        lock.lock()
        defer { lock.unlock() }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try handler.perform([landmarksRequest])
        } catch {
            logger.error("VNDetectFaceLandmarks failed: \(error.localizedDescription)")
            return nil
        }

        guard let observation = landmarksRequest.results?.first,
              let landmarks = observation.landmarks else {
            logger.debug("No face detected in frame")
            return nil
        }

        func extractPoints(_ region: VNFaceLandmarkRegion2D?) -> [CGPoint] {
            guard let region else { return [] }
            return region.normalizedPoints.map { CGPoint(x: $0.x, y: $0.y) }
        }

        let outerLips   = extractPoints(landmarks.outerLips)
        let innerLips   = extractPoints(landmarks.innerLips)
        let leftEye     = extractPoints(landmarks.leftEye)
        let rightEye    = extractPoints(landmarks.rightEye)
        let faceContour = extractPoints(landmarks.faceContour)

        var allPoints: [CGPoint] = []
        allPoints += outerLips
        allPoints += innerLips
        allPoints += leftEye
        allPoints += rightEye
        allPoints += extractPoints(landmarks.leftEyebrow)
        allPoints += extractPoints(landmarks.rightEyebrow)
        allPoints += extractPoints(landmarks.nose)
        allPoints += extractPoints(landmarks.noseCrest)
        allPoints += extractPoints(landmarks.medianLine)
        allPoints += faceContour

        return FaceLandmarkResult(
            allPoints:      allPoints,
            mouthPoints:    outerLips + innerLips,
            leftEyePoints:  leftEye,
            rightEyePoints: rightEye,
            jawPoints:      faceContour,
            boundingBox:    observation.boundingBox,
            confidence:     observation.confidence
        )
    }

    // MARK: - Lip Symmetry (vDSP)

    public func analyzeLipSymmetry(landmarks: FaceLandmarkResult) -> LipSymmetryResult {
        let pts = landmarks.mouthPoints
        guard pts.count >= 4 else {
            return LipSymmetryResult(
                symmetryScore:  0.5,
                leftCorner:     .zero,
                rightCorner:    .zero,
                mouthOpenRatio: 0,
                isOpen:         false
            )
        }

        var xsFloat = pts.map { Float($0.x) }
        var ysFloat = pts.map { Float($0.y) }
        let n = vDSP_Length(pts.count)

        var minX: Float = 0; var maxX: Float = 0
        var minY: Float = 0; var maxY: Float = 0
        vDSP_minv(&xsFloat, 1, &minX, n)
        vDSP_maxv(&xsFloat, 1, &maxX, n)
        vDSP_minv(&ysFloat, 1, &minY, n)
        vDSP_maxv(&ysFloat, 1, &maxY, n)

        let width  = maxX - minX
        let height = maxY - minY
        let midY   = (minY + maxY) / 2

        let leftCorner  = CGPoint(x: CGFloat(minX), y: CGFloat(midY))
        let rightCorner = CGPoint(x: CGFloat(maxX), y: CGFloat(midY))

        // Насколько центр рта совпадает с центром кадра (0.5).
        // Отклонение > 0.25 = полная асимметрия.
        let mouthCenterX = (minX + maxX) / 2
        let deviation    = abs(mouthCenterX - 0.5)
        let rawSymmetry  = 1.0 - deviation * 4.0
        let symmetryScore = min(1.0, max(0.0, rawSymmetry))

        let mouthOpenRatio = width > 0.001 ? height / width : 0
        let isOpen = mouthOpenRatio > 0.15

        return LipSymmetryResult(
            symmetryScore:  symmetryScore,
            leftCorner:     leftCorner,
            rightCorner:    rightCorner,
            mouthOpenRatio: mouthOpenRatio,
            isOpen:         isOpen
        )
    }

    // MARK: - Air Stream Detection (RMS via vDSP)

    public func detectAirStream(buffer: AVAudioPCMBuffer) async -> FaceAirStreamResult {
        guard let channelData = buffer.floatChannelData else {
            return FaceAirStreamResult(rmsLevel: 0, isBreathing: false, confidence: 0)
        }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else {
            return FaceAirStreamResult(rmsLevel: 0, isBreathing: false, confidence: 0)
        }

        var samples = [Float](UnsafeBufferPointer(start: channelData[0], count: frameCount))

        // RMS через vDSP_rmsqv (квадратный корень среднего квадрата)
        var rms: Float = 0
        vDSP_rmsqv(&samples, 1, &rms, vDSP_Length(frameCount))

        // Нормализация: типичный выдох ≈ 0.01–0.12 RMS.
        // Порог 0.15 принят как условный «100%» силы выдоха.
        let normalized    = min(1.0, rms / 0.15)

        // Выдох: не тишина (> 0.05) и не крик/шум (< 0.7)
        let isBreathing   = normalized > 0.05 && normalized < 0.7
        let confidence    = isBreathing ? min(1.0, normalized * 2.0) : 0.0

        return FaceAirStreamResult(
            rmsLevel:    normalized,
            isBreathing: isBreathing,
            confidence:  confidence
        )
    }
}

// MARK: - Mock Implementation

/// Мок-реализация для unit-тестов и SwiftUI Preview.
public final class MockFaceAnalysisService: FaceAnalysisService, @unchecked Sendable {

    public var mockLandmarkResult: FaceLandmarkResult?

    public init() {}

    public func analyzeFaceLandmarks(pixelBuffer: CVPixelBuffer) async -> FaceLandmarkResult? {
        mockLandmarkResult
    }

    public func analyzeLipSymmetry(landmarks: FaceLandmarkResult) -> LipSymmetryResult {
        LipSymmetryResult(
            symmetryScore:  0.85,
            leftCorner:     CGPoint(x: 0.3, y: 0.5),
            rightCorner:    CGPoint(x: 0.7, y: 0.5),
            mouthOpenRatio: 0.3,
            isOpen:         true
        )
    }

    public func detectAirStream(buffer: AVAudioPCMBuffer) async -> FaceAirStreamResult {
        FaceAirStreamResult(rmsLevel: 0.3, isBreathing: true, confidence: 0.8)
    }
}
