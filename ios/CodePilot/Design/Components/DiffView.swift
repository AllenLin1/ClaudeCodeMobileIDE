import SwiftUI

struct DiffView: View {
    let diff: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("DIFF")
                    .font(Theme.smallLabel)
                    .foregroundColor(Theme.textTertiary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.codeBg.opacity(0.8))

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(diff.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                        DiffLine(text: line)
                    }
                }
                .padding(8)
            }
            .background(Theme.codeBg)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.codeRadius))
    }
}

private struct DiffLine: View {
    let text: String

    private var lineColor: Color {
        if text.hasPrefix("+") && !text.hasPrefix("+++") {
            return Theme.statusActive
        } else if text.hasPrefix("-") && !text.hasPrefix("---") {
            return Theme.statusError
        } else if text.hasPrefix("@@") {
            return Theme.accent
        }
        return Theme.textSecondary
    }

    private var bgColor: Color {
        if text.hasPrefix("+") && !text.hasPrefix("+++") {
            return Theme.statusActive.opacity(0.1)
        } else if text.hasPrefix("-") && !text.hasPrefix("---") {
            return Theme.statusError.opacity(0.1)
        }
        return .clear
    }

    var body: some View {
        Text(text)
            .font(Theme.code)
            .foregroundColor(lineColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(bgColor)
    }
}
