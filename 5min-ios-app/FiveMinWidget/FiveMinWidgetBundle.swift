import SwiftUI
import WidgetKit

@main
struct FiveMinWidgetBundle: WidgetBundle {
    var body: some Widget {
        TimerLiveActivity()
        TimerHomeWidget()
    }
}
