import SwiftUI

struct ChatStartView: View {
    let session: AppSession
    let chatService: ChatServiceProtocol
    let directoryService: UserDirectoryServiceProtocol = UserDirectoryService()
    let onCreated: (Conversation) -> Void

    @State private var users: [DirectoryUser] = []
    @State private var selected: Set<String> = []
    @State private var search: String = ""
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                TextField("搜尋姓名或 Email", text: $search)
            }
            Section("選擇成員") {
                ForEach(filteredUsers) { u in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(u.displayName).font(.subheadline.weight(.medium))
                            if !u.email.isEmpty { Text(u.email).font(.caption).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        if selected.contains(u.id) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { toggle(u.id) }
                }
            }
        }
        .navigationTitle("新對話")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("建立") { Task { await create() } }
                    .disabled(selected.isEmpty)
            }
        }
        .task { await load() }
    }

    private var filteredUsers: [DirectoryUser] {
        let me = session.user.id
        var base = users.filter { $0.id != me }
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            base = base.filter { $0.displayName.lowercased().contains(q) || $0.email.lowercased().contains(q) }
        }
        return base
    }

    private func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    @MainActor
    private func load() async {
        isLoading = true
        users = await directoryService.fetchUsers(limit: 100)
        isLoading = false
    }

    @MainActor
    private func create() async {
        var participantIds = Array(selected)
        participantIds.append(session.user.id)
        let title: String
        if participantIds.count == 2, let peer = users.first(where: { $0.id == participantIds.first(where: { $0 != session.user.id }) }) {
            title = peer.displayName
        } else {
            title = "新對話"
        }
        if let convo = try? await chatService.createConversation(participantIds: participantIds, title: title) {
            onCreated(convo)
            dismiss()
        }
    }
}

