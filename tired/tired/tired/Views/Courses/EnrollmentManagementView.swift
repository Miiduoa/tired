import SwiftUI

/// 選課管理視圖
/// 供教師管理課程的選課名單、變更角色、審核申請
@available(iOS 17.0, *)
struct EnrollmentManagementView: View {
    let courseId: String
    
    @StateObject private var viewModel: EnrollmentManagementViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showImportSheet = false
    @State private var showExportSheet = false
    @State private var selectedEnrollment: EnrollmentWithUser?
    @State private var showRoleSheet = false
    
    init(courseId: String) {
        self.courseId = courseId
        _viewModel = StateObject(wrappedValue: EnrollmentManagementViewModel())
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 統計摘要
                statisticsHeader
                
                Divider()
                
                // 篩選器
                filterSection
                
                // 選課列表
                if viewModel.isLoading && viewModel.enrollmentsWithUsers.isEmpty {
                    ProgressView("載入中...")
                        .frame(maxHeight: .infinity)
                } else if viewModel.filteredEnrollments.isEmpty {
                    emptyView
                } else {
                    enrollmentList
                }
            }
            .navigationTitle("選課管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    moreMenu
                }
            }
            .sheet(isPresented: $showRoleSheet) {
                if let enrollment = selectedEnrollment {
                    roleChangeSheet(for: enrollment)
                }
            }
            .alert("錯誤", isPresented: $viewModel.showError) {
                Button("確定", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "發生未知錯誤")
            }
            .task {
                await viewModel.loadEnrollments(courseId: courseId)
            }
            .refreshable {
                await viewModel.refresh(courseId: courseId)
            }
        }
    }
    
    // MARK: - Statistics Header
    
    private var statisticsHeader: some View {
        VStack(spacing: 12) {
            // 總人數
            HStack {
                Text("總選課人數")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(viewModel.statistics.totalEnrollments)")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            // 角色分佈
            HStack(spacing: 16) {
                roleStatCard(
                    title: "教師",
                    count: viewModel.statistics.teacherCount,
                    color: .red
                )
                
                roleStatCard(
                    title: "助教",
                    count: viewModel.statistics.taCount,
                    color: .orange
                )
                
                roleStatCard(
                    title: "學生",
                    count: viewModel.statistics.studentCount,
                    color: .blue
                )
                
                roleStatCard(
                    title: "旁聽",
                    count: viewModel.statistics.observerCount,
                    color: .gray
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private func roleStatCard(title: String, count: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.headline)
                .foregroundColor(color)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Filter Section
    
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // 角色篩選
                Menu {
                    Button("全部角色") {
                        viewModel.selectedRoleFilter = nil
                    }
                    ForEach(CourseRole.allCases, id: \.self) { role in
                        Button(role.displayName) {
                            viewModel.selectedRoleFilter = role
                        }
                    }
                } label: {
                    Label(
                        viewModel.selectedRoleFilter?.displayName ?? "全部角色",
                        systemImage: "person.2"
                    )
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                // 狀態篩選
                Menu {
                    Button("全部狀態") {
                        viewModel.selectedStatusFilter = nil
                    }
                    ForEach(EnrollmentStatus.allCases, id: \.self) { status in
                        Button(status.displayName) {
                            viewModel.selectedStatusFilter = status
                        }
                    }
                } label: {
                    Label(
                        viewModel.selectedStatusFilter?.displayName ?? "全部狀態",
                        systemImage: "checkmark.circle"
                    )
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Enrollment List
    
    private var enrollmentList: some View {
        List {
            // 按角色分組
            ForEach(Array(viewModel.enrollmentsByRole.keys.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { role in
                if let enrollments = viewModel.enrollmentsByRole[role], !enrollments.isEmpty {
                    Section(header: Text(role.displayName)) {
                        ForEach(enrollments) { enrollmentWithUser in
                            enrollmentRow(enrollmentWithUser)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    swipeActions(for: enrollmentWithUser)
                                }
                        }
                    }
                }
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "搜索姓名或 Email")
    }
    
    @ViewBuilder
    private func enrollmentRow(_ enrollmentWithUser: EnrollmentWithUser) -> some View {
        HStack(spacing: 12) {
            // 頭像
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "person.fill")
                        .foregroundColor(.white)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                // 姓名
                Text(enrollmentWithUser.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                // Email
                if let email = enrollmentWithUser.email {
                    Text(email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // 選課時間
                Text("加入時間：\(formatDate(enrollmentWithUser.enrollment.enrolledAt))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                // 角色徽章
                RoleBadge(role: enrollmentWithUser.enrollment.role)
                
                // 狀態
                Text(enrollmentWithUser.enrollment.status.displayName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedEnrollment = enrollmentWithUser
            showRoleSheet = true
        }
    }
    
    // MARK: - Swipe Actions
    
    @ViewBuilder
    private func swipeActions(for enrollment: EnrollmentWithUser) -> some View {
        // 變更角色
        Button(action: {
            selectedEnrollment = enrollment
            showRoleSheet = true
        }) {
            Label("角色", systemImage: "person.badge.key")
        }
        .tint(.blue)
        
        // 移除成員
        Button(role: .destructive, action: {
            Task {
                await viewModel.removeMember(enrollment)
            }
        }) {
            Label("移除", systemImage: "trash")
        }
    }
    
    // MARK: - Role Change Sheet
    
    @ViewBuilder
    private func roleChangeSheet(for enrollment: EnrollmentWithUser) -> some View {
        NavigationStack {
            List {
                Section("選擇新角色") {
                    ForEach(CourseRole.allCases, id: \.self) { role in
                        Button(action: {
                            Task {
                                await viewModel.changeMemberRole(enrollment, newRole: role)
                                showRoleSheet = false
                            }
                        }) {
                            HStack {
                                Label(role.displayName, systemImage: role.icon)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if enrollment.enrollment.role == role {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
                
                Section("權限說明") {
                    Text("教師：完整權限，可管理課程和評分")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("助教：協助教學，可評分和管理內容")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("學生：基本學習權限，可繳交作業")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("旁聽生：只能查看課程內容")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("變更角色")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showRoleSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Empty View
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("沒有符合條件的選課記錄")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - More Menu
    
    private var moreMenu: some View {
        Menu {
            Button(action: { showImportSheet = true }) {
                Label("批次匯入學生", systemImage: "square.and.arrow.down")
            }
            
            Button(action: { exportToCSV() }) {
                Label("匯出名單", systemImage: "square.and.arrow.up")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
    
    // MARK: - Helper Functions
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter.string(from: date)
    }
    
    private func exportToCSV() {
        let csv = viewModel.exportStudentsCSV()
        
        // 在實際應用中，這裡應該使用 UIActivityViewController 分享 CSV
        // 這裡只是示範
        UIPasteboard.general.string = csv
        
        // TODO: 實作完整的匯出功能
    }
}

#Preview {
    EnrollmentManagementView(courseId: "preview-course-id")
}
