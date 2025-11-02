// ChatService+Compat.swift
import Foundation

// Backwards-compat shim so older call sites using `markAsRead` still compile.
// Your protocol currently declares `markRead(conversationId:userId:)`.
extension ChatServiceProtocol {
    func markAsRead(conversationId: String, userId: String) async {
        await markRead(conversationId: conversationId, userId: userId)
    }
}
