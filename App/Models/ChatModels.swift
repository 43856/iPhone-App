import Foundation
import SwiftData

@Model
final class Conversation {
    var id: UUID = UUID()
    var title: String = "Neuer Chat"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    /// Chat, der über die Benachrichtigungen geführt wird.
    var isQuickChat: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \ConversationMessage.conversation)
    var messages: [ConversationMessage] = []

    init(title: String = "Neuer Chat", isQuickChat: Bool = false) {
        self.id = UUID()
        self.title = title
        self.isQuickChat = isQuickChat
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var sortedMessages: [ConversationMessage] {
        messages.sorted { $0.createdAt < $1.createdAt }
    }
}

@Model
final class ConversationMessage {
    var id: UUID = UUID()
    /// "user" oder "assistant"
    var role: String = "user"
    var text: String = ""
    var createdAt: Date = Date()
    /// Wurde zu dieser Frage Bildschirmtext mitgeschickt?
    var usedScreen: Bool = false
    var conversation: Conversation?

    init(role: String, text: String, usedScreen: Bool = false) {
        self.id = UUID()
        self.role = role
        self.text = text
        self.usedScreen = usedScreen
        self.createdAt = Date()
    }

    var isUser: Bool { role == "user" }
}
