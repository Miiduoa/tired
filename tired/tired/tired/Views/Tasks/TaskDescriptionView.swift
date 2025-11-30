import SwiftUI

/// 任務描述輸入視圖，支持多行文本輸入
@available(iOS 17.0, *)
struct TaskDescriptionView: View {
    @Binding var description: String
    @FocusState private var isFocused: Bool
    @State private var textHeight: CGFloat = 100
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("描述")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                if !description.isEmpty {
                    Button {
                        description = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                    }
                }
            }
            
            ZStack(alignment: .topLeading) {
                if description.isEmpty {
                    Text("輸入任務描述（選填）")
                        .foregroundColor(.secondary.opacity(0.6))
                        .font(AppDesignSystem.bodyFont)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 12)
                }
                
                TextEditor(text: $description)
                    .font(AppDesignSystem.bodyFont)
                    .frame(minHeight: 100, maxHeight: 200)
                    .scrollContentBackground(.hidden)
                    .focused($isFocused)
                    .onChange(of: description) {
                        // 限制最大長度
                        if description.count > 1000 {
                            description = String(description.prefix(1000))
                        }
                    }
            }
            .padding(AppDesignSystem.paddingMedium)
            .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusSmall)
            
            if !description.isEmpty {
                HStack {
                    Spacer()
                    Text("\(description.count)/1000")
                        .font(AppDesignSystem.captionFont)
                        .foregroundColor(description.count > 900 ? .orange : .secondary)
                }
            }
        }
    }
}





