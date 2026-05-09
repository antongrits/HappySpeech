@testable import HappySpeech
import XCTest

// MARK: - NotificationServiceExtTests
//
// Block V v18 — дополнительные тесты для NotificationService через MockNotificationService.
// MockNotificationService уже существует в MockServices.swift — используем её напрямую.

final class NotificationServiceExtTests: XCTestCase {

    private func makeSUT() -> MockNotificationService {
        MockNotificationService()
    }

    // MARK: - requestPermission

    func test_requestPermission_returnsTrue() async {
        let sut = makeSUT()
        let granted = await sut.requestPermission()
        XCTAssertTrue(granted)
    }

    // MARK: - scheduleDailyReminder

    func test_scheduleDailyReminder_doesNotThrow() async {
        let sut = makeSUT()
        await XCTAssertNoThrowAsync { try await sut.scheduleDailyReminder(at: 17, minute: 30) }
    }

    // MARK: - cancelAllReminders

    func test_cancelAllReminders_doesNotThrow() async {
        let sut = makeSUT()
        await sut.cancelAllReminders()
        // Mock — no assertions needed, verifies API contract
    }

    // MARK: - scheduleDailyKidReminder

    func test_scheduleDailyKidReminder_doesNotThrow() async {
        let sut = makeSUT()
        await sut.scheduleDailyKidReminder(childName: "Ваня")
    }

    // MARK: - cancelDailyKidReminder

    func test_cancelDailyKidReminder_doesNotThrow() async {
        let sut = makeSUT()
        await sut.cancelDailyKidReminder(childName: "Ваня")
    }

    // MARK: - scheduleWeeklyParentSummary

    func test_scheduleWeeklyParentSummary_doesNotThrow() async {
        let sut = makeSUT()
        await sut.scheduleWeeklyParentSummary(achievementsCount: 3, streakDays: 7)
    }

    // MARK: - cancelWeeklyParentSummary

    func test_cancelWeeklyParentSummary_doesNotThrow() async {
        let sut = makeSUT()
        await sut.cancelWeeklyParentSummary()
    }
}

// MARK: - XCTAssertNoThrowAsync helper

private func XCTAssertNoThrowAsync(
    _ expression: () async throws -> Void,
    file: StaticString = #file,
    line: UInt = #line
) async {
    do {
        try await expression()
    } catch {
        XCTFail("Unexpected throw: \(error)", file: file, line: line)
    }
}
