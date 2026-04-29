import SwiftUI
import WidgetKit

// MARK: - HappySpeechWidgetBundle

@main
struct HappySpeechWidgetBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOSApplicationExtension 16.1, *) {
            LessonSessionLiveActivity()
        }
    }
}
