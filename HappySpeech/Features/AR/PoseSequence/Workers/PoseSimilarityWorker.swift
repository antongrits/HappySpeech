import ARKit
import simd

// MARK: - TargetPose

/// Эталонная поза тела: имя, локализованная подсказка и целевые позиции суставов.
public struct TargetPose: Sendable, Identifiable {
    public let id: String
    /// Русское название позы для UI (например «Руки вверх»).
    public let name: String
    /// Подсказка для ребёнка (короткая инструкция, например «Подними руки над головой»).
    public let hint: String
    /// Целевые позиции суставов в нормализованной системе координат (origin = root).
    public let jointTargets: [ARSkeleton.JointName: SIMD3<Float>]

    public init(
        id: String,
        name: String,
        hint: String,
        jointTargets: [ARSkeleton.JointName: SIMD3<Float>]
    ) {
        self.id = id
        self.name = name
        self.hint = hint
        self.jointTargets = jointTargets
    }
}

// MARK: - PoseSimilarityWorker

/// Вычисляет cosine similarity между текущими суставами и эталонной позой.
/// Возвращает score 0...100 — чем выше, тем точнее поза.
///
/// Алгоритм:
/// 1. Нормализуем векторы текущей и целевой позиции каждого сустава от root.
/// 2. Считаем cosine similarity: dot(a_norm, b_norm) ∈ [-1, 1].
/// 3. Зажимаем в [0, 1], усредняем по всем совпадающим суставам.
/// 4. Умножаем на 100.
public actor PoseSimilarityWorker {

    public init() {}

    /// Рассчитывает сходство текущей позы с эталоном. Возвращает 0...100.
    /// - Parameters:
    ///   - current: словарь суставов из `BodyPoseWorker`.
    ///   - target: эталонная поза из `TargetPosesRepository`.
    /// - Returns: score 0...100.
    public func score(
        current: [ARSkeleton.JointName: SIMD3<Float>],
        target: TargetPose
    ) -> Int {
        let currentRoot = current[.root] ?? .zero
        let targetRoot = target.jointTargets[.root] ?? .zero

        var totalScore: Float = 0
        var count: Float = 0

        for (joint, targetPos) in target.jointTargets {
            guard joint != .root, let currentPos = current[joint] else { continue }

            // Позиции относительно root
            let currentVec = currentPos - currentRoot
            let targetVec = targetPos - targetRoot

            let currentLen = simd_length(currentVec)
            let targetLen = simd_length(targetVec)

            // Если оба вектора близки к нулю — считаем совпадением
            if currentLen < 1e-4 && targetLen < 1e-4 {
                totalScore += 1.0
                count += 1
                continue
            }

            // Если один из векторов нулевой — 0 совпадения
            guard currentLen > 1e-4, targetLen > 1e-4 else {
                count += 1
                continue
            }

            let cosine = simd_dot(
                simd_normalize(currentVec),
                simd_normalize(targetVec)
            )
            // Зажимаем: cosine ∈ [-1, 1] → [0, 1]
            totalScore += max(0, cosine)
            count += 1
        }

        guard count > 0 else { return 0 }
        let avg = totalScore / count
        return Int((avg * 100).rounded())
    }
}
