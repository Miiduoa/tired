import SwiftUI
import FirebaseAuth

/// 成績列表視圖
@available(iOS 17.0, *)
struct GradeListView: View {
    @StateObject private var viewModel = GradeViewModel()
    let organizationId: String
    let organizationName: String
    let isStudentView: Bool // true = 學員視角, false = 教師視角
    
    @State private var selectedGrade: Grade?
    @State private var showingGradeDetail = false
    @State private var showingStatistics = false
    @State private var showingGradeSummary = false
    @State private var showingGradeItemManagement = false
    
    var body: some View {
        ZStack {
            Color.appPrimaryBackground.ignoresSafeArea()
            
            if viewModel.isLoading {
                ProgressView("載入中...")
            } else if viewModel.filteredGrades.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    VStack(spacing: AppDesignSystem.paddingMedium) {
                        // 總成績摘要卡片
                        if isStudentView, let summary = viewModel.gradeSummary {
                            NavigationLink(destination: GradeSummaryView(
                                summary: summary,
                                organizationName: organizationName
                            )) {
                                gradeSummaryCard(summary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // 篩選器
                        filterSection
                        
                        // 成績列表
                        LazyVStack(spacing: AppDesignSystem.paddingSmall) {
                            ForEach(viewModel.filteredGrades) { grade in
                                GradeRow(grade: grade)
                                    .onTapGesture {
                                        selectedGrade = grade
                                        showingGradeDetail = true
                                    }
                            }
                        }
                    }
                    .padding(.horizontal, AppDesignSystem.paddingMedium)
                    .padding(.vertical, AppDesignSystem.paddingLarge)
                }
                .refreshable {
                    if isStudentView {
                        viewModel.loadStudentGrades(organizationId: organizationId)
                        await viewModel.calculateFinalGrade(organizationId: organizationId)
                    } else {
                        viewModel.loadCourseGrades(organizationId: organizationId, gradeItemId: viewModel.selectedGradeItemId)
                    }
                }
            }
        }
        .navigationTitle("成績")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    if isStudentView {
                        Button(action: {
                            showingGradeSummary = true
                        }) {
                            Image(systemName: "chart.bar.fill")
                        }
                    } else {
                        // 成績項目管理（Moodle-like 功能）
                        Button(action: {
                            showingGradeItemManagement = true
                        }) {
                            Image(systemName: "list.bullet.rectangle.fill")
                        }

                        Button(action: {
                            showingStatistics = true
                        }) {
                            Image(systemName: "chart.pie.fill")
                        }
                    }
                }
            }
        }
        .onAppear {
            // 設定視角模式
            viewModel.isStudentView = isStudentView

            if isStudentView {
                viewModel.loadStudentGrades(organizationId: organizationId)
                viewModel.loadGradeItems(organizationId: organizationId)
                _Concurrency.Task {
                    await viewModel.calculateFinalGrade(organizationId: organizationId)
                }
            } else {
                viewModel.loadCourseGrades(organizationId: organizationId)
                viewModel.loadGradeItems(organizationId: organizationId)
            }
        }
        .sheet(item: $selectedGrade) { grade in
            GradeDetailView(grade: grade, organizationName: organizationName)
        }
        .sheet(isPresented: $showingStatistics) {
            if let statistics = viewModel.gradeStatistics {
                GradeStatisticsView(statistics: statistics, organizationName: organizationName)
            } else {
                ProgressView("載入統計中...")
                    .onAppear {
                        _Concurrency.Task {
                            await viewModel.loadGradeStatistics(organizationId: organizationId)
                        }
                    }
            }
        }
        .sheet(isPresented: $showingGradeSummary) {
            if let summary = viewModel.gradeSummary {
                GradeSummaryView(summary: summary, organizationName: organizationName)
            }
        }
        .sheet(isPresented: $showingGradeItemManagement) {
            NavigationView {
                GradeItemManagementView(
                    organizationId: organizationId,
                    organizationName: organizationName
                )
            }
        }
    }
    
    // MARK: - Views
    
    private var emptyStateView: some View {
        VStack(spacing: AppDesignSystem.paddingLarge) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text(isStudentView ? "尚無成績記錄" : "尚無成績資料")
                .font(AppDesignSystem.headlineFont)
                .foregroundColor(.secondary)
            
            Text(isStudentView ? "您的成績將在此顯示" : "學員的成績將在此顯示")
                .font(AppDesignSystem.captionFont)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func gradeSummaryCard(_ summary: GradeSummary) -> some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.paddingSmall) {
            HStack {
                Text("總成績")
                    .font(AppDesignSystem.headlineFont)
                Spacer()
                if let finalGrade = summary.finalGrade {
                    Text(finalGrade.rawValue)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(Color(hex: gradeColor(for: summary.finalPercentage ?? 0)))
                }
            }
            
            if let percentage = summary.finalPercentage {
                HStack {
                    Text("總百分比")
                        .font(AppDesignSystem.captionFont)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.1f%%", percentage))
                        .font(AppDesignSystem.bodyFont.weight(.semibold))
                }
            }
        }
        .standardCard()
    }
    
    private var filterSection: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.paddingSmall) {
            if !viewModel.gradeItems.isEmpty {
                Menu {
                    Button("全部項目") {
                        viewModel.selectedGradeItemId = nil
                    }
                    ForEach(viewModel.gradeItems) { item in
                        Button(item.name) {
                            viewModel.selectedGradeItemId = item.id
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text(viewModel.selectedGradeItemId == nil ? "全部項目" : viewModel.gradeItems.first(where: { $0.id == viewModel.selectedGradeItemId })?.name ?? "選擇項目")
                        Spacer()
                        Image(systemName: "chevron.down")
                    }
                    .font(AppDesignSystem.bodyFont)
                    .foregroundColor(.primary)
                    .padding(AppDesignSystem.paddingMedium)
                    .background(Color.appSecondaryBackground)
                    .cornerRadius(AppDesignSystem.cornerRadiusSmall)
                }
            }
            
            if !isStudentView {
                Toggle("只顯示已評分", isOn: $viewModel.showOnlyGraded)
                    .font(AppDesignSystem.bodyFont)
            }
        }
    }
    
    private func gradeColor(for percentage: Double) -> String {
        if percentage >= 90 { return "#10B981" }
        if percentage >= 80 { return "#3B82F6" }
        if percentage >= 70 { return "#F59E0B" }
        if percentage >= 60 { return "#F97316" }
        return "#EF4444"
    }
}

// MARK: - Grade Row

struct GradeRow: View {
    let grade: Grade
    
    var body: some View {
        HStack(spacing: AppDesignSystem.paddingMedium) {
            // 成績顯示
            VStack(alignment: .leading, spacing: 4) {
                if let gradeItemName = grade.gradeItemId {
                    Text(gradeItemName)
                        .font(AppDesignSystem.captionFont)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 8) {
                    if let letterGrade = grade.grade {
                        Text(letterGrade.rawValue)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Color(hex: grade.gradeColor))
                    } else if let score = grade.score {
                        Text(String(format: "%.1f", score))
                            .font(.system(size: 20, weight: .semibold))
                        Text("/ \(String(format: "%.0f", grade.maxScore))")
                            .font(AppDesignSystem.captionFont)
                            .foregroundColor(.secondary)
                    } else if let isPass = grade.isPass {
                        Text(isPass ? "通過" : "不通過")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(isPass ? .green : .red)
                    } else {
                        Text("未評分")
                            .font(AppDesignSystem.bodyFont)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let percentage = grade.calculatedPercentage {
                    Text(String(format: "%.1f%%", percentage))
                        .font(AppDesignSystem.captionFont)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 狀態標籤
            VStack(alignment: .trailing, spacing: 4) {
                statusBadge
                
                if let gradedAt = grade.gradedAt {
                    Text(gradedAt, style: .date)
                        .font(AppDesignSystem.captionFont)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(AppDesignSystem.paddingMedium)
        .background(Color.appSecondaryBackground)
        .cornerRadius(AppDesignSystem.cornerRadiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: AppDesignSystem.cornerRadiusMedium)
                .stroke(Color.appCardBorder, lineWidth: 0.5)
        )
    }
    
    private var statusBadge: some View {
        Text(grade.status.displayName)
            .font(AppDesignSystem.captionFont)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(4)
    }
    
    private var statusColor: Color {
        switch grade.status {
        case .pending: return .orange
        case .inProgress: return .blue
        case .graded: return .green
        case .needsRevision: return .red
        case .excused: return .gray
        }
    }
}

// MARK: - Color Extension (使用 ColorExtensions.swift 中的定義)

