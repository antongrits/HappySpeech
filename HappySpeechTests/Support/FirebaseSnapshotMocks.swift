import Foundation

// MARK: - FirebaseSnapshotMocks
//
// Plan v22 Block 4.4 — Mock-объекты для Firebase Firestore snapshot тестирования.
//
// Используются в интеграционных тестах для имитации Firestore snapshot callbacks
// без зависимости от Firebase SDK. Позволяют тестировать Sync-слой и репозитории
// в изоляции от реального облака.
//
// Типы в этом файле не конфликтуют с Firebase SDK — у них другие имена.

// MARK: - MockFirestoreSnapshot

/// Имитирует DocumentSnapshot из Firebase Firestore.
/// Хранит произвольный [String: Any] payload и предоставляет
/// тот же API доступа к данным что реальный DocumentSnapshot.
public final class MockFirestoreSnapshot: @unchecked Sendable {

    public let documentID: String
    private let data: [String: Any]

    /// Создаёт snapshot с заданным ID и полезными данными.
    /// - Parameters:
    ///   - id: Идентификатор документа (по умолчанию UUID).
    ///   - data: Словарь полей документа.
    public init(id: String = UUID().uuidString, data: [String: Any]) {
        self.documentID = id
        self.data = data
    }

    /// Возвращает значение поля по ключу.
    public func get(_ key: String) -> Any? { data[key] }

    /// Проверяет наличие поля в документе.
    public func contains(_ key: String) -> Bool { data[key] != nil }

    /// Возвращает все данные документа.
    public func allData() -> [String: Any] { data }

    /// Проверяет что snapshot не пустой.
    public var exists: Bool { !data.isEmpty }
}

// MARK: - MockQuerySnapshot

/// Имитирует QuerySnapshot из Firebase Firestore.
/// Содержит набор документов с аналогичным API доступа.
public final class MockQuerySnapshot: @unchecked Sendable {

    public let documents: [MockFirestoreSnapshot]

    /// Создаёт снимок коллекции.
    /// - Parameter documents: Массив документов в коллекции.
    public init(documents: [MockFirestoreSnapshot]) {
        self.documents = documents
    }

    /// Количество документов в снимке.
    public var count: Int { documents.count }

    /// Проверяет что коллекция пустая.
    public var isEmpty: Bool { documents.isEmpty }

    /// Возвращает документ по индексу (nil если out-of-bounds).
    public subscript(index: Int) -> MockFirestoreSnapshot? {
        guard index >= 0 && index < documents.count else { return nil }
        return documents[index]
    }
}

// MARK: - MockListenerRegistration

/// Имитирует ListenerRegistration из Firebase Firestore.
/// Позволяет тестировать жизненный цикл snapshot listeners.
public final class MockListenerRegistration: @unchecked Sendable {

    private let cancelClosure: () -> Void
    public private(set) var isRemoved: Bool = false

    /// Создаёт регистрацию с колбэком отмены.
    /// - Parameter cancel: Вызывается при remove().
    public init(cancel: @escaping () -> Void = {}) {
        self.cancelClosure = cancel
    }

    /// Отменяет подписку. Идемпотентен — повторные вызовы безопасны.
    public func remove() {
        guard !isRemoved else { return }
        isRemoved = true
        cancelClosure()
    }
}

// MARK: - FirestoreSnapshotTestBuilders

/// Удобные фабрики для создания тестовых Firestore snapshot данных.
public enum FirestoreSnapshotTestBuilders {

    /// Создаёт snapshot профиля ребёнка.
    public static func childProfileSnapshot(
        id: String = "child-001",
        name: String = "Маша",
        age: Int = 6,
        parentId: String = "parent-001",
        targetSounds: [String] = ["Р", "Ш"]
    ) -> MockFirestoreSnapshot {
        MockFirestoreSnapshot(
            id: id,
            data: [
                "name": name,
                "age": age,
                "parentId": parentId,
                "targetSounds": targetSounds,
                "currentStreak": 0,
                "totalSessionMinutes": 0,
                "createdAt": Date().timeIntervalSince1970
            ]
        )
    }

    /// Создаёт snapshot сессии.
    public static func sessionSnapshot(
        id: String = "session-001",
        childId: String = "child-001",
        targetSound: String = "Р",
        correctAttempts: Int = 8,
        totalAttempts: Int = 10
    ) -> MockFirestoreSnapshot {
        MockFirestoreSnapshot(
            id: id,
            data: [
                "childId": childId,
                "targetSound": targetSound,
                "correctAttempts": correctAttempts,
                "totalAttempts": totalAttempts,
                "durationSeconds": 180,
                "stage": "wordInit",
                "isSynced": false,
                "date": Date().timeIntervalSince1970
            ]
        )
    }

    /// Создаёт пустую коллекцию.
    public static func emptyCollection() -> MockQuerySnapshot {
        MockQuerySnapshot(documents: [])
    }

    /// Создаёт коллекцию профилей детей.
    public static func childrenCollection(count: Int = 3) -> MockQuerySnapshot {
        let docs = (0..<count).map { i in
            childProfileSnapshot(id: "child-\(String(format: "%03d", i))", name: "Ребёнок \(i)")
        }
        return MockQuerySnapshot(documents: docs)
    }
}
