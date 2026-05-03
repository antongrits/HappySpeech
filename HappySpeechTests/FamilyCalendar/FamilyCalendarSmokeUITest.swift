@testable import HappySpeech
import SwiftUI
import XCTest

// MARK: - FamilyCalendarSmokeUITest
//
// Smoke-тест: FamilyCalendarView инициализируется и рендерится без краша (F3-005).
// Не требует запуска XCUIApplication / симулятора.
// Паттерн идентичен CustomizationSmokeUITest и GrammarGameSmokeUITest.

@MainActor
final class FamilyCalendarSmokeUITest: XCTestCase {

    // MARK: - 1. Smoke: empty state рендерится без краша

    func test_familyCalendarView_emptyState_rendersWithoutCrash() {
        let vm = FamilyCalendarViewModel(
            children: [
                ChildAvatarViewModel(id: "all", name: "Все", initials: "", avatarStyle: "all", streak: 0, isAll: true)
            ],
            selectedChildId: nil,
            currentMonth: Date(),
            weekOffset: 0,
            weekDays: [],
            calendarDays: [],
            heatmapEntries: [],
            comparisonCards: [],
            weekGoalCards: [],
            insights: [],
            isLoading: false,
            isLoadingInsights: false,
            toastMessage: nil,
            isEmpty: true,
            selectedDayDetail: nil,
            weekSummary: nil
        )

        let view = NavigationStack {
            ZStack {
                ColorTokens.Parent.bg.ignoresSafeArea()
                VStack(spacing: SpacingTokens.xxLarge) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 56))
                        .foregroundStyle(ColorTokens.Parent.inkSoft)
                        .accessibilityHidden(true)
                    Text("Нет данных")
                        .font(TypographyTokens.title())
                        .foregroundStyle(ColorTokens.Parent.ink)
                }
                .accessibilityLabel(vm.children.first?.name ?? "")
            }
        }
        .environment(AppContainer.preview())
        .environment(AppCoordinator())
        .environment(\.circuitContext, .parent)

        let host = UIHostingController(rootView: view)
        host.view.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view,
                        "UIHostingController.view не должен быть nil (empty state)")
        XCTAssertFalse(host.view.bounds.isEmpty,
                       "bounds не должны быть пустыми (empty state)")
        XCTAssertEqual(vm.isEmpty, true,
                       "ViewModel.isEmpty должен быть true")
    }

    // MARK: - 2. Smoke: loading state рендерится без краша

    func test_familyCalendarView_loadingState_rendersWithoutCrash() {
        let vm = FamilyCalendarViewModel.empty

        let view = NavigationStack {
            ZStack {
                ColorTokens.Parent.bg.ignoresSafeArea()
                ProgressView()
                    .tint(ColorTokens.Brand.primary)
                    .scaleEffect(1.4)
            }
        }
        .environment(AppContainer.preview())
        .environment(AppCoordinator())
        .environment(\.circuitContext, .parent)

        let host = UIHostingController(rootView: view)
        host.view.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view,
                        "UIHostingController.view не должен быть nil (loading state)")
        XCTAssertTrue(vm.isLoading,
                      "FamilyCalendarViewModel.empty.isLoading должен быть true")
    }

    // MARK: - 3. Smoke: FamilyCalendarViewModel.empty имеет корректные дефолты

    func test_familyCalendarViewModel_empty_hasCorrectDefaults() {
        let vm = FamilyCalendarViewModel.empty

        XCTAssertTrue(vm.children.isEmpty,
                      "children должен быть пустым для .empty")
        XCTAssertNil(vm.selectedChildId,
                     "selectedChildId должен быть nil для .empty")
        XCTAssertTrue(vm.calendarDays.isEmpty,
                      "calendarDays должен быть пустым для .empty")
        XCTAssertTrue(vm.heatmapEntries.isEmpty,
                      "heatmapEntries должен быть пустым для .empty")
        XCTAssertTrue(vm.comparisonCards.isEmpty,
                      "comparisonCards должен быть пустым для .empty")
        XCTAssertTrue(vm.insights.isEmpty,
                      "insights должен быть пустым для .empty")
        XCTAssertTrue(vm.isLoading,
                      "isLoading должен быть true для .empty")
        XCTAssertNil(vm.toastMessage,
                     "toastMessage должен быть nil для .empty")
        XCTAssertTrue(vm.isEmpty,
                      "isEmpty должен быть true для .empty")
        XCTAssertNil(vm.selectedDayDetail,
                     "selectedDayDetail должен быть nil для .empty")
    }

    // MARK: - 4. Smoke: FamilyStatsWorker buildCalendarDays не крашится

    func test_familyStatsWorker_buildCalendarDays_doesNotCrash() {
        let worker = FamilyStatsWorker()
        let days = worker.buildCalendarDays(month: Date(), dayActivities: [:])

        XCTAssertEqual(days.count, 42,
                       "buildCalendarDays должен возвращать 42 ячейки (6×7)")
        XCTAssertFalse(days.isEmpty,
                       "buildCalendarDays не должен возвращать пустой массив")
    }

    // MARK: - 5. Smoke: FamilyCalendarScene инициализируется без краша

    func test_familyCalendarScene_init_doesNotCrash() {
        let childRepo = MockChildRepository(children: ChildProfileDTO.previewList)
        let sessionRepo = MockSessionRepository(sessions: [.preview])
        let coordinator = AppCoordinator()

        let scene = FamilyCalendarScene(
            childRepository: childRepo,
            sessionRepository: sessionRepo,
            notificationService: nil,
            llmDecisionService: nil,
            coordinator: coordinator
        )

        XCTAssertNotNil(scene.interactor,
                        "FamilyCalendarScene.interactor не должен быть nil")
        XCTAssertNotNil(scene.presenter,
                        "FamilyCalendarScene.presenter не должен быть nil")
        XCTAssertNotNil(scene.router,
                        "FamilyCalendarScene.router не должен быть nil")
    }
}
