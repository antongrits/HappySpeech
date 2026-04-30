import Foundation
import Observation

// MARK: - MascotEyeContactState

/// Shared @Observable state — реакция маскота Ляли на зрительный контакт ребёнка.
///
/// Поток данных:
///   ARFaceAnchor → EyeFocusWorker → ARMirrorView → MascotEyeContactState → LyalyaMascotView
///
/// Thread safety: @MainActor. Весь доступ — только из MainActor-контекста.
/// Распространяется через Environment: `.environment(\.mascotEyeContactState, state)`.
@MainActor
@Observable
public final class MascotEyeContactState {

    // MARK: - State

    /// true = ребёнок смотрит в камеру (isLookingAtCamera из EyeFocusObservation).
    /// Маскот реагирует: моргает + поднимает mood.
    public private(set) var isEyeContact: Bool = false

    /// Скользящее среднее внимания 0...1 за последние ~2 сек.
    /// Используется AR-играми для адаптации сложности заданий.
    public private(set) var attentionScore: Float = 0.0

    /// Время последнего момента eye contact (для расчёта паузы без внимания).
    public private(set) var lastEyeContactDate: Date?

    /// Секунд прошло с последнего eye contact. nil если контакт был никогда.
    public var secondsSinceLastEyeContact: TimeInterval? {
        guard let last = lastEyeContactDate else { return nil }
        return Date().timeIntervalSince(last)
    }

    // MARK: - Init

    public init() {}

    // MARK: - Update

    /// Вызывается из ARMirrorView после каждого кадра EyeFocusWorker.
    public func update(isLookingAtCamera: Bool, attention: Float) {
        attentionScore = attention
        if isLookingAtCamera {
            if !isEyeContact {
                // Начало нового eye contact — обновляем время
                lastEyeContactDate = Date()
            }
            isEyeContact = true
        } else {
            isEyeContact = false
        }
    }

    /// Сброс при завершении AR-сессии или смене игры.
    public func reset() {
        isEyeContact = false
        attentionScore = 0.0
        lastEyeContactDate = nil
    }
}

// MARK: - EnvironmentKey

import SwiftUI

// Swift 6 concurrency: тот же паттерн что и MascotLipSyncStateKey.
// MascotEyeContactState изолирован на @MainActor, но EnvironmentKey.defaultValue
// требует nonisolated static. Используем MainActor.assumeIsolated — безопасно,
// т.к. SwiftUI строит View-дерево на MainActor.
private struct MascotEyeContactStateKey: EnvironmentKey {
    static let defaultValue: MascotEyeContactState = {
        MainActor.assumeIsolated {
            MascotEyeContactState()
        }
    }()
}

public extension EnvironmentValues {
    var mascotEyeContactState: MascotEyeContactState {
        get { self[MascotEyeContactStateKey.self] }
        set { self[MascotEyeContactStateKey.self] = newValue }
    }
}
