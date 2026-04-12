import SwiftUI
import SwiftData

struct SessionListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) var modelContext
    @Query(sort: \SessionModel.lastActivity, order: .reverse) var sessions: [SessionModel]
    @State private var showNewSession = false
    @State private var selectedSession: SessionModel?

    private var groupedSessions: [(String, [SessionModel])] {
        let grouped = Dictionary(grouping: sessions) { $0.cwd }
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bgPrimary.ignoresSafeArea()

                if sessions.isEmpty {
                    emptyState
                } else {
                    sessionList
                }
            }
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    connectionIndicator
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewSession = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Theme.accent)
                    }
                }
            }
            .sheet(isPresented: $showNewSession) {
                NewSessionView()
            }
            .navigationDestination(item: $selectedSession) { session in
                ChatView(session: session)
            }
        }
    }

    @State private var showConnectionAlert = false

    private var connectionIndicator: some View {
        Button {
            if !appState.isConnected {
                showConnectionAlert = true
            }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                Text(statusText)
                    .font(Theme.label)
                    .foregroundColor(appState.isConnected ? Theme.statusActive : Theme.textSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                appState.isConnected
                    ? Theme.statusActive.opacity(0.1)
                    : Theme.bgSecondary
            )
            .clipShape(Capsule())
        }
        .alert("Connection Status", isPresented: $showConnectionAlert) {
            Button("Retry") {
                appState.connect()
            }
            Button("Re-pair Device") {
                appState.unpair()
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(connectionAlertMessage)
        }
    }

    private var statusColor: Color {
        switch appState.connectionStatus {
        case .connected: return Theme.statusActive
        case .connecting: return Theme.statusWarning
        case .disconnected: return Theme.statusError
        case .error: return Theme.statusError
        }
    }

    private var statusText: String {
        switch appState.connectionStatus {
        case .connected: return "Online"
        case .connecting: return "Connecting..."
        case .disconnected: return "Offline"
        case .error: return "Error"
        }
    }

    private var connectionAlertMessage: String {
        if let error = appState.connectionError {
            return "Connection error: \(error)\n\nMake sure the server and bridge are running."
        }
        switch appState.connectionStatus {
        case .disconnected:
            return "Not connected to the relay server.\n\nMake sure:\n1. Server is running (npx wrangler dev)\n2. Bridge is running (node bin/cli.js start)\n3. Your device is on the same network"
        case .connecting:
            return "Trying to connect..."
        default:
            return "Connection issue detected."
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(Theme.textTertiary)

            Text("No Sessions Yet")
                .font(Theme.cardTitle)
                .foregroundColor(Theme.textPrimary)

            Text("Create a new session to start\ncoding with Claude.")
                .font(Theme.body)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                showNewSession = true
            } label: {
                Label("New Session", systemImage: "plus")
                    .font(Theme.cardTitle)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Theme.accent)
                    .clipShape(Capsule())
            }
            .pressEffect()
        }
    }

    private var sessionList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(groupedSessions, id: \.0) { cwd, cwdSessions in
                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textTertiary)
                        Text(cwd)
                            .font(Theme.code)
                            .foregroundColor(Theme.textTertiary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    ForEach(cwdSessions) { session in
                        SessionCard(
                            name: session.name,
                            model: session.model,
                            status: session.sessionStatus,
                            lastMessage: session.lastMessage,
                            timeAgo: timeAgo(session.lastActivity),
                            onTap: { selectedSession = session }
                        )
                        .padding(.horizontal, 16)
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteSession(session)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .refreshable {
            appState.relayService.send(["type": "session:list"])
        }
    }

    private func deleteSession(_ session: SessionModel) {
        appState.relayService.send([
            "type": "session:kill",
            "sessionId": session.id,
        ] as [String: Any])
        modelContext.delete(session)
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }
}
