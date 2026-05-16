@testable import HappySpeech
import XCTest

// MARK: - SeasonalContentLoaderWorkerTests
//
// Покрывает: loadPack(packId:) — JSON-загрузка из bundle.
// loadActivePack() полагается на SeasonalEventsManager.shared — hardware side,
// тестируется косвенно через loadPack + отсутствие крэша.

final class SeasonalContentLoaderWorkerTests: XCTestCase {

    private let sut = SeasonalContentLoaderWorker()

    // MARK: - loadPack: несуществующий pack

    func test_loadPack_returnsNilForNonexistentPackId() async {
        let result = await sut.loadPack(packId: "seasonal_nonexistent_xyz")
        XCTAssertNil(result, "Несуществующий pack должен возвращать nil")
    }

    func test_loadPack_returnsNilForEmptyPackId() async {
        let result = await sut.loadPack(packId: "")
        XCTAssertNil(result, "Пустой packId должен возвращать nil")
    }

    func test_loadPack_returnsNilForPackIdWithSpecialCharacters() async {
        let result = await sut.loadPack(packId: "pack/../../etc/passwd")
        XCTAssertNil(result, "packId со спецсимволами должен безопасно возвращать nil")
    }

    func test_loadPack_returnsNilForRandomId() async {
        let result = await sut.loadPack(packId: UUID().uuidString)
        XCTAssertNil(result, "Случайный UUID не должен совпадать с bundle-ресурсом")
    }

    // MARK: - loadActivePack

    func test_loadActivePack_doesNotCrash() async {
        // SeasonalEventsManager.shared.activeEvent недоступен в тестах (нет активного события),
        // поэтому ожидаем либо nil, либо валидный DTO.
        let result = await sut.loadActivePack()
        // Просто убеждаемся что не крашит
        _ = result
    }

    // MARK: - SeasonalPackDTO декодирование

    func test_seasonalPackDTO_decodesFromValidJSON() throws {
        let json = """
        {
            "id": "halloween_2024",
            "soundTarget": "Ш",
            "group": "sibilants",
            "version": 1,
            "description": "Хэллоуин",
            "season": "autumn",
            "active_months": [10, 11]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let pack = try decoder.decode(SeasonalPackDTO.self, from: json)

        XCTAssertEqual(pack.id, "halloween_2024")
        XCTAssertEqual(pack.soundTarget, "Ш")
        XCTAssertEqual(pack.group, "sibilants")
        XCTAssertEqual(pack.version, 1)
        XCTAssertEqual(pack.season, "autumn")
        XCTAssertEqual(pack.activeMonths, [10, 11])
    }

    func test_seasonalPackDTO_activeMonthsDecodedFromSnakeCase() throws {
        let json = """
        {
            "id": "new_year",
            "soundTarget": "С",
            "group": "whistling",
            "version": 2,
            "description": "Новый год",
            "season": "winter",
            "active_months": [12, 1]
        }
        """.data(using: .utf8)!

        let pack = try JSONDecoder().decode(SeasonalPackDTO.self, from: json)
        XCTAssertEqual(pack.activeMonths, [12, 1],
                       "active_months должен декодироваться через CodingKeys")
    }

    func test_seasonalPackDTO_throwsOnMissingRequiredField() {
        let json = """
        {
            "id": "broken_pack",
            "soundTarget": "С"
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(
            try JSONDecoder().decode(SeasonalPackDTO.self, from: json),
            "Декодирование должно падать при отсутствии обязательных полей"
        )
    }
}
