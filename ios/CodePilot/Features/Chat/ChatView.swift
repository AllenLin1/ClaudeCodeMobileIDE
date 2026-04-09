import SwiftUI
import SwiftData

struct ChatView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) var modelContext
    @Bindable var session: SessionModel

    @Query var allMessages: [MessageModel]

    @State private var inputText = ""
    @State private var isRunning = false
    @State private var showModelPicker = false
    @State private var selectedModel: String

    private var messages: [MessageModel] {
        allMessages
            .filter { $0.sessionId == session.id }
            .sorted { $0.createdAt < $1.createdAt }
    }

    init(session: SessionModel) {
        self.session = session
        _selectedModel = State(initialValue: session.model)
    }

    var body: some View {
        ZStack {
            Theme.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                messageList
                inputBar
            }
        }
        .navigationTitle(session.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Text(session.name)
                        .font(Theme.navTitle)
                        .foregroundColor(Theme.textPrimary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    modelSelector

                    Circle()
                        .fill(isRunning ? Theme.statusActive : Theme.textTertiary)
                        .frame(width: 8, height: 8)
                }
            }
        }
        .onAppear {
            setupMessageListener()
        }
    }

    // MARK: - Model Selector
    private var modelSelector: some View {
        Menu {
            ForEach([
                ("default", "Default"),
                ("claude-sonnet-4-6-20260401", "Sonnet 4.6"),
                ("claude-opus-4-6-20260401", "Opus 4.6"),
                ("claude-haiku-4-6-20260401", "Haiku 4.6"),
            ], id: \.0) { id, label in
                Button {
                    selectedModel = id
                    session.model = id
                } label: {
                    HStack {
                        Text(label)
                        if selectedModel == id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text(modelDisplayName(selectedModel))
                .font(Theme.smallLabel)
                .foregroundColor(Theme.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.accent.opacity(0.15))
                .clipShape(Capsule())
        }
    }

    // MARK: - Message List
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(messages) { message in
                        messageView(for: message)
                            .id(message.id)
                    }
                }
                .padding(16)
            }
            .onChange(of: messages.count) {
                if let last = messages.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func messageView(for message: MessageModel) -> some View {
        switch message.role {
        case "user":
            UserMessageBubble(text: message.content ?? "", time: message.createdAt)

        case "assistant":
            switch message.type {
            case "text":
                AssistantTextBubble(text: message.content ?? "", isStreaming: message.isStreaming)

            case "tool_use":
                ToolCard(
                    toolName: message.toolName ?? "Tool",
                    input: message.toolInputDict,
                    result: message.toolResult
                )

            case "tool_request":
                if let toolName = message.toolName {
                    ApprovalCard(
                        toolName: toolName,
                        input: message.toolInputDict,
                        onApprove: { sendApproval(message, allow: true) },
                        onDeny: { sendApproval(message, allow: false) }
                    )
                }

            case "ask_question":
                QuestionCard(
                    question: message.content ?? "",
                    options: nil,
                    onAnswer: { answer in
                        sendAnswer(message, answer: answer)
                    }
                )

            case "result":
                ResultBubble(text: message.content ?? "")

            default:
                AssistantTextBubble(text: message.content ?? "", isStreaming: false)
            }

        default:
            EmptyView()
        }
    }

    // MARK: - Input Bar
    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Type a message...", text: $inputText, axis: .vertical)
                .font(Theme.body)
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1...5)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.bgSecondary)
                .clipShape(Capsule())

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(inputText.isEmpty ? Theme.textTertiary : Theme.accent)
            }
            .disabled(inputText.isEmpty)
            .pressEffect()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.bgPrimary)
    }

    // MARK: - Actions
    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        let text = inputText
        inputText = ""

        let userMsg = MessageModel(
            sessionId: session.id,
            role: "user",
            type: "text",
            content: text
        )
        modelContext.insert(userMsg)

        appState.relayService.send([
            "type": "prompt",
            "sessionId": session.id,
            "text": text,
        ] as [String: Any])

        isRunning = true
    }

    private func sendApproval(_ message: MessageModel, allow: Bool) {
        appState.relayService.send([
            "type": "approve",
            "requestId": message.id,
            "sessionId": session.id,
            "allow": allow,
        ] as [String: Any])
    }

    private func sendAnswer(_ message: MessageModel, answer: String) {
        appState.relayService.send([
            "type": "answer",
            "sessionId": session.id,
            "answers": ["default": answer],
        ] as [String: Any])
    }

    private func setupMessageListener() {
        appState.relayService.onMessage = { data in
            guard let msg = MessageMapper.parse(data) else { return }
            handleBridgeMessage(msg)
        }
    }

    private func handleBridgeMessage(_ msg: MessageMapper.BridgeMessage) {
        guard msg.sessionId == session.id || msg.sessionId == nil else { return }

        switch msg.type {
        case "sdk:text", "sdk:message":
            let content = msg.message?.content ?? msg.content
            let assistantMsg = MessageModel(
                sessionId: session.id,
                role: "assistant",
                type: "text",
                content: content,
                isStreaming: true
            )
            modelContext.insert(assistantMsg)

        case "sdk:tool_request":
            let toolMsg = MessageModel(
                id: msg.requestId ?? UUID().uuidString,
                sessionId: session.id,
                role: "assistant",
                type: "tool_request",
                toolName: msg.toolName ?? msg.message?.toolName,
                toolInput: serializeInput(msg.input?.value ?? msg.message?.toolInput?.value)
            )
            modelContext.insert(toolMsg)

        case "sdk:result":
            isRunning = false
            let resultMsg = MessageModel(
                sessionId: session.id,
                role: "assistant",
                type: "result",
                content: msg.message?.content ?? msg.content ?? "Done"
            )
            modelContext.insert(resultMsg)

        case "sdk:error", "error":
            isRunning = false
            let errorMsg = MessageModel(
                sessionId: session.id,
                role: "assistant",
                type: "error",
                content: msg.error ?? msg.message?.content ?? "Unknown error"
            )
            modelContext.insert(errorMsg)

        case "tier:limit":
            // Show paywall or limit message
            break

        default:
            break
        }
    }

    private func modelDisplayName(_ model: String) -> String {
        switch model {
        case "default": return "Default"
        case let m where m.contains("sonnet"): return "Sonnet 4.6"
        case let m where m.contains("opus"): return "Opus 4.6"
        case let m where m.contains("haiku"): return "Haiku 4.6"
        default: return model
        }
    }

    private func serializeInput(_ value: Any?) -> String? {
        guard let value else { return nil }
        if let dict = value as? [String: Any],
           let data = try? JSONSerialization.data(withJSONObject: dict),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "\(value)"
    }
}

// MARK: - Message Bubbles

struct UserMessageBubble: View {
    let text: String
    let time: Date

    var body: some View {
        HStack {
            Spacer(minLength: 60)
            VStack(alignment: .trailing, spacing: 4) {
                Text(text)
                    .font(Theme.body)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Theme.userBubble)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.bubbleRadius))

                Text(time, format: .dateTime.hour().minute())
                    .font(Theme.smallLabel)
                    .foregroundColor(Theme.textTertiary)
            }
        }
    }
}

struct AssistantTextBubble: View {
    let text: String
    let isStreaming: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.accent)
                    Text("Claude")
                        .font(Theme.smallLabel)
                        .foregroundColor(Theme.textTertiary)
                }

                Text(text + (isStreaming ? " ▍" : ""))
                    .font(Theme.body)
                    .foregroundColor(Theme.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Theme.bgTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.bubbleRadius))
                    .textSelection(.enabled)
            }
            Spacer(minLength: 40)
        }
    }
}

struct ResultBubble: View {
    let text: String

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Theme.statusActive)
                Text(text)
                    .font(Theme.label)
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Theme.statusActive.opacity(0.1))
            .clipShape(Capsule())

            Spacer()
        }
    }
}
