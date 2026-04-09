import SwiftUI

struct ApprovalCard: View {
    let toolName: String
    let input: [String: Any]?
    let onApprove: () -> Void
    let onDeny: () -> Void

    private var summary: String {
        if let input {
            if let cmd = input["command"] as? String { return cmd }
            if let path = input["file_path"] as? String { return path }
        }
        return toolName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.statusWarning)

                Text("Approval Needed")
                    .font(Theme.cardTitle)
                    .foregroundColor(Theme.statusWarning)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(toolName)
                    .font(Theme.label)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.textPrimary)

                Text(summary)
                    .font(Theme.code)
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(3)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 12) {
                Button(action: onApprove) {
                    Label("Allow", systemImage: "checkmark.circle.fill")
                        .font(Theme.label)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Theme.statusActive.opacity(0.2))
                        .foregroundColor(Theme.statusActive)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.buttonRadius))
                }
                .sensoryFeedback(.impact(weight: .medium), trigger: UUID())

                Button(action: onDeny) {
                    Label("Deny", systemImage: "xmark.circle.fill")
                        .font(Theme.label)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Theme.statusError.opacity(0.2))
                        .foregroundColor(Theme.statusError)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.buttonRadius))
                }
            }
        }
        .padding(14)
        .background(Theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .stroke(Theme.statusWarning.opacity(0.5), lineWidth: 1)
        )
    }
}
