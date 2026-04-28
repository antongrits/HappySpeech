import Foundation
import RealmSwift

// MARK: - CustomizationObject

/// Realm-объект для хранения кастомизации Ляли.
/// Primary key: "local" — один объект на всё приложение.
/// Realm schema version 4 — добавлена миграция в RealmMigrations.swift.
final class CustomizationObject: Object, @unchecked Sendable {
    @Persisted(primaryKey: true) var id: String = "local"
    @Persisted var skin: String = LyalyaSkin.classic.rawValue
    @Persisted var colorVariant: String = LyalyaColorVariant.warm.rawValue
    @Persisted var voice: String = LyalyaVoice.classic.rawValue
    @Persisted var updatedAt: Date = Date()
}

// MARK: - CustomizationDTO (Sendable snapshot)

/// Sendable DTO для безопасного пересечения actor-границ.
struct CustomizationDTO: Sendable {
    let skin: String
    let colorVariant: String
    let voice: String
    let updatedAt: Date

    init(object: CustomizationObject) {
        self.skin = object.skin
        self.colorVariant = object.colorVariant
        self.voice = object.voice
        self.updatedAt = object.updatedAt
    }

    init(skin: String, colorVariant: String, voice: String, updatedAt: Date = Date()) {
        self.skin = skin
        self.colorVariant = colorVariant
        self.voice = voice
        self.updatedAt = updatedAt
    }

    var skinEnum: LyalyaSkin { LyalyaSkin(rawValue: skin) ?? .classic }
    var colorEnum: LyalyaColorVariant { LyalyaColorVariant(rawValue: colorVariant) ?? .warm }
    var voiceEnum: LyalyaVoice { LyalyaVoice(rawValue: voice) ?? .classic }
}
