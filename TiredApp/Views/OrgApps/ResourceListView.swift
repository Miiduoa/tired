import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

// MARK: - Resource Model

struct OrgResource: Codable, Identifiable {
    @DocumentID var id: String?
    var organizationId: String
    var appInstanceId: String
    var title: String
    var description: String?
    var type: ResourceType
    var url: String?
    var fileSize: Int?
    var createdByUserId: String
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case organizationId
        case appInstanceId
        case title
        case description
        case type
        case url
        case fileSize
        case createdByUserId
        case createdAt
        case updatedAt
    }
}

enum ResourceType: String, Codable, CaseIterable {
    case link = "link"
    case document = "document"
    case image = "image"
    case video = "video"
    case file = "file"

    var displayName: String {
        switch self {
        case .link: return "連結"
        case .document: return "文件"
        case .image: return "圖片"
        case .video: return "影片"
        case .file: return "檔案"
        }
    }

    var icon: String {
        switch self {
        case .link: return "link"
        case .document: return "doc.text"
        case .image: return "photo"
        case .video: return "play.rectangle"
        case .file: return "folder"
        }
    }
}

// MARK: - Resource List View

@available(iOS 17.0, *)
struct ResourceListView: View {
    let appInstance: OrgAppInstance
    let organizationId: String

    @StateObject private var viewModel: ResourceListViewModel
    @State private var showingAddResource = false

    init(appInstance: OrgAppInstance, organizationId: String) {
        self.appInstance = appInstance
        self.organizationId = organizationId
        self._viewModel = StateObject(wrappedValue: ResourceListViewModel(
            appInstanceId: appInstance.id ?? "",
            organizationId: organizationId
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                VStack {
                    Spacer()
                    ProgressView("載入資源中...")
                    Spacer()
                }
            } else if viewModel.resources.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.resources) { resource in
                            ResourceCard(resource: resource, onDelete: {
                                viewModel.deleteResource(resource)
                            })
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(appInstance.name ?? "資源列表")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddResource = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showingAddResource) {
            AddResourceView(viewModel: viewModel)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "folder.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("還沒有資源")
                .font(.system(size: 18, weight: .semibold))

            Text("添加連結、文件或其他資源供成員查看")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showingAddResource = true
            } label: {
                Text("新增資源")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(20)
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Resource Card

@available(iOS 17.0, *)
struct ResourceCard: View {
    let resource: OrgResource
    let onDelete: () -> Void

    @State private var showingDeleteAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: resource.type.icon)
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                    .frame(width: 44, height: 44)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)

                VStack(alignment: .leading, spacing: 4) {
                    Text(resource.title)
                        .font(.system(size: 15, weight: .medium))

                    HStack(spacing: 8) {
                        Text(resource.type.displayName)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)

                        if let fileSize = resource.fileSize {
                            Text("·")
                                .foregroundColor(.secondary)
                            Text(formatFileSize(fileSize))
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }

                        Text("·")
                            .foregroundColor(.secondary)
                        Text(resource.createdAt.formatShort())
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Menu {
                    if let url = resource.url {
                        Button {
                            openURL(url)
                        } label: {
                            Label("打開", systemImage: "arrow.up.right.square")
                        }

                        Button {
                            copyToClipboard(url)
                        } label: {
                            Label("複製連結", systemImage: "doc.on.doc")
                        }
                    }

                    Divider()

                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("刪除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.secondary)
                        .font(.system(size: 20))
                }
            }

            if let description = resource.description, !description.isEmpty {
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(Color.appBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.appCardBorder, lineWidth: 1)
        )
        .alert("刪除資源", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("刪除", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("確定要刪除「\(resource.title)」嗎？此操作無法撤銷。")
        }
    }

    private func formatFileSize(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024
        if kb < 1024 {
            return String(format: "%.1f KB", kb)
        } else {
            let mb = kb / 1024
            return String(format: "%.1f MB", mb)
        }
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
    }
}

// MARK: - Add Resource View

@available(iOS 17.0, *)
struct AddResourceView: View {
    @ObservedObject var viewModel: ResourceListViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var url = ""
    @State private var type: ResourceType = .link
    @State private var isCreating = false

    var body: some View {
        NavigationView {
            Form {
                Section("資源信息") {
                    TextField("標題", text: $title)

                    Picker("類型", selection: $type) {
                        ForEach(ResourceType.allCases, id: \.self) { resourceType in
                            HStack {
                                Image(systemName: resourceType.icon)
                                Text(resourceType.displayName)
                            }
                            .tag(resourceType)
                        }
                    }

                    TextField("連結 URL", text: $url)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                }

                Section("描述（選填）") {
                    TextEditor(text: $description)
                        .frame(height: 80)
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
                    .disabled(title.isEmpty || url.isEmpty || isCreating)
                }
            }
        }
    }

    private func createResource() {
        isCreating = true

        Task {
            do {
                try await viewModel.createResource(
                    title: title,
                    description: description.isEmpty ? nil : description,
                    type: type,
                    url: url
                )
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("❌ Error creating resource: \(error)")
                await MainActor.run {
                    isCreating = false
                }
            }
        }
    }
}

// MARK: - Resource List ViewModel

class ResourceListViewModel: ObservableObject {
    @Published var resources: [OrgResource] = []
    @Published var isLoading = false

    private let db = FirebaseManager.shared.db
    private let appInstanceId: String
    private let organizationId: String

    private var userId: String? {
        FirebaseAuth.Auth.auth().currentUser?.uid
    }

    init(appInstanceId: String, organizationId: String) {
        self.appInstanceId = appInstanceId
        self.organizationId = organizationId
        loadResources()
    }

    func loadResources() {
        guard !appInstanceId.isEmpty else { return }

        isLoading = true

        Task {
            do {
                let snapshot = try await db.collection("orgResources")
                    .whereField("appInstanceId", isEqualTo: appInstanceId)
                    .order(by: "createdAt", descending: true)
                    .getDocuments()

                let resources = snapshot.documents.compactMap { doc -> OrgResource? in
                    try? doc.data(as: OrgResource.self)
                }

                await MainActor.run {
                    self.resources = resources
                    self.isLoading = false
                }
            } catch {
                print("❌ Error loading resources: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }

    func createResource(title: String, description: String?, type: ResourceType, url: String) async throws {
        guard let userId = userId else {
            throw NSError(domain: "ResourceListViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "用戶未登入"])
        }

        let resource = OrgResource(
            organizationId: organizationId,
            appInstanceId: appInstanceId,
            title: title,
            description: description,
            type: type,
            url: url,
            createdByUserId: userId,
            createdAt: Date(),
            updatedAt: Date()
        )

        _ = try db.collection("orgResources").addDocument(from: resource)
        loadResources()
    }

    func deleteResource(_ resource: OrgResource) {
        guard let resourceId = resource.id else { return }

        Task {
            do {
                try await db.collection("orgResources").document(resourceId).delete()
                loadResources()
            } catch {
                print("❌ Error deleting resource: \(error)")
            }
        }
    }
}
