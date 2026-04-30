import AVFoundation
import CoreImage
import OSLog
import Vision

// MARK: - HandPoseWorkerProtocol

/// Протокол для детектирования позы руки на одном кадре.
/// Реализован как `actor` — Swift 6 concurrency безопасен для вызова из любого контекста.
public protocol HandPoseWorkerProtocol: Actor {
    /// Анализирует один `CVPixelBuffer` и возвращает наблюдение, либо `nil` если рука не найдена.
    func detect(in pixelBuffer: CVPixelBuffer) async throws -> HandPoseObservation?
}

// MARK: - HandPoseWorker

/// Real-time детектор позы руки через `VNDetectHumanHandPoseRequest` (Vision framework, iOS 14+).
///
/// Работает на любом iPhone — не требует TrueDepth / LiDAR / A-серии выше A12.
/// Максимальное количество рук: 1 (для упрощения UX у детей).
/// Обрабатывает: `VNHumanHandPoseObservation` → 21 лендмарк → эвристика → `HandPose`.
///
/// Использование:
/// ```swift
/// let worker = HandPoseWorker()
/// if let obs = try await worker.detect(in: pixelBuffer) {
///     // obs.pose — определённая поза
/// }
/// ```
public actor HandPoseWorker: HandPoseWorkerProtocol {

    // MARK: - Private

    private let request: VNDetectHumanHandPoseRequest
    private let confidenceThreshold: Float

    // MARK: - Init

    /// - Parameters:
    ///   - maxHandCount: максимальное число рук (1 для детского режима).
    ///   - confidenceThreshold: минимальная уверенность точки для включения в landmarks.
    public init(maxHandCount: Int = 1, confidenceThreshold: Float = 0.6) {
        let req = VNDetectHumanHandPoseRequest()
        req.maximumHandCount = maxHandCount
        // Разрешаем работу в фоне, не блокируя main thread.
        req.preferBackgroundProcessing = true
        self.request = req
        self.confidenceThreshold = confidenceThreshold
    }

    // MARK: - Public API

    /// Детектирует позу руки в кадре.
    /// - Parameter pixelBuffer: входной кадр (AVCaptureOutput или ARFrame.capturedImage).
    /// - Returns: `HandPoseObservation` если рука найдена, `nil` если нет.
    /// - Throws: `VNError` если Vision не может обработать буфер.
    public func detect(in pixelBuffer: CVPixelBuffer) async throws -> HandPoseObservation? {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        try handler.perform([request])

        guard let result = request.results?.first else { return nil }

        // Извлекаем все 21 точку
        let allPoints: [VNHumanHandPoseObservation.JointName: VNRecognizedPoint]
        do {
            allPoints = try result.recognizedPoints(.all)
        } catch {
            HSLogger.ar.error("HandPoseWorker: recognizedPoints failed — \(error.localizedDescription)")
            return nil
        }

        let landmarks = buildLandmarks(from: allPoints)
        let pose = classifyPose(allPoints: allPoints)

        // Средняя уверенность детектированных точек
        let validConfidences = allPoints.values.map { Float($0.confidence) }.filter { $0 > 0 }
        let avgConfidence: Float = validConfidences.isEmpty ? 0 :
            validConfidences.reduce(0, +) / Float(validConfidences.count)

        let chirality: HandChirality = {
            switch result.chirality {
            case .left:    return .left
            case .right:   return .right
            default:       return .unknown
            }
        }()

        HSLogger.ar.debug("HandPoseWorker: pose=\(pose.debugDescription) conf=\(avgConfidence, format: .fixed(precision: 2)) chirality=\(chirality.rawValue)")

        return HandPoseObservation(
            pose: pose,
            confidence: avgConfidence,
            landmarks: landmarks,
            chirality: chirality,
            timestamp: Date().timeIntervalSince1970
        )
    }

    // MARK: - Landmarks extraction

    /// Строит массив из 21 нормализованных координат.
    /// Если точка не детектирована с нужной уверенностью — ставим (-1, -1).
    private func buildLandmarks(
        from allPoints: [VNHumanHandPoseObservation.JointName: VNRecognizedPoint]
    ) -> [CGPoint] {
        let orderedJoints: [VNHumanHandPoseObservation.JointName] = [
            // Запястье
            .wrist,
            // Большой палец
            .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
            // Указательный
            .indexMCP, .indexPIP, .indexDIP, .indexTip,
            // Средний
            .middleMCP, .middlePIP, .middleDIP, .middleTip,
            // Безымянный
            .ringMCP, .ringPIP, .ringDIP, .ringTip,
            // Мизинец
            .littleMCP, .littlePIP, .littleDIP, .littleTip
        ]
        return orderedJoints.map { joint in
            if let point = allPoints[joint], Float(point.confidence) >= confidenceThreshold {
                return CGPoint(x: point.location.x, y: point.location.y)
            }
            return CGPoint(x: -1, y: -1)
        }
    }

    // MARK: - Pose classification (эвристика)

    /// Классифицирует позу по геометрии лендмарков.
    /// Все координаты нормализованы [0…1] с началом координат в левом нижнем углу.
    private func classifyPose(
        allPoints: [VNHumanHandPoseObservation.JointName: VNRecognizedPoint]
    ) -> HandPose {
        guard
            let wrist       = point(allPoints, .wrist),
            let thumbTip    = point(allPoints, .thumbTip),
            let indexTip    = point(allPoints, .indexTip),
            let middleTip   = point(allPoints, .middleTip),
            let ringTip     = point(allPoints, .ringTip),
            let littleTip   = point(allPoints, .littleTip),
            let indexMCP    = point(allPoints, .indexMCP),
            let middleMCP   = point(allPoints, .middleMCP),
            let ringMCP     = point(allPoints, .ringMCP),
            let littleMCP   = point(allPoints, .littleMCP),
            let middlePIP   = point(allPoints, .middlePIP),
            let ringPIP     = point(allPoints, .ringPIP),
            let littlePIP   = point(allPoints, .littlePIP),
            let indexPIP    = point(allPoints, .indexPIP)
        else {
            return .unknown
        }

        // Расстояние от кончика пальца до запястья
        let indexExt   = distance(indexTip,  wrist)
        let middleExt  = distance(middleTip, wrist)
        let ringExt    = distance(ringTip,   wrist)
        let littleExt  = distance(littleTip, wrist)
        let thumbExt   = distance(thumbTip,  wrist)

        // Пальцы считаются "вытянутыми" если кончик заметно дальше от запястья, чем MCP
        let indexMCPDist  = distance(indexMCP,  wrist)
        let middleMCPDist = distance(middleMCP, wrist)
        let ringMCPDist   = distance(ringMCP,   wrist)
        let littleMCPDist = distance(littleMCP, wrist)

        let extRatio: Float = 1.35

        let indexExtended  = indexExt  > indexMCPDist  * extRatio
        let middleExtended = middleExt > middleMCPDist * extRatio
        let ringExtended   = ringExt   > ringMCPDist   * extRatio
        let littleExtended = littleExt > littleMCPDist * extRatio
        let thumbExtended  = thumbExt  > indexMCPDist  * 1.1

        // --- PINCH: большой и указательный близко ---
        let thumbIndexDist = distance(thumbTip, indexTip)
        if thumbIndexDist < 0.06, indexExtended || Float(indexTip.y) > Float(indexPIP.y) {
            return .pinch
        }

        // --- THUMBS UP: большой вверх, остальные свёрнуты ---
        // В системе координат Vision y=0 внизу, y=1 вверху.
        let thumbAboveWrist = Float(thumbTip.y) > Float(wrist.y) + 0.15
        let othersCurled = !indexExtended && !middleExtended && !ringExtended && !littleExtended
        if thumbExtended, thumbAboveWrist, othersCurled {
            return .thumbsUp
        }

        // --- FIST: все пальцы свёрнуты ---
        if !indexExtended, !middleExtended, !ringExtended, !littleExtended, !thumbExtended {
            return .fist
        }

        // --- OPEN PALM: все 5 вытянуты ---
        if indexExtended, middleExtended, ringExtended, littleExtended {
            return .openPalm
        }

        // --- POINT: только указательный вытянут ---
        let onlyIndex = indexExtended && !middleExtended && !ringExtended && !littleExtended
        if onlyIndex {
            return .point
        }

        // --- WAVE: указательный + средний + безымянный + мизинец вытянуты, большой нет ---
        // Дополнительно: кончики пальцев в горизонтально рассредоточены (веер)
        if indexExtended, middleExtended, ringExtended, littleExtended {
            let spread = abs(Float(indexTip.x) - Float(littleTip.x))
            if spread > 0.12 {
                return .wave
            }
        }

        // --- Дополнительные паттерны: индекс + средний (победа/ножницы) → wave ---
        // middlePIP / ringPIP / littlePIP используются в будущих расширениях эвристики
        _ = middlePIP
        _ = ringPIP
        _ = littlePIP

        if indexExtended, middleExtended, !ringExtended, !littleExtended {
            return .wave
        }

        return .unknown
    }

    // MARK: - Helpers

    private func point(
        _ allPoints: [VNHumanHandPoseObservation.JointName: VNRecognizedPoint],
        _ joint: VNHumanHandPoseObservation.JointName
    ) -> CGPoint? {
        guard let p = allPoints[joint], Float(p.confidence) >= confidenceThreshold else { return nil }
        return CGPoint(x: p.location.x, y: p.location.y)
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> Float {
        let dx = Float(a.x - b.x)
        let dy = Float(a.y - b.y)
        return (dx * dx + dy * dy).squareRoot()
    }
}
