import Foundation
import RealmSwift

// MARK: - FamilyRecordingObject

/// Realm-объект для хранения семейных голосовых записей.
/// Максимум 20 записей на профиль родителя — проверяется в FamilyVoiceInteractor.
/// Realm schema version 5 — добавлена миграция в RealmMigrations.swift.
final class FamilyRecordingObject: Object, @unchecked Sendable {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var word: String = ""
    /// Относительный путь к .m4a файлу внутри Documents/family_recordings/.
    @Persisted var audioFilePath: String = ""
    @Persisted var recordedAt: Date = Date()
    @Persisted var durationSeconds: Double = 0
    @Persisted var parentProfileId: String = ""
}
