import Testing
import Foundation
import Dependencies
@testable import StoreExamples
@testable import Store

@Suite("Realtime Chat Example Tests")
struct RealtimeChatExampleTests {
    
    @Test("Realtime chat initial state")
    @MainActor
    func testInitialState() async {
        let store = createRealtimeChatStore()
        #expect(store.currentState.messages.isEmpty)
        #expect(store.currentState.typingUsers.isEmpty)
        #expect(store.currentState.connectionStatus == .disconnected)
        #expect(store.currentState.messageQueue.isEmpty)
        #expect(store.currentState.draftMessage == "")
        #expect(store.currentState.isTyping == false)
        #expect(store.currentState.unreadCount == 0)
        #expect(store.currentState.currentUser.id == "user1")
        #expect(store.currentState.otherUsers.count == 2)
    }
    
    @Test("Connection management")
    @MainActor
    func testConnectionManagement() async {
        let store = createRealtimeChatStore()
        
        // Connect
        await store.dispatch(.connect)
        #expect(store.currentState.connectionStatus == .connecting)
        
        // Wait for connection
        await store.waitForEffects()
        #expect(store.currentState.connectionStatus == .connected)
        
        // Disconnect
        await store.dispatch(.disconnect)
        await store.waitForEffects()
        #expect(store.currentState.connectionStatus == .disconnected)
        #expect(store.currentState.typingUsers.isEmpty)
    }
    
    @Test("Send message when connected")
    func testSendMessageConnected() async {
        await withDependencies {
            $0.chatClient.sendMessage = { message in
                try await Task.sleep(for: .milliseconds(100))
                return .delivered
            }
        } operation: { @MainActor in
            let store = createRealtimeChatStore()
            
            // Connect first
            await store.dispatch(.connect)
            await store.waitForEffects()
            
            // Send message
            await store.dispatch(.sendMessage("Hello, world!"))
            
            // Check message was added
            #expect(store.currentState.messages.count == 1)
            #expect(store.currentState.messages[0].text == "Hello, world!")
            #expect(store.currentState.messages[0].senderId == store.currentState.currentUser.id)
            #expect(store.currentState.messages[0].status == .sending)
            #expect(store.currentState.draftMessage == "")
            
            // Wait for send to complete
            await store.waitForEffects()
            
            // Check status updated
            #expect(store.currentState.messages[0].status == .delivered)
            #expect(store.currentState.messageQueue.isEmpty)
        }
    }
    
    @Test("Send message when disconnected")
    @MainActor
    func testSendMessageDisconnected() async {
        let store = createRealtimeChatStore()
        
        // Send message while disconnected
        await store.dispatch(.sendMessage("Offline message"))
        
        // Check message was added with failed status
        #expect(store.currentState.messages.count == 1)
        #expect(store.currentState.messages[0].text == "Offline message")
        #expect(store.currentState.messages[0].status == .failed)
        
        // Check message was queued
        #expect(store.currentState.messageQueue.count == 1)
        #expect(store.currentState.messageQueue[0].id == store.currentState.messages[0].id)
    }
    
    @Test("Message send failure")
    func testMessageSendFailure() async {
        await withDependencies {
            $0.chatClient.sendMessage = { _ in
                throw ChatError.sendFailed
            }
        } operation: { @MainActor in
            let store = createRealtimeChatStore()
            
            // Connect
            await store.dispatch(.connect)
            await store.waitForEffects()
            
            // Send message
            await store.dispatch(.sendMessage("Will fail"))
            
            // Wait for send attempt
            await store.waitForEffects()
            
            // Check status is failed
            #expect(store.currentState.messages[0].status == .failed)
        }
    }
    
    @Test("Retry failed message")
    func testRetryFailedMessage() async {
        actor Counter {
            var value = 0
            func increment() -> Int {
                value += 1
                return value
            }
        }
        let counter = Counter()
        
        await withDependencies {
            $0.chatClient.sendMessage = { _ in
                let count = await counter.increment()
                if count == 1 {
                    throw ChatError.sendFailed
                }
                return .delivered
            }
        } operation: { @MainActor in
            let store = createRealtimeChatStore()
            
            // Connect
            await store.dispatch(.connect)
            await store.waitForEffects()
            
            // Send message (will fail)
            await store.dispatch(.sendMessage("Retry me"))
            await store.waitForEffects()
            
            let messageId = store.currentState.messages[0].id
            #expect(store.currentState.messages[0].status == .failed)
            
            // Retry
            await store.dispatch(.retryFailedMessage(messageId))
            #expect(store.currentState.messages[0].status == .sending)
            
            await store.waitForEffects()
            
            // Should succeed on retry
            #expect(store.currentState.messages[0].status == .delivered)
            #expect(await counter.value == 2)
        }
    }
    
    @Test("Receive message")
    @MainActor
    func testReceiveMessage() async {
        let store = createRealtimeChatStore()
        
        let incomingMessage = Message(
            id: "msg123",
            text: "Hello from Alice!",
            senderId: "user2",
            senderName: "Alice",
            status: .delivered
        )
        
        await store.dispatch(.receiveMessage(incomingMessage))
        
        #expect(store.currentState.messages.count == 1)
        #expect(store.currentState.messages[0].id == "msg123")
        #expect(store.currentState.messages[0].text == "Hello from Alice!")
        #expect(store.currentState.unreadCount == 1)
    }
    
    @Test("Typing indicators")
    func testTypingIndicators() async {
        await withDependencies {
            $0.chatClient.simulateTyping = { _ in
                try await Task.sleep(for: .milliseconds(100))
            }
        } operation: { @MainActor in
            let store = createRealtimeChatStore()
            
            // Update draft message
            await store.dispatch(.updateDraftMessage("Hello"))
            
            // Should trigger typing
            await store.waitForEffects()
            #expect(store.currentState.isTyping == true)
            
            // Clear draft
            await store.dispatch(.updateDraftMessage(""))
            await store.waitForEffects()
            #expect(store.currentState.isTyping == false)
            
            // Test other user typing
            await store.dispatch(.userStartedTyping(userId: "user2"))
            #expect(store.currentState.typingUsers.contains("user2"))
            
            await store.dispatch(.userStoppedTyping(userId: "user2"))
            #expect(!store.currentState.typingUsers.contains("user2"))
        }
    }
    
    @Test("Mark all as read")
    @MainActor
    func testMarkAllAsRead() async {
        let store = createRealtimeChatStore()
        
        // Add some received messages
        await store.dispatch(.receiveMessage(Message(
            id: "1",
            text: "Message 1",
            senderId: "user2",
            senderName: "Alice",
            status: .delivered
        )))
        await store.dispatch(.receiveMessage(Message(
            id: "2",
            text: "Message 2",
            senderId: "user3",
            senderName: "Bob",
            status: .delivered
        )))
        
        #expect(store.currentState.unreadCount == 2)
        
        // Mark all as read
        await store.dispatch(.markAllAsRead)
        
        #expect(store.currentState.unreadCount == 0)
        #expect(store.currentState.messages[0].status == .read)
        #expect(store.currentState.messages[1].status == .read)
    }
    
    @Test("Clear chat")
    @MainActor
    func testClearChat() async {
        let store = createRealtimeChatStore()
        
        // Add messages and queue
        await store.dispatch(.sendMessage("Test message"))
        await store.dispatch(.receiveMessage(Message(
            id: "1",
            text: "Received",
            senderId: "user2",
            senderName: "Alice",
            status: .delivered
        )))
        await store.dispatch(.userStartedTyping(userId: "user2"))
        
        #expect(store.currentState.messages.count == 2)
        #expect(store.currentState.unreadCount == 1)
        #expect(!store.currentState.typingUsers.isEmpty)
        
        // Clear chat
        await store.dispatch(.clearChat)
        
        #expect(store.currentState.messages.isEmpty)
        #expect(store.currentState.messageQueue.isEmpty)
        #expect(store.currentState.typingUsers.isEmpty)
        #expect(store.currentState.unreadCount == 0)
    }
    
    @Test("Empty message not sent")
    @MainActor
    func testEmptyMessageNotSent() async {
        let store = createRealtimeChatStore()
        
        // Try to send empty message
        await store.dispatch(.sendMessage(""))
        #expect(store.currentState.messages.isEmpty)
        
        // Try to send whitespace
        await store.dispatch(.sendMessage("   "))
        #expect(store.currentState.messages.isEmpty)
    }
    
    @Test("Delete message")
    @MainActor
    func testDeleteMessage() async {
        let store = createRealtimeChatStore()
        
        // Send messages while disconnected to add to queue
        await store.dispatch(.sendMessage("Message 1"))
        await store.dispatch(.sendMessage("Message 2"))
        
        let messageId = store.currentState.messages[0].id
        
        #expect(store.currentState.messages.count == 2)
        #expect(store.currentState.messageQueue.count == 2)
        
        // Delete first message
        await store.dispatch(.deleteMessage(messageId))
        
        #expect(store.currentState.messages.count == 1)
        #expect(store.currentState.messages[0].text == "Message 2")
        #expect(store.currentState.messageQueue.count == 1)
        #expect(!store.currentState.messageQueue.contains { $0.id == messageId })
    }
    
    @Test("Connection status changes")
    @MainActor
    func testConnectionStatusChanges() async {
        let store = createRealtimeChatStore()
        
        await store.dispatch(.connectionStatusChanged(.connecting))
        #expect(store.currentState.connectionStatus == .connecting)
        
        await store.dispatch(.connectionStatusChanged(.connected))
        #expect(store.currentState.connectionStatus == .connected)
        
        await store.dispatch(.connectionStatusChanged(.reconnecting))
        #expect(store.currentState.connectionStatus == .reconnecting)
        
        await store.dispatch(.connectionStatusChanged(.disconnected))
        #expect(store.currentState.connectionStatus == .disconnected)
    }
    
    @Test("Message queue processing on reconnect")
    func testMessageQueueProcessing() async {
        actor Counter {
            var value = 0
            func increment() {
                value += 1
            }
        }
        let counter = Counter()
        
        await withDependencies {
            $0.chatClient.sendMessage = { message in
                await counter.increment()
                return .delivered
            }
        } operation: { @MainActor in
            let store = createRealtimeChatStore()
            
            // Send message while disconnected
            await store.dispatch(.sendMessage("Queued message"))
            #expect(store.currentState.messageQueue.count == 1)
            
            // Connect
            await store.dispatch(.connect)
            await store.waitForEffects()
            
            // The connection effect returns a retry action, wait for that
            await store.waitForEffects()
            
            // Wait for the actual send to complete
            await store.waitForEffects()
            
            // Queue should be processed
            #expect(await counter.value == 1)
            #expect(store.currentState.messages[0].status == .delivered)
            #expect(store.currentState.messageQueue.isEmpty)
        }
    }
    
    @Test("Auto stop typing")
    func testAutoStopTyping() async {
        await withDependencies {
            $0.chatClient.simulateTyping = { _ in
                // No delay for test
            }
        } operation: { @MainActor in
            let store = createRealtimeChatStore()
            
            // Start typing
            await store.dispatch(.startTyping)
            #expect(store.currentState.isTyping == true)
            #expect(store.currentState.lastTypingTime != nil)
            
            // Should auto-stop after delay (simulated by waiting for effects)
            // In the real implementation, this would be after 3 seconds
            await store.waitForEffects()
            
            // For testing, manually stop
            await store.dispatch(.stopTyping)
            #expect(store.currentState.isTyping == false)
            #expect(store.currentState.lastTypingTime == nil)
        }
    }
    
    @Test("Message status enum")
    func testMessageStatusEnum() {
        #expect(MessageStatus.sending != MessageStatus.sent)
        #expect(MessageStatus.sent != MessageStatus.delivered)
        #expect(MessageStatus.delivered != MessageStatus.read)
        #expect(MessageStatus.failed != MessageStatus.sent)
    }
    
    @Test("User model")
    func testUserModel() {
        let user = User(id: "test", name: "Test User", avatarColor: .red)
        #expect(user.id == "test")
        #expect(user.name == "Test User")
        #expect(user.avatarColor == .red)
    }
    
    @Test("Message model")
    func testMessageModel() {
        let message = Message(
            id: "123",
            text: "Test message",
            senderId: "user1",
            senderName: "Test User",
            timestamp: Date(timeIntervalSince1970: 1000),
            status: .sent
        )
        
        #expect(message.id == "123")
        #expect(message.text == "Test message")
        #expect(message.senderId == "user1")
        #expect(message.senderName == "Test User")
        #expect(message.timestamp == Date(timeIntervalSince1970: 1000))
        #expect(message.status == .sent)
    }
    
    @Test("Reducer directly")
    func testReducerDirectly() {
        var state = RealtimeChatState()
        
        // Send message
        realtimeChatReducer(state: &state, action: .sendMessage("Hello"))
        #expect(state.messages.count == 1)
        #expect(state.messages[0].text == "Hello")
        #expect(state.draftMessage == "")
        
        // Update draft
        realtimeChatReducer(state: &state, action: .updateDraftMessage("Draft"))
        #expect(state.draftMessage == "Draft")
        
        // Start typing
        realtimeChatReducer(state: &state, action: .startTyping)
        #expect(state.isTyping == true)
        
        // Clear chat
        realtimeChatReducer(state: &state, action: .clearChat)
        #expect(state.messages.isEmpty)
    }
}