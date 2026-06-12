@testable import HappySpeech
import XCTest

// MARK: - OnboardingChildProvisionerTests
//
// Покрывает gap-фикс: фреш-онбординг должен создавать РЕАЛЬНЫЙ ChildProfile в
// Realm и помечать его активным. Тесты используют MockChildRepository (in-memory)
// и проверяют маппинг данных профиля, идемпотентность и резолюцию parentId.

@MainActor
final class OnboardingChildProvisionerTests: XCTestCase {

    private var repository: MockChildRepository!
    private var activeChildId: String?

    override func setUp() async throws {
        try await super.setUp()
        // Пустой репозиторий — имитируем фреш-установку (детей ещё нет).
        repository = MockChildRepository(children: [])
        activeChildId = nil
        SpeechDisorderStore.clear(childId: "")
    }

    override func tearDown() async throws {
        repository = nil
        activeChildId = nil
        try await super.tearDown()
    }

    private func makeSUT(authUser: AuthUser? = nil) -> LiveOnboardingChildProvisioner {
        let auth = MockAuthService(initialUser: authUser)
        return LiveOnboardingChildProvisioner(
            childRepository: repository,
            authService: auth,
            setActiveChild: { [weak self] id in self?.activeChildId = id }
        )
    }

    private func parentProfile(
        name: String = "Маша",
        age: Int = 6,
        sounds: Set<String> = ["R", "Sh"],
        disorder: SpeechDisorder = .ffn,
        preset: LyalyaPreset = .ocean
    ) -> OnboardingProfile {
        OnboardingProfile(
            role: .parent,
            childName: name,
            childAge: age,
            childAvatar: "word_fox",
            childGender: .girl,
            difficultSounds: sounds,
            disorder: disorder,
            privacyAccepted: true,
            lyalyaPreset: preset
        )
    }

    // MARK: - Happy path

    func test_provision_createsRealChildProfile() async throws {
        let sut = makeSUT()
        let id = await sut.provisionChild(from: parentProfile())

        let savedId = try XCTUnwrap(id)
        let all = try await repository.fetchAll()
        XCTAssertEqual(all.count, 1, "Должен появиться ровно один реальный профиль")
        XCTAssertEqual(all.first?.id, savedId)
        XCTAssertEqual(all.first?.name, "Маша")
        XCTAssertEqual(all.first?.age, 6)
    }

    func test_provision_marksChildActive() async throws {
        let sut = makeSUT()
        let id = await sut.provisionChild(from: parentProfile())
        XCTAssertEqual(activeChildId, id, "Созданный ребёнок должен стать активным")
    }

    func test_provision_mapsSoundIdsToCyrillic() async throws {
        let sut = makeSUT()
        _ = await sut.provisionChild(from: parentProfile(sounds: ["R", "Sh"]))
        let saved = try await repository.fetchAll().first
        // Онбординг хранит "R"/"Sh"; контентный слой ждёт кириллицу "Р"/"Ш".
        XCTAssertEqual(saved?.targetSounds, ["Р", "Ш"])
    }

    func test_provision_dropsUnknownSoundIds() async throws {
        let sut = makeSUT()
        _ = await sut.provisionChild(from: parentProfile(sounds: ["R", "BOGUS"]))
        let saved = try await repository.fetchAll().first
        XCTAssertEqual(saved?.targetSounds, ["Р"], "Неизвестный id отбрасывается, мусор не пишется")
    }

    func test_provision_persistsDisorderForCreatedChild() async throws {
        let sut = makeSUT()
        let id = try XCTUnwrap(await sut.provisionChild(from: parentProfile(disorder: .ffn)))
        XCTAssertEqual(SpeechDisorderStore.load(childId: id), .ffn)
        SpeechDisorderStore.clear(childId: id)
    }

    func test_provision_mapsLyalyaPresetToColorTheme() async throws {
        let sut = makeSUT()
        _ = await sut.provisionChild(from: parentProfile(preset: .forest))
        let saved = try await repository.fetchAll().first
        XCTAssertEqual(saved?.colorTheme, "green")
    }

    // MARK: - Role gating

    func test_provision_specialistRoleCreatesNoChild() async throws {
        var profile = parentProfile()
        profile.role = .specialist
        let sut = makeSUT()
        let id = await sut.provisionChild(from: profile)
        XCTAssertNil(id)
        let all = try await repository.fetchAll()
        XCTAssertTrue(all.isEmpty, "Специалист не создаёт собственного ребёнка")
    }

    func test_provision_childRoleCreatesChild() async throws {
        var profile = parentProfile()
        profile.role = .child
        let sut = makeSUT()
        let id = await sut.provisionChild(from: profile)
        XCTAssertNotNil(id)
        XCTAssertEqual(try await repository.fetchAll().count, 1)
    }

    // MARK: - Guard clauses

    func test_provision_emptyNameCreatesNoChild() async throws {
        let sut = makeSUT()
        let id = await sut.provisionChild(from: parentProfile(name: " "))
        XCTAssertNil(id)
        XCTAssertTrue(try await repository.fetchAll().isEmpty)
    }

    // MARK: - Idempotency

    func test_provision_isIdempotent_noDuplicateOnReplay() async throws {
        let sut = makeSUT()
        let firstId = try XCTUnwrap(await sut.provisionChild(from: parentProfile()))
        let secondId = try XCTUnwrap(await sut.provisionChild(from: parentProfile()))
        XCTAssertEqual(firstId, secondId, "Повтор онбординга не плодит дубликаты")
        XCTAssertEqual(try await repository.fetchAll().count, 1)
    }

    // MARK: - parentId resolution

    func test_provision_usesAuthUidWhenSignedIn() async throws {
        let sut = makeSUT(authUser: AuthUser(uid: "parent-uid-42", isAnonymous: false))
        _ = await sut.provisionChild(from: parentProfile())
        XCTAssertEqual(try await repository.fetchAll().first?.parentId, "parent-uid-42")
    }

    func test_provision_usesLocalParentWhenAnonymous() async throws {
        let sut = makeSUT(authUser: AuthUser(uid: "anon", isAnonymous: true))
        _ = await sut.provisionChild(from: parentProfile())
        XCTAssertEqual(try await repository.fetchAll().first?.parentId, "local-parent")
    }

    func test_provision_usesLocalParentWhenNoAuth() async throws {
        let sut = makeSUT(authUser: nil)
        _ = await sut.provisionChild(from: parentProfile())
        XCTAssertEqual(try await repository.fetchAll().first?.parentId, "local-parent")
    }
}
