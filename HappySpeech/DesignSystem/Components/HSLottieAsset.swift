import Foundation

// MARK: - HSLottieAsset

/// Семантический реестр Lottie-анимаций приложения.
///
/// Связывает осмысленный кейс с именем файла из `Resources/Animations/`.
/// Использование через enum (а не строковые литералы) делает все анимации
/// явно «подключёнными» и grep-able: добавление нового кейса = подключение файла,
/// удаление файла без удаления кейса вызовет ошибку обзора (нет такого ассета → graceful nil).
///
/// Загрузка — через `HSLottieView(asset:)` / `HSLottieContainer(asset:fallback:)`.
public enum HSLottieAsset: String, CaseIterable, Sendable {

    // MARK: Empty states (Animations/EmptyStates/)

    case emptyOffline             = "empty_offline"
    case emptyNetworkError        = "empty_network_error"
    case emptyNoChildren          = "empty_no_children"
    case emptyNoSessions          = "empty_no_sessions"
    case emptyNoHistory           = "empty_no_history"
    case emptyNoRewards           = "empty_no_rewards"
    case emptyNoAchievements      = "empty_no_achievements"
    case emptySearchNoResults     = "empty_search_no_results"
    case emptyMicrophoneDenied    = "empty_microphone_denied"
    case emptyCameraDenied        = "empty_camera_denied"

    // MARK: Loaders (Animations/Loaders/)

    case loaderInitializing       = "loader_initializing"
    case loaderLoadingLessons     = "loader_loading_lessons"
    case loaderSyncing            = "loader_syncing"
    case loaderUploading          = "loader_uploading"
    case loaderDownloadProgress   = "loader_download_progress"
    case loaderSearching          = "loader_searching"
    case loaderAudioProcessing    = "loader_audio_processing"
    case loaderVoiceRecording     = "loader_voice_recording"
    case loaderAIThinking         = "loader_ai_thinking"
    case loaderGeneratingReport   = "loader_generating_report"

    // MARK: Celebrations (Animations/Celebrations/)

    case celebrateFirstSession    = "celebrate_first_session"
    case celebratePerfectWord     = "celebrate_perfect_word"
    case celebratePerfectRound    = "celebrate_perfect_round"
    case celebrate3Stars          = "celebrate_3_stars"
    case celebrate5Stars          = "celebrate_5_stars"
    case celebrateDailyGoal       = "celebrate_daily_goal"
    case celebrateWeeklyGoal      = "celebrate_weekly_goal"
    case celebrateStreakMilestone = "celebrate_streak_milestone"
    case celebrateLevelUp         = "celebrate_level_up"
    case celebrateUnlockAchievement = "celebrate_unlock_achievement"
    case celebrateNewIslandUnlocked = "celebrate_new_island_unlocked"
    case celebrateCollectionComplete = "celebrate_collection_complete"
    case celebrateNewFriend       = "celebrate_new_friend"

    /// Имя файла анимации в бандле (без расширения).
    public var fileName: String { rawValue }
}
