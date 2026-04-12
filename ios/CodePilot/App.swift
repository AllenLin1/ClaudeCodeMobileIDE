import SwiftUI
import SwiftData

@main
struct CodePilotApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [
            DeviceModel.self,
            SessionModel.self,
            MessageModel.self,
        ])
    }
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if !appState.hasCompletedOnboarding {
                OnboardingView()
            } else {
                MainTabView()
                    .onAppear {
                        if !appState.isConnected && appState.connectionStatus != .connecting {
                            appState.connect()
                        }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.hasCompletedOnboarding)
    }
}

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            SessionListView()
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right")
                }
                .tag(0)

            FileBrowserView()
                .tabItem {
                    Label("Files", systemImage: "folder")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(2)
        }
        .tint(Theme.accent)
        .sensoryFeedback(.selection, trigger: selectedTab)
    }
}
