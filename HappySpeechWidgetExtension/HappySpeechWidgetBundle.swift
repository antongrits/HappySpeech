import SwiftUI
import WidgetKit

// MARK: - HappySpeechWidgetBundle

@main
struct HappySpeechWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Основное задание дня (small/medium/large)
        DailyMissionWidget()
        // Серия дней (small/medium)
        StreakWidget()
        // Три быстрых урока (medium)
        LessonQuickWidget()
        // Ляля с прогрессом (large)
        LyalyaWidget()
        // Live Activity
        if #available(iOSApplicationExtension 16.1, *) {
            LessonSessionLiveActivity()
        }
    }
}
