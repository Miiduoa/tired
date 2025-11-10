// Swift:ChatService+Compat.swift
import Foundation

extension ChatServiceProtocol {
    // Backwards-compat shim: forward the old name to the new one.
    func markAsRead(conversationId: String, userId: String) async {
        await markRead(conversationId: conversationId, userId: userId)
    }
}
