@testable import HappySpeech
import XCTest

// MARK: - PhonemePassportTests
//
// Покрывает секцию «Фонемный паспорт» (GOP-анализ) экрана PhonemeReport:
//   • PhonemePassportPresenter — построение VM из заполненного PhonemeProfile
//     (матрица × позиция, состояния/дефекты, прогноз с CI, CSV-строка);
//   • из ПУСТОГО профиля → empty-state;
//   • Interactor.load — мёрж sessions + passport, и graceful: сбой паспорта
//     НЕ валит весь экран (отчёт по сессиям остаётся).
//
// Все данные фиксированы (даты инъектируются) → числа детерминированы, без random.

@MainActor
final class PhonemePassportTests: XCTestCase {

    // MARK: - Fixtures

    private var base: Date { Date(timeIntervalSince1970: 1_700_000_000) }
    private func day(_ offset: Int) -> Date { base.addingTimeInterval(Double(offset) * 86_400) }

    private func obs(
        phoneme: String,
        position: PhonemeWordPosition,
        gop: Double,
        defect: String,
        competitor: String? = nil,
        dayOffset: Int = 0
    ) -> PhonemeObservationDTO {
        PhonemeObservationDTO(
            childId: "child-1",
            phoneme: phoneme,
            wordId: "word_x",
            position: position.rawValue,
            gop: gop,
            posterior: 0.6,
            defect: defect,
            competitor: competitor,
            date: day(dayOffset)
        )
    }

    /// Профиль с несколькими фонемами/позициями и достаточным числом наблюдений,
    /// чтобы получить прогноз по слабейшей фонеме.
    private func populatedProfile() -> PhonemeProfile {
        var observations: [PhonemeObservationDTO] = []
        // Фонема «ʂ» (Ш): растущая динамика, низкий старт → improving-прогноз.
        for index in 0..<10 {
            observations.append(
                obs(
                    phoneme: "ʂ",
                    position: index.isMultiple(of: 2) ? .initial : .final,
                    gop: -1.0 + Double(index) * 0.25,
                    defect: index < 3 ? "distortion" : "ok",
                    dayOffset: index
                )
            )
        }
        // Фонема «r» (Р): замены → poor.
        for index in 0..<6 {
            observations.append(
                obs(
                    phoneme: "r",
                    position: .medial,
                    gop: -1.5,
                    defect: "substitution",
                    competitor: "l",
                    dayOffset: index
                )
            )
        }
        return PhonemeProfileMath.buildProfile(
            childId: "child-1",
            observations: observations,
            now: day(20)
        )
    }

    // MARK: - Presenter: populated profile

    func test_presenter_populatedProfile_buildsMatrixAndDefects() throws {
        let profile = populatedProfile()
        XCTAssertFalse(profile.cells.isEmpty)

        let vm = PhonemePassportPresenter.makeViewModel(profile: profile, forecasts: [])

        XCTAssertFalse(vm.isEmpty)
        XCTAssertEqual(vm.columns.count, 3)
        XCTAssertFalse(vm.rows.isEmpty)
        // Каждая строка имеет ровно 3 ячейки (по числу колонок-позиций).
        for row in vm.rows {
            XCTAssertEqual(row.cells.count, 3)
        }
        // Фонема с заменами «r» отображается как Р и имеет poor-тон где есть данные.
        let rowR = try XCTUnwrap(vm.rows.first { $0.phoneme == "Р" })
        let medial = try XCTUnwrap(
            rowR.cells.first { $0.positionKey == PhonemeWordPosition.medial.rawValue }
        )
        XCTAssertTrue(medial.hasData)
        XCTAssertEqual(medial.tone, .poor)
        XCTAssertFalse(medial.levelText.isEmpty)
        // Ячейка без данных — нейтральная, без уровня.
        let initialR = try XCTUnwrap(
            rowR.cells.first { $0.positionKey == PhonemeWordPosition.initial.rawValue }
        )
        XCTAssertFalse(initialR.hasData)
        XCTAssertEqual(initialR.tone, .neutral)
        XCTAssertTrue(initialR.levelText.isEmpty)
    }

    func test_presenter_subtitleAndLastObservation_present() {
        let profile = populatedProfile()
        let vm = PhonemePassportPresenter.makeViewModel(profile: profile, forecasts: [])
        XCTAssertFalse(vm.subtitleText.isEmpty)
        XCTAssertFalse(vm.lastObservationText.isEmpty)
        XCTAssertFalse(vm.disclaimerText.isEmpty)
    }

    func test_presenter_trends_buildFromTopProblems() {
        let profile = populatedProfile()
        let vm = PhonemePassportPresenter.makeViewModel(profile: profile, forecasts: [])
        XCTAssertFalse(vm.trends.isEmpty)
        for trend in vm.trends {
            XCTAssertFalse(trend.points.isEmpty)
            XCTAssertFalse(trend.captionText.isEmpty)
        }
    }

    // MARK: - Presenter: forecast formatting

    func test_presenter_forecast_improving_hasEtaAndCI() {
        let forecast = MasteryForecast(
            childId: "child-1",
            phoneme: "ʂ",
            status: .improving,
            currentLevel: 0.5,
            weeklySlope: 0.1,
            observationCount: 10,
            estimatedWeeksToMastery: 4,
            etaLowerWeeks: 3,
            etaUpperWeeks: 7
        )
        let vm = PhonemePassportPresenter.makeForecast(forecast)
        XCTAssertEqual(vm.phoneme, "Ш")
        XCTAssertFalse(vm.summaryText.isEmpty)
        XCTAssertNotNil(vm.confidenceText)
        XCTAssertFalse(vm.needsConsultation)
        XCTAssertEqual(vm.tone, .medium)
        // CI нормирован к [0…1] относительно макс. горизонта (12 недель).
        XCTAssertEqual(vm.confidenceLowerFraction ?? -1, 3.0 / 12.0, accuracy: 0.0001)
        XCTAssertEqual(vm.confidenceUpperFraction ?? -1, 7.0 / 12.0, accuracy: 0.0001)
    }

    func test_presenter_forecast_needsConsultation_flagsBadge() {
        let forecast = MasteryForecast(
            childId: "child-1",
            phoneme: "r",
            status: .needsConsultation,
            currentLevel: 0.2,
            weeklySlope: -0.05,
            observationCount: 9,
            estimatedWeeksToMastery: nil,
            etaLowerWeeks: nil,
            etaUpperWeeks: nil
        )
        let vm = PhonemePassportPresenter.makeForecast(forecast)
        XCTAssertTrue(vm.needsConsultation)
        XCTAssertEqual(vm.tone, .poor)
        XCTAssertNil(vm.confidenceText)
    }

    // MARK: - Presenter: CSV export

    func test_presenter_csv_hasHeaderAndRowsFromRealCells() {
        let profile = populatedProfile()
        let vm = PhonemePassportPresenter.makeViewModel(profile: profile, forecasts: [])
        let csv = vm.csvExport
        XCTAssertFalse(csv.isEmpty)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false)
        // header + одна строка на каждую ячейку матрицы.
        XCTAssertEqual(lines.count, profile.cells.count + 1)
        // header содержит 7 колонок.
        let header = String(lines[0])
        XCTAssertEqual(header.split(separator: ",").count, 7)
        // Имя файла без PII (без полного childId).
        XCTAssertTrue(vm.csvFileName.hasPrefix("phoneme_passport_"))
    }

    func test_presenter_csv_directBuilder_isDeterministic() {
        let profile = populatedProfile()
        let csv1 = PhonemePassportPresenter.makeCSV(profile: profile)
        let csv2 = PhonemePassportPresenter.makeCSV(profile: profile)
        XCTAssertEqual(csv1, csv2)
    }

    // MARK: - Presenter: empty profile

    func test_presenter_emptyProfile_emptyState() {
        let empty = PhonemeProfile.empty(childId: "child-1", generatedAt: base)
        let vm = PhonemePassportPresenter.makeViewModel(profile: empty, forecasts: [])
        XCTAssertTrue(vm.isEmpty)
        XCTAssertTrue(vm.rows.isEmpty)
        XCTAssertTrue(vm.trends.isEmpty)
        XCTAssertTrue(vm.forecasts.isEmpty)
        XCTAssertTrue(vm.csvExport.isEmpty)
        XCTAssertFalse(vm.emptyText.isEmpty)
        XCTAssertFalse(vm.titleText.isEmpty)
    }

    // MARK: - Tone mapping

    func test_tone_mapping_warmSemantics() {
        XCTAssertEqual(PhonemePassportPresenter.tone(for: .noData, level: nil), .neutral)
        XCTAssertEqual(PhonemePassportPresenter.tone(for: .ok, level: 0.9), .good)
        XCTAssertEqual(PhonemePassportPresenter.tone(for: .distortion, level: 0.5), .medium)
        XCTAssertEqual(PhonemePassportPresenter.tone(for: .ageSubstitution, level: 0.5), .medium)
        XCTAssertEqual(PhonemePassportPresenter.tone(for: .substitution, level: 0.2), .poor)
        XCTAssertEqual(PhonemePassportPresenter.tone(for: .omission, level: 0.2), .poor)
    }

    // MARK: - Interactor: merges sessions + passport

    func test_interactor_load_mergesSessionsAndPassport() async {
        let sessions = [
            SessionDTO(
                id: "1", childId: "child-1", date: day(0),
                templateType: TemplateType.repeatAfterModel.rawValue,
                targetSound: "Р", stage: CorrectionStage.wordInit.rawValue,
                durationSeconds: 300, totalAttempts: 10, correctAttempts: 8,
                fatigueDetected: false, isSynced: false, attempts: []
            )
        ]
        let sessionRepo = MockSessionRepository(sessions: sessions)
        let childRepo = MockChildRepository(children: [
            ChildProfileDTO(
                id: "child-1", name: "Миша", age: 6,
                targetSounds: ["Р"], parentId: "parent-1"
            )
        ])
        // Паспорт с реальными наблюдениями.
        var observations: [PhonemeObservationDTO] = []
        for index in 0..<10 {
            observations.append(
                obs(phoneme: "ʂ", position: .initial,
                    gop: -1 + Double(index) * 0.2, defect: "distortion", dayOffset: index)
            )
        }
        let fixedNow = day(20)
        let passportService = MockPhonemeProfileService(
            observations: observations,
            now: { fixedNow }
        )

        let spy = DisplaySpy()
        let presenter = PhonemeReportPresenter()
        presenter.display = spy
        let interactor = PhonemeReportInteractor(
            sessionRepository: sessionRepo,
            childRepository: childRepo,
            phonemeProfileService: passportService
        )
        interactor.presenter = presenter

        await interactor.load(.init(childId: "child-1"))

        let vm = spy.lastVM
        XCTAssertNotNil(vm)
        XCTAssertNil(vm?.errorText)
        // Отчёт по сессиям присутствует.
        XCTAssertFalse(vm?.groups.isEmpty ?? true)
        // Паспорт присутствует и НЕ пуст.
        XCTAssertNotNil(vm?.passport)
        XCTAssertEqual(vm?.passport?.isEmpty, false)
        XCTAssertNotNil(interactor._lastProfile())
    }

    // MARK: - Interactor: graceful — passport failure does NOT break screen

    func test_interactor_load_passportFailure_isGraceful() async {
        let sessions = [
            SessionDTO(
                id: "1", childId: "child-1", date: day(0),
                templateType: TemplateType.repeatAfterModel.rawValue,
                targetSound: "Р", stage: CorrectionStage.wordInit.rawValue,
                durationSeconds: 300, totalAttempts: 10, correctAttempts: 8,
                fatigueDetected: false, isSynced: false, attempts: []
            )
        ]
        let sessionRepo = MockSessionRepository(sessions: sessions)
        let childRepo = MockChildRepository(children: [
            ChildProfileDTO(
                id: "child-1", name: "Миша", age: 6,
                targetSounds: ["Р"], parentId: "parent-1"
            )
        ])
        let interactor = PhonemeReportInteractor(
            sessionRepository: sessionRepo,
            childRepository: childRepo,
            phonemeProfileService: FailingPhonemeProfileService()
        )
        let spy = DisplaySpy()
        let presenter = PhonemeReportPresenter()
        presenter.display = spy
        interactor.presenter = presenter

        await interactor.load(.init(childId: "child-1"))

        let vm = spy.lastVM
        XCTAssertNotNil(vm)
        // Главное: экран НЕ в ошибке — отчёт по сессиям рабочий.
        XCTAssertNil(vm?.errorText)
        XCTAssertFalse(vm?.isEmpty ?? true)
        XCTAssertFalse(vm?.groups.isEmpty ?? true)
        // Паспорт скрыт (nil), но отчёт цел.
        XCTAssertNil(vm?.passport)
        XCTAssertNil(interactor._lastProfile())
    }

    // MARK: - Interactor: empty passport renders friendly empty-state

    func test_interactor_load_emptyPassport_isNonNilEmptyState() async {
        let sessions = [
            SessionDTO(
                id: "1", childId: "child-1", date: day(0),
                templateType: TemplateType.repeatAfterModel.rawValue,
                targetSound: "Р", stage: CorrectionStage.wordInit.rawValue,
                durationSeconds: 300, totalAttempts: 10, correctAttempts: 8,
                fatigueDetected: false, isSynced: false, attempts: []
            )
        ]
        let sessionRepo = MockSessionRepository(sessions: sessions)
        let childRepo = MockChildRepository(children: [
            ChildProfileDTO(
                id: "child-1", name: "Миша", age: 6,
                targetSounds: ["Р"], parentId: "parent-1"
            )
        ])
        // Пустой паспорт (нет наблюдений).
        let passportService = MockPhonemeProfileService(observations: [])
        let interactor = PhonemeReportInteractor(
            sessionRepository: sessionRepo,
            childRepository: childRepo,
            phonemeProfileService: passportService
        )
        let spy = DisplaySpy()
        let presenter = PhonemeReportPresenter()
        presenter.display = spy
        interactor.presenter = presenter

        await interactor.load(.init(childId: "child-1"))

        // Паспорт присутствует, но помечен пустым (дружелюбный empty-state).
        XCTAssertEqual(spy.lastVM?.passport?.isEmpty, true)
    }

    // MARK: - Helpers

    @MainActor
    private final class DisplaySpy: PhonemeReportDisplayLogic {
        var lastVM: PhonemeReportModels.Load.ViewModel?
        func displayLoad(_ viewModel: PhonemeReportModels.Load.ViewModel) {
            lastVM = viewModel
        }
    }

    /// Сервис паспорта, который всегда бросает — для проверки graceful-пути.
    private actor FailingPhonemeProfileService: PhonemeProfileServiceProtocol {
        // swiftlint:disable:next function_parameter_count
        func record(
            childId: String, phoneme: String, wordId: String,
            position: PhonemeWordPosition, gop: Double, posterior: Double,
            defect: String, competitor: String?
        ) async throws {
            throw AppError.entityNotFound("passport")
        }
        func profile(childId: String) async throws -> PhonemeProfile {
            throw AppError.entityNotFound("passport")
        }
        func predict(childId: String, phoneme: String) async throws -> MasteryForecast {
            throw AppError.entityNotFound("passport")
        }
    }
}
