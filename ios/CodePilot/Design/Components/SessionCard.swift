import SwiftUI

struct SessionCard: View {
    let name: String
    let model: String
    let status: SessionStatus
    let lastMessage: String?
    let timeAgo: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(status.color)
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(name)
                            .font(Theme.cardTitle)
                            .foregroundColor(Theme.textPrimary)
                            .lineLimit(1)

                        Spacer()

                        StatusBadge(status: status)
                    }

                    HStack(spacing: 6) {
                        Text(model)
                            .font(Theme.smallLabel)
                            .foregroundColor(Theme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.accent.opacity(0.15))
                            .clipShape(Capsule())

                        Text(timeAgo)
                            .font(Theme.smallLabel)
                            .foregroundColor(Theme.textTertiary)
                    }

                    if let lastMessage, !lastMessage.isEmpty {
                        Text(lastMessage)
                            .font(Theme.label)
                            .foregroundColor(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }
                .padding(12)
            }
            .background(Theme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        }
        .buttonStyle(.plain)
        .pressEffect()
    }
}
