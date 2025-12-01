import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

@available(iOS 17.0, *)
struct ResourceListView: View {
    let appInstance: OrgAppInstance
    let organizationId: String

    @StateObject private var viewModel: ResourceListViewModel
    @State private var showingCreateResource = false
    @State private var selectedCategory: String?

    init(appInstance: OrgAppInstance, organizationId: String) {
        self.appInstance = appInstance
        self.organizationId = organizationId
        self._viewModel = StateObject(wrappedValue: ResourceListViewModel(
            appInstanceId: appInstance.id ?? "",
            organizationId: organizationId
        ))
    }

    var body: some View {
        NavigationStack {
            scrollContent
                .navigationTitle(appInstance.name ?? "資源庫")
                .toolbar {
                    if viewModel.canManage {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                showingCreateResource = true
                            } label: {
                                Image(systemName: "plus")
                            }
                        }
                    }
                }
        }
        .sheet(isPresented: $showingCreateResource) {
            CreateResourceView(viewModel: viewModel)
        }
    }
    
    @ViewBuilder
    private var scrollContent: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 16) {
                if !viewModel.categories.isEmpty {
                    categoryFilter
                }

                LazyVStack(spacing: 12) {
                    if filteredResources.isEmpty {
                        emptyState
                    } else {
                        ForEach(filteredResources, id: \.id) { resource in
                            resourceCard(for: resource)
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private func resourceCard(for resource: Resource) -> some View {
        if viewModel.canManage {
            ResourceCard(
                resource: resource,
                onDelete: { () async -> Bool in
                    return await viewModel.deleteResourceAsync(resource)
                },
                organizationId: organizationId
            )
        } else {
            ResourceCard(
                resource: resource,
                onDelete: nil,
                organizationId: organizationId
            )
        }
    }

    private var filteredResources: [Resource] {
        if let category = selectedCategory {
            return viewModel.resources.filter { $0.category == category }
        }
        return viewModel.resources
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "全部",
                    isSelected: selectedCategory == nil,
                    onTap: { selectedCategory = nil }
                )

                ForEach(viewModel.categories, id: \.self) { category in
                    FilterChip(
                        title: category,
                        isSelected: selectedCategory == category,
                        onTap: { selectedCategory = category }
                    )
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("暫無資源")
                .font(.system(size: 18, weight: .semibold))

            if viewModel.canManage {
                Text("點擊右上角 + 號新增資源")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            } else {
                Text("組織管理員會在這裡分享資源")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 60)
    }

}

// MARK: - Filter Chip

@available(iOS 17.0, *)
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color.appSecondaryBackground)
                .cornerRadius(16)
        }
    }
}

// MARK: - Resource Card

@available(iOS 17.0, *)
struct ResourceCard: View {
    let resource: Resource
    let onDelete: (() async -> Bool)?
    var organizationId: String? = nil

    @State private var isDeleting = false
    @State private var showingVersionHistory = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Type icon
                Image(systemName: resource.type.iconName)
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                    .frame(width: 44, height: 44)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)

                VStack(alignment: .leading, spacing: 4) {
                    Text(resource.title)
                        .font(.system(size: 15, weight: .medium))
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Text(resource.type.displayName)
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.8))
                            .cornerRadius(4)

                        if let category = resource.category {
                            Text(category)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                // Action button
                if let url = resource.url ?? resource.fileUrl, let linkUrl = URL(string: url) {
                    Link(destination: linkUrl) {
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.blue)
                            .font(.system(size: 20))
                    }
                }
            }

            if let description = resource.description, !description.isEmpty {
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            // Tags
            if let tags = resource.tags, !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.system(size: 11))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
            }

            // Footer
            HStack {
                Text(resource.createdAt.formatShort())
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                // Moodle-like 版本資訊（P2-1）
                if resource.version > 1 {
                    Text("v\(resource.version)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppDesignSystem.accentColor)
                        .cornerRadius(4)
                }

                Spacer()

                // Moodle-like 版本歷史按鈕（P2-1）
                if let orgId = organizationId, resource.version > 1 || resource.previousVersionId != nil {
                    Button(action: {
                        showingVersionHistory = true
                    }) {
                        Label("歷史", systemImage: "clock.arrow.circlepath")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }

                if let onDelete = onDelete {
                    Button(role: .destructive) {
                        _Concurrency.Task {
                            guard !isDeleting else { return }
                            await MainActor.run { isDeleting = true }
                            let success = await onDelete()
                            if !success {
                                ToastManager.shared.showToast(message: "刪除資源失敗，請稍後再試。", type: .error)
                            }
                            await MainActor.run { isDeleting = false }
                        }
                    } label: {
                        if isDeleting {
                            ProgressView()
                        } else {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                        }
                    }
                    .disabled(isDeleting)
                }
            }
        }
        .padding()
        .background(Color.appBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.appCardBorder, lineWidth: 1)
        )
        .sheet(isPresented: $showingVersionHistory) {
            if let orgId = organizationId {
                ResourceVersionHistoryView(resource: resource, organizationId: orgId)
            }
        }
    }
}

// MARK: - Create Resource View

@available(iOS 17.0, *)
struct CreateResourceView: View {
    @ObservedObject var viewModel: ResourceListViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var resourceType: ResourceType = .link
    @State private var url = ""
    @State private var category = ""
    @State private var tagsText = ""
    @State private var isCreating = false
    @State private var showingFilePicker = false
    @State private var selectedFileData: Data?
    @State private var selectedFileName: String?
    @State private var uploadProgress: Double = 0.0

    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                SwiftUI.Section("基本信息") {
                    TextField("資源名稱", text: $title)

                    TextField("描述（選填）", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }

                SwiftUI.Section("資源類型") {
                    Picker("類型", selection: $resourceType) {
                        ForEach(ResourceType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.iconName)
                                Text(type.displayName)
                            }
                            .tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // Moodle-like 文件上傳
                if resourceType == .link {
                    SwiftUI.Section("連結") {
                        TextField("資源連結 URL", text: $url)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                    }
                } else {
                    SwiftUI.Section("檔案上傳") {
                        if let fileName = selectedFileName {
                            HStack {
                                Image(systemName: "doc.fill")
                                    .foregroundColor(.blue)
                                Text(fileName)
                                    .lineLimit(1)
                                Spacer()
                                Button(action: {
                                    selectedFileData = nil
                                    selectedFileName = nil
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else {
                            Button(action: {
                                showingFilePicker = true
                            }) {
                                HStack {
                                    Image(systemName: "doc.badge.plus")
                                    Text("選擇檔案")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        // 上傳進度
                        if isCreating && uploadProgress > 0 {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("上傳進度: \(Int(uploadProgress * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                ProgressView(value: uploadProgress)
                                    .progressViewStyle(.linear)
                            }
                        }
                    }
                }

                SwiftUI.Section("分類") {
                    TextField("分類（選填）", text: $category)

                    TextField("標籤（用逗號分隔，選填）", text: $tagsText)
                }
                }
                // Loading overlay for creation
                if isCreating {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    ProgressView("新增資源中...")
                        .padding(14)
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                }
            }
            .navigationTitle("新增資源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("新增") {
                        createResource()
                    }
                    .disabled(isFormInvalid || isCreating)
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.item],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
        }
    }

    private var isFormInvalid: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            return true
        }

        if resourceType == .link {
            return url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            return selectedFileData == nil
        }
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let fileURL = urls.first else { return }

            // 讀取文件數據
            do {
                let fileData = try Data(contentsOf: fileURL)
                selectedFileData = fileData
                selectedFileName = fileURL.lastPathComponent

                // 如果標題為空，使用文件名作為標題
                if title.isEmpty {
                    title = fileURL.deletingPathExtension().lastPathComponent
                }
            } catch {
                print("❌ Error reading file: \(error)")
                AlertHelper.shared.showError("無法讀取檔案：\(error.localizedDescription)")
            }

        case .failure(let error):
            print("❌ Error selecting file: \(error)")
            AlertHelper.shared.showError("選擇檔案失敗：\(error.localizedDescription)")
        }
    }

    private func createResource() {
        isCreating = true

        let tags: [String]? = tagsText.isEmpty ? nil : tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        _Concurrency.Task {
            do {
                var finalURL = url

                // Moodle-like 文件上傳功能
                if resourceType != .link, let fileData = selectedFileData, let fileName = selectedFileName {
                    await MainActor.run {
                        uploadProgress = 0.1
                    }

                    // 使用 StorageService.uploadResourceFile 上傳
                    let storageService = StorageService()
                    let mimeType = getMimeType(for: fileName)

                    await MainActor.run {
                        uploadProgress = 0.3
                    }

                    finalURL = try await storageService.uploadResourceFile(
                        organizationId: viewModel.organizationId,
                        fileData: fileData,
                        fileName: fileName,
                        mimeType: mimeType
                    )

                    await MainActor.run {
                        uploadProgress = 0.8
                    }
                }

                // 創建資源記錄
                try await viewModel.createResource(
                    title: title,
                    description: description.isEmpty ? nil : description,
                    type: resourceType,
                    url: finalURL,
                    category: category.isEmpty ? nil : category,
                    tags: tags
                )

                await MainActor.run {
                    uploadProgress = 1.0
                    isCreating = false
                    AlertHelper.shared.showSuccess("資源新增成功")
                    dismiss()
                }
            } catch {
                print("❌ Error creating resource: \(error)")
                await MainActor.run {
                    isCreating = false
                    uploadProgress = 0.0
                    AlertHelper.shared.showError("新增資源失敗：\(error.localizedDescription)")
                }
            }
        }
    }

    private func getMimeType(for fileName: String) -> String {
        let fileExtension = (fileName as NSString).pathExtension.lowercased()

        switch fileExtension {
        // 文檔
        case "pdf": return "application/pdf"
        case "doc": return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xls": return "application/vnd.ms-excel"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "ppt": return "application/vnd.ms-powerpoint"
        case "pptx": return "application/vnd.openxmlformats-officedocument.presentationml.presentation"

        // 圖片
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"

        // 影片
        case "mp4": return "video/mp4"
        case "mov": return "video/quicktime"
        case "avi": return "video/x-msvideo"

        // 音訊
        case "mp3": return "audio/mpeg"
        case "wav": return "audio/wav"

        // 壓縮檔
        case "zip": return "application/zip"
        case "rar": return "application/x-rar-compressed"

        // 文本
        case "txt": return "text/plain"
        case "html": return "text/html"
        case "css": return "text/css"
        case "js": return "text/javascript"

        default: return "application/octet-stream"
        }
    }
}

