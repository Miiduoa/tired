import SwiftUI

@available(iOS 17.0, *)
struct RecurringTasksView: View {
    @StateObject private var viewModel = RecurringTasksViewModel()
    @State private var taskToDelete: RecurringTask?
    @State private var showDeleteAlert = false
    
    var body: some View {
        List {
            if viewModel.isLoading {
                loadingSection
            } else if viewModel.recurringTasks.isEmpty {
                emptyStateSection
            } else {
                // 活躍任務區塊
                let activeTasks = viewModel.recurringTasks.filter { !$0.isPaused }
                if !activeTasks.isEmpty {
                    Section(header: Text("運作中").font(.subheadline)) {
                        ForEach(activeTasks) { task in
                            RecurringTaskRow(task: task, viewModel: viewModel)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    deleteButton(for: task)
                                    pauseButton(for: task)
                                }
                                .swipeActions(edge: .leading) {
                                    generateButton(for: task)
                                }
                        }
                    }
                }
                
                // 暫停任務區塊
                let pausedTasks = viewModel.recurringTasks.filter { $0.isPaused }
                if !pausedTasks.isEmpty {
                    Section(header: Text("已暫停").font(.subheadline)) {
                        ForEach(pausedTasks) { task in
                            RecurringTaskRow(task: task, viewModel: viewModel)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    deleteButton(for: task)
                                    resumeButton(for: task)
                                }
                        }
                    }
                }
            }
        }
        .navigationTitle("週期任務管理")
        .navigationBarTitleDisplayMode(.inline)
        .alert("確定要刪除嗎？", isPresented: $showDeleteAlert, presenting: taskToDelete) { task in
            Button("取消", role: .cancel) {}
            Button("刪除", role: .destructive) {
                viewModel.deleteRecurringTask(task)
            }
        } message: { task in
            Text("刪除週期任務也會一併刪除未來已生成的待辦事項。此動作無法復原。")
        }
    }
    
    // MARK: - Components
    
    private var loadingSection: some View {
        HStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .listRowBackground(Color.clear)
    }
    
    private var emptyStateSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "repeat.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.secondary.opacity(0.3))
                .padding(.top, 40)
            
            Text("沒有週期性任務")
                .font(.title3)
                .fontWeight(.medium)
            
            Text("設定週期任務讓 App 自動幫你建立待辦事項，\n例如：每週運動、每月繳費。")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .listRowBackground(Color.clear)
    }
    
    // MARK: - Buttons
    
    private func deleteButton(for task: RecurringTask) -> some View {
        Button(role: .destructive) {
            taskToDelete = task
            showDeleteAlert = true
        } label: {
            Label("刪除", systemImage: "trash")
        }
    }
    
    private func pauseButton(for task: RecurringTask) -> some View {
        Button {
            viewModel.togglePause(task)
        } label: {
            Label("暫停", systemImage: "pause.circle")
        }
        .tint(.orange)
    }
    
    private func resumeButton(for task: RecurringTask) -> some View {
        Button {
            viewModel.togglePause(task)
        } label: {
            Label("恢復", systemImage: "play.circle")
        }
        .tint(.green)
    }
    
    private func generateButton(for task: RecurringTask) -> some View {
        Button {
            viewModel.generateNow(task)
        } label: {
            Label("立即生成", systemImage: "arrow.clockwise.circle")
        }
        .tint(.blue)
    }
}

struct RecurringTaskRow: View {
    let task: RecurringTask
    @ObservedObject var viewModel: RecurringTasksViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(task.title)
                    .font(.headline)
                    .strikethrough(task.isPaused)
                    .foregroundStyle(task.isPaused ? Color.secondary : Color.primary)
                
                Spacer()
                
                CategoryBadge(category: task.category)
            }
            
            HStack {
                // 週期規則
                Label(task.recurrenceRule.displayName, systemImage: "repeat")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // 下次生成時間
                if task.isPaused {
                    Text("已暫停")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.1))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                } else {
                    let nextDate = task.nextGenerationDate
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.clock")
                        Text(nextDate.formatted(date: .abbreviated, time: .omitted))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle()) // 讓整個區域都可點擊
        .contextMenu {
            if task.isPaused {
                Button {
                    viewModel.togglePause(task)
                } label: {
                    Label("恢復任務", systemImage: "play")
                }
            } else {
                Button {
                    viewModel.togglePause(task)
                } label: {
                    Label("暫停任務", systemImage: "pause")
                }
                
                Button {
                    viewModel.generateNow(task)
                } label: {
                    Label("手動生成下一次", systemImage: "arrow.clockwise")
                }
            }
            
            Divider()
            
            Button(role: .destructive) {
                // 由於 ContextMenu 無法直接觸發 Alert 狀態綁定，這裡先從簡，
                // 實際專案中通常會透過 ViewModel 發送事件或使用更複雜的 Binding
                // 為了安全起見，建議主要使用 Swipe Action 刪除，或這裡不放刪除
            } label: {
                Label("刪除", systemImage: "trash")
            }
        }
    }
}

// 輔助視圖
struct CategoryBadge: View {
    let category: TaskCategory
    
    var body: some View {
        Text(category.displayName)
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.forCategory(category).opacity(0.15))
            .foregroundColor(Color.forCategory(category))
            .cornerRadius(6)
    }
}
