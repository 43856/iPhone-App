import Foundation
import SwiftData

/// Zentrale Stelle: Frage stellen → Bildschirm lesen → KI antworten lassen → im Chat speichern.
/// Wird von der Chat-Ansicht und (später) von den Benachrichtigungen benutzt.
@MainActor
enum AssistantEngine {
    /// Stellt eine Frage im angegebenen Chat und speichert Frage und Antwort.
    @discardableResult
    static func ask(
        _ question: String,
        in conversation: Conversation,
        context: ModelContext,
        onUpdate: @escaping (String) -> Void = { _ in }
    ) async -> String {
        let history = conversation.sortedMessages.map { (isUser: $0.isUser, text: $0.text) }

        var screen: ScreenReader.Result?
        if AppSettings.shared.includeScreen {
            screen = await ScreenReader.latestText()
        }

        let userMessage = ConversationMessage(role: "user", text: question, usedScreen: screen != nil)
        userMessage.conversation = conversation
        context.insert(userMessage)
        if conversation.messages.count <= 1 && conversation.title == "Neuer Chat" {
            conversation.title = String(question.prefix(40))
        }
        conversation.updatedAt = Date()
        try? context.save()

        let answer: String
        do {
            answer = try await LLMService.shared.answer(
                question: question,
                history: history,
                screenText: screen?.text,
                onUpdate: onUpdate
            )
        } catch {
            answer = "⚠️ \(error.localizedDescription)"
        }

        let reply = ConversationMessage(role: "assistant", text: answer.isEmpty ? "(keine Antwort)" : answer)
        reply.conversation = conversation
        context.insert(reply)
        conversation.updatedAt = Date()
        try? context.save()
        return reply.text
    }
}

enum Persistence {
    @MainActor
    static let container: ModelContainer = {
        do {
            return try ModelContainer(for: Conversation.self, ConversationMessage.self)
        } catch {
            fatalError("Datenbank konnte nicht geöffnet werden: \(error)")
        }
    }()
}
