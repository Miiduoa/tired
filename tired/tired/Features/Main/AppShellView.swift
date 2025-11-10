import SwiftUI

// 輕量殼層：直接承載新版 MainAppView，確保登入後呈現現代化 UI
struct AppShellView: View {
    var body: some View {
        MainAppView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.bg.ignoresSafeArea(.all))
    }
}

// 舊版 OrganizationShellView/GroupsTab 不再使用，統一走 MainAppView 的現代化路由
