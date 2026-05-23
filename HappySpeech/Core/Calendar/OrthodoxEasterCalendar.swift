import Foundation

// MARK: - OrthodoxEasterCalendar
//
// Считает дату православной Пасхи (Russian Orthodox Easter) по алгоритму Meeus.
// Юлианскую дату Пасхи переводит в григорианскую (текущий разрыв = 13 дней).
//
// Известные даты (для проверки):
//   2024 — 5 мая
//   2025 — 20 апреля
//   2026 — 12 апреля
//   2027 — 2 мая
//
// Используется в `SeasonalEventsManager` и `ChildHomeView` для точного gating
// пасхального контента: показываем сезонный баннер только в окне ±N дней
// вокруг даты Пасхи (а не весь март-май, как раньше).

public enum OrthodoxEasterCalendar {

    /// Возвращает дату православной Пасхи (по григорианскому календарю) для
    /// указанного года.
    ///
    /// Алгоритм Meeus для православной (юлианской) Пасхи + конверсия в
    /// григорианский календарь:
    ///   1. Считаем юлианскую дату Пасхи (день/месяц по юлианскому стилю).
    ///   2. Прибавляем разницу юлианского и григорианского календарей
    ///      (13 дней для XXI века).
    ///
    /// - Parameter year: год по григорианскому календарю.
    /// - Returns: `Date` начала дня Пасхи в текущей часовой зоне, либо `nil`
    ///   если конструкция `DateComponents` оказалась невалидной.
    public static func easterDate(year: Int) -> Date? {
        // Шаг 1: алгоритм Meeus для юлианской Пасхи.
        let a = year % 4
        let b = year % 7
        let c = year % 19
        let d = (19 * c + 15) % 30
        let e = (2 * a + 4 * b - d + 34) % 7
        let monthJulian = (d + e + 114) / 31           // 3 = март, 4 = апрель
        let dayJulian = ((d + e + 114) % 31) + 1

        // Шаг 2: переводим юлианскую дату в григорианскую.
        // Для XXI века разрыв = 13 дней (с 1900 по 2099 включительно).
        let offsetDays = gregorianOffset(forYear: year)

        var julianComponents = DateComponents()
        julianComponents.year = year
        julianComponents.month = monthJulian
        julianComponents.day = dayJulian

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        guard let julianDate = calendar.date(from: julianComponents) else {
            return nil
        }
        return calendar.date(byAdding: .day, value: offsetDays, to: julianDate)
    }

    /// Возвращает `true`, если указанная дата находится в окне ±`days`
    /// календарных дней от православной Пасхи того же года.
    ///
    /// - Parameters:
    ///   - days: половина ширины окна (например, `4` → окно 9 дней).
    ///   - date: проверяемая дата.
    /// - Returns: `true`, если `date` попадает в окно вокруг Пасхи.
    public static func isWithin(days: Int, of date: Date) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let year = calendar.component(.year, from: date)
        guard let easter = easterDate(year: year) else { return false }
        let startOfDay = calendar.startOfDay(for: date)
        let startOfEaster = calendar.startOfDay(for: easter)
        let components = calendar.dateComponents([.day], from: startOfEaster, to: startOfDay)
        guard let dayDelta = components.day else { return false }
        return abs(dayDelta) <= days
    }

    // MARK: - Private

    /// Сдвиг юлианский→григорианский календарь (дней) для года XX/XXI/XXII в.
    private static func gregorianOffset(forYear year: Int) -> Int {
        switch year {
        case 1900...2099: return 13
        case 2100...2199: return 14
        case 2200...2299: return 15
        default:          return 13   // безопасный default для актуальной эпохи
        }
    }
}
