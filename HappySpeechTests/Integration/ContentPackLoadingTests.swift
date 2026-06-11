@testable import HappySpeech
import XCTest

// MARK: - ContentPackLoadingTests
//
// Verifies that the 11 content packs added in Sprint 12 (489 exercises) are
// actually wired into `LiveContentService`:
//   • each new pack id resolves to its bundled JSON file via the registry;
//   • `loadPack(id:)` returns a non-empty `ContentPack` with the expected
//     number of items;
//   • `allPacks()` (the lesson catalog) surfaces every new pack;
//   • the pipe-encoded `imageAsset` field of picture-minimal-pairs items is
//     split into two illustration names by `LessonContentMap.assetPair`.
//
// Runs against the app bundle (TEST_HOST), so the real seed JSON is read.

final class ContentPackLoadingTests: XCTestCase {

    private var service: LiveContentService!

    override func setUp() {
        super.setUp()
        service = LiveContentService()
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    // MARK: - Expected inventory (matches Content/Seed/*.json)

    /// Pack id → expected total items across all stages.
    private static let expectedItemCount: [String: Int] = [
        "sound_cfocus_v1": 69,
        "sound_shchfocus_v1": 45,
        "sound_rsoft_v1": 49,
        "sound_lsoft_v1": 49,
        "sound_velars_v1": 59,
        "sound_yfocus_v1": 41,
        "sound_rclusters_v1": 53,
        "pack_diff_s_sh_v1": 32,
        "pack_diff_r_l_v1": 33,
        "pack_diff_paronyms_v1": 27,
        "pack_diff_voicing_v1": 30
    ]

    private static let totalExpectedExercises = 487

    // MARK: - 1. Every new pack loads with the expected item count

    func test_allElevenNewPacks_load() async throws {
        var loadedTotal = 0
        for (id, expected) in Self.expectedItemCount {
            let pack = try await service.loadPack(id: id)
            XCTAssertFalse(pack.items.isEmpty, "Pack \(id) loaded empty")
            XCTAssertEqual(
                pack.items.count, expected,
                "Pack \(id): expected \(expected) items, got \(pack.items.count)"
            )
            loadedTotal += pack.items.count
        }
        XCTAssertEqual(
            loadedTotal, Self.totalExpectedExercises,
            "All 11 new packs should sum to 487 exercises"
        )
    }

    // MARK: - 2. fileName resolution via the explicit registry

    func test_fileNameResolution_usesRegistryForNewPacks() {
        XCTAssertEqual(LiveContentService.fileName(for: "pack_diff_s_sh_v1"), "pack_diff_s_sh_pack")
        XCTAssertEqual(LiveContentService.fileName(for: "pack_diff_voicing_v1"), "pack_diff_voicing_pack")
        XCTAssertEqual(LiveContentService.fileName(for: "sound_cfocus_v1"), "sound_cfocus_pack")
        XCTAssertEqual(LiveContentService.fileName(for: "sound_velars_v1"), "sound_velars_pack")
    }

    func test_fileNameResolution_legacyPacksUnchanged() {
        XCTAssertEqual(LiveContentService.fileName(for: "sound_s_v1"), "sound_s_pack")
        XCTAssertEqual(LiveContentService.fileName(for: "sound_sh_v1"), "sound_sh_pack")
        XCTAssertEqual(LiveContentService.fileName(for: "sound_r_v1"), "sound_r_pack")
        XCTAssertEqual(LiveContentService.fileName(for: "sound_l_v1"), "sound_l_pack")
        XCTAssertEqual(LiveContentService.fileName(for: "sound_k_v1"), "sound_k_pack")
    }

    // MARK: - 3. The 5 legacy packs still load (no regression)

    func test_legacyPacks_stillLoad() async throws {
        for id in ["sound_s_v1", "sound_sh_v1", "sound_r_v1", "sound_l_v1", "sound_k_v1"] {
            let pack = try await service.loadPack(id: id)
            XCTAssertFalse(pack.items.isEmpty, "Legacy pack \(id) regressed (empty)")
        }
    }

    // MARK: - 4. Lesson catalog (allPacks) surfaces every new pack

    func test_allPacks_includesNewPacks() async throws {
        let metas = try await service.allPacks()
        let ids = Set(metas.map(\.id))
        for id in Self.expectedItemCount.keys {
            XCTAssertTrue(ids.contains(id), "allPacks() catalog missing \(id)")
        }
        // Legacy packs must remain in the catalog too.
        for id in ["sound_s_v1", "sound_sh_v1", "sound_r_v1", "sound_l_v1", "sound_k_v1"] {
            XCTAssertTrue(ids.contains(id), "allPacks() catalog lost legacy \(id)")
        }
    }

    func test_allPacks_metaHasBundledFlagAndSize() async throws {
        let metas = try await service.allPacks()
        for meta in metas where Self.expectedItemCount.keys.contains(meta.id) {
            XCTAssertTrue(meta.isBundled, "\(meta.id) should be bundled")
            XCTAssertGreaterThan(meta.sizeBytes, 0, "\(meta.id) size should be > 0")
            XCTAssertFalse(meta.soundTarget.isEmpty, "\(meta.id) soundTarget should be set")
        }
    }

    // MARK: - 5. Pipe-encoded imageAsset split (picture-minimal-pairs)

    func test_imageAssetPipeSplit_producesTwoIllustrations() {
        let pair = LessonContentMap.assetPair(from: "word_rak|word_lak")
        XCTAssertEqual(pair?.target, "word_rak")
        XCTAssertEqual(pair?.distractor, "word_lak")
    }

    func test_imageAssetPipeSplit_trimsWhitespace() {
        let pair = LessonContentMap.assetPair(from: " word_krysa | word_krysha ")
        XCTAssertEqual(pair?.target, "word_krysa")
        XCTAssertEqual(pair?.distractor, "word_krysha")
    }

    func test_imageAssetPipeSplit_returnsNilForSingleImage() {
        XCTAssertNil(LessonContentMap.assetPair(from: "word_sova"))
    }

    func test_asset_forPipeEncoded_returnsTargetComponent() {
        XCTAssertEqual(LessonContentMap.asset(for: "word_nos|word_nozh"), "word_nos")
    }

    // MARK: - 6. Differentiation packs really contain pipe-encoded items

    func test_diffPacks_containPipeEncodedImageAssets() async throws {
        let pack = try await service.loadPack(id: "pack_diff_s_sh_v1")
        let pipeItems = pack.items.filter { ($0.imageAsset ?? "").contains("|") }
        XCTAssertFalse(
            pipeItems.isEmpty,
            "pack_diff_s_sh_v1 should contain picture-minimal-pairs items with two illustrations"
        )
        for item in pipeItems {
            let pair = LessonContentMap.assetPair(from: item.imageAsset ?? "")
            XCTAssertNotNil(pair, "imageAsset \(item.imageAsset ?? "") should split into two assets")
        }
    }
}
