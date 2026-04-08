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

    private var connectionIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(appState.isConnected ? Theme.statusActive : Theme.statusError)
                .frame(width: 8, height: 8)

            Text(appState.isConnected ? "Connected" : "Disconnected")
                .font(Theme.smallLabel)
                .foregroundColor(Theme.textSecondary)
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
