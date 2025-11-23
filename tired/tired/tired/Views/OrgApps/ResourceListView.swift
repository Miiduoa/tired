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
        ScrollView {
            VStack(spacing: 16) {
                // Category filter
                if !viewModel.categories.isEmpty {
                    categoryFilter
                }

                // Resources list
                LazyVStack(spacing: 12) {
                    if filteredResources.isEmpty {
                        emptyState
                    } else {
                        ForEach(filteredResources) { resource in
                            ResourceCard(
                                resource: resource,
                                onDelete: viewModel.canManage ? {
                                    _Concurrency.Task {
                                        await viewModel.deleteResource(resource)
                                    }
                                } : nil
                            )
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(appInstance.name ?? "資源列表")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.canManage {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateResource = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreateResource) {
            CreateResourceView(viewModel: viewModel)
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
    let onDelete: (() -> Void)?

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

                Spacer()

                if let onDelete = onDelete {
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                    }
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

    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("資源名稱", text: $title)

                    TextField("描述（選填）", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("資源類型") {
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

                Section("連結") {
                    TextField("資源連結 URL", text: $url)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }

                Section("分類") {
                    TextField("分類（選填）", text: $category)

                    TextField("標籤（用逗號分隔，選填）", text: $tagsText)
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

        let tags: [String]? = tagsText.isEmpty ? nil : tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        _Concurrency.Task {
            do {
                try await viewModel.createResource(
                    title: title,
                    description: description.isEmpty ? nil : description,
                    type: resourceType,
                    url: url,
                    category: category.isEmpty ? nil : category,
                    tags: tags
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
