
import SwiftUI

enum Visibility: String, CaseIterable, Identifiable {
    case `public`, friends, group, org, `private`
    var id: String { rawValue }
    var label: String {
        switch self {
        case .public: return "公開"
        case .friends: return "好友"
        case .group: return "同群成員"
        case .org: return "同組織"
        case .private: return "僅自己"
        }
    }
    var icon: String {
        switch self {
        case .public: return "globe"
        case .friends: return "person.2"
        case .group: return "person.3"
        case .org: return "building.2"
        case .private: return "lock"
        }
    }
}

struct ProfileField: Identifiable {
    var id = UUID()
    var key: String
    var value: String
    var visibility: Visibility = .group
}

struct ProfileView: View {
    @State var displayName = ProfileField(key: "顯示名稱", value: "pine", visibility: .public)
    @State var bio = ProfileField(key: "簡介", value: "資管系 / 喜歡 AI & UX", visibility: .friends)
    @State var link = ProfileField(key: "連結", value: "https://tired.app", visibility: .public)
    @State var studentId = ProfileField(key: "學號", value: "A1234567", visibility: .org)
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TTokens.spacingXL) {
                    // 英雄頭像區（漸層背景 + 玻璃態卡片）
                    HeroCard(
                        title: displayName.value,
                        subtitle: "@pine-52 · 資管系 / 喜歡 AI & UX",
                        gradient: TTokens.gradientPrimary
                    ) {
                        HStack(spacing: TTokens.spacingLG) {
                            // 漸層環形頭像
                            AvatarRing(
                                imageURL: nil,
                                size: 80,
                                ringColor: .mint,
                                ringWidth: 3
                            )
                            .shadow(color: .mint.opacity(0.5), radius: 12, y: 6)
                            
                            Spacer()
                            
                            Button {
                                HapticFeedback.light()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "camera.fill")
                                    Text("更換")
                                }
                                .font(.subheadline.weight(.medium))
                            }
                            .neumorphicButton(color: .tint, isActive: false)
                        }
                        
                        // 狀態徽章
                        HStack(spacing: 8) {
                            TagBadge("開放工作機會", color: .success, icon: "briefcase.fill")
                            TagBadge("精選創作者", color: .creative, icon: "star.fill")
                        }
                        .padding(.top, TTokens.spacingSM)
                    }
                    
                    // 可編輯欄位區（玻璃態卡片）
                    VStack(spacing: TTokens.spacingMD) {
                        GlassmorphicCard(tint: .tint) {
                            ProfileEditableField(field: $displayName)
                        }
                        
                        GlassmorphicCard(tint: .mint) {
                            ProfileEditableField(field: $bio, multiline: true)
                        }
                        
                        GlassmorphicCard(tint: .coral) {
                            ProfileEditableField(field: $link, keyboard: .URL)
                        }
                        
                        GlassmorphicCard(tint: .creative) {
                            ProfileEditableField(field: $studentId)
                        }
                    }
                    
                    // 統計資訊卡片
                    HStack(spacing: TTokens.spacingMD) {
                        StatCard(value: "256", label: "追蹤中", color: .tint)
                        StatCard(value: "1.2K", label: "追蹤者", color: .success)
                        StatCard(value: "42", label: "貼文", color: .creative)
                    }
                    
                    Spacer(minLength: TTokens.spacingXL)
                }
                .padding(TTokens.spacingLG)
            }
            .background(
                ZStack {
                    Color.bg.ignoresSafeArea()
                    GradientMeshBackground()
                        .opacity(0.3)
                        .ignoresSafeArea()
                }
            )
            .navigationTitle("我")
        }
    }
}

/// 統計卡片（Stats Card）
private struct StatCard: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(color.gradient)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, TTokens.spacingLG)
        .floatingCard()
    }
}

struct ProfileEditableField: View {
    @Binding var field: ProfileField
    var multiline: Bool = false
    var keyboard: UIKeyboardType = .default
    
    var body: some View {
        VStack(alignment: .leading, spacing: TTokens.spacingSM) {
            HStack {
                Text(field.key).font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Menu {
                    ForEach(Visibility.allCases) { v in
                        Button {
                            field.visibility = v
                        } label: {
                            Label(v.label, systemImage: v.icon)
                        }
                    }
                } label: {
                    Label(field.visibility.label, systemImage: field.visibility.icon)
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color.card, in: Capsule())
                }
            }
            if multiline {
                TextEditor(text: Binding(get: { field.value }, set: { field.value = $0 }))
                    .frame(minHeight: 80)
                    .padding(TTokens.spacingMD)
                    .background(Color.card, in: RoundedRectangle(cornerRadius: TTokens.radiusSM, style: .continuous))
            } else {
                TextField("輸入\(field.key)", text: Binding(get: { field.value }, set: { field.value = $0 }))
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(.never)
                    .padding(TTokens.spacingMD)
                    .background(Color.card, in: RoundedRectangle(cornerRadius: TTokens.radiusSM, style: .continuous))
            }
        }
    }
}
