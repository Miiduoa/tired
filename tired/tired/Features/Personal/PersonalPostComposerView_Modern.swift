import SwiftUI

// MARK: - 🎨 現代化發文編輯器

struct PersonalPostComposerView_Modern: View {
    @Environment(\.dismiss) private var dismiss
    @State private var summary: String = ""
    @State private var content: String = ""
    @State private var category: PostCategory = .general
    @State private var visibility: PostVisibility = .public
    @State private var attachmentDraft: String = ""
    @State private var attachments: [AttachmentItem] = []
    @State private var summaryError: String?
    @State private var contentError: String?
    @State private var attachmentError: String?
    @State private var isSubmitting = false
    @State private var submissionError: String?
    @FocusState private var focusedField: Field?
    let onSubmit: (String, String, PostCategory, PostVisibility, [URL]) async throws -> Void
    
    private enum Field: Hashable {
        case summary
        case content
        case attachment
    }
    
    private struct AttachmentItem: Identifiable, Hashable {
        let id = UUID()
        let url: URL
        
        var displayName: String {
            if let host = url.host {
                let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                return path.isEmpty ? host : "\(host)/\(path)"
            }
            return url.absoluteString
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 現代化背景
                Color.bg.ignoresSafeArea()
                GradientMeshBackground()
                    .opacity(0.1)
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: TTokens.spacingXL) {
                        summarySection
                        contentSection
                        categorySection
                        visibilitySection
                        attachmentSection
                    }
                    .padding(16)
                }
            }
            .navigationTitle("發佈貼文")
            .navigationBarTitleDisplayMode(.large)
            .alert("發佈失敗", isPresented: Binding<Bool>(get: { submissionError != nil }, set: { isPresented in
                if !isPresented { submissionError = nil }
            })) {
                Button("知道了", role: .cancel) { submissionError = nil }
            } message: {
                Text(submissionError ?? "")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        HapticFeedback.selection()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(Color.tint)
                    } else {
                        Button {
                            HapticFeedback.medium()
                            Task { await submit() }
                        } label: {
                            Text("發佈")
                                .fontWeight(.semibold)
                        }
                        .disabled(!canSubmit)
                    }
                }
            }
        }
    }
    
    // MARK: - 摘要區
    
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: TTokens.spacingMD) {
            Label("重點摘要", systemImage: "text.quote")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            
            TextField("一句話描述重點", text: $summary)
                .font(.body)
                .padding(TTokens.spacingLG)
                .floatingCard()
                .onChange(of: summary) { newValue in
                    summary = String(newValue.prefix(80))
                    if summaryError != nil { summaryError = nil }
                }
            
            HStack {
                Text("\(summary.count)/80 字")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                
                Spacer()
                
                if let summaryError {
                    Text(summaryError)
                        .font(.caption)
                        .foregroundStyle(Color.danger)
                }
            }
        }
    }
    
    // MARK: - 內容區
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: TTokens.spacingMD) {
            Label("內容", systemImage: "text.alignleft")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            
            ZStack(alignment: .topLeading) {
                if content.isEmpty {
                    Text("詳細描述讓更多人理解你的內容")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(TTokens.spacingLG)
                }
                
                TextEditor(text: $content)
                    .font(.body)
                    .frame(minHeight: 200)
                    .focused($focusedField, equals: .content)
                    .scrollContentBackground(.hidden)
                    .onChange(of: content) { _ in
                        if contentError != nil { contentError = nil }
                    }
            }
            .padding(4)
            .floatingCard()
            
            HStack {
                Text("至少 10 個字")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                
                Spacer()
                
                if let contentError {
                    Text(contentError)
                        .font(.caption)
                        .foregroundColor(Color.danger)
                }
            }
        }
    }
    
    // MARK: - 分類區
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: TTokens.spacingMD) {
            Label("分類", systemImage: "tag.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(PostCategory.allCases) { item in
                    Button {
                        HapticFeedback.selection()
                        category = item
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "tag.fill")
                                .font(.title3)
                            
                            Text(item.displayName)
                                .font(.caption.weight(.medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, TTokens.spacingMD)
                        .foregroundStyle(category == item ? .white : .labelPrimary)
                        .background {
                            if category == item {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(TTokens.gradientPrimary)
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.neutralLight.opacity(0.3))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - 可見度區
    
    private var visibilitySection: some View {
        VStack(alignment: .leading, spacing: TTokens.spacingMD) {
            Label("可見度", systemImage: "eye.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(PostVisibility.allCases) { item in
                    Button {
                        HapticFeedback.selection()
                        visibility = item
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: item.icon)
                                .font(.title3)
                            
                            Text(item.label)
                                .font(.subheadline.weight(.medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, TTokens.spacingMD)
                        .foregroundStyle(visibility == item ? .white : .labelPrimary)
                        .background {
                            if visibility == item {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(TTokens.gradientCreative)
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.neutralLight.opacity(0.3))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - 附件區
    
    private var attachmentSection: some View {
        VStack(alignment: .leading, spacing: TTokens.spacingMD) {
            Label("附件", systemImage: "paperclip")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            
            if !attachments.isEmpty {
                LazyVStack(spacing: 8) {
                    ForEach(attachments) { attachment in
                        HStack(spacing: TTokens.spacingMD) {
                            Image(systemName: "link.circle.fill")
                                .foregroundStyle(.tint)
                            
                            Text(attachment.displayName)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            Spacer()
                            
                            Button {
                                HapticFeedback.light()
                                removeAttachment(attachment)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(TTokens.spacingMD)
                        .glassEffect(intensity: 0.5)
                    }
                }
            }
            
            HStack(spacing: TTokens.spacingMD) {
                HStack(spacing: TTokens.spacingSM) {
                    Image(systemName: "link")
                        .foregroundStyle(.tertiary)
                    
                    TextField("貼上網址", text: $attachmentDraft)
                        .font(.body)
                        .focused($focusedField, equals: .attachment)
                        .onChange(of: attachmentDraft) { _ in
                            if attachmentError != nil { attachmentError = nil }
                        }
                }
                .padding(TTokens.spacingLG)
                .floatingCard()
                
                Button {
                    HapticFeedback.light()
                    addAttachment()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(TTokens.gradientPrimary)
                }
                .disabled(attachmentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            
            if let attachmentError {
                Text(attachmentError)
                    .font(.caption)
                    .foregroundColor(Color.danger)
            } else {
                Text("可選填，提供作品集、社群或活動報名連結")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
    
    // MARK: - 邏輯方法
    
    private var trimmedSummary: String {
        summary.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var trimmedContent: String {
        content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var canSubmit: Bool {
        !isSubmitting && !trimmedSummary.isEmpty && !trimmedContent.isEmpty
    }
    
    @MainActor
    private func submit() async {
        guard validate() else { return }
        isSubmitting = true
        do {
            try await onSubmit(trimmedSummary, trimmedContent, category, visibility, attachments.map { $0.url })
            isSubmitting = false
            HapticFeedback.success()
            dismiss()
        } catch {
            isSubmitting = false
            HapticFeedback.error()
            submissionError = error.localizedDescription
        }
    }
    
    private func validate() -> Bool {
        summaryError = trimmedSummary.count >= 4 ? nil : "摘要至少需要 4 個字元"
        contentError = trimmedContent.count >= 10 ? nil : "內容至少需要 10 個字元"
        return summaryError == nil && contentError == nil
    }
    
    private func addAttachment() {
        let trimmed = attachmentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            attachmentError = "請輸入附件網址"
            return
        }
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            attachmentError = "請輸入有效的網址"
            return
        }
        if attachments.contains(where: { $0.url == url }) {
            attachmentError = "附件已存在"
            return
        }
        attachments.append(AttachmentItem(url: url))
        attachmentDraft = ""
        attachmentError = nil
        HapticFeedback.success()
    }
    
    private func removeAttachment(_ attachment: AttachmentItem) {
        attachments.removeAll { $0 == attachment }
    }
}

// MARK: - 表單字段組件已在 PageTemplates.swift 中定義，此處移除重複
