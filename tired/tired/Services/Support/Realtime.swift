import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
import Combine

protocol CancelableToken {
    func cancel()
}

#if canImport(FirebaseFirestore)
struct FirebaseListenerToken: CancelableToken {
    let inner: ListenerRegistration
    func cancel() { inner.remove() }
}
#endif

protocol ChatRealtimeListening {
    @discardableResult
    func listenConversations(for userId: String, onChange: @escaping ([Conversation]) -> Void) -> CancelableToken?
    @discardableResult
    func listenMessages(in conversationId: String, limit: Int, onChange: @escaping ([Message]) -> Void) -> CancelableToken?
}

protocol FriendsRealtimeListening {
    @discardableResult
    func listenFriends(of userId: String, onChange: @escaping ([Friend]) -> Void) -> CancelableToken?
    @discardableResult
    func listenRequests(for userId: String, onChange: @escaping ([FriendRequest]) -> Void) -> CancelableToken?
}

protocol ReadsRealtimeListening {
    @discardableResult
    func listenAllReads(for userId: String, onChange: @escaping ([String: Date]) -> Void) -> CancelableToken?
}
