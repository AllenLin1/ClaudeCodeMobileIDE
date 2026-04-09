import SwiftUI

struct GitPanelView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var branch = "main"
    @State private var changedFiles: [(path: String, status: String)] = []
    @State private var diff = ""
    @State private var commits: [(hash: String, message: String, author: String, date: String)] = []
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bgPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    Picker("View", selection: $selectedTab) {
                        Text("Status").tag(0)
                        Text("Diff").tag(1)
                        Text("Log").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    switch selectedTab {
                    case 0: statusView
                    case 1: diffView
                    case 2: logView
                    default: EmptyView()
                    }
                }
            }
            .navigationTitle("Git · \(branch)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.accent)
                }
            }
        }
        .onAppear { loadGitData() }
    }

    private var statusView: some View {
        ScrollView {
            if changedFiles.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 32))
                        .foregroundColor(Theme.statusActive)
                    Text("Working tree clean")
                        .font(Theme.body)
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(.top, 60)
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(changedFiles.enumerated()), id: \.offset) { _, file in
                        HStack(spacing: 12) {
                            Text(file.status)
                                .font(Theme.code)
                                .fontWeight(.bold)
                                .foregroundColor(gitStatusColor(file.status))
                                .frame(width: 20)

                            Text(file.path)
                                .font(Theme.code)
                                .foregroundColor(Theme.textPrimary)
                                .lineLimit(1)

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
            }
        }
    }

    private var diffView: some View {
        ScrollView {
            if diff.isEmpty {
                Text("No changes to display")
                    .font(Theme.body)
                    .foregroundColor(Theme.textSecondary)
                    .padding(.top, 60)
            } else {
                DiffView(diff: diff)
                    .padding(16)
            }
        }
    }

    private var logView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(commits.enumerated()), id: \.offset) { _, commit in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(commit.message)
                            .font(Theme.body)
                            .foregroundColor(Theme.textPrimary)
                            .lineLimit(2)

                        HStack(spacing: 8) {
                            Text(commit.hash.prefix(7))
                                .font(Theme.code)
                                .foregroundColor(Theme.accent)

                            Text(commit.author)
                                .font(Theme.smallLabel)
                                .foregroundColor(Theme.textSecondary)

                            Spacer()

                            Text(commit.date)
                                .font(Theme.smallLabel)
                                .foregroundColor(Theme.textTertiary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    Divider().background(Theme.bgElevated)
                }
            }
        }
    }

    private func loadGitData() {
        let cwd = "~"
        appState.relayService.send(["type": "git:status", "cwd": cwd] as [String: Any])
        appState.relayService.send(["type": "git:diff", "cwd": cwd] as [String: Any])
        appState.relayService.send(["type": "git:log", "cwd": cwd, "limit": 20] as [String: Any])
    }

    private func gitStatusColor(_ status: String) -> Color {
        switch status {
        case "M": return Theme.statusWarning
        case "A": return Theme.statusActive
        case "D": return Theme.statusError
        default: return Theme.textTertiary
        }
    }
}
