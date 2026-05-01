import ARKit
import CoreVideo
import OSLog

// MARK: - SendableCVPixelBuffer

/// Wrapper, позволяющий безопасно передавать `CVPixelBuffer` через actor boundaries.
/// CVPixelBuffer immutable в контексте Vision-детекции (read-only), поэтому @unchecked Sendable безопасен.
private struct SendableCVPixelBuffer: @unchecked Sendable {
    let buffer: CVPixelBuffer
}

// MARK: - UnifiedFacePose

/// Объединённые данные позы лица из ARKit blendshapes + Vision 76 landmarks.
/// Неизменяемое value-type для безопасной передачи между акторами.
public struct UnifiedFacePose: Sendable {
    /// 0–1. Открытость рта (ARKit jawOpen).
    public let mouthOpen: Float
    /// 0–1. Поджатие губ — форма «ы/у поджатое» (ARKit mouthPucker).
    public let lipsPucker: Float
    /// 0–1. Воронкообразная форма губ — звук «у» (ARKit mouthFunnel).
    public let lipsFunnel: Float
    /// 0–1. Улыбка — среднее mouthSmileLeft + mouthSmileRight.
    public let lipsSmile: Float
    /// 0–1. Язык высунут (ARKit tongueOut — единственный tongue blendshape).
    public let tongueOut: Float
    /// 0–1. Симметрия губ (1 = идеальная); из LipSymmetryAnalyzer.
    public let lipSymmetry: Float
    /// 76 Vision landmarks (outerLips + innerLips + ...) — nil если Vision недоступен.
    public let landmarks76: FaceLandmarks76?
}

// MARK: - Viseme

// swiftlint:disable identifier_name
/// Шесть базовых визем — стандарт логопедии для visual feedback.
public enum Viseme: String, Sendable, CaseIterable {
    case closed  // рот закрыт / нейтральная поза
    case a       // открытый рот (jawOpen > 0.6)
    case e       // улыбка (lipsSmile > 0.4)
    case i       // полуоткрытый (mouthOpen > 0.2)
    case o       // поджатие губ — «о» (lipsPucker > 0.5)
    case u       // воронка — «у» (lipsFunnel > 0.5)
}
// swiftlint:enable identifier_name

// MARK: - UnifiedFacePoseWorker

/// Объединяет ARKit 52 blendshapes + Apple Vision 76 landmarks в единый API.
///
/// Применение:
/// ```swift
/// let worker = UnifiedFacePoseWorker()
/// let pose = await worker.analyze(faceAnchor: anchor, pixelBuffer: frame.capturedImage)
/// let viseme = worker.currentViseme(pose)
/// ```
///
/// Real-time, on-device, COPPA-compliant.
/// Зависит от `AppleFaceLandmarksDetector` (actor) и `LipSymmetryAnalyzer` (enum).
@MainActor
public final class UnifiedFacePoseWorker {

    // MARK: - Dependencies

    private let landmarksDetector: AppleFaceLandmarksDetector
    private let logger = Logger(subsystem: "ru.happyspeech.app", category: "UnifiedFacePose")

    // MARK: - Init

    public init(landmarksDetector: AppleFaceLandmarksDetector = AppleFaceLandmarksDetector()) {
        self.landmarksDetector = landmarksDetector
    }

    // MARK: - Public API

    /// Анализирует ARFaceAnchor (blendshapes) + CVPixelBuffer (Vision landmarks).
    /// Vision детектирование происходит асинхронно, не блокирует главный поток.
    ///
    /// - Parameters:
    ///   - faceAnchor: текущий якорь ARKit (52 blendshapes, TrueDepth).
    ///   - pixelBuffer: кадр `ARFrame.capturedImage` (YCbCr, обычно 1920×1440).
    /// - Returns: `UnifiedFacePose` с ключевыми метриками для речевого анализа.
    public func analyze(faceAnchor: ARFaceAnchor, pixelBuffer: CVPixelBuffer) async -> UnifiedFacePose {
        // ARKit blendshapes — релевантные для артикуляции
        let blendShapes = faceAnchor.blendShapes

        let mouthOpen   = blendShapes[.jawOpen]        .floatValue
        let lipsPucker  = blendShapes[.mouthPucker]    .floatValue
        let lipsFunnel  = blendShapes[.mouthFunnel]    .floatValue
        let smileLeft   = blendShapes[.mouthSmileLeft] .floatValue
        let smileRight  = blendShapes[.mouthSmileRight].floatValue
        let lipsSmile   = (smileLeft + smileRight) / 2.0
        let tongueOut   = blendShapes[.tongueOut]      .floatValue

        // Vision 76 landmarks — передаём pixelBuffer через @unchecked Sendable wrapper
        // чтобы избежать Swift 6 data-race предупреждения при передаче в actor.
        let sendableBuffer = SendableCVPixelBuffer(buffer: pixelBuffer)
        let landmarks: FaceLandmarks76? = await landmarksDetector.detect(pixelBuffer: sendableBuffer.buffer)

        // Симметрия губ через vDSP (LipSymmetryAnalyzer — pure value-type)
        let lipSymmetry: Float
        if let lm = landmarks {
            lipSymmetry = LipSymmetryAnalyzer.analyze(landmarks: lm).symmetryScore
        } else {
            lipSymmetry = 1.0  // fallback — нет данных, не штрафуем
        }

        logger.debug("""
            UnifiedFacePose: jaw=\(mouthOpen, format: .fixed(precision: 2)) \
            pucker=\(lipsPucker, format: .fixed(precision: 2)) \
            funnel=\(lipsFunnel, format: .fixed(precision: 2)) \
            smile=\(lipsSmile, format: .fixed(precision: 2)) \
            tongue=\(tongueOut, format: .fixed(precision: 2)) \
            sym=\(lipSymmetry, format: .fixed(precision: 2)) \
            landmarks=\(landmarks != nil ? "yes" : "no")
            """)

        return UnifiedFacePose(
            mouthOpen:    mouthOpen,
            lipsPucker:   lipsPucker,
            lipsFunnel:   lipsFunnel,
            lipsSmile:    lipsSmile,
            tongueOut:    tongueOut,
            lipSymmetry:  lipSymmetry,
            landmarks76:  landmarks
        )
    }

    // MARK: - Viseme Mapping

    /// Определяет текущую визему по unified pose.
    /// Приоритет: pucker > funnel > jawOpen(a) > smile > i > closed.
    /// Используется для real-time lip-sync маскота Ляли.
    ///
    /// - Parameter pose: результат `analyze(faceAnchor:pixelBuffer:)`.
    /// - Returns: ближайшая логопедическая визема.
    public func currentViseme(_ pose: UnifiedFacePose) -> Viseme {
        if pose.lipsPucker > 0.5 { return .o }
        if pose.lipsFunnel  > 0.5 { return .u }
        if pose.mouthOpen   > 0.6 { return .a }
        if pose.lipsSmile   > 0.4 { return .e }
        if pose.mouthOpen   > 0.2 { return .i }
        return .closed
    }
}

// MARK: - NSNumber helper

private extension Optional where Wrapped == NSNumber {
    var floatValue: Float {
        self.map { Float(truncating: $0) } ?? 0.0
    }
}
