import Foundation
import os.signpost
import OSLog

// MARK: - HSSignpost

/// Централизованные `OSLog`-объекты для `os_signpost` инструментации.
///
/// Plan v22 Block 0.5 — Cold start instrumentation. Используется Instruments
/// → Points of Interest для измерения фаз запуска приложения.
///
/// ## Target
/// Cold start < 3 секунд на iPhone SE (3rd generation).
///
/// ## Замеряемые фазы
/// - `AppLaunch` (begin/end) — от `App.init()` до первого frame `ContentView`.
/// - `LaunchScreenAppear` / `LaunchScreenDisappear` (event) — splash жизненный цикл.
/// - `AuthInit` (begin/end) — bootstrap координатора авторизации.
/// - `MLWarmup` (begin/end) — параллельный прогрев Core ML моделей
///   (см. ``LiveMLModelWarmupService``, Plan v19 Block V).
/// - `ChildHomeFirstFrame` (event) — первый рендер главного детского экрана.
///
/// ## Профилирование
/// 1. Product → Profile (Cmd+I)
/// 2. Instruments → Points of Interest
/// 3. Запустить запись, остановить через ~10 секунд
/// 4. Развернуть «com.mmf.bsu.HappySpeech» → видны интервалы и события
///
/// ## Пример вызова
/// ```swift
/// os_signpost(.begin, log: HSSignpost.pointsOfInterest, name: "AuthInit")
/// // ... работа ...
/// os_signpost(.end, log: HSSignpost.pointsOfInterest, name: "AuthInit")
/// ```
public enum HSSignpost {

    /// OSLog категории `.pointsOfInterest` — стандарт для Instruments.
    public static let pointsOfInterest = OSLog(
        subsystem: "com.mmf.bsu.HappySpeech",
        category: .pointsOfInterest
    )
}
