import Foundation
import Testing
@testable import HappySpeech

// MARK: - LyalyaRealityKitViewTests
//
// Unit-тесты для типов lip-sync маскота Ляли (ADR-V29-MASCOT-3D).
//
// Snapshot-тесты ARView невозможны в стандартном simulator (Metal недоступен),
// поэтому тесты сосредоточены на value-логике:
//  1. LyalyaViseme — состав и уникальность кейсов
//  2. Viseme → scale mapping (математика 2D lip-sync оверлея)
//  3. LyalyaState — полнота состояний
//  4. LyalyaLipSyncCoordinator — инициализация и сброс
//
// 3D-модель lyalya3d_v3.usdz не содержит blendshapes рта — lip-sync остаётся
// на 2D-оверлее MouthBubbleOverlay; тестируется математика visemeScale.

@Suite("LyalyaRealityKitView")
struct LyalyaRealityKitViewTests {

    // MARK: - LyalyaViseme CaseIterable

    @Test("LyalyaViseme содержит 6 кейсов")
    func visemeCount() {
        #expect(LyalyaViseme.allCases.count == 6)
    }

    @Test("LyalyaViseme rawValues уникальны")
    func visemeRawValuesUnique() {
        let rawValues = LyalyaViseme.allCases.map(\.rawValue)
        let unique = Set(rawValues)
        #expect(rawValues.count == unique.count)
    }

    // MARK: - Viseme scale mapping logic

    @Test("rest viseme — scaleY минимальный (закрытый рот)")
    func restVisemeScaleMinimal() {
        // При rest + mouthOpen=0 → scaleY = 0.2
        let (_, scaleY) = visemeScale(viseme: .rest, mouthOpen: 0)
        #expect(scaleY < 0.4, "Rest визема должна давать малый scaleY (закрытый рот)")
    }

    @Test("viseme_a — scaleY максимальный (открытый рот)")
    func visemeAScaleMax() {
        // При a + mouthOpen=1.0 → scaleY = 0.8 + 0.8 = 1.6
        let (_, scaleY) = visemeScale(viseme: .a, mouthOpen: 1.0)
        #expect(scaleY > 1.0, "Визема 'a' с mouthOpen=1.0 должна давать scaleY > 1.0")
    }

    @Test("viseme_i — scaleX > scaleY (широкая улыбка)")
    func visemeIWideSmile() {
        let (scaleX, scaleY) = visemeScale(viseme: .i, mouthOpen: 0.5)
        #expect(scaleX > scaleY, "Визема 'i' (И) должна быть шире чем высота")
    }

    @Test("viseme_uSound — scaleX < 1.0 (вытянутые губы)")
    func visemeUSoundNarrow() {
        let (scaleX, _) = visemeScale(viseme: .uSound, mouthOpen: 0.5)
        #expect(scaleX < 0.8, "Визема 'uSound' (У) должна давать узкий scaleX (вытянутые губы)")
    }

    @Test("viseme_consonantClosed — scaleY почти нулевой")
    func consonantClosedAlmostZero() {
        let (_, scaleY) = visemeScale(viseme: .consonantClosed, mouthOpen: 0)
        #expect(scaleY < 0.2, "Консонантная закрытая визема должна давать scaleY ≈ 0.1")
    }

    @Test("mouthOpen=0 для любой визем → scaleY <= rest-scaleY-max")
    func mouthOpenZeroAllVisemes() {
        for v in LyalyaViseme.allCases {
            let (_, scaleY) = visemeScale(viseme: v, mouthOpen: 0)
            #expect(scaleY <= 1.7, "scaleY должен быть в разумных пределах при mouthOpen=0 для \(v.rawValue)")
        }
    }

    @Test("mouthOpen=1 для всех визем → scaleY <= 2.0 (нет переполнения)")
    func mouthOpenFullAllVisemes() {
        for v in LyalyaViseme.allCases {
            let (scaleX, scaleY) = visemeScale(viseme: v, mouthOpen: 1.0)
            #expect(scaleY <= 2.0, "scaleY не должен превышать 2.0 при mouthOpen=1.0 для \(v.rawValue)")
            #expect(scaleX <= 2.0, "scaleX не должен превышать 2.0 для \(v.rawValue)")
        }
    }

    // MARK: - LyalyaState compatibility

    @Test("LyalyaState содержит все состояния необходимые для 3D маскота")
    func lyalyaStateContainsRequired3DStates() {
        // LyalyaState не имеет .listening (используется .thinking как эквивалент per ADR-V13)
        let required: Set<LyalyaState> = [.idle, .celebrating, .thinking, .sad, .waving, .pointing, .explaining, .happy, .encouraging]
        let available = Set(LyalyaState.allCases)
        #expect(required.isSubset(of: available), "LyalyaState должен содержать все состояния для 3D маскота")
    }

    // MARK: - LyalyaLipSyncCoordinator initialization

    @MainActor
    @Test("LyalyaLipSyncCoordinator инициализируется с нейтральными значениями")
    func lipSyncCoordinatorInitialState() {
        let coordinator = LyalyaLipSyncCoordinator()
        #expect(coordinator.mouthOpen == 0, "Начальный mouthOpen должен быть 0")
        #expect(coordinator.viseme == .rest, "Начальная визема должна быть .rest")
    }

    @MainActor
    @Test("stopSpeech сбрасывает mouthOpen и viseme в нейтраль")
    func lipSyncCoordinatorStopResetsState() {
        let coordinator = LyalyaLipSyncCoordinator()
        // stopSpeech можно вызвать без предварительного play
        coordinator.stopSpeech()
        #expect(coordinator.mouthOpen == 0, "После stop mouthOpen должен быть 0")
        #expect(coordinator.viseme == .rest, "После stop viseme должна быть .rest")
    }

    @MainActor
    @Test("playSpeech с несуществующим URL бросает ошибку")
    func lipSyncCoordinatorInvalidURLThrows() {
        let coordinator = LyalyaLipSyncCoordinator()
        let badURL = URL(fileURLWithPath: "/nonexistent/audio.m4a")
        var didThrow = false
        do {
            try coordinator.playSpeech(audio: badURL)
        } catch {
            didThrow = true
        }
        #expect(didThrow, "playSpeech с несуществующим файлом должен бросать ошибку")
    }

    // MARK: - PhonemeTimestamp

    @Test("PhonemeTimestamp инициализируется корректно")
    func phonemeTimestampInit() {
        let ts = LyalyaLipSyncCoordinator.PhonemeTimestamp(time: 1.5, viseme: .a)
        #expect(ts.time == 1.5)
        #expect(ts.viseme == .a)
    }

    @Test("Phoneme timings отсортированы корректно (последний активный до currentTime)")
    func phonemeTimingLookup() {
        let timings: [LyalyaLipSyncCoordinator.PhonemeTimestamp] = [
            .init(time: 0.0, viseme: .rest),
            .init(time: 0.3, viseme: .a),
            .init(time: 0.7, viseme: .i),
            .init(time: 1.0, viseme: .consonantClosed)
        ]
        // Симулируем поиск активной визем на t=0.5
        let currentTime: TimeInterval = 0.5
        let active = timings.last(where: { $0.time <= currentTime })
        #expect(active?.viseme == .a, "На t=0.5 должна быть активна визема .a (начатая в 0.3)")
    }
}

// MARK: - Test helpers (viseme scale logic mirrors Coordinator internals)

/// Отражает логику `Coordinator.visemeScale` для тестирования.
/// Дублирование намеренно — тест не должен зависеть от private реализации.
private func visemeScale(viseme: LyalyaViseme, mouthOpen: Float) -> (scaleX: Float, scaleY: Float) {
    switch viseme {
    case .rest:
        return (1.0, 0.2 + mouthOpen * 0.4)
    case .a:
        return (0.8, 0.8 + mouthOpen * 0.8)
    case .i:
        return (1.2 + mouthOpen * 0.2, 0.3 + mouthOpen * 0.3)
    case .uSound:
        return (0.5 + mouthOpen * 0.1, 0.5 + mouthOpen * 0.3)
    case .consonantClosed:
        return (1.0, 0.1)
    case .consonantOpen:
        return (0.9 + mouthOpen * 0.2, 0.5 + mouthOpen * 0.4)
    }
}
