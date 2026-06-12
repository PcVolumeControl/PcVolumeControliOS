import SwiftUI

@main
struct PCVolumeControlApp: App {
    @StateObject private var aliasManager = AliasManager()
    @StateObject private var motion = MotionProvider()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(aliasManager)
                .environmentObject(motion)
                .onAppear { motion.start() }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        motion.start()
                    case .inactive, .background:
                        motion.stop()
                    @unknown default:
                        break
                    }
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "pcvolumecontrol" else { return }

        if url.host == "connect" {
            appLog("Widget tapped - opening app for connection/reconnection")
        }
    }
}
