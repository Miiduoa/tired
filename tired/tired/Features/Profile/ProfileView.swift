
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
                VStack(alignment: .leading, spacing: TTokens.spacingLG) {
                    // 頭像區
                    HStack(spacing: TTokens.spacingLG) {
                        Circle().fill(Color.card).frame(width: 72, height: 72)
                            .overlay(Image(systemName: "person.crop.circle").font(.system(size: 36)).foregroundStyle(.secondary))
                        VStack(alignment: .leading) {
                            Text(displayName.value).font(.title2).bold()
                            Text("@pine-52").foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { } label: { Image(systemName: "camera") }
                            .buttonStyle(.bordered)
                    }
                    
                    ProfileEditableField(field: $displayName)
                    ProfileEditableField(field: $bio, multiline: true)
                    ProfileEditableField(field: $link, keyboard: .URL)
                    ProfileEditableField(field: $studentId)
                    
                    Spacer(minLength: TTokens.spacingXL)
                }
                .standardPadding()
            }
            .background(Color.bg.ignoresSafeArea())
            .navigationTitle("我")
        }
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
