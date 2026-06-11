import SwiftUI
import UIKit
import XCTest
@testable import HappySpeech

/// Проверки метаданных артикуляции (`ArticulationSound`) для всех 10 укладов,
/// используемых карточкой артикуляции `Articulation3DCard` (режимы «Видео» и
/// «Настоящий рот» 3D). Тест чисто-логический и детерминированный: убеждается,
/// что кириллица каждой фонемы маппится на ожидаемый уклад, флаг звонкости верен,
/// а текстовая подсказка позы непустая. 3D-сцена (Metal/SceneKit) визуально
/// выверяется вручную на симуляторе — её кадр не снимается в host-render-харнессе.
@MainActor
final class Articulation3DRenderTest: XCTestCase {

    func testCyrillicMapsToExpectedPose() {
        let cases: [(String, ArticulationSound)] = [
            ("С", .s), ("Сь", .s), ("Ц", .s),
            ("З", .z), ("Зь", .z),
            ("Ш", .sh), ("Ч", .sh), ("Щ", .sh),
            ("Ж", .zh),
            ("Р", .r), ("Рь", .r),
            ("Л", .soundL), ("Ль", .soundL),
            ("К", .k),
            ("Г", .g),
            ("Х", .kh)
        ]
        for (cyrillic, expected) in cases {
            XCTAssertEqual(
                ArticulationSound.fromCyrillic(cyrillic), expected,
                "Кириллица «\(cyrillic)» должна маппиться на уклад \(expected)"
            )
        }
    }

    func testNonArticulatorySoundReturnsNil() {
        // Гласные и прочие звуки без научной позы → nil (показывается видео-фоллбэк).
        for cyrillic in ["А", "О", "У", "Е", "Б", "М"] {
            XCTAssertNil(
                ArticulationSound.fromCyrillic(cyrillic),
                "Для «\(cyrillic)» научной позы нет — ожидается nil"
            )
        }
    }

    func testVoicingFlags() {
        let voiced: [ArticulationSound] = [.z, .zh, .r, .soundL, .g]
        let voiceless: [ArticulationSound] = [.neutral, .s, .sh, .k, .kh]
        for sound in voiced {
            XCTAssertTrue(sound.isVoiced, "\(sound) должен быть звонким")
        }
        for sound in voiceless {
            XCTAssertFalse(sound.isVoiced, "\(sound) должен быть глухим")
        }
    }

    func testEveryPoseHasNonEmptyHint() {
        for sound in ArticulationSound.allCases {
            XCTAssertFalse(
                sound.localizedHint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                "Подсказка позы для \(sound) не должна быть пустой"
            )
        }
    }
}
