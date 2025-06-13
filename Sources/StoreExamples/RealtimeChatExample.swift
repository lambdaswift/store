import SwiftUI
import Store
import Dependencies

// MARK: - Models

public struct Message: Identifiable, Equatable, Sendable {
    public let id: String
    public let text: String
    public let senderId: String
    public let senderName: String
    public let timestamp: Date
    public var status: MessageStatus
    
    public init(
        id: String = UUID().uuidString,
        text: String,
        senderId: String,
        senderName: String,
        timestamp: Date = Date(),
        status: MessageStatus = .sending
    ) {
        self.id = id
        self.text = text
        self.senderId = senderId
        self.senderName = senderName
        self.timestamp = timestamp
        self.status = status
    }
}

public enum MessageStatus: Equatable, Sendable {
    case sending
    case sent
    case delivered
    case read
    case failed
}

public struct User: Equatable, Sendable {
    public let id: String
    public let name: String
    public let avatarColor: Color
    
    public init(id: String, name: String, avatarColor: Color) {
        self.id = id
        self.name = name
        self.avatarColor = avatarColor
    }
}

public enum ConnectionStatus: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case reconnecting
}

// MARK: - State & Actions

public struct RealtimeChatState: Equatable, Sendable {
    public var currentUser: User
    public var messages: [Message]
    public var typingUsers: Set<String>
    public var connectionStatus: ConnectionStatus
    public var messageQueue: [Message] // Messages waiting to be sent
    public var draftMessage: String
    public var isTyping: Bool
    public var lastTypingTime: Date?
    public var otherUsers: [User]
    public var unreadCount: Int
    
    public init(
        currentUser: User = User(id: "user1", name: "You", avatarColor: .blue),
        otherUsers: [User] = [
            User(id: "user2", name: "Alice", avatarColor: .green),
            User(id: "user3", name: "Bob", avatarColor: .orange)
        ]
    ) {
        self.currentUser = currentUser
        self.messages = []
        self.typingUsers = []
        self.connectionStatus = .disconnected
        self.messageQueue = []
        self.draftMessage = ""
        self.isTyping = false
        self.lastTypingTime = nil
        self.otherUsers = otherUsers
        self.unreadCount = 0
    }
}

public enum RealtimeChatAction: Equatable, Sendable {
    // Connection
    case connect
    case connectionStatusChanged(ConnectionStatus)
    case disconnect
    
    // Messaging
    case sendMessage(String)
    case messageStatusUpdated(id: String, status: MessageStatus)
    case receiveMessage(Message)
    case retryFailedMessage(String)
    case deleteMessage(String)
    
    // Typing
    case updateDraftMessage(String)
    case startTyping
    case stopTyping
    case userStartedTyping(userId: String)
    case userStoppedTyping(userId: String)
    
    // Other
    case markAllAsRead
    case clearChat
    case simulateIncomingMessage
}

// MARK: - Reducer

public func realtimeChatReducer(state: inout RealtimeChatState, action: RealtimeChatAction) {
    switch action {
    // Connection
    case .connect:
        state.connectionStatus = .connecting
        
    case .connectionStatusChanged(let status):
        state.connectionStatus = status
        // Process queued messages when connected
        if status == .connected && !state.messageQueue.isEmpty {
            // Messages will be sent via effects
        }
        
    case .disconnect:
        state.connectionStatus = .disconnected
        state.typingUsers.removeAll()
        
    // Messaging
    case .sendMessage(let text):
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let message = Message(
            text: text,
            senderId: state.currentUser.id,
            senderName: state.currentUser.name,
            status: state.connectionStatus == .connected ? .sending : .failed
        )
        
        state.messages.append(message)
        
        if state.connectionStatus != .connected {
            state.messageQueue.append(message)
        }
        
        state.draftMessage = ""
        state.isTyping = false
        
    case .messageStatusUpdated(let id, let status):
        if let index = state.messages.firstIndex(where: { $0.id == id }) {
            state.messages[index].status = status
            
            // Remove from queue if sent successfully
            if status == .sent || status == .delivered {
                state.messageQueue.removeAll { $0.id == id }
            }
        }
        
    case .receiveMessage(let message):
        state.messages.append(message)
        if message.senderId != state.currentUser.id {
            state.unreadCount += 1
        }
        
    case .retryFailedMessage(let id):
        if let index = state.messages.firstIndex(where: { $0.id == id }) {
            state.messages[index].status = .sending
            if !state.messageQueue.contains(where: { $0.id == id }) {
                state.messageQueue.append(state.messages[index])
            }
        }
        
    case .deleteMessage(let id):
        state.messages.removeAll { $0.id == id }
        state.messageQueue.removeAll { $0.id == id }
        
    // Typing
    case .updateDraftMessage(let text):
        state.draftMessage = text
        
    case .startTyping:
        if !state.isTyping {
            state.isTyping = true
            state.lastTypingTime = Date()
        }
        
    case .stopTyping:
        state.isTyping = false
        state.lastTypingTime = nil
        
    case .userStartedTyping(let userId):
        state.typingUsers.insert(userId)
        
    case .userStoppedTyping(let userId):
        state.typingUsers.remove(userId)
        
    // Other
    case .markAllAsRead:
        state.unreadCount = 0
        for index in state.messages.indices {
            if state.messages[index].senderId != state.currentUser.id &&
               state.messages[index].status != .read {
                state.messages[index].status = .read
            }
        }
        
    case .clearChat:
        state.messages = []
        state.messageQueue = []
        state.typingUsers = []
        state.unreadCount = 0
        
    case .simulateIncomingMessage:
        // Handled by effects
        break
    }
}

// MARK: - Dependencies

public struct ChatClient: DependencyKey, Sendable {
    public static let liveValue = ChatClient()
    
    public var sendMessage: @Sendable (Message) async throws -> MessageStatus = { message in
        // Simulate network delay
        try await Task.sleep(for: .milliseconds(Double.random(in: 500...1500)))
        
        // Simulate occasional failures
        if Double.random(in: 0...1) < 0.1 {
            throw ChatError.sendFailed
        }
        
        // Simulate delivery after a bit more delay
        try await Task.sleep(for: .milliseconds(500))
        
        return .delivered
    }
    
    public var simulateTyping: @Sendable (String) async throws -> Void = { userId in
        // Simulate typing indicator delay
        try await Task.sleep(for: .seconds(2))
    }
}

enum ChatError: Error {
    case sendFailed
    case connectionLost
}

extension DependencyValues {
    public var chatClient: ChatClient {
        get { self[ChatClient.self] }
        set { self[ChatClient.self] = newValue }
    }
}

// MARK: - Effects

public func realtimeChatEffects(
    action: RealtimeChatAction,
    state: RealtimeChatState
) async -> RealtimeChatAction? {
    @Dependency(\.chatClient) var chatClient
    
    switch action {
    case .connect:
        // Simulate connection delay
        try? await Task.sleep(for: .seconds(1))
        return .connectionStatusChanged(.connected)
        
    case .disconnect:
        return .connectionStatusChanged(.disconnected)
        
    case .sendMessage:
        // Find the message that was just added
        guard let message = state.messages.last,
              message.senderId == state.currentUser.id,
              message.status == .sending else { return nil }
        
        do {
            let status = try await chatClient.sendMessage(message)
            return .messageStatusUpdated(id: message.id, status: status)
        } catch {
            return .messageStatusUpdated(id: message.id, status: .failed)
        }
        
    case .retryFailedMessage(let id):
        // Find and retry the message
        guard let message = state.messages.first(where: { $0.id == id }) else { return nil }
        
        do {
            let status = try await chatClient.sendMessage(message)
            return .messageStatusUpdated(id: message.id, status: status)
        } catch {
            return .messageStatusUpdated(id: message.id, status: .failed)
        }
        
    case .connectionStatusChanged(.connected):
        // Process message queue when reconnected
        if let firstQueued = state.messageQueue.first {
            return .retryFailedMessage(firstQueued.id)
        }
        return nil
        
    case .startTyping:
        // Simulate notifying other users
        try? await Task.sleep(for: .milliseconds(100))
        
        // Auto-stop typing after 3 seconds
        try? await Task.sleep(for: .seconds(3))
        if state.isTyping {
            return .stopTyping
        }
        return nil
        
    case .updateDraftMessage where !state.draftMessage.isEmpty && !state.isTyping:
        return .startTyping
        
    case .updateDraftMessage where state.draftMessage.isEmpty && state.isTyping:
        return .stopTyping
        
    case .simulateIncomingMessage:
        // Simulate incoming message from another user
        let otherUser = state.otherUsers.randomElement() ?? state.otherUsers[0]
        let messages = [
            "Hey! How's it going?",
            "Did you see the latest update?",
            "That's awesome!",
            "Let me know when you're free",
            "Thanks for sharing!",
            "Sounds good to me 👍",
            "I'll check it out",
            "See you tomorrow!",
            "Got it, thanks!",
        ]
        
        // Simulate typing first
        let typingAction = RealtimeChatAction.userStartedTyping(userId: otherUser.id)
        
        // Create a task to stop typing and send message
        Task {
            try? await Task.sleep(for: .seconds(Double.random(in: 1...3)))
            await store?.dispatch(.userStoppedTyping(userId: otherUser.id))
            
            let message = Message(
                text: messages.randomElement()!,
                senderId: otherUser.id,
                senderName: otherUser.name,
                status: .delivered
            )
            await store?.dispatch(.receiveMessage(message))
        }
        
        return typingAction
        
    default:
        return nil
    }
}

// Weak reference to store for simulate incoming message effect
@MainActor
private weak var store: Store<RealtimeChatState, RealtimeChatAction>?

// MARK: - Store Creation

@MainActor
public func createRealtimeChatStore() -> Store<RealtimeChatState, RealtimeChatAction> {
    let chatStore = Store(
        initialState: RealtimeChatState(),
        reducer: realtimeChatReducer,
        effects: [realtimeChatEffects]
    )
    
    // Store weak reference for simulation
    store = chatStore
    
    return chatStore
}

// MARK: - SwiftUI Views

public struct RealtimeChatView: View {
    let store: Store<RealtimeChatState, RealtimeChatAction>
    @FocusState private var isMessageFieldFocused: Bool
    
    public init(store: Store<RealtimeChatState, RealtimeChatAction>) {
        self.store = store
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            ChatHeaderView(store: store)
            
            Divider()
            
            // Messages
            ChatMessagesView(store: store)
            
            // Typing indicator
            if !store.currentState.typingUsers.isEmpty {
                TypingIndicatorView(store: store)
            }
            
            Divider()
            
            // Message input
            MessageInputView(store: store, isMessageFieldFocused: $isMessageFieldFocused)
        }
        .onAppear {
            Task {
                await store.dispatch(.connect)
            }
        }
        .onDisappear {
            Task {
                await store.dispatch(.disconnect)
            }
        }
    }
}

struct ChatHeaderView: View {
    let store: Store<RealtimeChatState, RealtimeChatAction>
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Chat Room")
                    .font(.headline)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(connectionColor)
                        .frame(width: 8, height: 8)
                    
                    Text(connectionText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if store.currentState.unreadCount > 0 {
                Button(action: {
                    Task { await store.dispatch(.markAllAsRead) }
                }) {
                    Label("\(store.currentState.unreadCount)", systemImage: "envelope.badge")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            Menu {
                Button(action: {
                    Task { await store.dispatch(.simulateIncomingMessage) }
                }) {
                    Label("Simulate Incoming", systemImage: "message.badge")
                }
                
                Button(action: {
                    Task { await store.dispatch(.clearChat) }
                }) {
                    Label("Clear Chat", systemImage: "trash")
                }
                
                Divider()
                
                Button(action: {
                    Task {
                        await store.dispatch(.disconnect)
                        try? await Task.sleep(for: .seconds(1))
                        await store.dispatch(.connect)
                    }
                }) {
                    Label("Reconnect", systemImage: "arrow.clockwise")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        .padding()
    }
    
    var connectionColor: Color {
        switch store.currentState.connectionStatus {
        case .connected: return .green
        case .connecting, .reconnecting: return .orange
        case .disconnected: return .red
        }
    }
    
    var connectionText: String {
        switch store.currentState.connectionStatus {
        case .connected: return "Connected"
        case .connecting: return "Connecting..."
        case .reconnecting: return "Reconnecting..."
        case .disconnected: return "Disconnected"
        }
    }
}

struct ChatMessagesView: View {
    let store: Store<RealtimeChatState, RealtimeChatAction>
    @State private var scrollViewProxy: ScrollViewProxy?
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(store.currentState.messages) { message in
                        MessageBubble(
                            message: message,
                            isCurrentUser: message.senderId == store.currentState.currentUser.id,
                            store: store
                        )
                        .id(message.id)
                    }
                }
                .padding()
            }
            .onAppear {
                scrollViewProxy = proxy
                scrollToBottom()
            }
            .onChange(of: store.currentState.messages.count) { _, _ in
                scrollToBottom()
            }
        }
    }
    
    private func scrollToBottom() {
        if let lastMessage = store.currentState.messages.last {
            withAnimation {
                scrollViewProxy?.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
}

struct MessageBubble: View {
    let message: Message
    let isCurrentUser: Bool
    let store: Store<RealtimeChatState, RealtimeChatAction>
    
    var body: some View {
        HStack {
            if isCurrentUser { Spacer() }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                if !isCurrentUser {
                    Text(message.senderName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(message.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isCurrentUser ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundColor(isCurrentUser ? .white : .primary)
                    .cornerRadius(16)
                
                HStack(spacing: 4) {
                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if isCurrentUser {
                        statusIcon
                    }
                    
                    if message.status == .failed {
                        Button(action: {
                            Task { await store.dispatch(.retryFailedMessage(message.id)) }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.red)
                    }
                }
            }
            
            if !isCurrentUser { Spacer() }
        }
    }
    
    @ViewBuilder
    var statusIcon: some View {
        switch message.status {
        case .sending:
            ProgressView()
                .scaleEffect(0.5)
        case .sent:
            Image(systemName: "checkmark")
                .font(.caption2)
                .foregroundColor(.secondary)
        case .delivered:
            HStack(spacing: -4) {
                Image(systemName: "checkmark")
                Image(systemName: "checkmark")
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        case .read:
            HStack(spacing: -4) {
                Image(systemName: "checkmark")
                Image(systemName: "checkmark")
            }
            .font(.caption2)
            .foregroundColor(.blue)
        case .failed:
            Image(systemName: "exclamationmark.circle")
                .font(.caption2)
                .foregroundColor(.red)
        }
    }
}

struct TypingIndicatorView: View {
    let store: Store<RealtimeChatState, RealtimeChatAction>
    @State private var animationPhase = 0
    
    var body: some View {
        HStack {
            ForEach(Array(store.currentState.typingUsers), id: \.self) { userId in
                if let user = store.currentState.otherUsers.first(where: { $0.id == userId }) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(user.avatarColor)
                            .frame(width: 8, height: 8)
                        
                        Text("\(user.name) is typing")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 2) {
                            ForEach(0..<3) { index in
                                Circle()
                                    .fill(Color.secondary)
                                    .frame(width: 4, height: 4)
                                    .scaleEffect(animationPhase == index ? 1.2 : 0.8)
                                    .animation(.easeInOut(duration: 0.5).repeatForever().delay(Double(index) * 0.2), value: animationPhase)
                            }
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .onAppear {
            animationPhase = 1
        }
    }
}

struct MessageInputView: View {
    let store: Store<RealtimeChatState, RealtimeChatAction>
    @FocusState.Binding var isMessageFieldFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            TextField("Type a message...", text: .init(
                get: { store.currentState.draftMessage },
                set: { newValue in Task { await store.dispatch(.updateDraftMessage(newValue)) } }
            ))
            .textFieldStyle(.roundedBorder)
            .focused($isMessageFieldFocused)
            .onSubmit {
                Task {
                    await store.dispatch(.sendMessage(store.currentState.draftMessage))
                    isMessageFieldFocused = true
                }
            }
            .disabled(store.currentState.connectionStatus != .connected)
            
            Button(action: {
                Task {
                    await store.dispatch(.sendMessage(store.currentState.draftMessage))
                    isMessageFieldFocused = true
                }
            }) {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(store.currentState.draftMessage.isEmpty || store.currentState.connectionStatus != .connected ? Color.gray : Color.blue)
                    .clipShape(Circle())
            }
            .disabled(store.currentState.draftMessage.isEmpty || store.currentState.connectionStatus != .connected)
        }
        .padding()
    }
}

// MARK: - Preview

#Preview("Realtime Chat") {
    RealtimeChatView(store: createRealtimeChatStore())
}
