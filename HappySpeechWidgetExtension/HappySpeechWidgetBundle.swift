import WidgetKit
import SwiftUI

// MARK: - HappySpeechWidgetBundle

@main
struct HappySpeechWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyMissionWidget()
        if #available(iOSApplicationExtension 16.1, *) {
            LessonSessionLiveActivity()
        }
    }
}
