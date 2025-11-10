import SwiftUI

// MARK: - 🎨 現代化頁面模板（批量升級助手）

/// 標準列表頁模板
struct ModernListPage<Item: Identifiable, Content: View>: View {
    let title: String
    let items: [Item]
    let isLoading: Bool
    let emptyTitle: String
    let emptySubtitle: String
    let emptyIcon: String
    @ViewBuilder let content: (Int, Item) -> Content
    let onRefresh: (() async -> Void)?
    let toolbarContent: (() -> AnyView)?
    
    init(
        title: String,
        items: [Item],
        isLoading: Bool = false,
        emptyTitle: String = "沒有內容",
        emptySubtitle: String = "稍後再來看看",
        emptyIcon: String = "tray",
        @ViewBuilder content: @escaping (Int, Item) -> Content,
        onRefresh: (() async -> Void)? = nil,
        toolbarContent: (() -> AnyView)? = nil
    ) {
        self.title = title
        self.items = items
        self.isLoading = isLoading
        self.emptyTitle = emptyTitle
        self.emptySubtitle = emptySubtitle
        self.emptyIcon = emptyIcon
        self.content = content
        self.onRefresh = onRefresh
        self.toolbarContent = toolbarContent
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                Color.bg.ignoresSafeArea()
                GradientMeshBackground()
                    .opacity(0.2)
                    .ignoresSafeArea()
                
                // 內容
                Group {
                    if isLoading && items.isEmpty {
                        loadingView
                    } else if items.isEmpty {
                        AppEmptyStateView(
                            systemImage: emptyIcon,
                            title: emptyTitle,
                            subtitle: emptySubtitle
                        )
                    } else {
                        listView
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if let toolbar = toolbarContent {
                    toolbar()
                }
            }
        }
    }
    
    private var loadingView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(0..<5, id: \.self) { index in
                    SkeletonCard()
                        .padding(.horizontal, 16)
                        .transition(.scale.combined(with: .opacity))
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.8)
                                .delay(Double(index) * 0.08),
                            value: isLoading
                        )
                }
            }
            .padding(.top, 12)
        }
    }
    
    private var listView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    content(index, item)
                        .padding(.horizontal, 16)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.95).combined(with: .opacity),
                            removal: .scale(scale: 0.98).combined(with: .opacity)
                        ))
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.8)
                                .delay(Double(index % 10) * 0.04),
                            value: items.count
                        )
                }
            }
            .padding(.top, 12)
        }
        .refreshable {
            if let refresh = onRefresh {
                await refresh()
            }
        }
    }
}

/// 標準詳情頁模板
struct ModernDetailPage<Content: View>: View {
    let title: String
    let gradient: LinearGradient
    @ViewBuilder let headerContent: Content
    @ViewBuilder let bodyContent: Content
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: TTokens.spacingXL) {
                    // 英雄區域
                    HeroCard(
                        title: title,
                        subtitle: nil,
                        gradient: gradient
                    ) {
                        headerContent
                    }
                    .padding(.horizontal, 16)
                    
                    // 主要內容
                    bodyContent
                        .padding(.horizontal, 16)
                }
                .padding(.vertical, 16)
            }
            .background {
                ZStack {
                    Color.bg.ignoresSafeArea()
                    GradientMeshBackground()
                        .opacity(0.3)
                        .ignoresSafeArea()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// 標準表單頁模板
struct ModernFormPage<Content: View>: View {
    let title: String
    let submitTitle: String
    let isSubmitting: Bool
    let canSubmit: Bool
    @ViewBuilder let content: Content
    let onSubmit: () -> Void
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: TTokens.spacingLG) {
                    content
                    
                    // 提交按鈕
                    Button(action: {
                        HapticFeedback.medium()
                        onSubmit()
                    }) {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            } else {
                                Text(submitTitle)
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: TTokens.touchTargetComfortable)
                    }
                    .fluidButton(gradient: canSubmit ? TTokens.gradientPrimary : LinearGradient(colors: [Color.gray.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .disabled(!canSubmit || isSubmitting)
                }
                .padding(TTokens.spacingLG)
            }
            .background {
                ZStack {
                    Color.bg.ignoresSafeArea()
                    GradientMeshBackground()
                        .opacity(0.2)
                        .ignoresSafeArea()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// 標準儀表板頁模板
struct ModernDashboardPage<Content: View>: View {
    let title: String
    let statsCards: [StatCardData]
    @ViewBuilder let content: Content
    
    struct StatCardData: Identifiable {
        let id = UUID()
        let value: String
        let label: String
        let color: Color
        let icon: String
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TTokens.spacingXL) {
                    // 統計卡片組
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: TTokens.spacingMD) {
                        ForEach(statsCards) { stat in
                            VStack(spacing: TTokens.spacingSM) {
                                HStack {
                                    Image(systemName: stat.icon)
                                        .font(.title3)
                                        .foregroundStyle(stat.color)
                                    Spacer()
                                }
                                
                                Text(stat.value)
                                    .font(.title.weight(.bold))
                                    .foregroundStyle(stat.color.gradient)
                                
                                Text(stat.label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(TTokens.spacingLG)
                            .floatingCard()
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    // 主要內容
                    content
                        .padding(.horizontal, 16)
                }
                .padding(.vertical, 16)
            }
            .background {
                ZStack {
                    Color.bg.ignoresSafeArea()
                    GradientMeshBackground()
                        .opacity(0.3)
                        .ignoresSafeArea()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - 通用列表項組件

/// 現代化列表行
struct ModernListRow<Content: View>: View {
    let title: String
    let subtitle: String?
    let leadingIcon: String?
    let leadingColor: Color
    let trailingText: String?
    let badge: String?
    @ViewBuilder let content: Content
    
    init(
        title: String,
        subtitle: String? = nil,
        leadingIcon: String? = nil,
        leadingColor: Color = .tint,
        trailingText: String? = nil,
        badge: String? = nil,
        @ViewBuilder content: () -> Content = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leadingIcon = leadingIcon
        self.leadingColor = leadingColor
        self.trailingText = trailingText
        self.badge = badge
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: TTokens.spacingMD) {
            HStack(spacing: TTokens.spacingMD) {
                // 前置圖標
                if let icon = leadingIcon {
                    ZStack {
                        Circle()
                            .fill(leadingColor.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: icon)
                            .font(.title3)
                            .foregroundStyle(leadingColor)
                    }
                }
                
                // 標題和副標題
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.labelPrimary)
                        
                        if let badge {
                            Text(badge)
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(leadingColor.opacity(0.15), in: Capsule())
                                .foregroundStyle(leadingColor)
                        }
                    }
                    
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // 尾部文字
                if let trailing = trailingText {
                    Text(trailing)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // 箭頭
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            
            // 自定義內容
            content
        }
        .padding(TTokens.spacingLG)
        .floatingCard()
    }
}

// MARK: - 通用表單欄位組件

/// 現代化表單欄位
struct ModernFormField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let icon: String?
    let keyboardType: UIKeyboardType
    let isSecure: Bool
    
    init(
        title: String,
        placeholder: String = "",
        text: Binding<String>,
        icon: String? = nil,
        keyboardType: UIKeyboardType = .default,
        isSecure: Bool = false
    ) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
        self.keyboardType = keyboardType
        self.isSecure = isSecure
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: TTokens.spacingSM) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            
            HStack(spacing: TTokens.spacingMD) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                }
                
                Group {
                    if isSecure {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .keyboardType(keyboardType)
                .font(.body)
            }
            .padding(TTokens.spacingMD)
            .background(Color.card, in: RoundedRectangle(cornerRadius: TTokens.radiusMD, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: TTokens.radiusMD, style: .continuous)
                    .strokeBorder(Color.separator.opacity(0.5), lineWidth: 0.5)
            }
        }
    }
}

