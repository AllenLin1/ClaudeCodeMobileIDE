import SwiftUI

struct FileViewerView: View {
    let fileName: String
    let filePath: String

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var content = ""
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bgPrimary.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(Theme.accent)
                } else {
                    ScrollView([.horizontal, .vertical]) {
                        Text(content)
                            .font(Theme.code)
                            .foregroundColor(Theme.textPrimary)
                            .padding(16)
                    }
                    .background(Theme.codeBg)
                }
            }
            .navigationTitle(fileName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.accent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        UIPasteboard.general.string = content
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(Theme.accent)
                    }
                }
            }
        }
        .onAppear { loadFile() }
    }

    private func loadFile() {
        appState.relayService.send([
            "type": "file:read",
            "path": filePath,
        ] as [String: Any])

        // Listen for the response
        appState.relayService.onMessage = { data in
            if let msg = MessageMapper.parse(data),
               msg.type == "file:content",
               msg.path == filePath {
                content = msg.content ?? ""
                isLoading = false
            }
        }
    }
}
