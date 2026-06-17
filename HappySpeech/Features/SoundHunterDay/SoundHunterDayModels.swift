import Foundation
import SwiftUI

// MARK: - SoundHunterDay VIP Models
//
// «Звуковой охотник дня» — перенос поставленного/автоматизированного звука из
// упражнений в спонтанную бытовую речь (завершающий этап коррекции: Фомичёва,
// Коноваленко, Жукова). Связка двух контуров:
//   • kid    — «миссия дня»: ловит звук в быту, копит «пойманные» слова в сачок
//              (5 слотов-звёзд), серия дней охоты;
//   • parent — «подтверждение переноса»: 3-градационный чек-ин + голосовая
//              заметка. Сигнал питает AdaptivePlannerService через CorrectionStage.
//
// 2 экрана (см. open-design sound-hunter-day-1/2.html):
//   1. Миссия дня (kid)      — hero-миссия со звуком, 2 задания-охоты, сачок, CTA.
//   2. Копилка + подтверждение — kid «копилка дня» (трофей + слова + streak) и
//      parent «подтверждение переноса» (чек-ин + заметка-перл + сигнал плану).
//
// Контент — pack_carryover_missions.json. Лог — CarryoverLog (Realm v20).

enum SoundHunterDayModels {

    // MARK: - Контур экрана

    /// Какой контур показываем (kid/parent). Один экран, две роли — как в
    /// open-design (экран 2 совмещает kid-копилку и parent-подтверждение).
    enum Circuit: Sendable, Equatable {
        case kid
        case parent
    }

    // MARK: - Start

    enum Start {
        struct Request {
            let childId: String
            let circuit: Circuit
        }
        struct Response {
            let mission: CarryoverMission
            let log: CarryoverLogDTO
            let childName: String
            let childAge: Int
            let streakDays: Int
            let weekDots: [DayDot]
            let circuit: Circuit
        }
    }

    // MARK: - CatchWord (ребёнок «поймал слово»)

    enum CatchWord {
        struct Request {
            /// Конкретное слово (если ребёнок выбрал из подсказок) или nil —
            /// тогда берётся следующее непойманное слово-пример миссии.
            let word: String?
        }
        struct Response {
            let log: CarryoverLogDTO
            let mission: CarryoverMission
            let isNetFull: Bool
            /// Поймано первое слово сегодня (для «новый день охоты» обратной связи).
            let justStarted: Bool
        }
    }

    // MARK: - ToggleTask (ребёнок отметил задание-охоту выполненным)

    enum ToggleTask {
        struct Request {
            let taskId: String
        }
        struct Response {
            let log: CarryoverLogDTO
            let mission: CarryoverMission
        }
    }

    // MARK: - ParentCheckIn (родитель подтверждает перенос)

    enum ParentCheckIn {
        struct Request {
            let grade: CarryoverGrade
        }
        struct Response {
            let log: CarryoverLogDTO
            let grade: CarryoverGrade
            let mission: CarryoverMission
        }
    }

    // MARK: - VoiceNote (родительская заметка-перл)

    enum VoiceNote {
        struct RecordResponse {
            let isRecording: Bool
            let durationSec: Double
        }
        struct SavedResponse {
            let log: CarryoverLogDTO
            let durationSec: Double
        }
    }

    // MARK: - Save (родитель сохранил наблюдение)

    enum Save {
        struct Response {
            let log: CarryoverLogDTO
        }
    }

    // MARK: - View models

    /// Одна точка недельной серии (kid-копилка, экран 2).
    struct DayDot: Sendable, Equatable, Identifiable {
        public var id: String { weekdayLabel }
        let weekdayLabel: String
        let isOn: Bool
        let isToday: Bool
    }
}

// MARK: - Domain types

/// Миссия переноса звука дня (из `pack_carryover_missions.json`).
struct CarryoverMission: Sendable, Equatable, Identifiable {
    var id: String { sound }
    /// Целевой звук (кириллица, например «Р»).
    let sound: String
    /// Эмодзи-маркер на soundball (по дизайну — 🎯).
    let soundball: String
    let title: String
    let subtitle: String
    let hint: String
    /// Подсказки «где искать» — реальные слова со звуком (не задания).
    let examples: [String]
    let tasks: [CarryoverTask]
    /// Целевое число «пойманных» слов на день (слотов сачка).
    let netGoal: Int

    /// Минимальная встроенная миссия — на случай отсутствия пака. Никогда не
    /// оставляет экран пустым.
    static func fallback(sound: String) -> CarryoverMission {
        CarryoverMission(
            sound: sound,
            soundball: "🎯",
            title: String(
                format: String(localized: "soundHunter.fallback.title %@",
                               defaultValue: "Сегодня ловим звук %@!"),
                sound
            ),
            subtitle: String(localized: "soundHunter.fallback.subtitle",
                             defaultValue: "Слушай себя — где спрятался этот звук вокруг тебя."),
            hint: String(localized: "soundHunter.fallback.hint",
                         defaultValue: "Ищи слова с этим звуком дома и на улице."),
            examples: [],
            tasks: [
                CarryoverTask(
                    id: "home-objects",
                    icon: "🏠",
                    title: String(
                        format: String(localized: "soundHunter.fallback.task1 %@",
                                       defaultValue: "Назови 3 предмета со звуком %@ дома"),
                        sound
                    ),
                    subtitle: String(localized: "soundHunter.fallback.task1.sub",
                                     defaultValue: "Оглянись вокруг — что слышишь?")
                ),
                CarryoverTask(
                    id: "tell-about",
                    icon: "💬",
                    title: String(localized: "soundHunter.fallback.task2",
                                  defaultValue: "Расскажи маме историю с этим звуком"),
                    subtitle: String(localized: "soundHunter.fallback.task2.sub",
                                     defaultValue: "Говори чисто и не спеши.")
                )
            ],
            netGoal: 5
        )
    }
}

/// Одно задание-охота миссии дня.
struct CarryoverTask: Sendable, Equatable, Identifiable {
    let id: String
    /// Эмодзи-иконка задания (🏠, 🤖 …).
    let icon: String
    let title: String
    let subtitle: String
}

/// Родительская градация переноса звука в свободную речь.
/// Питает AdaptivePlannerService через CorrectionStage.
enum CarryoverGrade: String, Sendable, Equatable, CaseIterable, Codable {
    /// «Да, говорит чисто» — звук пошёл в свободную речь → движение к завершению.
    case clean
    /// «Иногда, с напоминанием» — нужен сознательный контроль → удержание этапа.
    case sometimes
    /// «Пока нет» — в свободной речи теряется → возврат упражнений автоматизации.
    case notyet

    /// Хранимое значение в CarryoverLog.parentCheckIn.
    var storageValue: String { rawValue }

    init?(storage: String) {
        self.init(rawValue: storage)
    }
}
