@testable import HappySpeech
import SwiftUI
import XCTest

// MARK: - PhonemePassportSnapshotTests
//
// Snapshot-покрытие секции «Фонемный паспорт» (GOP-анализ) на экране
// PhonemeReportView в light+dark, с данными паспорта и без (empty).
//
// Smoke-подход (`assertRendersNonBlank`), не pixel-diff: PhonemeReportView
// строит свой VIP-цикл в `.task` и грузит паспорт асинхронно через
// PhonemeProfileService — момент захвата кадра гонится с завершением загрузки,
// поэтому пиксельный снимок недетерминирован (как у SpecialistReportsView /
// SessionCompleteView). Smoke ловит главный класс регрессий: краш конструкции,
// пустой кадр, отсутствие env, падение при построении секции паспорта.
//
// Детерминизм: reduceMotion=true (фон HSMeshGradientBackground заморожен),
// данные паспорта фиксированы (инъектированная now() + ручные GOP).

@MainActor
final class PhonemePassportSnapshotTests: XCTestCase {

    private let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)
    private func day(_ offset: Int) -> Date {
        fixedNow.addingTimeInterval(Double(offset) * 86_400)
    }

    // MARK: - Seeded observations (детерминированные)

    private func seededObservations() -> [PhonemeObservationDTO] {
        var observations: [PhonemeObservationDTO] = []
        // Ш: растущая динамика по позициям → improving + матрица с данными.
        for index in 0..<12 {
            observations.append(
                PhonemeObservationDTO(
                    childId: "preview-child-1",
                    phoneme: "ʂ",
                    wordId: "word_shar",
                    position: index.isMultiple(of: 2)
                        ? PhonemeWordPosition.initial.rawValue
                        : PhonemeWordPosition.final.rawValue,
                    gop: -1.0 + Double(index) * 0.22,
                    posterior: 0.6,
                    defect: index < 4 ? "distortion" : "ok",
                    competitor: nil,
                    date: day(index)
                )
            )
        }
        // Р: устойчивые замены → poor + needsConsultation-ветка прогноза.
        for index in 0..<10 {
            observations.append(
                PhonemeObservationDTO(
                    childId: "preview-child-1",
                    phoneme: "r",
                    wordId: "word_ruka",
                    position: PhonemeWordPosition.medial.rawValue,
                    gop: -1.6,
                    posterior: 0.55,
                    defect: "substitution",
                    competitor: "l",
                    date: day(index)
                )
            )
        }
        return observations
    }

    private func makeContainer(observations: [PhonemeObservationDTO]) -> AppContainer {
        let container = AppContainer.preview()
        container.overridePhonemeProfileService(
            MockPhonemeProfileService(observations: observations, now: { [fixedNow] in fixedNow })
        )
        return container
    }

    // MARK: - With passport data

    func test_phonemeReport_withPassport_light() {
        let view = PhonemeReportView(childId: "preview-child-1")
            .environment(makeContainer(observations: seededObservations()))
            .environment(AppCoordinator())
        SnapshotTestHelper.assertRendersNonBlank(
            view, style: .light, label: "PhonemePassport·Data·Light"
        )
    }

    func test_phonemeReport_withPassport_dark() {
        let view = PhonemeReportView(childId: "preview-child-1")
            .environment(makeContainer(observations: seededObservations()))
            .environment(AppCoordinator())
        SnapshotTestHelper.assertRendersNonBlank(
            view, style: .dark, label: "PhonemePassport·Data·Dark"
        )
    }

    // MARK: - Empty passport (no family-voice observations yet)

    func test_phonemeReport_emptyPassport_light() {
        let view = PhonemeReportView(childId: "preview-child-1")
            .environment(makeContainer(observations: []))
            .environment(AppCoordinator())
        SnapshotTestHelper.assertRendersNonBlank(
            view, style: .light, label: "PhonemePassport·Empty·Light"
        )
    }

    func test_phonemeReport_emptyPassport_dark() {
        let view = PhonemeReportView(childId: "preview-child-1")
            .environment(makeContainer(observations: []))
            .environment(AppCoordinator())
        SnapshotTestHelper.assertRendersNonBlank(
            view, style: .dark, label: "PhonemePassport·Empty·Dark"
        )
    }
}
