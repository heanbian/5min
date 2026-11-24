import SwiftUI

@main
struct FiveMinApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = TimerViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(model)
                .task {
                    model.bootstrap()
                    let vm = model
                    AppDelegate.onOpenURL = { [weak vm] url in
                        vm?.handleDeepLink(url)
                    }
                }
                .onOpenURL { url in
                    model.handleDeepLink(url)
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.consumeShortcutPending()
                model.scheduleCloudSyncIfNeeded()
            }
        }
    }
}
