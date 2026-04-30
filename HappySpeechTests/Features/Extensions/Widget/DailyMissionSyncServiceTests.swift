import XCTest
@testable import HappySpeech

// MARK: - DailyMissionSyncServiceTests

final class DailyMissionSyncServiceTests: XCTestCase {

    // MARK: - Test Cases

    /// Проверяет, что MockDailyMissionSyncService сохраняет переданные данные задания.
    func testMockSyncStoresLastUpdate() async {
        let sut = MockDailyMissionSyncService()

        await sut.updateMission(
            title: "Звук Ш",
            description: "5 раундов",
            streakDays: 7,
            lyalyaState: "happy",
            progress: 0.6
        )

        let update = await sut.lastUpdate
        XCTAssertNotNil(update, "lastUpdate должен быть установлен после вызова updateMission")
        XCTAssertEqual(update?.title, "Звук Ш")
        XCTAssertEqual(update?.description, "5 раундов")
        XCTAssertEqual(update?.streakDays, 7)
        XCTAssertEqual(update?.lyalyaState, "happy")
        XCTAssertEqual(update?.progress ?? 0, 0.6, accuracy: 0.001)
    }

    /// Проверяет обновление при нулевом стрике и прогрессе.
    func testMockSyncWithZeroStreakAndProgress() async {
        let sut = MockDailyMissionSyncService()

        await sut.updateMission(
            title: "Звук Р",
            description: "3 раунда",
            streakDays: 0,
            lyalyaState: "sleepy",
            progress: 0.0
        )

        let update = await sut.lastUpdate
        XCTAssertEqual(update?.streakDays, 0)
        XCTAssertEqual(update?.lyalyaState, "sleepy")
        XCTAssertEqual(update?.progress ?? 0, 0.0, accuracy: 0.001)
    }

    /// Проверяет корректность данных при стопроцентном прогрессе и состоянии "encouraging".
    func testMockSyncWithFullProgressAndEncouragingState() async {
        let sut = MockDailyMissionSyncService()

        await sut.updateMission(
            title: "Звук Л",
            description: "10 раундов",
            streakDays: 30,
            lyalyaState: "encouraging",
            progress: 1.0
        )

        let update = await sut.lastUpdate
        XCTAssertEqual(update?.title, "Звук Л")
        XCTAssertEqual(update?.description, "10 раундов")
        XCTAssertEqual(update?.streakDays, 30)
        XCTAssertEqual(update?.lyalyaState, "encouraging")
        XCTAssertEqual(update?.progress ?? 0, 1.0, accuracy: 0.001)
    }
}
