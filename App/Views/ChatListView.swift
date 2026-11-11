import SwiftUI
import SwiftData

struct ChatListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]

    @State private var confirmDeleteAll = false
    @State private var renaming: Conversation?
    @State private var newTitle = ""
    @State private var path: [Conversation] = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if conversations.isEmpty {
                    ContentUnavailableView("Noch keine Chats", systemImage: "bubble.left.and.bubble.right",
                                           description: Text("Tippe oben rechts auf das Stift-Symbol, um einen Chat zu beginnen."))
                } else {
                    List {
                        ForEach(conversations) { conversation in
                            NavigationLink(value: conversation) {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        if conversation.isQuickChat {
                                            Image(systemName: "bell.badge").foregroundStyle(.blue)
                                        }
                                        Text(conversation.title).font(.headline).lineLimit(1)
                                    }
                                    Text(conversation.sortedMessages.last?.text ?? "leer")
                                        .font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                                    Text(conversation.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2).foregroundStyle(.tertiary)
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    delete(conversation)
                                } label: { Label("Löschen", systemImage: "trash") }
                                Button {
                                    newTitle = conversation.title
                                    renaming = conversation
                                } label: { Label("Umbenennen", systemImage: "pencil") }
                                .tint(.blue)
                            }
                            .contextMenu {
                                Button {
                                    newTitle = conversation.title
                                    renaming = conversation
                                } label: { Label("Umbenennen", systemImage: "pencil") }
                                Button(role: .destructive) { delete(conversation) } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Chats")
            .navigationDestination(for: Conversation.self) { ChatDetailView(conversation: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !conversations.isEmpty {
                        Button("Alle löschen", role: .destructive) { confirmDeleteAll = true }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let c = Conversation()
                        context.insert(c)
                        try? context.save()
                        path.append(c)
                    } label: { Image(systemName: "square.and.pencil") }
                }
            }
            .confirmationDialog("Wirklich alle Chats löschen?", isPresented: $confirmDeleteAll, titleVisibility: .visible) {
                Button("Alle Chats löschen", role: .destructive) { deleteAll() }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Das kann nicht rückgängig gemacht werden.")
            }
            .alert("Chat umbenennen", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
                TextField("Name", text: $newTitle)
                Button("Speichern") {
                    let t = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let renaming, !t.isEmpty {
                        renaming.title = t
                        try? context.save()
                    }
                    renaming = nil
                }
                Button("Abbrechen", role: .cancel) { renaming = nil }
            }
        }
    }

    private func delete(_ conversation: Conversation) {
        context.delete(conversation)
        try? context.save()
    }

    private func deleteAll() {
        for c in conversations { context.delete(c) }
        try? context.save()
    }
}
