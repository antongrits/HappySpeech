@testable import HappySpeech
import RealityKit
import XCTest

// MARK: - FaceMaskEntityBuilderTests
//
// Покрывает чистую RealityKit-сборку 3D-аксессуаров маски. Построение Entity
// из примитивов НЕ требует ARSession/TrueDepth → выполняется на симуляторе.
// Привязка к реальному `ARFaceAnchor` и движение за лицом — ручная верификация
// на устройстве A12+ (нет в симуляторе).

@MainActor
final class FaceMaskEntityBuilderTests: XCTestCase {

    // MARK: - makeEntity: для каждой маски строится непустой аксессуар

    func test_makeEntity_buildsNonEmptyEntityForEveryMask() {
        for mask in FaceMaskKind.allCases {
            let entity = FaceMaskEntityBuilder.makeEntity(for: mask)
            XCTAssertFalse(
                entity.children.isEmpty,
                "Маска \(mask.rawValue) должна состоять хотя бы из одной части"
            )
        }
    }

    func test_makeEntity_rootNameEncodesMaskKind() {
        for mask in FaceMaskKind.allCases {
            let entity = FaceMaskEntityBuilder.makeEntity(for: mask)
            XCTAssertEqual(entity.name, "mask.\(mask.rawValue)")
        }
    }

    // MARK: - Реактивные части (ушки/клапаны) присутствуют там, где ожидаются

    func test_makeEntity_kitten_hasReactiveEars() {
        let entity = FaceMaskEntityBuilder.makeEntity(for: .kitten)
        XCTAssertNotNil(entity.findEntity(named: FaceMaskEntityBuilder.PartName.leftEar))
        XCTAssertNotNil(entity.findEntity(named: FaceMaskEntityBuilder.PartName.rightEar))
    }

    func test_makeEntity_fox_hasReactiveEars() {
        let entity = FaceMaskEntityBuilder.makeEntity(for: .fox)
        XCTAssertNotNil(entity.findEntity(named: FaceMaskEntityBuilder.PartName.leftEar))
        XCTAssertNotNil(entity.findEntity(named: FaceMaskEntityBuilder.PartName.rightEar))
    }

    func test_makeEntity_ushanka_hasReactiveFlaps() {
        let entity = FaceMaskEntityBuilder.makeEntity(for: .ushanka)
        XCTAssertNotNil(entity.findEntity(named: FaceMaskEntityBuilder.PartName.leftEar))
        XCTAssertNotNil(entity.findEntity(named: FaceMaskEntityBuilder.PartName.rightEar))
    }

    func test_makeEntity_crown_hasNoEars() {
        // У короны нет «ушек» — реактивность ушек к ней не применяется (no-op).
        let entity = FaceMaskEntityBuilder.makeEntity(for: .crown)
        XCTAssertNil(entity.findEntity(named: FaceMaskEntityBuilder.PartName.leftEar))
        XCTAssertNil(entity.findEntity(named: FaceMaskEntityBuilder.PartName.rightEar))
    }

    func test_makeEntity_eachCallReturnsFreshEntity() {
        // Аксессуары не должны шарить состояние между привязками.
        let a = FaceMaskEntityBuilder.makeEntity(for: .kitten)
        let b = FaceMaskEntityBuilder.makeEntity(for: .kitten)
        XCTAssertFalse(a === b)
    }
}
