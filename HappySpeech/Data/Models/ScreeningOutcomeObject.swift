import Foundation
import RealmSwift

// MARK: - ScreeningOutcomeObject
//
// Persisted screening verdict for a child. Created once per screening pass
// (initial onboarding + every re-screening in 2–4 weeks). Used by:
//   • ParentHome — для отображения текущего среза по звукам.
//   • AdaptivePlannerService — как опорный сигнал для дневного маршрута.
//   • SpecialistExportService — как часть PDF/CSV отчёта.
//
// Поле `overallSeverity` — агрегированная оценка по всем звукам:
//   "mild"     → нет звуков с verdict == .intervention.
//   "moderate" → 1–2 звука с verdict == .intervention.
//   "severe"   → 3+ звуков с verdict == .intervention.

final class ScreeningOutcomeObject: Object, @unchecked Sendable {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var childId: String = ""
    @Persisted var completedAt: Date = Date()
    /// "mild" | "moderate" | "severe" — see file header for derivation rules.
    @Persisted var overallSeverity: String = "mild"
    /// Звуки, по которым требуется вмешательство (verdict == .intervention).
    /// Отсортированы по убыванию приоритета (наиболее проблемные — первыми).
    @Persisted var problematicSounds: List<String>
    /// Предлагаемые контент-паки на основе problematicSounds
    /// (например, ["sound_r_pack", "sound_sh_pack"]).
    @Persisted var recommendedPacks: List<String>
    /// Свободные заметки специалиста / автогенерируемые комментарии (опционально).
    @Persisted var notes: String = ""
    /// Версия алгоритма скрининга — пригодится при ребрендинге шкалы.
    @Persisted var screeningVersion: Int = 1
}
