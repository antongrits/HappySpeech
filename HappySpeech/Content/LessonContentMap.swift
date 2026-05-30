import Foundation
import OSLog

// MARK: - LessonContentMap

/// Centralized russian-word → asset name mapping for all lesson presenters.
///
/// Backed by `word_manifest.json` bundled at the app level (see
/// `HappySpeech/Content/word_manifest.json`). Lazy-loaded once on first
/// access and cached for the process lifetime.
///
/// Use this from any lesson Presenter / Interactor / Models that needs to
/// resolve a russian word to an asset image name. The asset name is then
/// passed to `HSContentSymbol(name:)`, which routes between SF Symbol and
/// `Assets.xcassets/Illustrations/word_*.imageset`.
///
/// ## Usage
/// ```swift
/// if let asset = LessonContentMap.asset(for: "корова") {
///     HSContentSymbol(asset, size: 64)
/// }
/// ```
///
/// ## Thread-safety
/// All accessors are read-only and call into immutable `let` storage. Safe
/// to call from any actor. The internal cache is built once via a `let`
/// initializer; subsequent reads are lock-free.
///
/// ## Manifest lifecycle (snapshot semantics)
/// The manifest JSON is bundled into the .app at archive time and read **once**
/// on first access from any thread; the resulting `entries` slice is frozen for
/// the entire process lifetime. This is intentional:
///
/// - The asset pipeline (Imagen / FLUX background processes) may keep extending
///   `word_manifest.json` on the developer's filesystem AFTER an app build is
///   archived; those additions become visible only in the NEXT build.
/// - There is no runtime "reload" path because the manifest entries reference
///   imagesets that are baked into `Assets.xcassets` at compile time — a new
///   manifest entry without its matching imageset would yield broken assets at
///   runtime anyway.
///
/// To pick up new words: rebuild the app. There is no hot-reload trigger.
public enum LessonContentMap {

    // MARK: - Public Types

    /// One word ↔ asset entry from the manifest.
    public struct Entry: Sendable, Decodable {
        public let word: String
        public let asset: String
        public let recommendedStages: [String]
        public let visualComplexity: String
        public let semanticCategory: String
        public let methodologySource: String?
        public let soundFamily: String?
    }

    // MARK: - Manifest envelope

    private struct Manifest: Decodable {
        let version: Int
        let words: [Entry]
    }

    // MARK: - Storage

    /// All loaded entries (lazy, read once from bundle).
    /// Immutable `let` initialized via a synchronous closure run on first
    /// access; the value is never mutated thereafter.
    private static let entries: [Entry] = loadEntries()

    /// Lowercased word → asset name lookup.
    private static let assetByWord: [String: String] = {
        Dictionary(
            entries.map { ($0.word.lowercased(), $0.asset) },
            uniquingKeysWith: { first, _ in first }
        )
    }()

    // MARK: - Loader

    private static func loadEntries() -> [Entry] {
        guard let url = Bundle.main.url(
            forResource: "word_manifest",
            withExtension: "json"
        ) else {
            HSLogger.content.error("LessonContentMap: word_manifest.json not in bundle")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let manifest = try JSONDecoder().decode(Manifest.self, from: data)
            HSLogger.content.info("LessonContentMap: loaded \(manifest.words.count) entries (v\(manifest.version))")
            return manifest.words
        } catch {
            HSLogger.content.error("LessonContentMap: decode failure — \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Public API

    /// Returns the asset name (e.g. `"word_cow"`) for the given russian word,
    /// or `nil` if the word is not in the manifest. Case-insensitive.
    ///
    /// Tolerant of pipe-encoded `imageAsset` values from differentiation packs
    /// (e.g. `"word_rak|word_lak"`): the first (target) component is returned.
    public static func asset(for word: String) -> String? {
        if word.contains("|") {
            return assetPair(from: word)?.target
        }
        return assetByWord[word.lowercased()]
    }

    /// Splits a pipe-encoded `imageAsset` field from a content pack item into
    /// its two illustration names — the target word and the distractor.
    ///
    /// Picture-minimal-pairs items in the differentiation packs encode both
    /// images directly as asset names separated by `|`, e.g.
    /// `"word_rak|word_lak"` → (`"word_rak"`, `"word_lak"`). The values are
    /// already asset names (not russian words), so they are passed straight to
    /// `HSContentSymbol` without a manifest lookup.
    ///
    /// Returns `nil` if the field does not contain a `|` separator (i.e. it is a
    /// single-image item and the caller should use `asset(for:)` instead).
    public static func assetPair(from imageAsset: String) -> (target: String, distractor: String)? {
        let parts = imageAsset
            .split(separator: "|", maxSplits: 1, omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return nil }
        return (parts[0], parts[1])
    }

    /// Returns the full manifest entry for the given russian word, or `nil`.
    public static func entry(for word: String) -> Entry? {
        let key = word.lowercased()
        return entries.first { $0.word.lowercased() == key }
    }

    /// All entries whose `recommendedStages` contains the given stage
    /// (e.g. `"wordInit"`, `"wordMid"`).
    public static func words(stage: String) -> [Entry] {
        entries.filter { $0.recommendedStages.contains(stage) }
    }

    /// All entries belonging to the given sound family
    /// (e.g. `"Р"`, `"С"`, `"Ш"`).
    public static func words(soundFamily: String) -> [Entry] {
        entries.filter { $0.soundFamily == soundFamily }
    }

    /// Total number of entries available (useful for diagnostics).
    public static var count: Int { entries.count }
}
