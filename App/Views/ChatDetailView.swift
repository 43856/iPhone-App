import SwiftUI
import SwiftData

struct ChatDetailView: View {
    @Bindable var conversation: Conversation
    @Environment(\.modelContext) private var context
    @Environment(LLMService.self) private var llm
    @Environment(AppSettings.self) private var settings

    @State private var input = ""
    @State private var pendingQuestion: String?
    @State private var streamingText = ""
    @State private var isWorking = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(conversation.sortedMessages) { message in
                        bubble(text: message.text, isUser: message.isUser, usedScreen: message.usedScreen)
                    }
                    if let pendingQuestion {
                        bubble(text: pendingQuestion, isUser: true, usedScreen: false)
                    }
                    if isWorking {
                        bubble(text: streamingText.isEmpty ? workingHint : streamingText, isUser: false, usedScreen: false)
                            .opacity(streamingText.isEmpty ? 0.6 : 1)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding()
            }
            .onChange(of: streamingText) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
            .onChange(of: conversation.messages.count) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
            .onAppear { proxy.scrollTo("bottom", anchor: .bottom) }
        }
        .safeAreaInset(edge: .bottom) { inputBar }
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var workingHint: String {
        switch llm.state {
        case .downloading(let p): return "Modell wird heruntergeladen … \(Int(p * 100)) %"
        case .loading: return "Modell wird geladen …"
        default: return settings.includeScreen ? "Lese Bildschirm und denke nach …" : "Denke nach …"
        }
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Frage oder Befehl …", text: $input, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.roundedBorder)
                .focused($inputFocused)
            Button {
                send()
            } label: {
                Image(systemName: "arrow.up.circle.fill").font(.system(size: 32))
            }
            .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isWorking)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func bubble(text: String, isUser: Bool, usedScreen: Bool) -> some View {
        HStack {
            if isUser { Spacer(minLength: 40) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(text)
                    .textSelection(.enabled)
                    .padding(10)
                    .background(isUser ? Color.accentColor : Color(.secondarySystemBackground))
                    .foregroundStyle(isUser ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                if usedScreen {
                    Label("mit Bildschirminhalt", systemImage: "rectangle.dashed")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            if !isUser { Spacer(minLength: 40) }
        }
    }

    private func send() {
        let question = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        input = ""
        inputFocused = false
        streamingText = ""
        isWorking = true
        Task {
            await AssistantEngine.ask(question, in: conversation, context: context) { partial in
                streamingText = partial
            }
            isWorking = false
            streamingText = ""
        }
    }
}
