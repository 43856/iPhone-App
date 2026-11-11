import SwiftUI
import SwiftData

@main
struct KIAssistentApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let heartbeat = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(AppSettings.shared)
                .environment(LLMService.shared)
                .onReceive(heartbeat) { _ in
                    if scenePhase == .active { FrameStore.appForegroundHeartbeat = Date() }
                }
        }
        .modelContainer(Persistence.container)
        .onChange(of: scenePhase) { _, phase in
            FrameStore.appForegroundHeartbeat = phase == .active ? Date() : nil
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            AssistantView()
                .tabItem { Label("Assistent", systemImage: "sparkles") }
            ChatListView()
                .tabItem { Label("Chats", systemImage: "bubble.left.and.bubble.right") }
            SettingsView()
                .tabItem { Label("Einstellungen", systemImage: "gearshape") }
        }
    }
}
