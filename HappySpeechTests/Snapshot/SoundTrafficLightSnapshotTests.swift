@testable import HappySpeech
import SwiftUI
import XCTest

// MARK: - SoundTrafficLightSnapshotTests
//
// v29 Фаза 8, Функция 5 «Звуковой светофор» — прогрессия дифференциации.
//
// Снимки каждого уровня лестницы (СЛОГ / СЛОВО / ФРАЗА / ТЕКСТ) в light + dark
// на двух устройствах. Уровни рендерятся детерминированно через
// `SoundTrafficLightLevelPreview` из заранее собранного `Start.ViewModel`
// (реальный Presenter, без async-воркера и random-выборки).
//
// Корневой `SoundTrafficLightView` имеет async-bootstrap + random-выбор слов
// (worker.makeRounds → shuffled) — его пиксельный снимок недетерминирован,
// поэтому для него отдельный smoke-тест (assertRendersNonBlank), ловящий
// краш/пустой кадр/отсутствие окружения. Паттерн совпадает с SyllableConstructor.

@MainActor
final class SoundTrafficLightSnapshotTests: XCTestCase {

    private struct DeviceConfig {
        let name: String
        let size: CGSize
    }

    private let devices: [DeviceConfig] = [
        DeviceConfig(name: "iPhoneSE3",   size: CGSize(width: 375, height: 667)),
        DeviceConfig(name: "iPhone17Pro", size: CGSize(width: 402, height: 874))
    ]

    private let appearances: [(String, UIUserInterfaceStyle)] = [
        ("Light", .light),
        ("Dark",  .dark)
    ]

    // MARK: - Deterministic level ViewModel builder

    /// Capturing display собирает ViewModel из реального Presenter.
    private final class CaptureDisplay: SoundTrafficLightDisplayLogic {
        var startVM: SoundTrafficLightModels.Start.ViewModel?
        func displayStart(viewModel: SoundTrafficLightModels.Start.ViewModel) async { startVM = viewModel }
        func displaySort(viewModel: SoundTrafficLightModels.Sort.ViewModel) async {}
        func displayChoosePhrase(viewModel: SoundTrafficLightModels.ChoosePhrase.ViewModel) async {}
        func displayCountText(viewModel: SoundTrafficLightModels.CountText.ViewModel) async {}
    }

    private func makeViewModel(level: DifferentiationLevel) async -> SoundTrafficLightModels.Start.ViewModel {
        guard let pair = SoundTrafficLightCorpus.pair(forId: "pair-s-sh") else {
            fatalError("pair-s-sh must exist in differentiation pack")
        }
        let response = SoundTrafficLightWorker.makeSession(pair: pair, level: level)
        let display = CaptureDisplay()
        let presenter = SoundTrafficLightPresenter(displayLogic: display)
        await presenter.presentStart(response: response)
        guard let viewModel = display.startVM else {
            fatalError("Presenter must produce a start ViewModel for level \(level)")
        }
        return viewModel
    }

    private func snapshotLevel(_ level: DifferentiationLevel) async throws {
        let viewModel = await makeViewModel(level: level)
        let view = SoundTrafficLightLevelPreview(viewModel: viewModel)
        try record(view, screen: "SoundTrafficLight_\(level.rawValue)")
    }

    // MARK: - Per-level pixel snapshots

    func test_level_syllable() async throws {
        try await snapshotLevel(.syllable)
    }

    func test_level_word() async throws {
        try await snapshotLevel(.word)
    }

    func test_level_phrase() async throws {
        try await snapshotLevel(.phrase)
    }

    func test_level_text() async throws {
        try await snapshotLevel(.text)
    }

    // MARK: - Root view smoke (async + random selection)

    func test_rootView_rendersNonBlank() throws {
        let view = SoundTrafficLightView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        for device in devices {
            for (appearanceName, style) in appearances {
                SnapshotTestHelper.assertRendersNonBlank(
                    view,
                    size: device.size,
                    style: style,
                    label: "SoundTrafficLightView·\(device.name)·\(appearanceName)"
                )
            }
        }
    }

    // MARK: - Record / compare

    private func record<V: View>(
        _ view: V,
        screen: String,
        maxDiffRatio: Double = SnapshotTestHelper.defaultMaxDiffRatio
    ) throws {
        for device in devices {
            for (appearanceName, style) in appearances {
                let image = SnapshotTestHelper.renderView(
                    view, size: device.size, style: style, reduceMotion: true
                )
                let url = SnapshotTestHelper.snapshotURL(
                    testClass: Self.self,
                    category: "SoundTrafficLight",
                    screen: screen,
                    device: device.name,
                    appearance: appearanceName
                )
                try SnapshotTestHelper.assertPixelMatch(
                    image,
                    referenceURL: url,
                    maxDiffRatio: maxDiffRatio,
                    label: "\(screen)·\(device.name)·\(appearanceName)"
                )
            }
        }
    }
}
