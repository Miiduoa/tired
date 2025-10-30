import Foundation

struct Conversation: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let participantIds: [String]
    let lastMessagePreview: String
    let updatedAt: Date
}

struct Message: Identifiable, Codable, Hashable {
    let id: String
    let conversationId: String
    let senderId: String
    let senderName: String
    let text: String
    let createdAt: Date
    let attachments: [String]?

    init(
        id: String,
        conversationId: String,
        senderId: String,
        senderName: String,
        text: String,
        createdAt: Date,
        attachments: [String]? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.senderName = senderName
        self.text = text
        self.createdAt = createdAt
        self.attachments = attachments
    }
}

struct FriendUser: Identifiable, Codable, Hashable {
    let id: String
    let displayName: String
    let photoURL: String?
}

struct Friend: Identifiable, Codable, Hashable {
    let id: String
    let user: FriendUser
    let since: Date
}

struct FriendRequest: Identifiable, Codable, Hashable {
    let id: String
    let from: FriendUser
    let createdAt: Date
}

