import Foundation

// MARK: - MLBundle

/// Утилита для поиска скомпилированных Core ML моделей в бандле приложения.
///
/// ## Почему нужен этот хелпер
///
/// Xcode автоматически **компилирует** каждый `.mlpackage` в `.mlmodelc` в процессе
/// сборки (фаза «Compile Sources» для CoreML). В рантаймовом бандле (`.app`) файлы
/// `.mlpackage` отсутствуют — вместо них лежат `.mlmodelc`.
///
/// До введения этого хелпера все 9 мест загрузки моделей в проекте вызывали
/// `Bundle.main.url(forResource:withExtension:"mlpackage")`, что всегда возвращало
/// `nil` → `MLModel` никогда не инициализировался → все ML-сервисы падали с
/// ошибкой «модель не найдена» и продакшн подставлял мок-данные с фиктивным score.
///
/// Правильный способ загрузки скомпилированной модели:
/// ```swift
/// let url = MLBundle.compiledModelURL(name: "PronunciationScorer_hissing")
/// let model = try MLModel(contentsOf: url, configuration: config)
/// ```
///
/// ## Fallback-порядок
///
/// 1. `.mlmodelc` — рантайм-бандл (норма для Release и Debug-сборок через Xcode).
/// 2. `.mlpackage` — сырой пакет (unit-тесты, SPM-тесты, ручная сборка без CoreML
///    compile phase или будущие Swift Package targets). В таких окружениях Xcode не
///    компилирует CoreML, поэтому `.mlmodelc` может отсутствовать.
///
/// - Note: `MLModel(contentsOf:)` принимает URL как `.mlmodelc`, так и `.mlpackage` —
///   оба формата валидны для инициализации.
public enum MLBundle {

    /// Возвращает URL скомпилированной Core ML модели для заданного имени.
    ///
    /// Поиск выполняется последовательно:
    /// 1. `<bundle>/<name>.mlmodelc` (скомпилированный рантайм-формат).
    /// 2. `<bundle>/<name>.mlpackage` (исходный пакет, fallback для тестов).
    ///
    /// - Parameters:
    ///   - name: Имя модели без расширения (например `"PronunciationScorer_hissing"`).
    ///   - bundle: Бандл для поиска. По умолчанию `Bundle.main`.
    /// - Returns: URL модели, или `nil` если модель не найдена ни в одном формате.
    public static func compiledModelURL(name: String, bundle: Bundle = .main) -> URL? {
        if let compiled = bundle.url(forResource: name, withExtension: "mlmodelc") {
            return compiled
        }
        return bundle.url(forResource: name, withExtension: "mlpackage")
    }
}
