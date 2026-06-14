import SwiftUI

// MARK: - SoundAccuracy

/// Data point for sound/session accuracy charts. Consumed by the Specialist
/// SessionReview phoneme chart and family comparison visualisations.
public struct SoundAccuracy: Identifiable, Sendable, Equatable {
    public let id: String
    public let label: String
    public let value: Double
    public let color: Color

    public init(id: String, label: String, value: Double, color: Color) {
        self.id = id
        self.label = label
        self.value = value
        self.color = color
    }
}
