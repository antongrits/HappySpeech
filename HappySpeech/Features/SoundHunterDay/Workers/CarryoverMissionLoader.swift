import Foundation
import OSLog

// MARK: - CarryoverMissionLoader
//
// Worker фичи «Звуковой охотник дня». Две задачи:
//   1. Загрузка банка миссий переноса `pack_carryover_missions.json` →
//      `[CarryoverMission]` (по одной на звук).
//   2. Чистая методическая логика: подобрать звук дня по профилю ребёнка
//      (`pickSound`) и подобрать следующее «непойманное» слово-пример из миссии.
//
// Загрузка пака и подбор слова — чистые функции (тестируемы без I/O через
// конструктор `seededMissions`).

@MainActor
final class CarryoverMissionLoader {

    private let logger = Logger(subsystem: "ru.happyspeech", category: "CarryoverMissionLoader")

    /// Тестовый seam: если задано — используется вместо чтения пака.
    private let seededMissions: [CarryoverMission]?

    init(seededMissions: [CarryoverMission]? = nil) {
        self.seededMissions = seededMissions
    }

    // MARK: - Public

    /// Загружает все миссии. Если пак отсутствует/повреждён — возвращает пустой
    /// массив (вызывающая сторона подставит `CarryoverMission.fallback`).
    func loadMissions() -> [CarryoverMission] {
        if let seededMissions { return seededMissions }
        guard let raw = Self.loadPack() else {
            logger.warning("pack_carryover_missions.json missing — caller will use fallback")
            return []
        }
        let missions = raw.missions.compactMap(Self.makeMission)
        logger.info("loaded \(missions.count, privacy: .public) carryover missions")
        return missions
    }

    /// Миссия дня по звуку. Если миссии для звука нет — fallback по этому звуку.
    func mission(for sound: String, in missions: [CarryoverMission]) -> CarryoverMission {
        missions.first { $0.sound.caseInsensitiveCompare(sound) == .orderedSame }
            ?? CarryoverMission.fallback(sound: sound)
    }

    // MARK: - Pure: подбор звука дня

    /// Выбирает звук дня детерминированно для стабильности в течение суток.
    ///
    /// Правила (методически — переносим автоматизируемый звук):
    ///   • среди целевых звуков ребёнка берём наименее освоенный
    ///     (`progressSummary` rate, по возрастанию — он нуждается в переносе);
    ///   • при равенстве / отсутствии прогресса — детерминированный выбор по дню
    ///     (ротация), чтобы каждый звук получал свою «миссию дня»;
    ///   • пустой список целей → дефолтный звук «Р» (самый частотный запрос).
    static func pickSound(
        targetSounds: [String],
        progressSummary: [String: Double],
        day: Date,
        calendar: Calendar = .current
    ) -> String {
        let candidates = targetSounds.filter { !$0.isEmpty }
        guard !candidates.isEmpty else { return "Р" }

        // Наименее освоенный среди целевых (rate по возрастанию); отсутствующий
        // прогресс трактуем как 0 (наибольший приоритет переноса).
        let sortedByNeed = candidates.sorted { lhs, rhs in
            let lr = progressSummary[lhs] ?? 0
            let rr = progressSummary[rhs] ?? 0
            if lr != rr { return lr < rr }
            return lhs < rhs
        }

        // Если все цели уже на высоком прогрессе (>= 0.95) — ротируем по дню,
        // чтобы перенос шёл по всем звукам, а не залипал на одном.
        let allHigh = candidates.allSatisfy { (progressSummary[$0] ?? 0) >= 0.95 }
        if allHigh {
            let dayIndex = calendar.ordinality(of: .day, in: .era, for: day) ?? 0
            let idx = ((dayIndex % candidates.count) + candidates.count) % candidates.count
            return candidates.sorted()[idx]
        }
        return sortedByNeed.first ?? "Р"
    }

    /// Следующее «непойманное» слово-пример миссии (для CTA «Поймал!», когда
    /// ребёнок не вводит слово вручную). Возвращает первое из `examples`, которого
    /// ещё нет в `caught`; если все примеры пойманы — синтезирует подпись
    /// «слово N» (ловля продолжается до netGoal даже после исчерпания примеров).
    static func nextExample(mission: CarryoverMission, caught: [String]) -> String {
        let caughtLower = Set(caught.map { $0.lowercased() })
        if let fresh = mission.examples.first(where: { !caughtLower.contains($0.lowercased()) }) {
            return fresh
        }
        let n = caught.count + 1
        return String(
            format: String(localized: "soundHunter.caught.generic %lld",
                           defaultValue: "слово %lld"),
            n
        )
    }

    // MARK: - Pack mapping

    private static func makeMission(_ rm: RawMission) -> CarryoverMission? {
        guard !rm.sound.isEmpty, !rm.title.isEmpty else { return nil }
        let tasks = rm.tasks.map {
            CarryoverTask(id: $0.id, icon: $0.icon, title: $0.title, subtitle: $0.subtitle)
        }
        return CarryoverMission(
            sound: rm.sound,
            soundball: rm.soundball.isEmpty ? "🎯" : rm.soundball,
            title: rm.title,
            subtitle: rm.subtitle,
            hint: rm.hint,
            examples: rm.examples,
            tasks: tasks,
            netGoal: max(1, rm.netGoal ?? 5)
        )
    }

    // MARK: - Pack DTOs

    private struct RawPack: Decodable {
        let netGoal: Int?
        let missions: [RawMission]
    }
    private struct RawMission: Decodable {
        let sound: String
        let soundball: String
        let title: String
        let subtitle: String
        let hint: String
        let examples: [String]
        let tasks: [RawTask]
        let netGoal: Int?

        enum CodingKeys: String, CodingKey {
            case sound, soundball, title, subtitle, hint, examples, tasks, netGoal
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            sound = try c.decode(String.self, forKey: .sound)
            soundball = (try? c.decode(String.self, forKey: .soundball)) ?? "🎯"
            title = try c.decode(String.self, forKey: .title)
            subtitle = (try? c.decode(String.self, forKey: .subtitle)) ?? ""
            hint = (try? c.decode(String.self, forKey: .hint)) ?? ""
            examples = (try? c.decode([String].self, forKey: .examples)) ?? []
            tasks = (try? c.decode([RawTask].self, forKey: .tasks)) ?? []
            netGoal = try? c.decode(Int.self, forKey: .netGoal)
        }
    }
    private struct RawTask: Decodable {
        let id: String
        let icon: String
        let title: String
        let subtitle: String

        enum CodingKeys: String, CodingKey { case id, icon, title, subtitle }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            icon = (try? c.decode(String.self, forKey: .icon)) ?? "✦"
            title = try c.decode(String.self, forKey: .title)
            subtitle = (try? c.decode(String.self, forKey: .subtitle)) ?? ""
        }
    }

    // MARK: - Pack IO

    private static func loadPack() -> RawPack? {
        guard let url = Bundle.main.url(forResource: "pack_carryover_missions", withExtension: "json")
            ?? Bundle.main.url(
                forResource: "pack_carryover_missions",
                withExtension: "json",
                subdirectory: "Seed"
            ),
            let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(RawPack.self, from: data)
    }
}
