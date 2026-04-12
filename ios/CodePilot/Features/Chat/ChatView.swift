import SwiftUI
import SwiftData
import Combine

struct ChatView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) var modelContext
    @Bindable var session: SessionModel

    @State private var inputText = ""
    @State private var isRunning = false
    @State private var selectedModel: String
    @State private var bridgeSessionId: String?
    @State private var messageCancellable: AnyCancellable?

    @Query var allMessages: [MessageModel]

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
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    modelSelector
                    Circle()
                        .fill(isRunning ? Theme.statusActive : Theme.textTertiary)
                        .frame(width: 8, height: 8)
                }
            }
        }
        .onAppear { setupMessageListener() }
        .onDisappear { messageCancellable?.cancel() }
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
            case "result":
                ResultBubble(text: message.content ?? "Done")
            case "error":
                ErrorBubble(text: message.content ?? "Error")
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
            if isRunning {
                Button {
                    sendInterrupt()
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Theme.statusError)
                }
            }

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
            "sessionId": bridgeSessionId ?? session.id,
            "text": text,
            "name": session.name,
            "cwd": session.cwd,
            "model": session.model,
        ] as [String: Any])

        isRunning = true
    }

    private func sendApproval(_ message: MessageModel, allow: Bool) {
        appState.relayService.send([
            "type": "approve",
            "requestId": message.id,
            "sessionId": bridgeSessionId ?? session.id,
            "allow": allow,
        ] as [String: Any])
    }

    private func sendInterrupt() {
        appState.relayService.send([
            "type": "interrupt",
            "sessionId": bridgeSessionId ?? session.id,
        ] as [String: Any])
        isRunning = false
    }

    // MARK: - Message Listener
    private func setupMessageListener() {
        messageCancellable = appState.relayService.messagePublisher
            .receive(on: RunLoop.main)
            .sink { [self] data in
                guard let msg = MessageMapper.parse(data) else {
                    print("[chat] Failed to parse message")
                    return
                }
                handleBridgeMessage(msg)
            }
    }

    private func handleBridgeMessage(_ msg: MessageMapper.BridgeMessage) {
        switch msg.type {
        case "session:created":
            if let newId = msg.sessionId {
                let oldId = msg.originalSessionId
                if oldId == session.id || bridgeSessionId == nil {
                    bridgeSessionId = newId
                    print("[chat] Bridge session mapped: \(session.id) -> \(newId)")
                }
            }

        case "pair:success":
            print("[chat] Key exchange confirmed by bridge")

        case "sdk:text":
            let content = msg.sdkMessage?.content ?? msg.content ?? ""
            if !content.isEmpty {
                insertAssistantMessage(type: "text", content: content, isStreaming: true)
            }

        case "sdk:tool_use":
            let toolName = msg.toolName ?? msg.sdkMessage?.toolName ?? "Tool"
            let toolInput = msg.toolInput ?? msg.sdkMessage?.toolInput
            insertAssistantMessage(
                type: "tool_use",
                toolName: toolName,
                toolInput: toolInput
            )

        case "sdk:tool_request":
            if let toolName = msg.toolName ?? msg.sdkMessage?.toolName {
                let assistantMsg = MessageModel(
                    id: msg.requestId ?? UUID().uuidString,
                    sessionId: session.id,
                    role: "assistant",
                    type: "tool_request",
                    toolName: toolName,
                    toolInput: serializeDict(msg.toolInput ?? msg.sdkMessage?.toolInput)
                )
                modelContext.insert(assistantMsg)
            }

        case "sdk:result":
            isRunning = false
            markAllStreaming(false)
            let content = msg.sdkMessage?.content ?? msg.content ?? "Done"
            insertAssistantMessage(type: "result", content: content)

        case "sdk:error", "error":
            isRunning = false
            markAllStreaming(false)
            let content = msg.errorMessage ?? msg.sdkMessage?.content ?? msg.content ?? "Unknown error"
            insertAssistantMessage(type: "error", content: content)

        case "tier:limit":
            isRunning = false
            let content = msg.errorMessage ?? "Feature limited. Upgrade to Pro."
            insertAssistantMessage(type: "error", content: "⚡ \(content)")

        case "auth:required":
            appState.relayService.send([
                "type": "auth",
                "token": "dev",
            ])

        case "auth:success":
            print("[chat] Auth success, tier: \(msg.tier ?? "unknown")")

        case "session:list":
            // Handled by SessionListView if needed
            break

        case "session:history":
            // Could replay messages here
            break

        default:
            print("[chat] Unhandled message type: \(msg.type)")
        }
    }

    // MARK: - Helpers

    private func insertAssistantMessage(
        type: String,
        content: String? = nil,
        toolName: String? = nil,
        toolInput: [String: Any]? = nil,
        isStreaming: Bool = false
    ) {
        let msg = MessageModel(
            sessionId: session.id,
            role: "assistant",
            type: type,
            content: content,
            toolName: toolName,
            toolInput: serializeDict(toolInput),
            isStreaming: isStreaming
        )
        modelContext.insert(msg)
    }

    private func markAllStreaming(_ streaming: Bool) {
        for msg in messages where msg.isStreaming {
            msg.isStreaming = streaming
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

    private func serializeDict(_ dict: [String: Any]?) -> String? {
        guard let dict,
              let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else { return nil }
        return str
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

struct ErrorBubble: View {
    let text: String

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(Theme.statusError)
                Text(text)
                    .font(Theme.label)
                    .foregroundColor(Theme.statusError)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Theme.statusError.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            Spacer()
        }
    }
}
