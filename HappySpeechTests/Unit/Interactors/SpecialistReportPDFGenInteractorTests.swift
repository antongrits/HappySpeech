@testable import HappySpeech
import XCTest

// MARK: - SpecialistReportPDFGenInteractorTests
//
// Thin VIP (@Observable interactor with state, no presenter). Tests:
//   - initial state contains all sections selected
//   - toggle removes/re-adds a section
//   - generate flips isGenerating around the await

@MainActor
final class SpecialistReportPDFGenInteractorTests: XCTestCase {

    private func makeSUT() -> SpecialistReportPDFGenInteractor {
        SpecialistReportPDFGenInteractor(childId: "child-1", specialistId: "spec-1")
    }

    // MARK: - Init / initial state

    func test_init_storesIds() {
        let sut = makeSUT()
        XCTAssertEqual(sut.childId, "child-1")
        XCTAssertEqual(sut.specialistId, "spec-1")
    }

    func test_initialState_allSectionsSelected() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state.sections, Set(SpecialistReportPDFGenModels.Section.allCases))
    }

    func test_initialState_notGenerating() {
        let sut = makeSUT()
        XCTAssertFalse(sut.state.isGenerating)
    }

    // MARK: - toggle

    func test_toggle_removesSelectedSection() {
        let sut = makeSUT()
        sut.toggle(.summary)
        XCTAssertFalse(sut.state.sections.contains(.summary))
    }

    func test_toggle_twice_reAddsSection() {
        let sut = makeSUT()
        sut.toggle(.sounds)
        sut.toggle(.sounds)
        XCTAssertTrue(sut.state.sections.contains(.sounds))
    }

    func test_toggle_onlyAffectsTargetSection() {
        let sut = makeSUT()
        sut.toggle(.recommendations)
        // The other four remain selected.
        let remaining = Set(SpecialistReportPDFGenModels.Section.allCases)
            .subtracting([.recommendations])
        XCTAssertTrue(remaining.isSubset(of: sut.state.sections))
    }

    func test_toggle_removingAll_leavesEmptySet() {
        let sut = makeSUT()
        for section in SpecialistReportPDFGenModels.Section.allCases {
            sut.toggle(section)
        }
        XCTAssertTrue(sut.state.sections.isEmpty)
    }

    // MARK: - generate

    func test_generate_resetsIsGeneratingAfterCompletion() async {
        let sut = makeSUT()
        await sut.generate()
        XCTAssertFalse(sut.state.isGenerating)
    }

    // MARK: - Section model

    func test_section_titleAndIcon_nonEmpty() {
        for section in SpecialistReportPDFGenModels.Section.allCases {
            XCTAssertFalse(section.title.isEmpty)
            XCTAssertFalse(section.icon.isEmpty)
            XCTAssertEqual(section.id, section.rawValue)
        }
    }
}
