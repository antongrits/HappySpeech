import Foundation

// MARK: - ChildAgeFormatter
//
// Единая точка форматирования возраста ребёнка в локализованную строку
// («6 лет»). Устраняет два класса дефектов, замеченных на первом запуске:
//
//   1. Антипаттерн `String(localized: "\(age) лет")` — значение
//      интерполировалось прямо в КЛЮЧ, из-за чего в каталоге появлялся
//      «мусорный» ключ и при `age == 0` на экране был раздражающий «0 лет».
//   2. Невалидный/неизвестный возраст (`age <= 0`) рендерился как «, 0 лет».
//
// Формат строится через явный ключ-шаблон `child.age.years` («%lld лет»)
// с корректным русским склонением (1 год / 2 года / 5 лет) — это покрывает
// и валидный диапазон 5–8, и любой граничный возраст 3–12.
//
// Для невалидного возраста (`age <= 0`) методы возвращают `nil` — вызывающая
// сторона показывает только имя ребёнка вместо «Имя, 0 лет» (грамотный
// fallback вместо обрезанной/бессмысленной подписи).

enum ChildAgeFormatter {

    /// Допустимый диапазон возраста ребёнка в приложении. Вне его — считаем
    /// возраст неизвестным и подпись не показываем.
    static let validRange = 1...17

    /// Локализованная подпись возраста («6 лет») или `nil`, если возраст
    /// невалиден (`age` вне ``validRange``). `nil` означает «возраст не
    /// показываем» — вызывающий код выводит только имя.
    static func yearsLabel(for age: Int) -> String? {
        guard validRange.contains(age) else { return nil }
        // `localizedStringWithFormat` обязательно для применения plural-правил
        // из xcstrings (1 год / 2 года / 5 лет) — обычный `String(format:)`
        // склонение НЕ выбирает.
        return String.localizedStringWithFormat(
            String(localized: "child.age.years"),
            age
        )
    }

    /// «Имя, 6 лет», либо просто «Имя», если возраст неизвестен. Никогда не
    /// возвращает «Имя, 0 лет».
    static func nameWithAge(name: String, age: Int) -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let years = yearsLabel(for: age) else { return trimmedName }
        guard !trimmedName.isEmpty else { return years }
        return "\(trimmedName), \(years)"
    }
}
