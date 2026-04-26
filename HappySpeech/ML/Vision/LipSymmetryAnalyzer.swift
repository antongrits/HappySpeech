import Accelerate
import Foundation

// MARK: - LipSymmetryScore

/// Детальный результат анализа симметрии губ.
public struct LipSymmetryScore: Sendable {
    /// Интегральный балл симметрии 0.0–1.0. 1.0 = идеальная симметрия.
    public let symmetryScore: Float
    /// Левый угол рта в нормализованных координатах Vision.
    public let leftCorner: CGPoint
    /// Правый угол рта в нормализованных координатах Vision.
    public let rightCorner: CGPoint
    /// Координата Y медианы рта (нормализованная).
    public let mouthCenterY: Float
    /// Соотношение высота/ширина рта (mouthOpenRatio). > 0.15 = открыт.
    public let mouthOpenRatio: Float
    /// Рот открыт.
    public let isOpen: Bool
    /// Вертикальное смещение левого угла от правого (признак гипотонии уголка).
    /// Значение > 0.05 указывает на значимую асимметрию (возможная дизартрия).
    public let cornerVerticalAsymmetry: Float
    /// Обнаружена ли гипотония (опускание уголка губ — признак дизартрии).
    public let hasHypotonia: Bool
}

// MARK: - LipSymmetryAnalyzer

/// Анализатор симметрии губ на основе 76 точек Apple Vision (pure Swift + vDSP).
/// Не требует ML-модели. Работает с `FaceLandmarks76` из `AppleFaceLandmarksDetector`
/// или `FaceLandmarkResult` из `FaceAnalysisService`.
///
/// Алгоритм:
///   1. Извлечь точки губ (outerLips + innerLips)
///   2. vDSP: найти minX / maxX / minY / maxY — bbox губ
///   3. Левый угол = (minX, midY), правый = (maxX, midY)
///   4. Симметрия = 1 − |centerX − 0.5| × 4 (отклонение от центра кадра)
///   5. Гипотония: |leftY − rightY| > hypotonia threshold
///
/// Пороги откалиброваны на 76-точечном созвездии iOS Vision.
public enum LipSymmetryAnalyzer {

    // MARK: - Thresholds

    /// Рот считается открытым при отношении высота/ширина выше этого значения.
    private static let openRatioThreshold: Float = 0.15
    /// Вертикальная разница уголков выше этого порога = гипотония.
    private static let hypotoniaTreshold: Float = 0.04

    // MARK: - Public API

    /// Анализирует симметрию губ по структуре FaceLandmarks76.
    /// - Parameter landmarks: результат из AppleFaceLandmarksDetector.
    /// - Returns: подробный отчёт симметрии.
    public static func analyze(landmarks: FaceLandmarks76) -> LipSymmetryScore {
        let pts = landmarks.outerLips + landmarks.innerLips
        return compute(mouthPoints: pts)
    }

    /// Анализирует симметрию по массиву точек губ (совместимость с FaceLandmarkResult).
    /// - Parameter mouthPoints: массив точек outerLips + innerLips.
    /// - Returns: подробный отчёт симметрии.
    public static func analyze(mouthPoints: [CGPoint]) -> LipSymmetryScore {
        compute(mouthPoints: mouthPoints)
    }

    // MARK: - Core computation

    private static func compute(mouthPoints pts: [CGPoint]) -> LipSymmetryScore {
        guard pts.count >= 4 else {
            return LipSymmetryScore(
                symmetryScore: 0.5,
                leftCorner: .zero,
                rightCorner: .zero,
                mouthCenterY: 0.5,
                mouthOpenRatio: 0,
                isOpen: false,
                cornerVerticalAsymmetry: 0,
                hasHypotonia: false
            )
        }

        // Конвертация в Float-массивы для vDSP
        var xsF = pts.map { Float($0.x) }
        var ysF = pts.map { Float($0.y) }
        let n = vDSP_Length(pts.count)

        // vDSP: bbox
        var minX: Float = 0, maxX: Float = 0
        var minY: Float = 0, maxY: Float = 0
        vDSP_minv(&xsF, 1, &minX, n)
        vDSP_maxv(&xsF, 1, &maxX, n)
        vDSP_minv(&ysF, 1, &minY, n)
        vDSP_maxv(&ysF, 1, &maxY, n)

        let width   = maxX - minX
        let height  = maxY - minY
        let midY    = (minY + maxY) / 2
        let centerX = (minX + maxX) / 2

        // Симметрия: отклонение центра рта от оси кадра (0.5)
        let deviation = abs(centerX - 0.5)
        let rawSym    = 1.0 - deviation * 4.0
        let symScore  = min(1.0, max(0.0, rawSym))

        // Уголки
        let leftCorner  = CGPoint(x: CGFloat(minX), y: CGFloat(midY))
        let rightCorner = CGPoint(x: CGFloat(maxX), y: CGFloat(midY))

        // Вертикальная асимметрия уголков
        // Ищем реальные точки крайнего левого / правого X
        let leftIdx  = xsF.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
        let rightIdx = xsF.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0
        let leftY    = ysF[leftIdx]
        let rightY   = ysF[rightIdx]
        let vertAsym = abs(leftY - rightY)

        let mouthOpenRatio = width > 0.001 ? height / width : 0
        let isOpen = mouthOpenRatio > openRatioThreshold
        let hasHypotonia = vertAsym > hypotoniaTreshold

        return LipSymmetryScore(
            symmetryScore: symScore,
            leftCorner: leftCorner,
            rightCorner: rightCorner,
            mouthCenterY: midY,
            mouthOpenRatio: mouthOpenRatio,
            isOpen: isOpen,
            cornerVerticalAsymmetry: vertAsym,
            hasHypotonia: hasHypotonia
        )
    }
}
