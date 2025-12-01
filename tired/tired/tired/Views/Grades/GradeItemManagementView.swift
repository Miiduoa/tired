import SwiftUI
import FirebaseAuth
import Combine

/// 成績項目管理視圖 - Moodle 風格的成績權重管理
@available(iOS 17.0, *)
struct GradeItemManagementView: View {
    @StateObject private var viewModel = GradeItemManagementViewModel()
    let organizationId: String
    let organizationName: String

    @State private var showingAddItem = false
    @State private var editingItem: GradeItem?
    @State private var showingDeleteAlert = false
    @State private var itemToDelete: GradeItem?

    var body: some View {
        ZStack {
            Color.appPrimaryBackground.ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView("載入中...")
            } else {
                ScrollView {
                    VStack(spacing: AppDesignSystem.paddingMedium) {
                        // 總權重警告卡片
                        totalWeightCard

                        // 按分類分組的成績項目
                        if viewModel.gradeItems.isEmpty {
                            emptyStateView
                        } else {
                            gradeItemsByCategory
                        }
                    }
                    .padding(.horizontal, AppDesignSystem.paddingMedium)
                    .padding(.vertical, AppDesignSystem.paddingLarge)
                }
            }
        }
        .navigationTitle("成績項目管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingAddItem = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showingAddItem) {
            GradeItemEditSheet(
                organizationId: organizationId,
                onSave: { newItem in
                    _Concurrency.Task {
                        await viewModel.createGradeItem(newItem)
                    }
                }
            )
        }
        .sheet(item: $editingItem) { item in
            GradeItemEditSheet(
                organizationId: organizationId,
                existingItem: item,
                onSave: { updatedItem in
                    _Concurrency.Task {
                        await viewModel.updateGradeItem(updatedItem)
                    }
                }
            )
        }
        .alert("刪除成績項目", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("刪除", role: .destructive) {
                if let item = itemToDelete {
                    _Concurrency.Task {
                        await viewModel.deleteGradeItem(item)
                        itemToDelete = nil
                    }
                }
            }
        } message: {
            Text("確定要刪除「\(itemToDelete?.name ?? "")」嗎？此操作無法復原。")
        }
        .onAppear {
            viewModel.loadGradeItems(organizationId: organizationId)
        }
    }

    // MARK: - Subviews

    private var totalWeightCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("總權重")
                        .font(AppDesignSystem.captionFont)
                        .foregroundColor(.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", viewModel.totalWeight))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(weightColor)
                        Text("/ 100")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // 權重指示器
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                        .frame(width: 60, height: 60)

                    Circle()
                        .trim(from: 0, to: min(viewModel.totalWeight / 100, 1.0))
                        .stroke(weightColor, lineWidth: 8)
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))

                    Text("\(Int(viewModel.totalWeight))%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(weightColor)
                }
            }

            // 警告訊息
            if abs(viewModel.totalWeight - 100) > 0.1 {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)

                    Text(viewModel.totalWeight < 100 ?
                         "總權重未達 100%，建議調整項目權重" :
                         "總權重超過 100%，請調整項目權重")
                        .font(AppDesignSystem.captionFont)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(AppDesignSystem.paddingMedium)
        .glassmorphicCard()
    }

    private var weightColor: Color {
        let diff = abs(viewModel.totalWeight - 100)
        if diff < 0.1 {
            return .green
        } else if diff < 10 {
            return .orange
        } else {
            return .red
        }
    }

    private var gradeItemsByCategory: some View {
        ForEach(viewModel.categorizedItems.keys.sorted(), id: \.self) { category in
            VStack(alignment: .leading, spacing: AppDesignSystem.paddingSmall) {
                // 分類標題
                HStack {
                    Text(category)
                        .font(AppDesignSystem.bodyFont.weight(.semibold))
                        .foregroundColor(.primary)

                    Spacer()

                    let categoryWeight = viewModel.categorizedItems[category]?
                        .reduce(0.0) { $0 + $1.weight } ?? 0

                    Text(String(format: "%.1f%%", categoryWeight))
                        .font(AppDesignSystem.captionFont)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, AppDesignSystem.paddingSmall)

                // 項目列表
                ForEach(viewModel.categorizedItems[category] ?? []) { item in
                    GradeItemRow(
                        item: item,
                        onEdit: {
                            editingItem = item
                        },
                        onDelete: {
                            itemToDelete = item
                            showingDeleteAlert = true
                        }
                    )
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("尚無成績項目")
                .font(AppDesignSystem.titleFont)
                .foregroundColor(.primary)

            Text("點擊右上角的 + 按鈕新增成績項目")
                .font(AppDesignSystem.bodyFont)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(AppDesignSystem.paddingLarge)
        .frame(maxWidth: .infinity)
        .glassmorphicCard()
    }
}

// MARK: - Grade Item Row

@available(iOS 17.0, *)
struct GradeItemRow: View {
    let item: GradeItem
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: AppDesignSystem.paddingMedium) {
            // 左側：名稱和描述
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(AppDesignSystem.bodyFont.weight(.semibold))
                    .foregroundColor(.primary)

                if let description = item.description, !description.isEmpty {
                    Text(description)
                        .font(AppDesignSystem.captionFont)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                // 元資訊
                HStack(spacing: 8) {
                    // 滿分
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                        Text("\(Int(item.maxScore)) 分")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.secondary)

                    // 截止日期
                    if let dueDate = item.dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                            Text(dueDate.formatShort())
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.secondary)
                    }

                    // 必做標記
                    if item.isRequired {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 10))
                            Text("必做")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.red)
                    }
                }
            }

            Spacer()

            // 右側：權重和操作
            VStack(alignment: .trailing, spacing: 8) {
                // 權重徽章
                Text(String(format: "%.1f%%", item.weight))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppDesignSystem.accentColor)
                    .cornerRadius(8)

                // 操作按鈕
                HStack(spacing: 12) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }

                    Button(action: onDelete) {
                        Image(systemName: "trash.circle.fill")
                            .font(.title3)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding(AppDesignSystem.paddingMedium)
        .glassmorphicCard()
    }
}

// MARK: - Grade Item Edit Sheet

@available(iOS 17.0, *)
struct GradeItemEditSheet: View {
    let organizationId: String
    var existingItem: GradeItem?
    let onSave: (GradeItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var category: String
    @State private var weight: Double
    @State private var maxScore: Double
    @State private var dueDate: Date
    @State private var hasDueDate: Bool
    @State private var isRequired: Bool
    @State private var description: String

    init(organizationId: String, existingItem: GradeItem? = nil, onSave: @escaping (GradeItem) -> Void) {
        self.organizationId = organizationId
        self.existingItem = existingItem
        self.onSave = onSave

        // 初始化狀態
        _name = State(initialValue: existingItem?.name ?? "")
        _category = State(initialValue: existingItem?.category ?? "作業")
        _weight = State(initialValue: existingItem?.weight ?? 10.0)
        _maxScore = State(initialValue: existingItem?.maxScore ?? 100.0)
        _dueDate = State(initialValue: existingItem?.dueDate ?? Date())
        _hasDueDate = State(initialValue: existingItem?.dueDate != nil)
        _isRequired = State(initialValue: existingItem?.isRequired ?? true)
        _description = State(initialValue: existingItem?.description ?? "")
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.appPrimaryBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppDesignSystem.paddingLarge) {
                        // 基本資訊
                        VStack(alignment: .leading, spacing: AppDesignSystem.paddingMedium) {
                            Text("基本資訊")
                                .font(AppDesignSystem.bodyFont.weight(.semibold))

                            // 名稱
                            VStack(alignment: .leading, spacing: 8) {
                                Text("項目名稱")
                                    .font(AppDesignSystem.captionFont)
                                    .foregroundColor(.secondary)

                                TextField("例如：期中考試", text: $name)
                                    .textFieldStyle(.roundedBorder)
                            }

                            // 分類
                            VStack(alignment: .leading, spacing: 8) {
                                Text("分類")
                                    .font(AppDesignSystem.captionFont)
                                    .foregroundColor(.secondary)

                                Menu {
                                    ForEach(GradeItemCategory.allCases, id: \.self) { cat in
                                        Button(cat.displayName) {
                                            category = cat.rawValue
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(category)
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                    }
                                    .padding()
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            }

                            // 描述
                            VStack(alignment: .leading, spacing: 8) {
                                Text("描述（可選）")
                                    .font(AppDesignSystem.captionFont)
                                    .foregroundColor(.secondary)

                                TextEditor(text: $description)
                                    .frame(height: 80)
                                    .padding(8)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(AppDesignSystem.paddingMedium)
                        .glassmorphicCard()

                        // 評分設定
                        VStack(alignment: .leading, spacing: AppDesignSystem.paddingMedium) {
                            Text("評分設定")
                                .font(AppDesignSystem.bodyFont.weight(.semibold))

                            // 權重
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("權重")
                                        .font(AppDesignSystem.captionFont)
                                        .foregroundColor(.secondary)

                                    Spacer()

                                    Text(String(format: "%.1f%%", weight))
                                        .font(AppDesignSystem.bodyFont.weight(.bold))
                                        .foregroundColor(AppDesignSystem.accentColor)
                                }

                                HStack(spacing: 12) {
                                    Slider(value: $weight, in: 0...100, step: 0.5)

                                    Text(String(format: "%.1f", weight))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .frame(width: 50)
                                }
                            }

                            // 滿分
                            VStack(alignment: .leading, spacing: 8) {
                                Text("滿分")
                                    .font(AppDesignSystem.captionFont)
                                    .foregroundColor(.secondary)

                                HStack(spacing: 12) {
                                    Slider(value: $maxScore, in: 1...200, step: 1)

                                    Text("\(Int(maxScore))")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .frame(width: 50)
                                }
                            }
                        }
                        .padding(AppDesignSystem.paddingMedium)
                        .glassmorphicCard()

                        // 其他設定
                        VStack(alignment: .leading, spacing: AppDesignSystem.paddingMedium) {
                            Text("其他設定")
                                .font(AppDesignSystem.bodyFont.weight(.semibold))

                            // 截止日期
                            Toggle(isOn: $hasDueDate) {
                                Text("設定截止日期")
                                    .font(AppDesignSystem.bodyFont)
                            }

                            if hasDueDate {
                                DatePicker(
                                    "截止日期",
                                    selection: $dueDate,
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                                .datePickerStyle(.compact)
                            }

                            // 必做項目
                            Toggle(isOn: $isRequired) {
                                Text("必做項目")
                                    .font(AppDesignSystem.bodyFont)
                            }
                        }
                        .padding(AppDesignSystem.paddingMedium)
                        .glassmorphicCard()
                    }
                    .padding(.horizontal, AppDesignSystem.paddingMedium)
                    .padding(.vertical, AppDesignSystem.paddingLarge)
                }
            }
            .navigationTitle(existingItem == nil ? "新增成績項目" : "編輯成績項目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("儲存") {
                        saveItem()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }

    private func saveItem() {
        let item = GradeItem(
            id: existingItem?.id,
            organizationId: organizationId,
            name: name,
            category: category,
            weight: weight,
            maxScore: maxScore,
            dueDate: hasDueDate ? dueDate : nil,
            isRequired: isRequired,
            description: description.isEmpty ? nil : description,
            createdAt: existingItem?.createdAt ?? Date(),
            updatedAt: Date()
        )

        onSave(item)
        dismiss()
    }
}

// MARK: - Grade Item Categories

enum GradeItemCategory: String, CaseIterable {
    case homework = "作業"
    case exam = "考試"
    case quiz = "小測驗"
    case project = "專題"
    case participation = "課堂參與"
    case other = "其他"

    var displayName: String {
        return rawValue
    }
}

// MARK: - View Model

@MainActor
class GradeItemManagementViewModel: ObservableObject {
    @Published var gradeItems: [GradeItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let gradeService = GradeService()
    private var cancellables = Set<AnyCancellable>()

    var totalWeight: Double {
        gradeItems.reduce(0.0) { $0 + $1.weight }
    }

    var categorizedItems: [String: [GradeItem]] {
        Dictionary(grouping: gradeItems) { item in
            item.category ?? "未分類"
        }
    }

    func loadGradeItems(organizationId: String) {
        isLoading = true
        cancellables.removeAll()

        gradeService.getGradeItems(organizationId: organizationId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = "載入成績項目失敗：\(error.localizedDescription)"
                    }
                },
                receiveValue: { [weak self] items in
                    self?.gradeItems = items
                }
            )
            .store(in: &cancellables)
    }

    func createGradeItem(_ item: GradeItem) async {
        do {
            _ = try await gradeService.createGradeItem(item)
            ToastManager.shared.showToast(message: "成績項目已新增", type: .success)
        } catch {
            errorMessage = "新增成績項目失敗：\(error.localizedDescription)"
            ToastManager.shared.showToast(message: "新增失敗：\(error.localizedDescription)", type: .error)
        }
    }

    func updateGradeItem(_ item: GradeItem) async {
        guard let itemId = item.id else { return }

        do {
            let updates: [String: Any] = [
                "name": item.name,
                "category": item.category ?? "",
                "weight": item.weight,
                "maxScore": item.maxScore,
                "dueDate": item.dueDate as Any,
                "isRequired": item.isRequired,
                "description": item.description as Any,
                "updatedAt": Date()
            ]

            try await gradeService.updateGradeItem(itemId: itemId, updates: updates)
            ToastManager.shared.showToast(message: "成績項目已更新", type: .success)
        } catch {
            errorMessage = "更新成績項目失敗：\(error.localizedDescription)"
            ToastManager.shared.showToast(message: "更新失敗：\(error.localizedDescription)", type: .error)
        }
    }

    func deleteGradeItem(_ item: GradeItem) async {
        guard let itemId = item.id else { return }

        do {
            try await gradeService.deleteGradeItem(itemId: itemId)
            ToastManager.shared.showToast(message: "成績項目已刪除", type: .success)
        } catch {
            errorMessage = "刪除成績項目失敗：\(error.localizedDescription)"
            ToastManager.shared.showToast(message: "刪除失敗：\(error.localizedDescription)", type: .error)
        }
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
struct GradeItemManagementView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            GradeItemManagementView(
                organizationId: "test-org",
                organizationName: "測試課程"
            )
        }
    }
}
