import SwiftUI

enum SessionStatus: String, Codable {
    case active, paused, completed, error

    var color: Color {
        switch self {
        case .active: return Theme.statusActive
        case .paused: return Theme.statusWarning
        case .completed: return Theme.textSecondary
        case .error: return Theme.statusError
        }
    }

    var icon: String {
        switch self {
        case .active: return "circle.fill"
        case .paused: return "pause.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .error: return "exclamationmark.circle.fill"
        }
    }

    var label: String {
        switch self {
        case .active: return "Running"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .error: return "Error"
        }
    }
}

struct StatusBadge: View {
    let status: SessionStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.system(size: 8))
            Text(status.label)
                .font(Theme.smallLabel)
        }
        .foregroundColor(status.color)
    }
}
