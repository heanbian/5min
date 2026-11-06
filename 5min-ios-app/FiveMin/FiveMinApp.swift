import SwiftUI

@main
struct FiveMinApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = TimerViewModel()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(model)
                .onAppear {
                    model.bootstrap()
                }
        }
    }
}
