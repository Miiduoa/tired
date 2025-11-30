import Foundation
import FirebaseFirestoreSwift

/// Represents a chat room in the application.
struct ChatRoom: Codable, Identifiable {
    @DocumentID var id: String?
    
    /// The type of chat room.
    var type: ChatRoomType
    
    /// List of user IDs participating in this chat.
    /// For `.direct` type, this will contain 2 user IDs.
    /// For `.organization` type, this will contain all member IDs.
    var participantIds: [String]
    
    /// The ID of the associated organization, if it's an organization chat.
    var organizationId: String?
    
    /// The name of the chat room.
    /// For `.direct` chats, this might be nil or a concatenation of user names.
    /// For `.organization` chats, this would be the organization's name.
    var name: String?
    
    /// URL for the chat room's avatar.
    /// For `.direct` chats, this could be the other user's avatar.
    /// For `.organization` chats, this would be the organization's avatar.
    var avatarUrl: String?
    
    /// Information about the last message sent in this room, for display in a chat list.
    var lastMessage: LastMessageInfo?
    
    var createdAt: Date
    var updatedAt: Date
}

/// Enum defining the type of a chat room.
enum ChatRoomType: String, Codable {
    /// A direct message between two users.
    case direct
    /// A group chat for all members of an organization.
    case organization
}

/// A nested struct to hold information about the last message for preview purposes.
struct LastMessageInfo: Codable {
    var messageId: String
    var text: String
    var senderId: String
    var timestamp: Date
}
