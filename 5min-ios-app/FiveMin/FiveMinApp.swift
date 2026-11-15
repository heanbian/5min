import SwiftUI

@main
struct FiveMinApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = TimerViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(model)
                .onAppear {
                    model.bootstrap()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.scheduleCloudSyncIfNeeded()
            }
        }
    }
}
