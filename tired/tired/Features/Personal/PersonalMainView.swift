import SwiftUI

private enum PersonalTab: Hashable {
    case home
    case feed
    case explore
    case profile
}

struct PersonalMainView: View {
    let session: AppSession
    @State private var selection: PersonalTab = .home
    @StateObject private var timelineStore: PersonalTimelineStore
    private let feedService: GlobalFeedServiceProtocol = GlobalFeedService()
    private let talentService: TalentServiceProtocol = TalentService()
    
    init(session: AppSession) {
        self.session = session
        _timelineStore = StateObject(wrappedValue: PersonalTimelineStore(user: session.user))
    }
    
    var body: some View {
        TabView(selection: $selection) {
            PersonalHomeView(session: session, timelineStore: timelineStore, talentService: talentService)
                .tabItem { Label("首頁", systemImage: "person.crop.circle") }
                .tag(PersonalTab.home)
            GlobalFeedView(session: session, membership: nil, personalTimelineStore: timelineStore, feedService: feedService)
                .tabItem { Label("探索", systemImage: "globe") }
                .tag(PersonalTab.feed)
            PersonalExploreView(session: session, feedService: feedService, talentService: talentService)
                .tabItem { Label("找機會", systemImage: "briefcase.fill") }
                .tag(PersonalTab.explore)
            NavigationStack {
                ProfileView()
            }
            .tabItem { Label("我", systemImage: "person.fill") }
            .tag(PersonalTab.profile)
        }
    }
}

private struct PersonalHomeView: View {
    let session: AppSession
    @ObservedObject var timelineStore: PersonalTimelineStore
    let talentService: TalentServiceProtocol
    
    @State private var experiences: [Experience] = []
    @State private var showComposer = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TTokens.spacingXL) {
                    welcomeCard
                    experienceSection
                    recentPostsSection
                }
                .padding(20)
            }
            .background(Color.bg.ignoresSafeArea())
            .navigationTitle("個人首頁")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showComposer = true }) {
                        Label("發佈", systemImage: "square.and.pencil")
                    }
                }
            }
            .task {
                await timelineStore.load()
                experiences = await talentService.fetchExperiences(for: session.user)
            }
            .sheet(isPresented: $showComposer) {
                PersonalPostComposerView { summary, content, category, visibility, attachments in
                    try await timelineStore.create(summary: summary, content: content, category: category, visibility: visibility, attachments: attachments)
                }
            }
        }
    }
    
    private var welcomeCard: some View {
        VStack(alignment: .leading, spacing: TTokens.spacingMD) {
            Text(session.personalProfile.headline)
                .font(.title2.weight(.semibold))
            Text(session.personalProfile.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if session.personalProfile.isOpenToWork {
                Label("開放新機會", systemImage: "briefcase.badge.plus")
                    .font(.footnote)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.12), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.card, in: RoundedRectangle(cornerRadius: TTokens.radiusLG, style: .continuous))
    }
    
    private var experienceSection: some View {
        VStack(alignment: .leading, spacing: TTokens.spacingMD) {
            HStack {
                Text("經歷與認證")
                    .font(.headline)
                Spacer()
                Button("管理") { }
                    .font(.footnote)
            }
            ForEach(experiences) { exp in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(exp.organizationName).font(.subheadline.weight(.semibold))
                        Spacer()
                        label(for: exp.verification)
                    }
                    Text(exp.role).font(.footnote)
                    Text(exp.summary).font(.footnote).foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.card, in: RoundedRectangle(cornerRadius: TTokens.radiusMD, style: .continuous))
            }
        }
    }
    
    private var recentPostsSection: some View {
        VStack(alignment: .leading, spacing: TTokens.spacingMD) {
            HStack {
                Text("最近貼文")
                    .font(.headline)
                Spacer()
                Button("發佈") { showComposer = true }
                    .font(.footnote)
            }
            if timelineStore.posts.isEmpty {
                Text("尚未發佈貼文，開始分享你的故事吧！")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(timelineStore.posts.prefix(3)) { post in
                    PostRowView(post: post)
                }
            }
        }
    }
    
    private func label(for status: Experience.VerificationStatus) -> some View {
        let (text, color, icon): (String, Color, String) = {
            switch status {
            case .pending: return ("審核中", .orange, "hourglass")
            case .verified: return ("已驗證", .green, "checkmark.seal")
            case .rejected: return ("未通過", .red, "xmark.octagon")
            }
        }()
        return Label(text, systemImage: icon)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
            .foregroundStyle(color)
    }
}

struct PostRowView: View {
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: post.sourceType == .personal ? "person.crop.circle" : "building.2")
                    .foregroundStyle(post.sourceType == .personal ? Color.blue : Color.purple)
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.authorName).font(.subheadline.weight(.semibold))
                    if let org = post.organizationName {
                        Text(org).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(post.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(post.summary)
                .font(.subheadline)
            Text(post.content)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            if !post.attachmentURLs.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(post.attachmentURLs, id: \.absoluteString) { url in
                        Link(destination: url) {
                            Label(displayName(for: url), systemImage: "link")
                        }
                        .font(.caption)
                        .foregroundStyle(.blue)
                    }
                }
            }
            HStack(spacing: 12) {
                Label(post.category.displayName, systemImage: "tag")
                Label(post.visibility.label, systemImage: "eye")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.card, in: RoundedRectangle(cornerRadius: TTokens.radiusMD, style: .continuous))
    }
}

private extension PostRowView {
    func displayName(for url: URL) -> String {
        if let host = url.host {
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return path.isEmpty ? host : "\(host)/\(path)"
        }
        return url.absoluteString
    }
}



private struct PersonalExploreView: View {
    let session: AppSession
    let feedService: GlobalFeedServiceProtocol
    let talentService: TalentServiceProtocol
    
    @State private var recommendedPosts: [Post] = []
    @State private var spotlightOrganizations: [OrganizationSuggestion] = OrganizationSuggestion.defaults
    @State private var experiences: [Experience] = []
    @State private var isLoading = false
    @State private var searchText: String = ""
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading && recommendedPosts.isEmpty && spotlightOrganizations.isEmpty {
                    ProgressView("分析你的背景…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            heroCard
                            organizationSection
                            opportunitiesSection
                            skillsSection
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 24)
                    }
                }
            }
            .navigationTitle("找機會")
            .background(Color.bg.ignoresSafeArea())
            .task {
                await loadContent()
            }
            .refreshable {
                await loadContent(force: true)
            }
            .searchable(text: $searchText, prompt: "搜尋職缺或組織")
        }
    }
    
    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("嗨，\(session.user.displayName.isEmpty ? session.user.initials : session.user.displayName)")
                .font(.title3.weight(.semibold))
            Text("根據你的經歷與偏好，這裡整理了最適合的合作機會。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if session.personalProfile.isOpenToWork {
                Label("已設定開放新機會", systemImage: "briefcase.badge.plus")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.12), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.card, in: RoundedRectangle(cornerRadius: TTokens.radiusLG, style: .continuous))
    }
    
    private var filteredOrganizations: [OrganizationSuggestion] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return spotlightOrganizations }
        let token = searchText.lowercased()
        return spotlightOrganizations.filter { suggestion in
            suggestion.name.lowercased().contains(token) ||
            suggestion.headline.lowercased().contains(token) ||
            suggestion.tags.joined(separator: " ").lowercased().contains(token)
        }
    }
    
    private var filteredOpportunities: [Post] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return recommendedPosts }
        let token = searchText.lowercased()
        return recommendedPosts.filter { post in
            post.summary.lowercased().contains(token) ||
            post.content.lowercased().contains(token) ||
            post.tags.contains(where: { $0.lowercased().contains(token) }) ||
            (post.organizationName?.lowercased().contains(token) ?? false)
        }
    }
    
    private var organizationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("推薦組織")
                    .font(.headline)
                Spacer()
                Button("管理曝光") {
                    // 未來導向個人檔案設定
                }
                .font(.footnote)
            }
            if filteredOrganizations.isEmpty {
                Text("目前沒有符合的組織，更新你的經歷或技能標籤試試看。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(filteredOrganizations) { suggestion in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(suggestion.name)
                                    .font(.subheadline.weight(.semibold))
                                Text(suggestion.headline)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                Text(suggestion.highlight)
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                                HStack {
                                    ForEach(suggestion.tags.prefix(3), id: \.self) { tag in
                                        Text(tag)
                                            .font(.caption2)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.gray.opacity(0.15), in: Capsule())
                                    }
                                }
                            }
                            .padding()
                            .frame(width: 220, alignment: .leading)
                            .background(Color.card, in: RoundedRectangle(cornerRadius: TTokens.radiusMD, style: .continuous))
                        }
                    }
                }
            }
        }
    }
    
    private var opportunitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("熱門職缺與專案")
                    .font(.headline)
                Spacer()
                Button("篩選") {
                    // TODO: 打開更進階的篩選條件
                }
                .font(.footnote)
            }
            if filteredOpportunities.isEmpty {
                Text("暫時沒有符合的公開職缺，開啟更多技能標籤試試看。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 16) {
                    ForEach(filteredOpportunities.prefix(6)) { post in
                        PostRowView(post: post)
                    }
                }
            }
        }
    }
    
    private var skillsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("技能雷達")
                .font(.headline)
            if experiences.isEmpty {
                Text("尚未同步經歷，補充職涯資訊後即可獲得專屬推薦。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(skillChips, id: \.self) { chip in
                        Text(chip)
                            .font(.caption2)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.12), in: Capsule())
                    }
                }
            }
        }
    }
    
    private var skillChips: [String] {
        var chips: [String] = []
        for experience in experiences {
            chips.append(experience.role)
            chips.append(experience.kind.displayName)
            if !experience.organizationName.isEmpty {
                chips.append(experience.organizationName)
            }
        }
        return Array(NSOrderedSet(array: chips)) as? [String] ?? chips
    }
    
    @MainActor
    private func loadContent(force: Bool = false) async {
        if isLoading && !force { return }
        isLoading = true
        defer { isLoading = false }
        async let postsTask = feedService.fetchPosts(for: session.user, filter: FeedFilter(onlyOrganizations: true))
        async let experiencesTask = talentService.fetchExperiences(for: session.user)
        let posts = await postsTask
        let experiences = await experiencesTask
        let curated = posts.filter { $0.category == .job || $0.category == .project || $0.category == .announcement }
        recommendedPosts = Array(curated.prefix(8))
        spotlightOrganizations = deriveOrganizations(from: experiences, posts: posts)
        self.experiences = experiences
    }
    
    private func deriveOrganizations(from experiences: [Experience], posts: [Post]) -> [OrganizationSuggestion] {
        var results: [OrganizationSuggestion] = []
        var seen: Set<String> = []
        for experience in experiences {
            let key = experience.organizationId ?? experience.organizationName
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            let tags = [experience.role, experience.kind.displayName]
            let highlight = experience.verification == .verified ? "已驗證經歷" : "歷史合作"
            results.append(.init(id: key, name: experience.organizationName, headline: "曾任 - \(experience.role)", tags: tags, highlight: highlight))
        }
        for post in posts where post.sourceType == .organization {
            let key = post.organizationName ?? post.sourceId
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            let tags = post.tags.isEmpty ? [post.category.displayName] : post.tags
            results.append(.init(id: key, name: post.organizationName ?? "合作夥伴", headline: post.summary, tags: Array(tags.prefix(3)), highlight: post.visibility == .public ? "公開招募" : "限定釋出"))
        }
        if results.isEmpty {
            return OrganizationSuggestion.defaults
        }
        return Array(results.prefix(8))
    }
}

private struct OrganizationSuggestion: Identifiable {
    let id: String
    let name: String
    let headline: String
    let tags: [String]
    let highlight: String
    
    static let defaults: [OrganizationSuggestion] = [
        OrganizationSuggestion(id: "tsmc", name: "台積電研發處", headline: "正在尋找熟悉 SwiftUI 與 Firebase 的實習生", tags: ["半導體", "SwiftUI", "Cloud"], highlight: "企業邀請"),
        OrganizationSuggestion(id: "puc", name: "靜宜大學創新中心", headline: "尋找產學合作夥伴，共同推進 ESG 方案", tags: ["產學合作", "ESG"], highlight: "校園合作")
    ]
}
