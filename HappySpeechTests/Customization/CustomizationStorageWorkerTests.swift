@testable import HappySpeech
import RealmSwift
import XCTest

// MARK: - CustomizationStorageWorkerTests
//
// CustomizationStorageWorker зависит от RealmActor (нет протокола — нельзя полностью замокать).
// Тестируем:
//   1. syncToCloud — чистая логика (анонимный/аутентифицированный пользователь).
//   2. fetchAndMergeFromCloud — чистая логика (пропускает анонима).
//   3. CustomizationDTO — вычисляемые свойства skinEnum/colorEnum/voiceEnum.
//   4. load/saveLocal — через in-memory Realm.

// MARK: - CustomizationDTO unit-тесты (не требуют Realm)

final class CustomizationDTOTests: XCTestCase {

    func test_skinEnum_returnsClassicForDefaultRawValue() {
        let dto = CustomizationDTO(
            skin: LyalyaSkin.classic.rawValue,
            colorVariant: LyalyaColorVariant.warm.rawValue,
            voice: LyalyaVoice.classic.rawValue
        )
        XCTAssertEqual(dto.skinEnum, .classic)
    }

    func test_colorEnum_returnsCorrectVariant() {
        let dto = CustomizationDTO(
            skin: "classic",
            colorVariant: LyalyaColorVariant.cool.rawValue,
            voice: "classic"
        )
        XCTAssertEqual(dto.colorEnum, .cool)
    }

    func test_voiceEnum_returnsCorrectVoice() {
        let dto = CustomizationDTO(skin: "classic", colorVariant: "warm", voice: LyalyaVoice.soft.rawValue)
        XCTAssertEqual(dto.voiceEnum, .soft)
    }

    func test_voiceEnum_fallsBackToClassicForInvalidRawValue() {
        let dto = CustomizationDTO(skin: "classic", colorVariant: "warm", voice: "unknown_voice")
        XCTAssertEqual(dto.voiceEnum, .classic,
                       "Неизвестное rawValue для голоса должно давать .classic")
    }

    func test_skinEnum_fallsBackToClassicForUnknownRawValue() {
        let dto = CustomizationDTO(skin: "nonexistent_skin", colorVariant: "warm", voice: "classic")
        XCTAssertEqual(dto.skinEnum, .classic)
    }

    func test_colorEnum_fallsBackToWarmForUnknownRawValue() {
        let dto = CustomizationDTO(skin: "classic", colorVariant: "bad_color", voice: "classic")
        XCTAssertEqual(dto.colorEnum, .warm)
    }

    func test_dto_equatableFields() {
        let date = Date(timeIntervalSince1970: 1000)
        let dto1 = CustomizationDTO(skin: "classic", colorVariant: "warm", voice: "soft", updatedAt: date)
        let dto2 = CustomizationDTO(skin: "classic", colorVariant: "warm", voice: "soft", updatedAt: date)
        XCTAssertEqual(dto1.skin, dto2.skin)
        XCTAssertEqual(dto1.colorVariant, dto2.colorVariant)
        XCTAssertEqual(dto1.voice, dto2.voice)
    }
}

// MARK: - CustomizationStorageWorker.syncToCloud (логика анонимного пользователя)
//
// syncToCloud: чистая логика без RealmActor — результат определяется только authService.

final class CustomizationStorageWorkerSyncTests: XCTestCase {

    private func makeWorkerAndRealm(authService: any AuthService) async throws
        -> CustomizationStorageWorker
    {
        var config = Realm.Configuration()
        config.inMemoryIdentifier = "customization-test-\(UUID().uuidString)"
        let realm = RealmActor()
        try await realm.open(configuration: config)
        return CustomizationStorageWorker(realmActor: realm, authService: authService)
    }

    // MARK: - syncToCloud: анонимный пользователь → false

    func test_syncToCloud_anonymousUser_returnsFalse() async throws {
        let authService = SpyAuthService()
        authService.stubbedUser = TestDataBuilder.authUser(isAnonymous: true)
        let sut = try await makeWorkerAndRealm(authService: authService)
        let dto = CustomizationDTO(skin: "classic", colorVariant: "warm", voice: "classic")

        let result = await sut.syncToCloud(dto: dto)

        XCTAssertFalse(result,
                       "Для анонимного пользователя syncToCloud должен возвращать false")
    }

    // MARK: - syncToCloud: nil пользователь → false

    func test_syncToCloud_nilUser_returnsFalse() async throws {
        let authService = SpyAuthService()
        authService.stubbedUser = nil
        let sut = try await makeWorkerAndRealm(authService: authService)
        let dto = CustomizationDTO(skin: "classic", colorVariant: "warm", voice: "classic")

        let result = await sut.syncToCloud(dto: dto)

        XCTAssertFalse(result,
                       "При отсутствии пользователя syncToCloud должен возвращать false")
    }

    // MARK: - syncToCloud: аутентифицированный пользователь → Firestore hook (pending F2-010)
    // Текущая реализация: хук не подключён, возвращает false.
    // Тест документирует ожидаемое поведение при заглушке.

    func test_syncToCloud_authenticatedUser_returnsFalseUntilF2010() async throws {
        let authService = SpyAuthService()
        authService.stubbedUser = TestDataBuilder.authUser(isAnonymous: false)
        let sut = try await makeWorkerAndRealm(authService: authService)
        let dto = CustomizationDTO(skin: "fox", colorVariant: "cool", voice: "soft")

        let result = await sut.syncToCloud(dto: dto)

        // Пока Firestore хук не реализован (F2-010), метод возвращает false.
        // Когда F2-010 будет закрыт — тест изменится на true.
        XCTAssertFalse(result,
                       "Firestore sync hook ещё не реализован (F2-010) — ожидается false")
    }

    // MARK: - fetchAndMergeFromCloud: не крашит для анонима

    func test_fetchAndMergeFromCloud_anonymousUser_doesNotCrash() async throws {
        let authService = SpyAuthService()
        authService.stubbedUser = TestDataBuilder.authUser(isAnonymous: true)
        let sut = try await makeWorkerAndRealm(authService: authService)

        await sut.fetchAndMergeFromCloud()
        // Если не крашит — тест пройден
    }

    // MARK: - load: возвращает дефолт при пустом Realm

    func test_load_returnsDefaultDTOWhenRealmEmpty() async throws {
        let authService = SpyAuthService()
        let sut = try await makeWorkerAndRealm(authService: authService)

        let dto = await sut.load()

        XCTAssertEqual(dto.skin, LyalyaSkin.classic.rawValue,
                       "По умолчанию skin должен быть classic")
        XCTAssertEqual(dto.colorVariant, LyalyaColorVariant.warm.rawValue,
                       "По умолчанию colorVariant должен быть warm")
        XCTAssertEqual(dto.voice, LyalyaVoice.classic.rawValue,
                       "По умолчанию voice должен быть classic")
    }

    // MARK: - saveLocal + load: round-trip

    func test_saveLocalAndLoad_roundTrip() async throws {
        let authService = SpyAuthService()
        let sut = try await makeWorkerAndRealm(authService: authService)
        let dto = CustomizationDTO(skin: "fox", colorVariant: "cool", voice: "soft")

        try await sut.saveLocal(dto: dto)
        let loaded = await sut.load()

        XCTAssertEqual(loaded.skin, "fox")
        XCTAssertEqual(loaded.colorVariant, "cool")
        XCTAssertEqual(loaded.voice, "soft")
    }
}
