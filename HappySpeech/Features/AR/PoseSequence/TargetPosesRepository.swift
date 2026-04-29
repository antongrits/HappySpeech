import ARKit

// MARK: - TargetPosesRepository

/// Хранилище 5 эталонных поз для игры PoseSequence.
/// Координаты суставов — синтетические, нормализованные (root = origin).
/// Система координат: X — вправо, Y — вверх, Z — вперёд.
///
/// Позы:
/// 1. `armsUp`        — руки подняты над головой (йога: Уттхита Хастасана)
/// 2. `handsOnHips`   — руки на бёдрах (разминка)
/// 3. `cobra`         — кобра (упрощённая: руки опущены, голова вперёд)
/// 4. `warrior`       — воин (руки в стороны, как Т)
/// 5. `tree`          — дерево (симметричная поза, руки сложены перед грудью)
public enum TargetPosesRepository {

    /// Полный список поз для сессии (фиксированный порядок).
    public static let allPoses: [TargetPose] = [
        armsUp,
        handsOnHips,
        cobra,
        warrior,
        tree
    ]

    // MARK: - 1. Руки вверх

    static let armsUp = TargetPose(
        id: "arms_up",
        name: String(localized: "pose.armsUp.name"),
        hint: String(localized: "pose.armsUp.hint"),
        jointTargets: [
            .root:          SIMD3( 0.00,  0.00,  0.00),
            .head:          SIMD3( 0.00,  1.70,  0.00),
            .leftShoulder:  SIMD3(-0.22,  1.40,  0.00),
            .rightShoulder: SIMD3( 0.22,  1.40,  0.00),
            .leftHand:      SIMD3(-0.25,  2.20,  0.00),
            .rightHand:     SIMD3( 0.25,  2.20,  0.00),
            .leftFoot:      SIMD3(-0.15,  0.00,  0.00),
            .rightFoot:     SIMD3( 0.15,  0.00,  0.00)
        ]
    )

    // MARK: - 2. Руки на бёдрах

    static let handsOnHips = TargetPose(
        id: "hands_on_hips",
        name: String(localized: "pose.handsOnHips.name"),
        hint: String(localized: "pose.handsOnHips.hint"),
        jointTargets: [
            .root:          SIMD3( 0.00,  0.00,  0.00),
            .head:          SIMD3( 0.00,  1.70,  0.00),
            .leftShoulder:  SIMD3(-0.22,  1.40,  0.00),
            .rightShoulder: SIMD3( 0.22,  1.40,  0.00),
            .leftHand:      SIMD3(-0.30,  0.90,  0.05),
            .rightHand:     SIMD3( 0.30,  0.90,  0.05),
            .leftFoot:      SIMD3(-0.15,  0.00,  0.00),
            .rightFoot:     SIMD3( 0.15,  0.00,  0.00)
        ]
    )

    // MARK: - 3. Кобра

    static let cobra = TargetPose(
        id: "cobra",
        name: String(localized: "pose.cobra.name"),
        hint: String(localized: "pose.cobra.hint"),
        jointTargets: [
            .root:          SIMD3( 0.00,  0.00,  0.00),
            .head:          SIMD3( 0.00,  1.60,  0.10),
            .leftShoulder:  SIMD3(-0.22,  1.35,  0.00),
            .rightShoulder: SIMD3( 0.22,  1.35,  0.00),
            .leftHand:      SIMD3(-0.22,  0.70, -0.05),
            .rightHand:     SIMD3( 0.22,  0.70, -0.05),
            .leftFoot:      SIMD3(-0.15,  0.00,  0.00),
            .rightFoot:     SIMD3( 0.15,  0.00,  0.00)
        ]
    )

    // MARK: - 4. Воин (руки в стороны — T-pose)

    static let warrior = TargetPose(
        id: "warrior",
        name: String(localized: "pose.warrior.name"),
        hint: String(localized: "pose.warrior.hint"),
        jointTargets: [
            .root:          SIMD3( 0.00,  0.00,  0.00),
            .head:          SIMD3( 0.00,  1.70,  0.00),
            .leftShoulder:  SIMD3(-0.22,  1.40,  0.00),
            .rightShoulder: SIMD3( 0.22,  1.40,  0.00),
            .leftHand:      SIMD3(-0.80,  1.40,  0.00),
            .rightHand:     SIMD3( 0.80,  1.40,  0.00),
            .leftFoot:      SIMD3(-0.30,  0.00,  0.00),
            .rightFoot:     SIMD3( 0.30,  0.00,  0.00)
        ]
    )

    // MARK: - 5. Дерево (руки перед грудью)

    static let tree = TargetPose(
        id: "tree",
        name: String(localized: "pose.tree.name"),
        hint: String(localized: "pose.tree.hint"),
        jointTargets: [
            .root:          SIMD3( 0.00,  0.00,  0.00),
            .head:          SIMD3( 0.00,  1.70,  0.00),
            .leftShoulder:  SIMD3(-0.22,  1.40,  0.00),
            .rightShoulder: SIMD3( 0.22,  1.40,  0.00),
            .leftHand:      SIMD3(-0.10,  1.35,  0.15),
            .rightHand:     SIMD3( 0.10,  1.35,  0.15),
            .leftFoot:      SIMD3(-0.05,  0.00,  0.00),
            .rightFoot:     SIMD3( 0.05,  0.00,  0.00)
        ]
    )
}
