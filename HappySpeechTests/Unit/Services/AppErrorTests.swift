import XCTest
@testable import HappySpeech

// MARK: - AppErrorTests

final class AppErrorTests: XCTestCase {

    func testErrorDescriptionsAreNotEmpty() {
        let errors: [AppError] = [
            .networkUnavailable,
            .audioPermissionDenied,
            .asrModelNotLoaded,
            .arNotSupported,
            .llmNotDownloaded,
            .contentPackNotFound("test-pack"),
            .realmWriteFailed("test"),
            .unknown("test"),
        ]

        for error in errors {
            let description = error.errorDescription
            XCTAssertNotNil(description, "errorDescription не должен быть nil для \(error)")
            XCTAssertFalse(description!.isEmpty, "errorDescription не должен быть пустым для \(error)")
        }
    }

    func testErrorDescriptionsAreInRussian() {
        // Check a few key errors for Russian text
        XCTAssertTrue(AppError.networkUnavailable.errorDescription!.contains("интернет"))
        XCTAssertTrue(AppError.audioPermissionDenied.errorDescription!.contains("микрофон"))
        XCTAssertTrue(AppError.llmNotDownloaded.errorDescription!.contains("загружена") ||
                      AppError.llmNotDownloaded.errorDescription!.contains("загрузить"))
    }

    func testErrorEquality() {
        XCTAssertEqual(AppError.networkUnavailable, AppError.networkUnavailable)
        XCTAssertNotEqual(AppError.networkUnavailable, AppError.networkTimeout)
    }

    func testCancelledError() {
        XCTAssertNotNil(AppError.cancelled.errorDescription)
    }
}
