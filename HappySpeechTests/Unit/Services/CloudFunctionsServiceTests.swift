@testable import HappySpeech
import XCTest

// MARK: - CloudFunctionsServiceTests
//
// 2.10 v25 — покрытие CloudFunctionsService.
// LiveCloudFunctionsService SDK-bound (Functions.functions / App Check / httpsCallable.call) —
// тестируется через MockCloudFunctionsService (контракт протокола) + чистые модели/ошибки.
// Прямые вызовы Firebase Cloud Functions документированы для ADR-V25-COVERAGE.

final class CloudFunctionsServiceTests: XCTestCase {

    private func makeSUT() -> MockCloudFunctionsService {
        MockCloudFunctionsService()
    }

    private let sampleAudio = Data(repeating: 0x01, count: 256)

    // MARK: - Result models — value semantics

    func test_scoringResult_equatableAndStoresFields() {
        let result = ScoringResult(
            overallScore: 0.9,
            phonemeScores: ["р": 0.8],
            label: "good",
            specialistNote: "примечание"
        )
        XCTAssertEqual(result.overallScore, 0.9, accuracy: 0.0001)
        XCTAssertEqual(result.phonemeScores["р"], 0.8)
        XCTAssertEqual(result.label, "good")
        XCTAssertEqual(result.specialistNote, "примечание")
        let copy = ScoringResult(
            overallScore: 0.9, phonemeScores: ["р": 0.8], label: "good", specialistNote: "примечание"
        )
        XCTAssertEqual(result, copy)
    }

    func test_neurolinguistSummary_storesFields() {
        let now = Date()
        let summary = NeurolinguistSummary(
            reportId: "r-1",
            summary: "Прогресс стабильный.",
            recommendations: ["Совет 1"],
            chartsData: ["Р": [0.3, 0.6]],
            generatedAt: now
        )
        XCTAssertEqual(summary.reportId, "r-1")
        XCTAssertEqual(summary.recommendations.count, 1)
        XCTAssertEqual(summary.chartsData["Р"], [0.3, 0.6])
        XCTAssertEqual(summary.generatedAt, now)
    }

    func test_speechProgressAnalysis_storesTrends() {
        let analysis = SpeechProgressAnalysis(
            trends: [SpeechProgressTrend(soundGroup: "шипящие", direction: "up", changePercent: 15)],
            strengths: ["Чёткое Ш"],
            gaps: ["Звук Р"]
        )
        XCTAssertEqual(analysis.trends.first?.soundGroup, "шипящие")
        XCTAssertEqual(analysis.trends.first?.direction, "up")
        XCTAssertEqual(analysis.trends.first?.changePercent, 15)
        XCTAssertEqual(analysis.strengths.count, 1)
        XCTAssertEqual(analysis.gaps.count, 1)
    }

    func test_specialistReportResult_nilDownloadURLForOnDevice() {
        let result = SpecialistReportResult(
            reportId: "spec-1", format: "pdf", downloadUrl: nil, message: "on-device"
        )
        XCTAssertNil(result.downloadUrl)
        XCTAssertEqual(result.format, "pdf")
    }

    func test_familyInviteToken_storesShortCodeAndURL() throws {
        let url = try XCTUnwrap(URL(string: "https://happyspeech.mmf.bsu.app/invite?token=abc"))
        let token = FamilyInviteToken(
            token: "abc", shortCode: "K7M2X9", expiresAt: Date(), deepLinkURL: url
        )
        XCTAssertEqual(token.shortCode, "K7M2X9")
        XCTAssertEqual(token.deepLinkURL, url)
    }

    func test_childVoiceValidationResult_storesConfidence() {
        let result = ChildVoiceValidationResult(isChildVoice: true, confidence: 0.92)
        XCTAssertTrue(result.isChildVoice)
        XCTAssertEqual(result.confidence, 0.92, accuracy: 0.0001)
    }

    // MARK: - CloudFunctionsError — localized descriptions

    func test_error_descriptions_areRussianAndNonEmpty() {
        let errors: [CloudFunctionsError] = [
            .appCheckFailed,
            .invalidResponse("деталь"),
            .serverError("сбой"),
            .networkUnavailable,
            .audioEncodingFailed
        ]
        for error in errors {
            let description = error.errorDescription
            XCTAssertNotNil(description)
            XCTAssertFalse(description?.isEmpty ?? true, "Описание ошибки не должно быть пустым")
        }
    }

    func test_error_invalidResponse_includesDetail() {
        let error = CloudFunctionsError.invalidResponse("отсутствует поле")
        XCTAssertTrue(error.errorDescription?.contains("отсутствует поле") ?? false)
    }

    // MARK: - scoreSpeechQuality (mock contract)

    func test_scoreSpeechQuality_returnsStubbedResult() async throws {
        let sut = makeSUT()
        let result = try await sut.scoreSpeechQuality(audio: sampleAudio, targetSound: "р")
        XCTAssertEqual(result.label, "good")
        XCTAssertGreaterThan(result.overallScore, 0.0)
    }

    func test_scoreSpeechQuality_customStub_propagates() async throws {
        let sut = makeSUT()
        sut.stubbedScoringResult = ScoringResult(
            overallScore: 0.5, phonemeScores: [:], label: "fair", specialistNote: nil
        )
        let result = try await sut.scoreSpeechQuality(audio: sampleAudio, targetSound: "ш")
        XCTAssertEqual(result.label, "fair")
        XCTAssertNil(result.specialistNote)
    }

    func test_scoreSpeechQuality_whenShouldThrow_throwsNetworkError() async {
        let sut = makeSUT()
        sut.shouldThrowError = true
        do {
            _ = try await sut.scoreSpeechQuality(audio: sampleAudio, targetSound: "р")
            XCTFail("Должна быть выброшена ошибка")
        } catch let error as CloudFunctionsError {
            if case .networkUnavailable = error { } else {
                XCTFail("Ожидалась networkUnavailable, получено \(error)")
            }
        } catch {
            XCTFail("Неверный тип ошибки: \(error)")
        }
    }

    // MARK: - generateNeurolinguistSummary

    func test_generateNeurolinguistSummary_returnsStub() async throws {
        let sut = makeSUT()
        let summary = try await sut.generateNeurolinguistSummary(childId: "child-1", period: "week")
        XCTAssertFalse(summary.summary.isEmpty)
        XCTAssertFalse(summary.recommendations.isEmpty)
    }

    func test_generateNeurolinguistSummary_whenShouldThrow_throws() async {
        let sut = makeSUT()
        sut.shouldThrowError = true
        do {
            _ = try await sut.generateNeurolinguistSummary(childId: "child-1", period: "month")
            XCTFail("Должна быть выброшена ошибка")
        } catch {
            XCTAssertTrue(error is CloudFunctionsError)
        }
    }

    // MARK: - validateChildVoice

    func test_validateChildVoice_returnsChildVoiceTrue() async throws {
        let sut = makeSUT()
        let result = try await sut.validateChildVoice(audio: sampleAudio)
        XCTAssertTrue(result.isChildVoice)
        XCTAssertGreaterThan(result.confidence, 0.0)
    }

    // MARK: - analyzeSpeechProgress

    func test_analyzeSpeechProgress_returnsTrends() async throws {
        let sut = makeSUT()
        let analysis = try await sut.analyzeSpeechProgress(childId: "child-1")
        XCTAssertFalse(analysis.trends.isEmpty)
        XCTAssertFalse(analysis.strengths.isEmpty)
    }

    // MARK: - generateSpecialistReport

    func test_generateSpecialistReport_jsonFormat_returnsReport() async throws {
        let sut = makeSUT()
        let report = try await sut.generateSpecialistReport(childId: "child-1", format: "json")
        XCTAssertEqual(report.format, "json")
        XCTAssertFalse(report.reportId.isEmpty)
    }

    // MARK: - createFamilyInviteToken

    func test_createFamilyInviteToken_returnsToken() async throws {
        let sut = makeSUT()
        let token = try await sut.createFamilyInviteToken(
            parentId: "parent-1", role: .secondary, durationHours: 24
        )
        XCTAssertFalse(token.shortCode.isEmpty)
        XCTAssertGreaterThan(token.expiresAt, Date())
    }

    func test_createFamilyInviteToken_whenShouldThrow_throwsServerError() async {
        let sut = makeSUT()
        sut.shouldThrowError = true
        do {
            _ = try await sut.createFamilyInviteToken(
                parentId: "parent-1", role: .observer, durationHours: 12
            )
            XCTFail("Должна быть выброшена ошибка")
        } catch let error as CloudFunctionsError {
            if case .serverError = error { } else {
                XCTFail("Ожидалась serverError, получено \(error)")
            }
        } catch {
            XCTFail("Неверный тип ошибки: \(error)")
        }
    }
}
