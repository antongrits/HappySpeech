import XCTest

// MARK: - AllScreensTourUITests
//
// Plan v23 Block 1.1 — единый UI-test tour, который снимает screenshot
// каждого из 104 экранов HappySpeech через debug shortcut `-HSStartRoute`.
//
// Замена bash MCP screenshot tour (v22) — раньше ловил пустые экраны до
// первого render. Теперь screenshot снимается ТОЛЬКО после явного render
// confirm: `waitForExistence(timeout:)` per screen + 1.2s sleep на
// завершение первой кадровой отрисовки Lottie/анимаций.
//
// Theme выбирается через env-variable `HS_THEME` (light/dark) — отдельные
// schemes не нужны. По умолчанию — light.
//
// Routes маппятся в `AppCoordinatorView.resolveStartRoute(_:)` (v22 Block 0.2,
// 104 entries). Если route неизвестен — fallback `.auth`.
//
// === Plan v23 Block 1.3 — Test harness fixes ===
//
// Issue #1: Mic permission alert overlays ~56 P0 screens.
//   Fix: pre-grant microphone/camera/notifications через shell helper
//   `scripts/grant_uitest_permissions.sh` (запускается ПЕРЕД xcodebuild test —
//   Foundation.Process недоступен в iOS test runner) + addUIInterruptionMonitor
//   с button labels {"Разрешить", "OK", "Allow", …} как defense-in-depth.
//
// Issue #2: Dark theme не применяется (117/117 Dark screenshots рендерят Light).
//   Fix: `XCUIDevice.shared.appearance = .dark` (iOS 13+ API) для UIKit-уровня
//   + новый App launchArg `-HSForceDarkTheme 1` для SwiftUI ColorScheme
//   (см. HappySpeechApp.resolvedColorScheme(from:)). Env var `HS_THEME`
//   передаётся через `TEST_RUNNER_HS_THEME=dark` префикс для xcodebuild test.
//
// Issue #3: Sub-navigation routes (settings.*, demoStep*, rewards*, specialist*)
//   резолвят к root AppRoute → identical screenshots. Defer через ADR-V23-TOUR
//   (см. .claude/team/decisions.md). Sub-routes screenshots = parent root.

final class AllScreensTourUITests: XCTestCase {

    // MARK: - Setup

    /// Plan v23 Issue #1 — pre-grant permissions через shell helper
    /// `scripts/grant_uitest_permissions.sh` который вызывается ПЕРЕД
    /// `xcodebuild test`. `Foundation.Process` недоступен в iOS test runner
    /// (только macOS), поэтому grant выполняется снаружи. Внутри теста —
    /// только interruption monitor как fallback (см. captureScreen).
    override func setUpWithError() throws {
        // continueAfterFailure = true → если один screen не зарендерился, tour
        // не останавливается и остальные 103 routes всё равно проверяются.
        continueAfterFailure = true

        // Plan v23 Issue #2 — Dark theme на уровне симулятора (UIKit) через
        // XCUIDevice (iOS 13+). SwiftUI ColorScheme дополнительно форсится через
        // `-HSForceDarkTheme 1` launchArg в captureScreen.
        let theme = ProcessInfo.processInfo.environment["HS_THEME"] ?? "light"
        if theme.lowercased() == "dark" {
            XCUIDevice.shared.appearance = .dark
        } else {
            XCUIDevice.shared.appearance = .light
        }
    }

    // MARK: - Helper

    /// Запускает приложение с `-HSStartRoute <route>`, ждёт первый render
    /// и снимает screenshot как `XCTAttachment` с lifetime `.keepAlways`.
    ///
    /// - Parameters:
    ///   - route: имя route из `AppCoordinatorView.resolveStartRoute`.
    ///   - anchorTimeout: максимум секунд на появление любого XCUIElement.
    private func captureScreen(route: String, anchorTimeout: TimeInterval) {
        let theme = ProcessInfo.processInfo.environment["HS_THEME"] ?? "light"
        let isDark = theme.lowercased() == "dark"
        let themeTag = isDark ? "dark" : "light"

        let app = XCUIApplication()
        app.launchArguments = [
            "-HSStartRoute", route,
            "-UITESTING", "1",
            // Plan v23 Issue #2 — App-side force theme (SwiftUI .preferredColorScheme).
            "-HSForceDarkTheme", isDark ? "1" : "0"
        ]

        // Plan v23 Issue #1 — fallback interruption monitor для permission alerts.
        // Pre-grant в `setUp()` должен покрыть основное, но монитор страхует случаи
        // когда симулятор откатил privacy state либо новый service не был granted.
        let interruptionToken = addUIInterruptionMonitor(
            withDescription: "Permission alert handler"
        ) { alert in
            let candidates = [
                "Разрешить",
                "OK",
                "Allow",
                "Не разрешать",
                "Don't Allow",
                "Allow While Using App",
                "Разрешить при использовании"
            ]
            for label in candidates {
                let btn = alert.buttons[label]
                if btn.exists {
                    btn.tap()
                    return true
                }
            }
            return false
        }
        defer { removeUIInterruptionMonitor(interruptionToken) }

        app.launch()

        // Ждём пока появится любой UI-элемент — гарантирует что render
        // действительно произошёл, а не получаем пустой launch-image. Если на
        // экране всплыл system permission alert, он также является descendant —
        // waitForExistence вернёт true до того как мы попробуем dismiss его.
        let anyElement = app.descendants(matching: .any).firstMatch
        let rendered = anyElement.waitForExistence(timeout: anchorTimeout)
        XCTAssertTrue(
            rendered,
            "Screen '\(route)' did not render in \(anchorTimeout)s"
        )

        // Plan v23 Issue #1 — flush interruption monitor через benign tap.
        // Без user-interaction interruption monitor не вызовется.
        //
        // v27 fix (N-1 / N-2): tap по центру окна случайно активировал кнопки
        // на интерактивных экранах — roleSelect открывал ParentHome (попадание
        // по карточке «Родитель»), familyHome открывал Onboarding (попадание
        // по AddChildCard). Тапаем по безопасной точке у верхнего края, под
        // статус-баром, где на экранах HappySpeech нет интерактивных контролов.
        let safeFlushPoint = app.coordinate(
            withNormalizedOffset: CGVector(dx: 0.5, dy: 0.04)
        )
        safeFlushPoint.tap()

        // Дополнительная пауза — Lottie / SwiftUI transitions / first-frame
        // SF Symbols layout успевают завершить первую кадровую отрисовку.
        Thread.sleep(forTimeInterval: 1.2)

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "\(route)_\(themeTag)"
        attachment.lifetime = .keepAlways
        add(attachment)

        app.terminate()
    }

    // MARK: - Base 19 routes

    func test_route_demoMode() {
        captureScreen(route: "demoMode", anchorTimeout: 8)
    }

    func test_route_parentHome() {
        captureScreen(route: "parentHome", anchorTimeout: 8)
    }

    func test_route_roleSelect() {
        captureScreen(route: "roleSelect", anchorTimeout: 8)
    }

    func test_route_onboarding() {
        captureScreen(route: "onboarding", anchorTimeout: 8)
    }

    func test_route_settings() {
        captureScreen(route: "settings", anchorTimeout: 8)
    }

    func test_route_offlineState() {
        captureScreen(route: "offlineState", anchorTimeout: 8)
    }

    func test_route_childHome() {
        captureScreen(route: "childHome", anchorTimeout: 8)
    }

    func test_route_progressDashboard() {
        captureScreen(route: "progressDashboard", anchorTimeout: 8)
    }

    func test_route_rewards() {
        captureScreen(route: "rewards", anchorTimeout: 8)
    }

    func test_route_worldMap() {
        captureScreen(route: "worldMap", anchorTimeout: 8)
    }

    func test_route_sessionHistory() {
        captureScreen(route: "sessionHistory", anchorTimeout: 8)
    }

    func test_route_sessionComplete() {
        captureScreen(route: "sessionComplete", anchorTimeout: 8)
    }

    func test_route_arZone() {
        captureScreen(route: "arZone", anchorTimeout: 8)
    }

    func test_route_lessonPlayer() {
        captureScreen(route: "lessonPlayer", anchorTimeout: 8)
    }

    func test_route_familyVoice() {
        captureScreen(route: "familyVoice", anchorTimeout: 8)
    }

    func test_route_stuttering() {
        captureScreen(route: "stuttering", anchorTimeout: 8)
    }

    func test_route_fluencyDiary() {
        captureScreen(route: "fluencyDiary", anchorTimeout: 8)
    }

    func test_route_siblingMultiplayer() {
        captureScreen(route: "siblingMultiplayer", anchorTimeout: 8)
    }

    func test_route_auth() {
        captureScreen(route: "auth", anchorTimeout: 8)
    }

    // MARK: - Tier 1 (7)

    func test_route_authSignUp() {
        captureScreen(route: "authSignUp", anchorTimeout: 8)
    }

    func test_route_authForgotPassword() {
        captureScreen(route: "authForgotPassword", anchorTimeout: 8)
    }

    func test_route_authVerifyEmail() {
        captureScreen(route: "authVerifyEmail", anchorTimeout: 8)
    }

    func test_route_anonymousAuth() {
        captureScreen(route: "anonymousAuth", anchorTimeout: 8)
    }

    func test_route_splash() {
        captureScreen(route: "splash", anchorTimeout: 8)
    }

    func test_route_specialistHome() {
        captureScreen(route: "specialistHome", anchorTimeout: 8)
    }

    func test_route_childHome2() {
        captureScreen(route: "childHome2", anchorTimeout: 8)
    }

    // MARK: - Onboarding 10

    func test_route_onboarding1() {
        captureScreen(route: "onboarding1", anchorTimeout: 8)
    }

    func test_route_onboarding2() {
        captureScreen(route: "onboarding2", anchorTimeout: 8)
    }

    func test_route_onboarding3() {
        captureScreen(route: "onboarding3", anchorTimeout: 8)
    }

    func test_route_onboarding4() {
        captureScreen(route: "onboarding4", anchorTimeout: 8)
    }

    func test_route_onboarding5() {
        captureScreen(route: "onboarding5", anchorTimeout: 8)
    }

    func test_route_onboarding6() {
        captureScreen(route: "onboarding6", anchorTimeout: 8)
    }

    func test_route_onboarding7() {
        captureScreen(route: "onboarding7", anchorTimeout: 8)
    }

    func test_route_onboarding8() {
        captureScreen(route: "onboarding8", anchorTimeout: 8)
    }

    func test_route_onboarding9() {
        captureScreen(route: "onboarding9", anchorTimeout: 8)
    }

    func test_route_onboarding10() {
        captureScreen(route: "onboarding10", anchorTimeout: 8)
    }

    // MARK: - LessonPlayer 16

    func test_route_lessonListenAndChoose() {
        captureScreen(route: "lessonListenAndChoose", anchorTimeout: 8)
    }

    func test_route_lessonRepeatAfterModel() {
        captureScreen(route: "lessonRepeatAfterModel", anchorTimeout: 8)
    }

    func test_route_lessonDragAndMatch() {
        captureScreen(route: "lessonDragAndMatch", anchorTimeout: 8)
    }

    func test_route_lessonStoryCompletion() {
        captureScreen(route: "lessonStoryCompletion", anchorTimeout: 8)
    }

    func test_route_lessonPuzzleReveal() {
        captureScreen(route: "lessonPuzzleReveal", anchorTimeout: 8)
    }

    func test_route_lessonSorting() {
        captureScreen(route: "lessonSorting", anchorTimeout: 8)
    }

    func test_route_lessonMemory() {
        captureScreen(route: "lessonMemory", anchorTimeout: 8)
    }

    func test_route_lessonBingo() {
        captureScreen(route: "lessonBingo", anchorTimeout: 8)
    }

    func test_route_lessonSoundHunter() {
        captureScreen(route: "lessonSoundHunter", anchorTimeout: 8)
    }

    func test_route_lessonArticulationImitation() {
        captureScreen(route: "lessonArticulationImitation", anchorTimeout: 8)
    }

    func test_route_lessonARActivity() {
        captureScreen(route: "lessonARActivity", anchorTimeout: 8)
    }

    func test_route_lessonVisualAcoustic() {
        captureScreen(route: "lessonVisualAcoustic", anchorTimeout: 8)
    }

    func test_route_lessonBreathingExercise() {
        captureScreen(route: "lessonBreathingExercise", anchorTimeout: 8)
    }

    func test_route_lessonRhythm() {
        captureScreen(route: "lessonRhythm", anchorTimeout: 8)
    }

    func test_route_lessonNarrativeQuest() {
        captureScreen(route: "lessonNarrativeQuest", anchorTimeout: 8)
    }

    func test_route_lessonMinimalPairs() {
        captureScreen(route: "lessonMinimalPairs", anchorTimeout: 8)
    }

    // MARK: - AR 9

    func test_route_arMirror() {
        captureScreen(route: "arMirror", anchorTimeout: 8)
    }

    func test_route_arStoryQuest() {
        captureScreen(route: "arStoryQuest", anchorTimeout: 8)
    }

    func test_route_breathingAR() {
        captureScreen(route: "breathingAR", anchorTimeout: 8)
    }

    func test_route_butterflyCatch() {
        captureScreen(route: "butterflyCatch", anchorTimeout: 8)
    }

    func test_route_holdThePose() {
        captureScreen(route: "holdThePose", anchorTimeout: 8)
    }

    func test_route_mascot3D() {
        captureScreen(route: "mascot3D", anchorTimeout: 8)
    }

    func test_route_mimicLyalya() {
        captureScreen(route: "mimicLyalya", anchorTimeout: 8)
    }

    func test_route_poseSequence() {
        captureScreen(route: "poseSequence", anchorTimeout: 8)
    }

    func test_route_soundAndFace() {
        captureScreen(route: "soundAndFace", anchorTimeout: 8)
    }

    // MARK: - Session 5

    func test_route_sessionShell() {
        captureScreen(route: "sessionShell", anchorTimeout: 8)
    }

    func test_route_sessionDetail() {
        captureScreen(route: "sessionDetail", anchorTimeout: 8)
    }

    func test_route_celebrationOverlay() {
        captureScreen(route: "celebrationOverlay", anchorTimeout: 8)
    }

    func test_route_rewardDetail() {
        captureScreen(route: "rewardDetail", anchorTimeout: 8)
    }

    func test_route_rewardAlbum() {
        captureScreen(route: "rewardAlbum", anchorTimeout: 8)
    }

    // MARK: - Settings 9

    func test_route_settingsTheme() {
        captureScreen(route: "settingsTheme", anchorTimeout: 8)
    }

    func test_route_settingsNotifications() {
        captureScreen(route: "settingsNotifications", anchorTimeout: 8)
    }

    func test_route_settingsModelPacks() {
        captureScreen(route: "settingsModelPacks", anchorTimeout: 8)
    }

    func test_route_settingsPrivacy() {
        captureScreen(route: "settingsPrivacy", anchorTimeout: 8)
    }

    func test_route_settingsGDPR() {
        captureScreen(route: "settingsGDPR", anchorTimeout: 8)
    }

    func test_route_settingsAbout() {
        captureScreen(route: "settingsAbout", anchorTimeout: 8)
    }

    func test_route_settingsVoice() {
        captureScreen(route: "settingsVoice", anchorTimeout: 8)
    }

    func test_route_settingsLanguage() {
        captureScreen(route: "settingsLanguage", anchorTimeout: 8)
    }

    func test_route_settingsAccessibility() {
        captureScreen(route: "settingsAccessibility", anchorTimeout: 8)
    }

    // MARK: - Demo/Misc 7

    func test_route_demoStep1() {
        captureScreen(route: "demoStep1", anchorTimeout: 8)
    }

    func test_route_demoStep5() {
        captureScreen(route: "demoStep5", anchorTimeout: 8)
    }

    func test_route_demoStep10() {
        captureScreen(route: "demoStep10", anchorTimeout: 8)
    }

    func test_route_demoStep15() {
        captureScreen(route: "demoStep15", anchorTimeout: 8)
    }

    func test_route_homeTasks() {
        captureScreen(route: "homeTasks", anchorTimeout: 8)
    }

    func test_route_rewardCollection() {
        captureScreen(route: "rewardCollection", anchorTimeout: 8)
    }

    func test_route_dailyStreak() {
        captureScreen(route: "dailyStreak", anchorTimeout: 8)
    }

    // MARK: - Family 6

    func test_route_familyHome() {
        captureScreen(route: "familyHome", anchorTimeout: 8)
    }

    func test_route_profileEditor() {
        captureScreen(route: "profileEditor", anchorTimeout: 8)
    }

    func test_route_comparisonDashboard() {
        captureScreen(route: "comparisonDashboard", anchorTimeout: 8)
    }

    func test_route_familyCalendar() {
        captureScreen(route: "familyCalendar", anchorTimeout: 8)
    }

    func test_route_familyLeaderboard() {
        captureScreen(route: "familyLeaderboard", anchorTimeout: 8)
    }

    func test_route_familyAchievements() {
        captureScreen(route: "familyAchievements", anchorTimeout: 8)
    }

    // MARK: - Specialist 5

    func test_route_specialistLogin() {
        captureScreen(route: "specialistLogin", anchorTimeout: 8)
    }

    func test_route_studentsList() {
        captureScreen(route: "studentsList", anchorTimeout: 8)
    }

    func test_route_programEditor() {
        captureScreen(route: "programEditor", anchorTimeout: 8)
    }

    func test_route_sessionReview() {
        captureScreen(route: "sessionReview", anchorTimeout: 8)
    }

    func test_route_reports() {
        captureScreen(route: "reports", anchorTimeout: 8)
    }

    // MARK: - Stuttering 5

    func test_route_stutteringHome() {
        captureScreen(route: "stutteringHome", anchorTimeout: 8)
    }

    func test_route_breathingTree() {
        captureScreen(route: "breathingTree", anchorTimeout: 8)
    }

    func test_route_metronome() {
        captureScreen(route: "metronome", anchorTimeout: 8)
    }

    func test_route_softOnset() {
        captureScreen(route: "softOnset", anchorTimeout: 8)
    }

    func test_route_fluencyDiaryHome() {
        captureScreen(route: "fluencyDiaryHome", anchorTimeout: 8)
    }

    // MARK: - Misc 9

    func test_route_neurolinguistInsights() {
        captureScreen(route: "neurolinguistInsights", anchorTimeout: 8)
    }

    func test_route_speechVisualization() {
        captureScreen(route: "speechVisualization", anchorTimeout: 8)
    }

    func test_route_offlineMiniGame() {
        captureScreen(route: "offlineMiniGame", anchorTimeout: 8)
    }

    func test_route_arFaceFilter() {
        captureScreen(route: "arFaceFilter", anchorTimeout: 8)
    }

    func test_route_guidedTour() {
        captureScreen(route: "guidedTour", anchorTimeout: 8)
    }

    func test_route_grammarGame() {
        captureScreen(route: "grammarGame", anchorTimeout: 8)
    }

    func test_route_siblingMultiplayerDiscovery() {
        captureScreen(route: "siblingMultiplayerDiscovery", anchorTimeout: 8)
    }

    func test_route_siblingMultiplayerLobby() {
        captureScreen(route: "siblingMultiplayerLobby", anchorTimeout: 8)
    }

    func test_route_siblingMultiplayerGame() {
        captureScreen(route: "siblingMultiplayerGame", anchorTimeout: 8)
    }

    // MARK: - R+AE 11

    func test_route_dialectAdaptation() {
        captureScreen(route: "dialectAdaptation", anchorTimeout: 8)
    }

    func test_route_logopedistChat() {
        captureScreen(route: "logopedistChat", anchorTimeout: 8)
    }

    func test_route_weeklyChallenge() {
        captureScreen(route: "weeklyChallenge", anchorTimeout: 8)
    }

    func test_route_culturalContent() {
        captureScreen(route: "culturalContent", anchorTimeout: 8)
    }

    func test_route_pronunciationLeaderboard() {
        captureScreen(route: "pronunciationLeaderboard", anchorTimeout: 8)
    }

    func test_route_soundDictionary() {
        captureScreen(route: "soundDictionary", anchorTimeout: 8)
    }

    func test_route_helpCenter() {
        captureScreen(route: "helpCenter", anchorTimeout: 8)
    }

    func test_route_dailyChallenge() {
        captureScreen(route: "dailyChallenge", anchorTimeout: 8)
    }

    func test_route_parentInsightsTimeline() {
        captureScreen(route: "parentInsightsTimeline", anchorTimeout: 8)
    }

    func test_route_familyAwardsCabinet() {
        captureScreen(route: "familyAwardsCabinet", anchorTimeout: 8)
    }

    func test_route_voiceCloning() {
        captureScreen(route: "voiceCloning", anchorTimeout: 8)
    }

    // MARK: - Coverage gap (4) — routes present in resolveStartRoute без теста

    func test_route_screening() {
        captureScreen(route: "screening", anchorTimeout: 8)
    }

    func test_route_weeklyReport() {
        captureScreen(route: "weeklyReport", anchorTimeout: 8)
    }

    func test_route_articulationGym() {
        captureScreen(route: "articulationGym", anchorTimeout: 8)
    }

    func test_route_wordBank() {
        captureScreen(route: "wordBank", anchorTimeout: 8)
    }
}
