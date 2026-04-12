import SwiftUI

struct NewSessionView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext

    @State private var name = ""
    @State private var cwd = "~/projects"
    @State private var selectedModel = "default"
    @State private var isCreating = false

    let models = [
        ("default", "Default"),
        ("claude-sonnet-4-6-20260401", "Sonnet 4.6"),
        ("claude-opus-4-6-20260401", "Opus 4.6"),
        ("claude-haiku-4-6-20260401", "Haiku 4.6"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bgPrimary.ignoresSafeArea()

                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SESSION NAME")
                            .font(Theme.smallLabel)
                            .foregroundColor(Theme.textTertiary)

                        TextField("e.g., API Refactor", text: $name)
                            .font(Theme.body)
                            .foregroundColor(Theme.textPrimary)
                            .padding(14)
                            .background(Theme.bgSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.buttonRadius))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("PROJECT DIRECTORY")
                            .font(Theme.smallLabel)
                            .foregroundColor(Theme.textTertiary)

                        TextField("~/projects/my-app", text: $cwd)
                            .font(Theme.code)
                            .foregroundColor(Theme.textPrimary)
                            .padding(14)
                            .background(Theme.bgSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.buttonRadius))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("MODEL")
                            .font(Theme.smallLabel)
                            .foregroundColor(Theme.textTertiary)

                        Picker("Model", selection: $selectedModel) {
                            ForEach(models, id: \.0) { id, label in
                                Text(label).tag(id)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Theme.accent)
                        .padding(10)
                        .background(Theme.bgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.buttonRadius))

                        if appState.currentTier == .free && selectedModel != "default" {
                            Label("Model selection requires Pro", systemImage: "lock.fill")
                                .font(Theme.smallLabel)
                                .foregroundColor(Theme.statusWarning)
                        }
                    }

                    Spacer()

                    Button {
                        createSession()
                    } label: {
                        if isCreating {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Theme.accent)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.buttonRadius))
                        } else {
                            Text("Create Session")
                                .font(Theme.cardTitle)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(name.isEmpty ? Theme.bgElevated : Theme.accent)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.buttonRadius))
                        }
                    }
                    .disabled(name.isEmpty || isCreating)
                    .pressEffect()
                }
                .padding(20)
            }
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.accent)
                }
            }
        }
    }

    private func createSession() {
        isCreating = true

        let model = (appState.currentTier == .free) ? "default" : selectedModel

        let sessionId = UUID().uuidString
        let session = SessionModel(
            id: sessionId,
            name: name,
            cwd: cwd,
            model: model
        )
        modelContext.insert(session)

        isCreating = false
        dismiss()
    }
}
