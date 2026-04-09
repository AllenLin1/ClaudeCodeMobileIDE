import SwiftUI

struct ChatInputBar: View {
    @Binding var text: String
    let onSend: () -> Void
    let onInterrupt: () -> Void
    let isRunning: Bool

    var body: some View {
        HStack(spacing: 12) {
            if isRunning {
                Button {
                    onInterrupt()
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Theme.statusError)
                }
                .pressEffect()
            }

            TextField("Type a message...", text: $text, axis: .vertical)
                .font(Theme.body)
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1...5)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.bgSecondary)
                .clipShape(Capsule())
                .onSubmit {
                    if !text.isEmpty { onSend() }
                }

            Button {
                onSend()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(text.isEmpty ? Theme.textTertiary : Theme.accent)
            }
            .disabled(text.isEmpty)
            .pressEffect()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.bgPrimary)
    }
}
