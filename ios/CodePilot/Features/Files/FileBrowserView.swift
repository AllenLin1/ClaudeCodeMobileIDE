import SwiftUI

struct FileBrowserView: View {
    @EnvironmentObject var appState: AppState
    @State private var files: [FileItem] = []
    @State private var currentPath = "~"
    @State private var selectedFile: FileItem?
    @State private var showGitPanel = false
    @State private var gitStatus: GitStatusInfo?

    struct FileItem: Identifiable {
        let id = UUID()
        let name: String
        let path: String
        let isDirectory: Bool
        let size: Int
        let gitStatus: String?
    }

    struct GitStatusInfo {
        let branch: String
        let ahead: Int
        let behind: Int
        let changedFiles: Int
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bgPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    if appState.currentTier == .free {
                        proFeatureBanner
                    } else {
                        fileList
                        gitStatusBar
                    }
                }
            }
            .navigationTitle("Files")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if appState.currentTier != .free {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showGitPanel = true
                        } label: {
                            Text("Git")
                                .font(Theme.label)
                                .foregroundColor(Theme.accent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Theme.accent.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .sheet(isPresented: $showGitPanel) {
                GitPanelView()
            }
            .sheet(item: $selectedFile) { file in
                FileViewerView(fileName: file.name, filePath: file.path)
            }
        }
    }

    private var proFeatureBanner: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 40))
                .foregroundColor(Theme.textTertiary)

            Text("File Browser is a Pro Feature")
                .font(Theme.cardTitle)
                .foregroundColor(Theme.textPrimary)

            Text("Upgrade to Pro to browse files\nand use Git integration.")
                .font(Theme.body)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)

            NavigationLink {
                PaywallView()
            } label: {
                Text("Upgrade to Pro")
                    .font(Theme.cardTitle)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Theme.accent)
                    .clipShape(Capsule())
            }
            .pressEffect()

            Spacer()
        }
    }

    private var fileList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Breadcrumb
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.accent)
                    Text(currentPath)
                        .font(Theme.code)
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                ForEach(files) { file in
                    FileRow(file: file) {
                        if file.isDirectory {
                            navigateToDirectory(file.path)
                        } else {
                            selectedFile = file
                        }
                    }
                }

                if files.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "questionmark.folder")
                            .font(.system(size: 32))
                            .foregroundColor(Theme.textTertiary)
                        Text("No files loaded")
                            .font(Theme.body)
                            .foregroundColor(Theme.textSecondary)
                        Text("Connect to a device to browse files.")
                            .font(Theme.label)
                            .foregroundColor(Theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                }
            }
        }
        .onAppear { loadFiles() }
    }

    private var gitStatusBar: some View {
        Group {
            if let git = gitStatus {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.accent)

                    Text(git.branch)
                        .font(Theme.code)
                        .foregroundColor(Theme.textPrimary)

                    if git.ahead > 0 {
                        Text("↑\(git.ahead)")
                            .font(Theme.smallLabel)
                            .foregroundColor(Theme.statusActive)
                    }

                    if git.behind > 0 {
                        Text("↓\(git.behind)")
                            .font(Theme.smallLabel)
                            .foregroundColor(Theme.statusWarning)
                    }

                    Spacer()

                    if git.changedFiles > 0 {
                        Text("\(git.changedFiles) changed")
                            .font(Theme.smallLabel)
                            .foregroundColor(Theme.statusWarning)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.bgSecondary)
            }
        }
    }

    private func loadFiles() {
        appState.relayService.send([
            "type": "file:list",
            "path": currentPath,
        ] as [String: Any])
    }

    private func navigateToDirectory(_ path: String) {
        currentPath = path
        loadFiles()
    }
}

private struct FileRow: View {
    let file: FileBrowserView.FileItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: file.isDirectory ? "folder.fill" : "doc.text")
                    .font(.system(size: 16))
                    .foregroundColor(file.isDirectory ? Theme.accent : Theme.textSecondary)
                    .frame(width: 24)

                Text(file.name)
                    .font(Theme.body)
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)

                Spacer()

                if let status = file.gitStatus {
                    Text(status)
                        .font(Theme.smallLabel)
                        .fontWeight(.bold)
                        .foregroundColor(gitStatusColor(status))
                }

                if !file.isDirectory {
                    Text(formatSize(file.size))
                        .font(Theme.smallLabel)
                        .foregroundColor(Theme.textTertiary)
                }

                if file.isDirectory {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textTertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    private func gitStatusColor(_ status: String) -> Color {
        switch status {
        case "M": return Theme.statusWarning
        case "A": return Theme.statusActive
        case "D": return Theme.statusError
        default: return Theme.textTertiary
        }
    }

    private func formatSize(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return "\(bytes / 1024) KB" }
        return String(format: "%.1f MB", Double(bytes) / 1024 / 1024)
    }
}
