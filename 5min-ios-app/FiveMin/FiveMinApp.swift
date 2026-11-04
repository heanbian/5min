import SwiftUI

@main
struct FiveMinApp: App {
    @StateObject private var model = TimerViewModel()

    var body: some Scene {
        WindowGroup {
            TimerView()
                .environmentObject(model)
                .onAppear {
                    model.bootstrap()
                }
        }
    }
}
