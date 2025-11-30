import Foundation
import Combine
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

@MainActor
class GlobalSearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var searchResults: [GlobalSearchResult.SearchResultType: [GlobalSearchResult]] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?

    // 暫時用來存儲本地搜尋的取消令牌
    private var currentSearchTask: _Concurrency.Task<Void, Never>?
    private let db = Firestore.firestore()
    
    // 用來簡單去抖動
    private var searchCancellable: AnyCancellable?

    init() {
        setupSearchDebouncer()
    }

    private func setupSearchDebouncer() {
        searchCancellable = $searchText
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.performSearch(query: query)
            }
    }

    func performSearch(query: String) {
        // 取消上一次的搜尋任務
        currentSearchTask?.cancel()
        
        let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
        guard !trimmedQuery.isEmpty else {
            self.searchResults = [:]
            self.isLoading = false
            return
        }

        self.isLoading = true
        self.errorMessage = nil

        // 開啟新的搜尋任務
        currentSearchTask = _Concurrency.Task {
            do {
                // 平行執行多個搜尋請求
                async let users = searchUsers(query: trimmedQuery)
                async let orgs = searchOrganizations(query: trimmedQuery)
                async let tasks = searchTasks(query: trimmedQuery)
                
                let (userResults, orgResults, taskResults) = await (users, orgs, tasks)
                
                // 檢查是否被取消
                if _Concurrency.Task.isCancelled { return }
                
                var newResults: [GlobalSearchResult.SearchResultType: [GlobalSearchResult]] = [:]
                
                if !userResults.isEmpty { newResults[.user] = userResults }
                if !orgResults.isEmpty { newResults[.organization] = orgResults }
                if !taskResults.isEmpty { newResults[.task] = taskResults }
                
                await MainActor.run {
                    self.searchResults = newResults
                    self.isLoading = false
                }
            } 
            // Removed unreachable catch block since search functions handle errors internally and return empty arrays
        }
    }
    
    // MARK: - Firebase Search Implementation
    
    // 搜尋使用者 (名字前綴匹配)
    // 注意：這是一個全域搜尋，實際生產環境應限制範圍（例如只搜尋好友或同組織成員）
    private func searchUsers(query: String) async -> [GlobalSearchResult] {
        do {
            // Firebase 的簡單前綴查詢技巧
            let queryEnd = query + "\u{f8ff}"
            
            let snapshot = try await db.collection("users")
                .whereField("name", isGreaterThanOrEqualTo: query)
                .whereField("name", isLessThan: queryEnd)
                .limit(to: 5)
                .getDocuments()
                
            return snapshot.documents.map { doc in
                let data = doc.data()
                let name = data["name"] as? String ?? "未命名"
                let email = data["email"] as? String
                return GlobalSearchResult(
                    objectID: doc.documentID,
                    title: name,
                    snippet: email,
                    type: .user
                )
            }
        } catch {
            print("Error searching users: \(error)")
            return []
        }
    }
    
    // 搜尋組織
    private func searchOrganizations(query: String) async -> [GlobalSearchResult] {
        do {
            let queryEnd = query + "\u{f8ff}"
            let snapshot = try await db.collection("organizations")
                .whereField("name", isGreaterThanOrEqualTo: query)
                .whereField("name", isLessThan: queryEnd)
                .limit(to: 5)
                .getDocuments()
                
            return snapshot.documents.map { doc in
                let data = doc.data()
                let name = data["name"] as? String ?? "未命名組織"
                let desc = data["description"] as? String
                return GlobalSearchResult(
                    objectID: doc.documentID,
                    title: name,
                    snippet: desc,
                    type: .organization
                )
            }
        } catch {
            print("Error searching organizations: \(error)")
            return []
        }
    }
    
    // 搜尋任務 (僅限自己有權限看到的)
    private func searchTasks(query: String) async -> [GlobalSearchResult] {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return [] }
        
        do {
            let queryEnd = query + "\u{f8ff}"
            
            // 搜尋指派給我的任務
            // 注意：Firebase 複合查詢限制較多，這裡只示範簡單標題搜尋
            // 理想情況是後端搜尋引擎，或在客戶端過濾（如果資料量小）
            
            // 這裡我們搜尋所有公開任務的一小部分並在客戶端過濾 (不推薦用於大量數據)
            // 為了演示，我們僅搜尋 "my" tasks 集合，假設有一個 user_tasks 子集合或類似結構
            // 由於 Firebase 結構限制，這裡我們搜尋全域 tasks 但限制 userId (個人任務)
            
            let personalTasksSnapshot = try await db.collection("tasks")
                .whereField("userId", isEqualTo: currentUserId)
                .whereField("title", isGreaterThanOrEqualTo: query)
                .whereField("title", isLessThan: queryEnd)
                .limit(to: 5)
                .getDocuments()
                
            return personalTasksSnapshot.documents.map { doc in
                let data = doc.data()
                let title = data["title"] as? String ?? "無標題"
                let desc = data["description"] as? String
                return GlobalSearchResult(
                    objectID: doc.documentID,
                    title: title,
                    snippet: desc,
                    type: .task
                )
            }
        } catch {
            print("Error searching tasks: \(error)")
            return []
        }
    }
}
