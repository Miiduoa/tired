import SwiftUI

/// 成績詳情視圖
@available(iOS 17.0, *)
struct GradeDetailView: View {
    let grade: Grade
    let organizationName: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appPrimaryBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppDesignSystem.paddingLarge) {
                        // 成績卡片
                        gradeCard
                        
                        // 評分資訊
                        if grade.isGraded {
                            gradingInfoSection
                        }
                        
                        // 評語和反饋
                        if let feedback = grade.feedback, !feedback.isEmpty {
                            feedbackSection(feedback)
                        }
                        
                        // 評分標準細項
                        if let rubricScores = grade.rubricScores, !rubricScores.isEmpty {
                            rubricSection(rubricScores)
                        }
                        
                        // 狀態資訊
                        statusSection
                    }
                    .padding(.horizontal, AppDesignSystem.paddingMedium)
                    .padding(.vertical, AppDesignSystem.paddingLarge)
                }
            }
            .navigationTitle("成績詳情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Views
    
    private var gradeCard: some View {
        VStack(spacing: AppDesignSystem.paddingMedium) {
            // 主要成績顯示
            VStack(spacing: AppDesignSystem.paddingSmall) {
                if let letterGrade = grade.grade {
                    Text(letterGrade.rawValue)
                        .font(.system(size: 64, weight: .bold))
                        .foregroundColor(Color(hex: self.grade.gradeColor))
                } else if let score = grade.score {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", score))
                            .font(.system(size: 48, weight: .bold))
                        Text("/ \(String(format: "%.0f", grade.maxScore))")
                            .font(.system(size: 24, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                } else if let isPass = grade.isPass {
                    Text(isPass ? "通過" : "不通過")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(isPass ? .green : .red)
                } else {
                    Text("未評分")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                
                if let percentage = grade.calculatedPercentage {
                    Text(String(format: "%.1f%%", percentage))
                        .font(AppDesignSystem.headlineFont)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, AppDesignSystem.paddingLarge)
        }
        .frame(maxWidth: .infinity)
        .standardCard()
    }
    
    private var gradingInfoSection: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.paddingMedium) {
            Text("評分資訊")
                .font(AppDesignSystem.headlineFont)
            
            VStack(spacing: AppDesignSystem.paddingSmall) {
                if let gradedAt = grade.gradedAt {
                    GradeInfoRow(label: "評分時間", value: gradedAt.formatted(date: .abbreviated, time: .shortened))
                }
                
                GradeInfoRow(label: "評分狀態", value: grade.status.displayName)
                
                if grade.isReleased {
                    GradeInfoRow(label: "發布狀態", value: "已發布", valueColor: .green)
                } else {
                    GradeInfoRow(label: "發布狀態", value: "未發布", valueColor: .orange)
                }
            }
        }
        .standardCard()
    }
    
    private func feedbackSection(_ feedback: String) -> some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.paddingMedium) {
            Text("評語")
                .font(AppDesignSystem.headlineFont)
            
            Text(feedback)
                .font(AppDesignSystem.bodyFont)
                .foregroundColor(.primary)
                .padding(AppDesignSystem.paddingMedium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appPrimaryBackground)
                .cornerRadius(AppDesignSystem.cornerRadiusSmall)
        }
        .standardCard()
    }
    
    private func rubricSection(_ rubricScores: [RubricScore]) -> some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.paddingMedium) {
            Text("評分標準細項")
                .font(AppDesignSystem.headlineFont)
            
            VStack(spacing: AppDesignSystem.paddingSmall) {
                ForEach(rubricScores) { rubric in
                    RubricRow(rubric: rubric)
                }
            }
        }
        .standardCard()
    }
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.paddingMedium) {
            Text("狀態資訊")
                .font(AppDesignSystem.headlineFont)
            
            VStack(spacing: AppDesignSystem.paddingSmall) {
                GradeInfoRow(label: "組織", value: organizationName)
                
                if let taskId = grade.taskId {
                    GradeInfoRow(label: "關聯任務", value: taskId)
                }
                
                GradeInfoRow(label: "創建時間", value: grade.createdAt.formatted(date: .abbreviated, time: .shortened))
                GradeInfoRow(label: "更新時間", value: grade.updatedAt.formatted(date: .abbreviated, time: .shortened))
            }
        }
        .standardCard()
    }
}

// MARK: - Supporting Views

struct GradeInfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary
    
    var body: some View {
        HStack {
            Text(label)
                .font(AppDesignSystem.bodyFont)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(AppDesignSystem.bodyFont.weight(.medium))
                .foregroundColor(valueColor)
        }
        .padding(.vertical, 4)
    }
}

struct RubricRow: View {
    let rubric: RubricScore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(rubric.criterion)
                    .font(AppDesignSystem.bodyFont.weight(.medium))
                Spacer()
                Text(String(format: "%.1f / %.1f", rubric.score, rubric.maxScore))
                    .font(AppDesignSystem.bodyFont)
                    .foregroundColor(.secondary)
            }
            
            if let feedback = rubric.feedback, !feedback.isEmpty {
                Text(feedback)
                    .font(AppDesignSystem.captionFont)
                    .foregroundColor(.secondary)
                    .padding(.leading, AppDesignSystem.paddingSmall)
            }
            
            // 進度條
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.appPrimaryBackground)
                        .frame(height: 4)
                    
                    Rectangle()
                        .fill(Color.appAccent)
                        .frame(width: geometry.size.width * CGFloat(rubric.score / rubric.maxScore), height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding(AppDesignSystem.paddingMedium)
        .background(Color.appPrimaryBackground)
        .cornerRadius(AppDesignSystem.cornerRadiusSmall)
    }
}

