import SwiftUI

struct MessageBubble: View {
    let message: MessageModel

    var body: some View {
        Group {
            switch message.role {
            case "user":
                UserMessageBubble(text: message.content ?? "", time: message.createdAt)

            case "assistant":
                assistantContent

            default:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private var assistantContent: some View {
        switch message.type {
        case "text":
            AssistantTextBubble(text: message.content ?? "", isStreaming: message.isStreaming)

        case "tool_use":
            ToolCard(
                toolName: message.toolName ?? "Tool",
                input: message.toolInputDict,
                result: message.toolResult
            )

        case "result":
            ResultBubble(text: message.content ?? "Done")

        case "error":
            errorBubble

        default:
            AssistantTextBubble(text: message.content ?? "", isStreaming: false)
        }
    }

    private var errorBubble: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(Theme.statusError)
                Text(message.content ?? "Error")
                    .font(Theme.label)
                    .foregroundColor(Theme.statusError)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Theme.statusError.opacity(0.1))
            .clipShape(Capsule())

            Spacer()
        }
    }
}
