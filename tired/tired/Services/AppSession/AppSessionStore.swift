
import Foundation
import Combine
import SwiftUI

@MainActor
final class AppSessionStore: ObservableObject {
    enum State {
        case loading
        case signedOut
        case ready(AppSession)
        case error(String)
        
        var identifier: String {
            switch self {
            case .loading: return "loading"
            case .signedOut: return "signedOut"
            case .ready(let session): 
                let membershipId = session.activeMembership?.id ?? "none"
                return "ready_\(session.user.id)_\(membershipId)"
            case .error(let message): return "error_\(message)"
            }
        }
    }
    
    @Published private(set) var state: State = .loading
    @Published private(set) var isLoadingMemberships = false
    
    let authService: AuthService
    private let tenantService: TenantServiceProtocol
    private var cancellables: Set<AnyCancellable> = []
    private var lastLoadTime: Date?
    private let cacheValidityDuration: TimeInterval = 60 // 60秒緩存
    private let sessionStorage = AppSessionStorage()
    
    init(authService: AuthService? = nil, tenantService: TenantServiceProtocol? = nil) {
        self.authService = authService ?? AuthService()
        self.tenantService = tenantService ?? TenantService()
        bindAuthChanges()
    }
    
    private func bindAuthChanges() {
        authService.$currentUser
            .removeDuplicates { $0?.id == $1?.id }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                guard let self else { return }
                Task { await self.handleAuthChange(user: user) }
            }
            .store(in: &cancellables)
    }
    
    private func handleAuthChange(user: User?) async {
        guard let user else {
            state = .signedOut
            lastLoadTime = nil
            return
        }

        // 若有本地快取的會話，先樂觀展示，提升離線/冷啟動體驗
        if case .loading = state, let cached = sessionStorage.load(for: user.id) {
            state = .ready(cached)
        }

        // 如果已有緩存且仍在有效期內，且狀態是 ready，則不需要重新載入
        if case .ready(let session) = state,
           session.user.id == user.id,
           let lastLoad = lastLoadTime,
           Date().timeIntervalSince(lastLoad) < cacheValidityDuration {
            return
        }

        await loadMemberships(for: user, forceRefresh: false)
    }
    
    func refreshMemberships(force: Bool = false) async {
        guard let user = authService.currentUser else {
            state = .signedOut
            lastLoadTime = nil
            return
        }
        await loadMemberships(for: user, forceRefresh: force)
    }
    
    func switchActiveMembership(to membershipId: String) {
        guard case .ready(var session) = state else { return }
        guard let selected = session.allMemberships.first(where: { $0.id == membershipId }) else { return }
        
        // 避免不必要的狀態更新
        guard selected.id != (session.activeMembership?.id ?? "") else { return }
        
        session.activeMembership = selected
        state = .ready(session)
    }
    
    private func loadMemberships(for user: User, forceRefresh: Bool) async {
        // 防止並發載入
        guard !isLoadingMemberships || forceRefresh else { return }
        
        isLoadingMemberships = true
        defer { isLoadingMemberships = false }
        
        // 如果不強制刷新且有緩存，使用緩存
        if !forceRefresh,
           case .ready(let session) = state,
           session.user.id == user.id,
           let lastLoad = lastLoadTime,
           Date().timeIntervalSince(lastLoad) < cacheValidityDuration {
            return
        }
        
        state = .loading
        
        do {
            let memberships = try await tenantService.fetchMemberships(for: user)
            
            // 驗證數據有效性
            guard !memberships.isEmpty else {
                state = .error("您目前不屬於任何租戶，請聯繫管理員")
                return
            }
            
            let profile = PersonalProfile.default(for: user)
            
            // 保持當前選擇的 membership（如果存在）
            let activeMembership: TenantMembership?
            if case .ready(let oldSession) = state,
               let oldActive = oldSession.activeMembership,
               let existing = memberships.first(where: { $0.id == oldActive.id }) {
                activeMembership = existing
            } else {
                activeMembership = memberships.first
            }
            
            let session = AppSession(
                user: user,
                activeMembership: activeMembership,
                allMemberships: memberships,
                personalProfile: profile
            )

            withAnimation {
                state = .ready(session)
            }

            lastLoadTime = Date()
            sessionStorage.save(session, for: user.id)
        } catch {
            // 如果之前有有效的 session，保持它；否則顯示錯誤
            if case .ready = state {
                // 保持舊狀態，不更新
                print("⚠️ 刷新租戶資訊失敗，使用緩存數據：\(error.localizedDescription)")
            } else if let cached = sessionStorage.load(for: user.id) {
                print("⚠️ 載入租戶資訊失敗，回退至本地快取會話。\n原因：\(error.localizedDescription)")
                state = .ready(cached)
            } else {
                state = .error("載入租戶資訊失敗：\(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Local session persistence per user

private final class AppSessionStorage {
    private func key(for userId: String) -> String { "AppSession.\(userId)" }
    
    func save(_ session: AppSession, for userId: String) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        UserDefaults.standard.set(data, forKey: key(for: userId))
    }
    
    func load(for userId: String) -> AppSession? {
        guard let data = UserDefaults.standard.data(forKey: key(for: userId)) else { return nil }
        return try? JSONDecoder().decode(AppSession.self, from: data)
    }
}
