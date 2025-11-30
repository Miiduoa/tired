import SwiftUI

/// 任務模板選擇視圖
@available(iOS 17.0, *)
struct TemplatePickerView: View {
    @Binding var selectedTemplate: TaskTemplate?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TaskTemplateViewModel()
    @State private var searchText = ""
    @State private var selectedCategory: TaskCategory?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.appPrimaryBackground.edgesIgnoringSafeArea(.all)
                
                if viewModel.isLoading {
                    ProgressView("載入模板...")
                } else {
                    ScrollView {
                        VStack(spacing: AppDesignSystem.paddingMedium) {
                            // 搜索欄
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                TextField("搜索模板", text: $searchText)
                                    .textFieldStyle(.plain)
                            }
                            .padding(AppDesignSystem.paddingMedium)
                            .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusSmall)
                            
                            // 分類過濾
                            if !viewModel.defaultTemplates.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        Button {
                                            selectedCategory = nil
                                        } label: {
                                            Text("全部")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(selectedCategory == nil ? .white : .primary)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(selectedCategory == nil ? AppDesignSystem.accentColor : Color.appSecondaryBackground.opacity(0.5))
                                                .cornerRadius(16)
                                        }
                                        
                                        ForEach(TaskCategory.allCases, id: \.self) { cat in
                                            Button {
                                                selectedCategory = cat
                                            } label: {
                                                HStack(spacing: 4) {
                                                    Circle()
                                                        .fill(Color.forCategory(cat))
                                                        .frame(width: 8, height: 8)
                                                    Text(cat.displayName)
                                                        .font(.system(size: 13, weight: .medium))
                                                }
                                                .foregroundColor(selectedCategory == cat ? .white : .primary)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(selectedCategory == cat ? AppDesignSystem.accentColor : Color.appSecondaryBackground.opacity(0.5))
                                                .cornerRadius(16)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, AppDesignSystem.paddingMedium)
                                }
                            }
                            
                            // 模板列表
                            let filteredTemplates = filteredTemplatesList
                            
                            if filteredTemplates.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "doc.text.magnifyingglass")
                                        .font(.system(size: 48))
                                        .foregroundColor(.secondary)
                                    Text("沒有找到模板")
                                        .font(AppDesignSystem.headlineFont)
                                        .foregroundColor(.secondary)
                                    Text("請嘗試其他搜索關鍵字或分類")
                                        .font(AppDesignSystem.captionFont)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.top, 60)
                            } else {
                                LazyVStack(spacing: 12) {
                                    ForEach(filteredTemplates) { template in
                                        TemplateCard(template: template) {
                                            selectedTemplate = template
                                            dismiss()
                                        }
                                    }
                                }
                            }
                        }
                        .padding(AppDesignSystem.paddingMedium)
                    }
                }
            }
            .navigationTitle("選擇模板")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.loadUserTemplates()
                viewModel.loadDefaultTemplates()
            }
        }
    }
    
    private var filteredTemplatesList: [TaskTemplate] {
        var templates = viewModel.templates + viewModel.defaultTemplates
        
        // 分類過濾
        if let category = selectedCategory {
            templates = templates.filter { $0.category == category }
        }
        
        // 搜索過濾
        if !searchText.isEmpty {
            let lowerSearch = searchText.lowercased()
            templates = templates.filter { template in
                template.name.lowercased().contains(lowerSearch) ||
                (template.description?.lowercased().contains(lowerSearch) ?? false) ||
                (template.tags?.contains(where: { $0.lowercased().contains(lowerSearch) }) ?? false)
            }
        }
        
        return templates
    }
}

/// 模板卡片視圖
@available(iOS 17.0, *)
struct TemplateCard: View {
    let template: TaskTemplate
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(template.name)
                            .font(AppDesignSystem.headlineFont)
                            .foregroundColor(.primary)
                        
                        if let description = template.description {
                            Text(description)
                                .font(AppDesignSystem.captionFont)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.forCategory(template.category))
                                .frame(width: 8, height: 8)
                            Text(template.category.displayName)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        if template.usageCount > 0 {
                            Text(template.usageStats)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // 標籤
                if let tags = template.tags, !tags.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(tags.prefix(3), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.system(size: 11))
                                .foregroundColor(AppDesignSystem.accentColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppDesignSystem.accentColor.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
                
                // 子任務預覽
                if let subtasks = template.subtasks, !subtasks.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("包含 \(subtasks.count) 個子任務")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(AppDesignSystem.paddingMedium)
            .glassmorphicCard(cornerRadius: AppDesignSystem.cornerRadiusMedium)
        }
        .buttonStyle(.plain)
    }
}






