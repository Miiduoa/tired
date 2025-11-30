import Foundation
import FirebaseFirestoreSwift

/// Represents a single message within a ChatRoom.
struct ChatMessage: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    
    /// The ID of the ChatRoom this message belongs to.
    var roomId: String
    
    /// The ID of the user who sent the message.
    var senderId: String
    
    /// The content of the message.
    var text: String
    
    /// The timestamp when the message was sent.
    var timestamp: Date
    
    /// The type of the message.
    var messageType: MessageType = .text
    
    /// A flag to indicate if the message has been read by the recipient(s).
    /// This can be expanded into a dictionary of [participantId: readTimestamp] for group chats.
    var isRead: Bool = false
    
    // Conform to Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

/// Enum for the type of message content.
enum MessageType: String, Codable {
    case text
    case image
    case file
    // Could be expanded to include polls, events, tasks, etc.
}

/// A simple struct to use for displaying messages in the UI, combining the message with sender info.
struct UIMessage: Identifiable, Hashable {
    let message: ChatMessage
    let sender: UserProfile?
    
    var id: String {
        message.id ?? UUID().uuidString
    }
    
    // Conform to Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: UIMessage, rhs: UIMessage) -> Bool {
        lhs.id == rhs.id
    }
}
