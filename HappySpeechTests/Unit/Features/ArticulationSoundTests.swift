@testable import HappySpeech
import XCTest

// MARK: - ArticulationSoundTests
//
// Покрывает чистую логику enum ArticulationSound:
//   • fromCyrillic(_:) — маппинг кириллических фонем на позы
//   • isVoiced — флаг звонкости каждого case
//   • localizedHint — ненулевая строка для каждого case
//
// Нет UI, нет SceneKit, нет сети — выполняется мгновенно.

final class ArticulationSoundTests: XCTestCase {

    // MARK: - fromCyrillic: прямые маппинги

    func test_fromCyrillic_С_returnsS() {
        XCTAssertEqual(ArticulationSound.fromCyrillic("С"), .s)
    }

    func test_fromCyrillic_lowercase_с_returnsS() {
        XCTAssertEqual(ArticulationSound.fromCyrillic("с"), .s)
    }

    func test_fromCyrillic_Ц_returnsS() {
        XCTAssertEqual(ArticulationSound.fromCyrillic("Ц"), .s)
    }

    func test_fromCyrillic_З_returnsZ() {
        XCTAssertEqual(ArticulationSound.fromCyrillic("З"), .z)
    }

    func test_fromCyrillic_Ш_returnsSh() {
        XCTAssertEqual(ArticulationSound.fromCyrillic("Ш"), .sh)
    }

    func test_fromCyrillic_Ч_returnsSh() {
        XCTAssertEqual(ArticulationSound.fromCyrillic("Ч"), .sh)
    }

    func test_fromCyrillic_Щ_returnsSh() {
        XCTAssertEqual(ArticulationSound.fromCyrillic("Щ"), .sh)
    }

    func test_fromCyrillic_Ж_returnsZh() {
        XCTAssertEqual(ArticulationSound.fromCyrillic("Ж"), .zh)
    }

    func test_fromCyrillic_Р_returnsR() {
        XCTAssertEqual(ArticulationSound.fromCyrillic("Р"), .r)
    }

    func test_fromCyrillic_Л_returnsSoundL() {
        XCTAssertEqual(ArticulationSound.fromCyrillic("Л"), .soundL)
    }

    func test_fromCyrillic_К_returnsK() {
        XCTAssertEqual(ArticulationSound.fromCyrillic("К"), .k)
    }

    func test_fromCyrillic_Г_returnsG() {
        XCTAssertEqual(ArticulationSound.fromCyrillic("Г"), .g)
    }

    func test_fromCyrillic_Х_returnsKh() {
        XCTAssertEqual(ArticulationSound.fromCyrillic("Х"), .kh)
    }

    // MARK: - fromCyrillic: мягкий знак удаляется

    func test_fromCyrillic_Сь_returnsS_softSignStripped() {
        XCTAssertEqual(ArticulationSound.fromCyrillic("Сь"), .s)
    }

    func test_fromCyrillic_Зь_returnsZ_softSignStripped() {
        XCTAssertEqual(ArticulationSound.fromCyrillic("Зь"), .z)
    }

    func test_fromCyrillic_Рь_returnsR_softSignStripped() {
        XCTAssertEqual(ArticulationSound.fromCyrillic("Рь"), .r)
    }

    func test_fromCyrillic_Ль_returnsSoundL_softSignStripped() {
        XCTAssertEqual(ArticulationSound.fromCyrillic("Ль"), .soundL)
    }

    // MARK: - fromCyrillic: пробелы обрезаются

    func test_fromCyrillic_withLeadingTrailingSpaces_returnsCorrect() {
        XCTAssertEqual(ArticulationSound.fromCyrillic("  Р  "), .r)
    }

    // MARK: - fromCyrillic: неизвестные фонемы → nil

    func test_fromCyrillic_А_returnsNil() {
        XCTAssertNil(ArticulationSound.fromCyrillic("А"))
    }

    func test_fromCyrillic_emptyString_returnsNil() {
        XCTAssertNil(ArticulationSound.fromCyrillic(""))
    }

    func test_fromCyrillic_P_latin_returnsNil() {
        // Латинская P ≠ кириллическая Р
        XCTAssertNil(ArticulationSound.fromCyrillic("P"))
    }

    func test_fromCyrillic_Б_returnsNil() {
        XCTAssertNil(ArticulationSound.fromCyrillic("Б"))
    }

    // MARK: - isVoiced

    func test_isVoiced_voicedSounds_returnTrue() {
        let voicedCases: [ArticulationSound] = [.z, .zh, .r, .soundL, .g]
        for sound in voicedCases {
            XCTAssertTrue(sound.isVoiced, "\(sound) должен быть звонким")
        }
    }

    func test_isVoiced_voicelessSounds_returnFalse() {
        let voicelessCases: [ArticulationSound] = [.neutral, .s, .sh, .k, .kh]
        for sound in voicelessCases {
            XCTAssertFalse(sound.isVoiced, "\(sound) должен быть глухим")
        }
    }

    func test_isVoiced_allCasesClassified() {
        // Убедимся, что isVoiced задан для каждого case (нет missing switch arm).
        for sound in ArticulationSound.allCases {
            _ = sound.isVoiced
        }
    }

    // MARK: - localizedHint

    func test_localizedHint_nonEmptyForAllCases() {
        // localizedHint опирается на String(localized:); если ключ не найден,
        // возвращается сам ключ (не пустая строка) — проверяем что не пусто.
        for sound in ArticulationSound.allCases {
            XCTAssertFalse(
                sound.localizedHint.isEmpty,
                "localizedHint для \(sound) не должен быть пустой строкой"
            )
        }
    }

    func test_localizedHint_sAndZShareSameKey() {
        // По реализации .s и .z возвращают одну и ту же строку локализации.
        XCTAssertEqual(ArticulationSound.s.localizedHint, ArticulationSound.z.localizedHint)
    }

    func test_localizedHint_shAndZhShareSameKey() {
        // .sh и .zh — оба «чашечка» вверх-назад.
        XCTAssertEqual(ArticulationSound.sh.localizedHint, ArticulationSound.zh.localizedHint)
    }

    func test_localizedHint_kAndGShareSameKey() {
        // .k и .g — задняя часть к мягкому нёбу.
        XCTAssertEqual(ArticulationSound.k.localizedHint, ArticulationSound.g.localizedHint)
    }

    func test_localizedHint_differentPositionsHaveDifferentHints() {
        // .r (кончик к альвеолам) ≠ .soundL (кончик к верхним резцам) ≠ .kh (задняя щель).
        XCTAssertNotEqual(ArticulationSound.r.localizedHint, ArticulationSound.soundL.localizedHint)
        XCTAssertNotEqual(ArticulationSound.r.localizedHint, ArticulationSound.kh.localizedHint)
    }

    // MARK: - CaseIterable

    func test_allCases_countMatchesDefinition() {
        // neutral + 9 согласных = 10
        XCTAssertEqual(ArticulationSound.allCases.count, 10)
    }

    func test_allCases_distinctRawValues() {
        let raws = ArticulationSound.allCases.map(\.rawValue)
        XCTAssertEqual(Set(raws).count, raws.count, "rawValue каждого case должен быть уникальным")
    }
}
