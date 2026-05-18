import Foundation

/// Роль родителя в семейном профиле.
public enum ParentRole: String, Sendable, CaseIterable {
    /// Основной родитель — создатель семьи, имеет полный доступ.
    case primary
    /// Второй родитель / опекун — доступ к чтению прогресса и просмотру сессий.
    case secondary
    /// Приглашённый наблюдатель — только чтение прогресса (бабушки/дедушки).
    case observer
}
