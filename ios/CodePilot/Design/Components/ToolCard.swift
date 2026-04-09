import SwiftUI

struct ToolCard: View {
    let toolName: String
    let input: [String: Any]?
    let result: String?

    @State private var isExpanded = false

    private var icon: String {
        switch toolName {
        case "Read": return "doc.text"
        case "Write", "Edit": return "pencil"
        case "Bash": return "terminal"
        case "Glob": return "magnifyingglass"
        case "Grep": return "text.magnifyingglass"
        default: return "wrench"
        }
    }

    private var summary: String {
        if let input {
            if let path = input["file_path"] as? String ?? input["path"] as? String {
                return path
            }
            if let command = input["command"] as? String {
                return command
            }
            if let pattern = input["pattern"] as? String {
                return pattern
            }
        }
        return toolName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(Theme.cardExpand) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(Theme.accent)
                        .frame(width: 24)

                    Text(toolName)
                        .font(Theme.label)
                        .fontWeight(.medium)
                        .foregroundColor(Theme.textPrimary)

                    Text(summary)
                        .font(Theme.label)
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textTertiary)
                }
                .padding(10)
            }
            .buttonStyle(.plain)

            if isExpanded, let result {
                Divider()
                    .background(Theme.bgElevated)

                CodeBlock(code: result, language: detectLanguage())
                    .padding(8)
            }
        }
        .background(Theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Theme.codeRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.codeRadius)
                .stroke(Theme.bgElevated, lineWidth: 0.5)
        )
    }

    private func detectLanguage() -> String {
        guard let path = input?["file_path"] as? String ?? input?["path"] as? String else {
            return toolName == "Bash" ? "bash" : "text"
        }
        let ext = (path as NSString).pathExtension.lowercased()
        let map = ["ts": "typescript", "js": "javascript", "py": "python",
                    "swift": "swift", "rs": "rust", "go": "go", "json": "json"]
        return map[ext] ?? "text"
    }
}
