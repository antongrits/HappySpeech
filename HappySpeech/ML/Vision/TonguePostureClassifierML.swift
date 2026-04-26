import CoreML
import Foundation
import OSLog

// MARK: - TonguePostureML

/// Артикуляционная поза языка для Core ML классификатора.
/// Совпадает с `ArticulationPosture` по 8 основным позам + neutral.
public enum TonguePostureML: String, Sendable, CaseIterable, Hashable {
    case neutral      = "neutral"
    case cupShape     = "cup_shape"
    case shoveling    = "shoveling"
    case mushroom     = "mushroom"
    case painter      = "painter"
    case tongueUp     = "tongue_up"
    case tongueDown   = "tongue_down"
    case tongueLeft   = "tongue_left"
    case tongueRight  = "tongue_right"

    /// Локализованное название (совместимо с ArticulationPosture.displayName).
    public var displayName: String {
        switch self {
        case .neutral:    return String(localized: "posture.neutral")
        case .cupShape:   return String(localized: "posture.cupShape")
        case .shoveling:  return String(localized: "posture.shoveling")
        case .mushroom:   return String(localized: "posture.mushroom")
        case .painter:    return String(localized: "posture.painter")
        case .tongueUp:   return String(localized: "posture.tongueUp")
        case .tongueDown: return String(localized: "posture.tongueDown")
        case .tongueLeft: return String(localized: "posture.tongueLeft")
        case .tongueRight:return String(localized: "posture.tongueRight")
        }
    }
}

// MARK: - TonguePostureMLResult

/// Результат классификации с указанием позы и уверенности.
public struct TonguePostureMLResult: Sendable {
    /// Наиболее вероятная поза.
    public let posture: TonguePostureML
    /// Уверенность 0.0–1.0.
    public let confidence: Float
    /// Полная карта вероятностей по всем классам.
    public let probabilities: [TonguePostureML: Float]
}

// MARK: - TonguePostureClassifierML

/// Core ML классификатор поз языка на основе CNN.
/// Принимает feature vector из 50 элементов (ARKit blendshapes + MediaPipe FaceMesh features).
///
/// Модель: `TonguePostureClassifier.mlpackage` (~2 MB, INT8 квантизация)
/// Архитектура: Linear(50→64) + ReLU + Dropout → Linear(64→64) + ReLU → Linear(64→9)
/// Обучена на синтетических данных (M5.3 prototype): 9 классов, 200 примеров/класс.
///
/// Если модель не загружена → автоматический fallback на rule-based `TonguePostureClassifier`.
public final class TonguePostureClassifierML: @unchecked Sendable {

    // MARK: - Private state

    private var mlModel: MLModel?
    private let logger = Logger(subsystem: "ru.happyspeech", category: "TonguePostureML")
    private let fallback = TonguePostureClassifier()
    private let lock = NSLock()

    // MARK: - Feature vector dimension

    /// Размерность входного вектора (blendshapes + FaceMesh агрегированные features).
    public static let featureDimension: Int = 50

    // MARK: - Init

    public init() {
        loadModel()
    }

    // MARK: - Model Loading

    private func loadModel() {
        guard let url = Bundle.main.url(
            forResource: "TonguePostureClassifier",
            withExtension: "mlpackage"
        ) else {
            logger.info("TonguePostureClassifier.mlpackage не найден — используется rule-based fallback")
            return
        }
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all
            mlModel = try MLModel(contentsOf: url, configuration: config)
            logger.info("TonguePostureClassifier.mlpackage загружен успешно")
        } catch {
            logger.error("Ошибка загрузки TonguePostureClassifier: \(error.localizedDescription)")
        }
    }

    // MARK: - Public API

    /// Классифицирует позу языка по feature vector.
    /// - Parameter features: Float-массив из `featureDimension` элементов.
    ///   Порядок: [jawOpen, jawForward, mouthFunnel, mouthPucker, mouthSmileLeft,
    ///   mouthSmileRight, mouthFrownLeft, mouthFrownRight, mouthRollLower, mouthRollUpper,
    ///   mouthStretchLeft, mouthStretchRight, mouthLowerDownLeft, mouthLowerDownRight,
    ///   mouthUpperUpLeft, mouthUpperUpRight, mouthClose, mouthLeft, mouthRight, tongueOut,
    ///   eyeBlinkLeft, eyeBlinkRight, cheekPuff, ... (27 reserved zeros for FaceMesh deltas)]
    /// - Returns: результат с позой и уверенностью.
    public func classify(features: [Float]) -> TonguePostureMLResult {
        guard features.count == Self.featureDimension else {
            logger.error("Неверная размерность features: \(features.count) != \(Self.featureDimension)")
            return fallbackResult(features: features)
        }

        lock.lock()
        defer { lock.unlock() }

        guard let model = mlModel else {
            return fallbackResult(features: features)
        }

        do {
            let inputArray = try MLMultiArray(shape: [NSNumber(value: Self.featureDimension)], dataType: .float32)
            for (i, v) in features.enumerated() {
                inputArray[i] = NSNumber(value: v)
            }
            let featureProvider = try MLDictionaryFeatureProvider(dictionary: ["features": inputArray])
            let prediction = try model.prediction(from: featureProvider)

            // Извлекаем classLabel и вероятности
            if let label = prediction.featureValue(for: "classLabel")?.stringValue,
               let posture = TonguePostureML(rawValue: label),
               let probDict = prediction.featureValue(for: "classProbability")?.dictionaryValue {

                var probs: [TonguePostureML: Float] = [:]
                for (key, val) in probDict {
                    if let keyStr = key as? String,
                       let p = TonguePostureML(rawValue: keyStr) {
                        probs[p] = val.floatValue
                    }
                }
                let confidence = probs[posture] ?? 0.5
                return TonguePostureMLResult(posture: posture, confidence: confidence, probabilities: probs)
            }
        } catch {
            logger.error("TonguePostureClassifier prediction error: \(error.localizedDescription)")
        }

        return fallbackResult(features: features)
    }

    /// Удобная перегрузка: принимает FaceBlendshapes напрямую.
    /// Дополняет вектор нулями в резервных позициях FaceMesh.
    public func classify(blendshapes: FaceBlendshapes) -> TonguePostureMLResult {
        let features = extractFeatureVector(blendshapes: blendshapes)
        return classify(features: features)
    }

    // MARK: - Feature extraction

    /// Формирует feature vector из FaceBlendshapes.
    /// Первые 23 значения = blendshapes; оставшиеся 27 = нули (зарезервировано для FaceMesh).
    public static func extractFeatureVector(blendshapes: FaceBlendshapes) -> [Float] {
        var v: [Float] = [
            blendshapes.jawOpen,
            blendshapes.jawForward,
            blendshapes.mouthFunnel,
            blendshapes.mouthPucker,
            blendshapes.mouthSmileLeft,
            blendshapes.mouthSmileRight,
            blendshapes.mouthFrownLeft,
            blendshapes.mouthFrownRight,
            blendshapes.mouthRollLower,
            blendshapes.mouthRollUpper,
            blendshapes.mouthStretchLeft,
            blendshapes.mouthStretchRight,
            blendshapes.mouthLowerDownLeft,
            blendshapes.mouthLowerDownRight,
            blendshapes.mouthUpperUpLeft,
            blendshapes.mouthUpperUpRight,
            blendshapes.mouthClose,
            blendshapes.mouthLeft,
            blendshapes.mouthRight,
            blendshapes.tongueOut,
            blendshapes.eyeBlinkLeft,
            blendshapes.eyeBlinkRight,
            blendshapes.cheekPuff
        ]
        // Дополняем до featureDimension нулями
        while v.count < featureDimension {
            v.append(0.0)
        }
        return v
    }

    // MARK: - Fallback (rule-based)

    private func fallbackResult(features: [Float]) -> TonguePostureMLResult {
        // Восстанавливаем blendshapes из первых 23 элементов
        let bs = FaceBlendshapes(
            jawOpen:             features.count > 0  ? features[0]  : 0,
            jawForward:          features.count > 1  ? features[1]  : 0,
            mouthFunnel:         features.count > 2  ? features[2]  : 0,
            mouthPucker:         features.count > 3  ? features[3]  : 0,
            mouthSmileLeft:      features.count > 4  ? features[4]  : 0,
            mouthSmileRight:     features.count > 5  ? features[5]  : 0,
            mouthFrownLeft:      features.count > 6  ? features[6]  : 0,
            mouthFrownRight:     features.count > 7  ? features[7]  : 0,
            mouthRollLower:      features.count > 8  ? features[8]  : 0,
            mouthRollUpper:      features.count > 9  ? features[9]  : 0,
            mouthStretchLeft:    features.count > 10 ? features[10] : 0,
            mouthStretchRight:   features.count > 11 ? features[11] : 0,
            mouthLowerDownLeft:  features.count > 12 ? features[12] : 0,
            mouthLowerDownRight: features.count > 13 ? features[13] : 0,
            mouthUpperUpLeft:    features.count > 14 ? features[14] : 0,
            mouthUpperUpRight:   features.count > 15 ? features[15] : 0,
            mouthClose:          features.count > 16 ? features[16] : 0,
            mouthLeft:           features.count > 17 ? features[17] : 0,
            mouthRight:          features.count > 18 ? features[18] : 0,
            tongueOut:           features.count > 19 ? features[19] : 0,
            eyeBlinkLeft:        features.count > 20 ? features[20] : 0,
            eyeBlinkRight:       features.count > 21 ? features[21] : 0,
            cheekPuff:           features.count > 22 ? features[22] : 0
        )
        let rulePosture = fallback.classify(bs)
        // Конвертируем ArticulationPosture → TonguePostureML
        let mlPosture   = TonguePostureML(rawValue: rulePosture.rawValue) ?? .neutral
        let conf        = fallback.confidence(bs, for: rulePosture)
        return TonguePostureMLResult(
            posture: mlPosture,
            confidence: conf,
            probabilities: [mlPosture: conf]
        )
    }

    // MARK: - Helper: instance wrapper для extractFeatureVector

    public func extractFeatureVector(blendshapes: FaceBlendshapes) -> [Float] {
        Self.extractFeatureVector(blendshapes: blendshapes)
    }
}
