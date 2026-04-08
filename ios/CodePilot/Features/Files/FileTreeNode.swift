import SwiftUI

struct FileTreeNode: View {
    let name: String
    let isDirectory: Bool
    let depth: Int
    let isExpanded: Bool
    let gitStatus: String?
    let onTap: () -> Void
    let onToggle: () -> Void

    var body: some View {
        Button(action: isDirectory ? onToggle : onTap) {
            HStack(spacing: 4) {
                Spacer()
                    .frame(width: CGFloat(depth) * 16)

                if isDirectory {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textTertiary)
                        .frame(width: 16)
                } else {
                    Spacer().frame(width: 16)
                }

                Image(systemName: isDirectory ? "folder.fill" : fileIcon)
                    .font(.system(size: 14))
                    .foregroundColor(isDirectory ? Theme.accent : Theme.textSecondary)

                Text(name)
                    .font(Theme.body)
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)

                Spacer()

                if let gitStatus {
                    Text(gitStatus)
                        .font(Theme.smallLabel)
                        .fontWeight(.bold)
                        .foregroundColor(statusColor)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var fileIcon: String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "js", "ts", "jsx", "tsx": return "doc.text"
        case "json": return "curlybraces"
        case "md": return "text.document"
        case "py": return "doc.text"
        default: return "doc"
        }
    }

    private var statusColor: Color {
        switch gitStatus {
        case "M": return Theme.statusWarning
        case "A": return Theme.statusActive
        case "D": return Theme.statusError
        default: return Theme.textTertiary
        }
    }
}
