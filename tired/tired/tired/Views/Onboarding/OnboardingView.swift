import SwiftUI

@available(iOS 17.0, *)
struct OnboardingView: View {
    @Binding var showOnboarding: Bool
    @State private var currentPage = 0
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "checkmark.circle.fill",
            iconColor: .green,
            title: "歡迎使用 Tired",
            subtitle: "多身份任務中樞",
            description: "從學校、工作到社團，用同一個節奏管理待辦與活動。告別多個 App 的混亂，讓生活更有條理。"
        ),
        OnboardingPage(
            icon: "person.3.fill",
            iconColor: .blue,
            title: "多重身份管理",
            subtitle: "一個 App，多種角色",
            description: "加入不同的組織，切換不同的身份。無論是學生、員工還是社團成員，都能輕鬆管理各自的任務。"
        ),
        OnboardingPage(
            icon: "wand.and.stars",
            iconColor: .purple,
            title: "智能自動排程",
            subtitle: "讓 AI 幫你安排",
            description: "基於任務的優先級和截止日期，自動將待辦事項分配到每一天，避免工作過載。"
        ),
        OnboardingPage(
            icon: "bell.badge.fill",
            iconColor: .orange,
            title: "智能提醒",
            subtitle: "永不錯過重要事項",
            description: "為每個任務設定提醒，在最佳時機收到通知，確保你始終掌控進度。"
        ),
        OnboardingPage(
            icon: "chart.bar.fill",
            iconColor: .cyan,
            title: "追蹤進度",
            subtitle: "可視化你的成就",
            description: "查看完成統計、獲得成就徽章，讓每次完成任務都成為一次小小的慶祝。"
        )
    ]
    
    var body: some View {
        ZStack {
            // 背景
            LinearGradient(
                colors: [
                    Color(hex: pages[currentPage].iconColor.description).opacity(0.1),
                    Color.appPrimaryBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: currentPage)
            
            VStack(spacing: 0) {
                // 跳過按鈕
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button("跳過") {
                            completeOnboarding()
                        }
                        .foregroundColor(.secondary)
                        .padding()
                    }
                }
                
                // 頁面內容
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // 頁面指示器
                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? pages[currentPage].iconColor : Color.gray.opacity(0.3))
                            .frame(width: index == currentPage ? 10 : 8, height: index == currentPage ? 10 : 8)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                .padding(.vertical, 20)
                
                // 按鈕
                VStack(spacing: 12) {
                    Button {
                        if currentPage < pages.count - 1 {
                            withAnimation(.spring(response: 0.4)) {
                                currentPage += 1
                            }
                        } else {
                            completeOnboarding()
                        }
                    } label: {
                        Text(currentPage < pages.count - 1 ? "繼續" : "開始使用")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(pages[currentPage].iconColor)
                            .cornerRadius(14)
                    }
                    .buttonStyle(.plain)
                    
                    if currentPage > 0 {
                        Button("返回") {
                            withAnimation(.spring(response: 0.4)) {
                                currentPage -= 1
                            }
                        }
                        .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
    
    private func completeOnboarding() {
        hasSeenOnboarding = true
        withAnimation(.spring(response: 0.3)) {
            showOnboarding = false
        }
    }
}

// MARK: - Onboarding Page Model

struct OnboardingPage {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let description: String
}

// MARK: - Onboarding Page View

@available(iOS 17.0, *)
struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // 圖標
            ZStack {
                Circle()
                    .fill(page.iconColor.opacity(0.15))
                    .frame(width: 140, height: 140)
                
                Image(systemName: page.icon)
                    .font(.system(size: 60, weight: .semibold))
                    .foregroundColor(page.iconColor)
            }
            
            // 標題區域
            VStack(spacing: 8) {
                Text(page.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(page.subtitle)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(page.iconColor)
                    .multilineTextAlignment(.center)
            }
            
            // 描述
            Text(page.description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
            Spacer()
        }
        .padding()
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(showOnboarding: .constant(true))
    }
}

