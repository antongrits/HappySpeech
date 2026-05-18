import Foundation
import XCTest
@testable import HappySpeech

// MARK: - AmbientSoundServiceTests
//
// Тесты MockAmbientSoundService + LiveAmbientSoundService + value-типы.
// LiveAmbientSoundService: .caf-файлы могут отсутствовать в тестовом бандле →
// play() логирует warning и не падает; проверяется устойчивость actor-обёртки.

final class AmbientSoundServiceTests: XCTestCase {

    // MARK: - AmbientScene

    func testAmbientSceneCaseCount() {
        XCTAssertEqual(AmbientScene.allCases.count, 10)
    }

    func testAmbientSceneRawValuesDistinct() {
        let raw = Set(AmbientScene.allCases.map(\.rawValue))
        XCTAssertEqual(raw.count, AmbientScene.allCases.count)
    }

    func testAmbientSceneKnownRawValues() {
        XCTAssertEqual(AmbientScene.childHome.rawValue, "childhome")
        XCTAssertEqual(AmbientScene.homeQuiet.rawValue, "home_quiet")
        XCTAssertEqual(AmbientScene.winterWind.rawValue, "winter_wind")
        XCTAssertEqual(AmbientScene.neutralWarm.rawValue, "neutral_warm")
    }

    // MARK: - AmbientVolumeSetting

    func testAmbientVolumeSettingValues() {
        XCTAssertEqual(AmbientVolumeSetting.off.volume, 0.0, accuracy: 0.001)
        XCTAssertEqual(AmbientVolumeSetting.subtle.volume, 0.15, accuracy: 0.001)
        XCTAssertEqual(AmbientVolumeSetting.medium.volume, 0.3, accuracy: 0.001)
        XCTAssertEqual(AmbientVolumeSetting.full.volume, 0.5, accuracy: 0.001)
    }

    func testAmbientVolumeSettingDefault() {
        XCTAssertEqual(AmbientVolumeSetting.defaultSetting, .medium)
    }

    func testAmbientVolumeSettingCaseCount() {
        XCTAssertEqual(AmbientVolumeSetting.allCases.count, 4)
    }

    func testAmbientVolumeSettingUserDefaultsKey() {
        XCTAssertEqual(AmbientVolumeSetting.userDefaultsKey, "AmbientSound.volumeSetting")
    }

    // MARK: - MockAmbientSoundService

    func testMockInitialSceneIsNil() async {
        let mock = MockAmbientSoundService()
        let scene = await mock.currentScene
        XCTAssertNil(scene)
    }

    func testMockPlaySetsCurrentScene() async {
        let mock = MockAmbientSoundService()
        await mock.play(scene: .forest, fadeDuration: 1.0)
        let scene = await mock.currentScene
        XCTAssertEqual(scene, .forest)
        let last = await mock.lastPlayedScene
        XCTAssertEqual(last, .forest)
    }

    func testMockStopClearsScene() async {
        let mock = MockAmbientSoundService()
        await mock.play(scene: .ocean, fadeDuration: 0.5)
        await mock.stop(fadeDuration: 0.5)
        let scene = await mock.currentScene
        XCTAssertNil(scene)
        let stopCount = await mock.stopCallCount
        XCTAssertEqual(stopCount, 1)
    }

    func testMockLastPlayedSceneSurvivesStop() async {
        let mock = MockAmbientSoundService()
        await mock.play(scene: .space, fadeDuration: 0.5)
        await mock.stop(fadeDuration: 0.5)
        let last = await mock.lastPlayedScene
        XCTAssertEqual(last, .space, "lastPlayedScene остаётся для аналитики после stop")
    }

    func testMockMultiplePlaysUpdateScene() async {
        let mock = MockAmbientSoundService()
        await mock.play(scene: .circus, fadeDuration: 0.5)
        await mock.play(scene: .garden, fadeDuration: 0.5)
        let scene = await mock.currentScene
        XCTAssertEqual(scene, .garden)
    }

    func testMockSetVolumeDoesNotCrash() async {
        let mock = MockAmbientSoundService()
        await mock.setVolume(0.7)
        await mock.setVolume(2.0)
        await mock.setVolume(-1.0)
    }

    func testMockStopCallCountAccumulates() async {
        let mock = MockAmbientSoundService()
        await mock.stop(fadeDuration: 0.1)
        await mock.stop(fadeDuration: 0.1)
        let count = await mock.stopCallCount
        XCTAssertEqual(count, 2)
    }

    // MARK: - LiveAmbientSoundService

    func testLiveInitDoesNotCrash() async {
        let service = LiveAmbientSoundService()
        let scene = await service.currentScene
        XCTAssertNil(scene)
    }

    func testLivePlayPresentAssetSetsScene() async {
        let service = LiveAmbientSoundService()
        // neutral_warm.caf присутствует в бандле приложения → play() успешно
        // создаёт плеер и выставляет currentScene.
        await service.play(scene: .neutralWarm, fadeDuration: 0.1)
        let scene = await service.currentScene
        XCTAssertEqual(scene, .neutralWarm, "Доступный ассет выставляет currentScene")
        await service.stop(fadeDuration: 0.05)
    }

    func testLiveStopWhenIdleIsNoop() async {
        let service = LiveAmbientSoundService()
        await service.stop(fadeDuration: 0.1)
        let scene = await service.currentScene
        XCTAssertNil(scene)
    }

    func testLiveSetVolumeWhenIdleDoesNotCrash() async {
        let service = LiveAmbientSoundService()
        await service.setVolume(0.4)
        await service.setVolume(1.5)
        await service.setVolume(-0.2)
    }
}
