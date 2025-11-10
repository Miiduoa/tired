import SwiftUI
import Foundation
import Combine

// MARK: - Deep Link Types

enum DeepLink: Hashable {
    case broadcast(String)  // broadcast/[id]
    case attendance(String) // attendance/[sessionId]
    case clock(String)      // clock/[siteId]
    case esg               // esg
    case activity(String)  // activity/[eventId]
    case profile(String)   // profile/[userId]
    case chat(String)      // chat/[conversationId]
    case post(String)      // post/[postId]
    case search(String)    // search?q=[query]
    case settings          // settings
    case notifications     // notifications
}

// MARK: - Deep Link Router

@MainActor
final class DeepLinkRouter: ObservableObject {
    static let shared = DeepLinkRouter()
    
    @Published var activeLink: DeepLink?
    @Published var showLinkHandler = false
    
    private init() {}
    
    /// 處理傳入的 URL
    func handle(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return
        }
        
        // 支持的 URL schemes: tired://  或 https://tired.app/
        guard url.scheme == "tired" || (url.scheme == "https" && url.host == "tired.app") else {
            return
        }
        
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let pathComponents = path.components(separatedBy: "/")
        
        guard !pathComponents.isEmpty else {
            return
        }
        
        let deepLink: DeepLink?
        
        switch pathComponents[0] {
        case "broadcast":
            if pathComponents.count > 1 {
                deepLink = .broadcast(pathComponents[1])
            } else {
                deepLink = nil
            }
            
        case "attendance":
            if pathComponents.count > 1 {
                deepLink = .attendance(pathComponents[1])
            } else {
                deepLink = nil
            }
            
        case "clock":
            if pathComponents.count > 1 {
                deepLink = .clock(pathComponents[1])
            } else {
                deepLink = nil
            }
            
        case "esg":
            deepLink = .esg
            
        case "activity":
            if pathComponents.count > 1 {
                deepLink = .activity(pathComponents[1])
            } else {
                deepLink = nil
            }
            
        case "profile":
            if pathComponents.count > 1 {
                deepLink = .profile(pathComponents[1])
            } else {
                deepLink = nil
            }
            
        case "chat":
            if pathComponents.count > 1 {
                deepLink = .chat(pathComponents[1])
            } else {
                deepLink = nil
            }
            
        case "post":
            if pathComponents.count > 1 {
                deepLink = .post(pathComponents[1])
            } else {
                deepLink = nil
            }
            
        case "search":
            if let query = components.queryItems?.first(where: { $0.name == "q" })?.value {
                deepLink = .search(query)
            } else {
                deepLink = nil
            }
            
        case "settings":
            deepLink = .settings
            
        case "notifications":
            deepLink = .notifications
            
        default:
            deepLink = nil
        }
        
        if let deepLink = deepLink {
            activeLink = deepLink
            showLinkHandler = true
            
            // 觸覺反饋
            HapticFeedback.light()
            
            // 顯示提示
            ToastCenter.shared.show("正在打開...", style: .info)
        }
    }
    
    /// 生成深度連結 URL
    static func generateURL(for link: DeepLink) -> URL? {
        let baseURL = "tired://"
        let path: String
        
        switch link {
        case .broadcast(let id):
            path = "broadcast/\(id)"
        case .attendance(let sessionId):
            path = "attendance/\(sessionId)"
        case .clock(let siteId):
            path = "clock/\(siteId)"
        case .esg:
            path = "esg"
        case .activity(let eventId):
            path = "activity/\(eventId)"
        case .profile(let userId):
            path = "profile/\(userId)"
        case .chat(let conversationId):
            path = "chat/\(conversationId)"
        case .post(let postId):
            path = "post/\(postId)"
        case .search(let query):
            path = "search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        case .settings:
            path = "settings"
        case .notifications:
            path = "notifications"
        }
        
        return URL(string: baseURL + path)
    }
    
    /// 分享深度連結
    static func share(_ link: DeepLink, from view: UIView) {
        guard let url = generateURL(for: link) else { return }
        
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            // iPad 支持
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = view
                popover.sourceRect = view.bounds
            }
            
            rootVC.present(activityVC, animated: true)
        }
    }
    
    /// 清除當前深度連結
    func clear() {
        activeLink = nil
        showLinkHandler = false
    }
}

// MARK: - Deep Link Handler View

struct DeepLinkHandlerView: View {
    @EnvironmentObject private var router: DeepLinkRouter
    @EnvironmentObject private var sessionStore: AppSessionStore
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("載入中...")
            } else if let link = router.activeLink {
                destinationView(for: link)
            } else {
                Text("無效的連結")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("深度連結")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("關閉") {
                    router.clear()
                    dismiss()
                }
            }
        }
        .task {
            // 模擬加載
            try? await Task.sleep(nanoseconds: 500_000_000)
            isLoading = false
        }
    }
    
    @ViewBuilder
    private func destinationView(for link: DeepLink) -> some View {
        switch link {
        case .broadcast(let id):
            if case .ready(let session) = sessionStore.state,
               let membership = session.activeMembership {
                // Mock broadcast
                let broadcast = BroadcastListItem(
                    id: id,
                    title: "公告詳情",
                    body: "這是從深度連結打開的公告",
                    deadline: nil,
                    requiresAck: false,
                    acked: false,
                    eventId: nil
                )
                BroadcastDetailView_Modern(broadcast: broadcast, membership: membership)
            } else {
                Text("需要登入")
            }
            
        case .attendance(let sessionId):
            Text("點名會話：\(sessionId)")
            // TODO: Navigate to attendance session
            
        case .clock(let siteId):
            Text("打卡據點：\(siteId)")
            // TODO: Navigate to clock location
            
        case .esg:
            Text("ESG 管理")
            // TODO: Navigate to ESG overview
            
        case .activity(let eventId):
            Text("活動：\(eventId)")
            // TODO: Navigate to event details
            
        case .profile(let userId):
            Text("用戶資料：\(userId)")
            // TODO: Navigate to user profile
            
        case .chat(let conversationId):
            Text("對話：\(conversationId)")
            // TODO: Navigate to chat thread
            
        case .post(let postId):
            Text("文章：\(postId)")
            // TODO: Navigate to post detail
            
        case .search(let query):
            if case .ready = sessionStore.state {
                GlobalSearchView()
            } else {
                Text("需要登入")
            }
            
        case .settings:
            SettingsView()
            
        case .notifications:
            Text("通知中心")
            // TODO: Navigate to notifications
        }
    }
}

// MARK: - Deep Link Button (for testing)

struct DeepLinkButton: View {
    let link: DeepLink
    let title: String
    
    var body: some View {
        Button {
            if let url = DeepLinkRouter.generateURL(for: link) {
                DeepLinkRouter.shared.handle(url)
            }
        } label: {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: "link")
                    .foregroundStyle(Color.tint)
            }
            .padding(TTokens.spacingMD)
            .background {
                RoundedRectangle(cornerRadius: TTokens.radiusMD)
                    .fill(.ultraThinMaterial)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Universal Link Handler

extension DeepLinkRouter {
    /// 處理 Universal Link (從外部打開應用)
    static func handleUniversalLink(_ url: URL) -> Bool {
        DeepLinkRouter.shared.handle(url)
        return true
    }
    
    /// 處理推播通知點擊
    static func handleNotification(userInfo: [AnyHashable: Any]) {
        // 從通知 payload 解析深度連結
        if let linkString = userInfo["deepLink"] as? String,
           let url = URL(string: linkString) {
            DeepLinkRouter.shared.handle(url)
        }
    }
}

// MARK: - View Extension

extension View {
    func handleDeepLinks() -> some View {
        self
            .environmentObject(DeepLinkRouter.shared)
            .sheet(isPresented: Binding(
                get: { DeepLinkRouter.shared.showLinkHandler },
                set: { if !$0 { DeepLinkRouter.shared.clear() } }
            )) {
                NavigationStack {
                    DeepLinkHandlerView()
                        .environmentObject(DeepLinkRouter.shared)
                }
            }
            .onOpenURL { url in
                DeepLinkRouter.shared.handle(url)
            }
    }
}
