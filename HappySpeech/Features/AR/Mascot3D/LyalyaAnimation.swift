import SwiftUI

// MARK: - LyalyaAnimation

/// Состояния анимации маскота Ляли для AR-контура (`ARZone`).
///
/// `LyalyaAnimation` — компактный набор состояний, которыми оперирует
/// `ARZonePresenter` / `ARZoneView`. Маппируется в ``LyalyaState`` для
/// рендера через ``LyalyaMascotView`` (3D-модель + 2D-fallback,
/// см. ADR-V29-MASCOT-3D).
public enum LyalyaAnimation: String, CaseIterable, Sendable {
    case idle
    case waving
    case celebrating
    case thinking
    case pointing
    case sad

    /// Маппинг в ``LyalyaState`` для рендера маскота.
    var lyalyaState: LyalyaState {
        switch self {
        case .idle:        return .idle
        case .waving:      return .waving
        case .celebrating: return .celebrating
        case .thinking:    return .thinking
        case .pointing:    return .pointing
        case .sad:         return .sad
        }
    }
}
