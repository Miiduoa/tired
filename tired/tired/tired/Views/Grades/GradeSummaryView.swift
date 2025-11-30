import SwiftUI
import Charts

/// 總成績視圖
@available(iOS 17.0, *)
struct GradeSummaryView: View {
    let summary: GradeSummary
    let organizationName: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appPrimaryBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppDesignSystem.paddingLarge) {
                        // 總成績卡片
                        finalGradeCard
                        
                        // 各項成績列表
                        gradeItemsSection
                    }
                    .padding(.horizontal, AppDesignSystem.paddingMedium)
                    .padding(.vertical, AppDesignSystem.paddingLarge)
                }
            }
            .navigationTitle("總成績")
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
    
    private var finalGradeCard: some View {
        VStack(spacing: AppDesignSystem.paddingLarge) {
            VStack(spacing: AppDesignSystem.paddingSmall) {
                if let finalGrade = summary.finalGrade {
                    Text(finalGrade.rawValue)
                        .font(.system(size: 72, weight: .bold))
                        .foregroundColor(gradeColor(for: summary.finalPercentage ?? 0))
                }
                
                if let percentage = summary.finalPercentage {
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
    
    private var gradeItemsSection: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.paddingMedium) {
            Text("各項成績")
                .font(AppDesignSystem.headlineFont)
                .padding(.horizontal, AppDesignSystem.paddingMedium)
            
            VStack(spacing: AppDesignSystem.paddingSmall) {
                ForEach(summary.gradeItems) { item in
                    GradeItemSummaryRow(item: item)
                }
            }
        }
    }
    
    private func gradeColor(for percentage: Double) -> Color {
        if percentage >= 90 { return Color(hex: "#10B981") }
        if percentage >= 80 { return Color(hex: "#3B82F6") }
        if percentage >= 70 { return Color(hex: "#F59E0B") }
        if percentage >= 60 { return Color(hex: "#F97316") }
        return Color(hex: "#EF4444")
    }
}

// MARK: - Grade Item Summary Row

struct GradeItemSummaryRow: View {
    let item: GradeSummary.GradeItemSummary
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.paddingSmall) {
            HStack {
                Text(item.name)
                    .font(AppDesignSystem.bodyFont.weight(.medium))
                Spacer()
                
                if let score = item.score {
                    Text(String(format: "%.1f / %.1f", score, item.maxScore))
                        .font(AppDesignSystem.bodyFont)
                        .foregroundColor(.secondary)
                } else {
                    Text("未評分")
                        .font(AppDesignSystem.bodyFont)
                        .foregroundColor(.secondary)
                }
            }
            
            if let percentage = item.percentage {
                HStack {
                    Text("百分比")
                        .font(AppDesignSystem.captionFont)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.1f%%", percentage))
                        .font(AppDesignSystem.captionFont.weight(.medium))
                }
                
                HStack {
                    Text("權重")
                        .font(AppDesignSystem.captionFont)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.1f%%", item.weight))
                        .font(AppDesignSystem.captionFont.weight(.medium))
                }
                
                if let weightedScore = item.weightedScore {
                    HStack {
                        Text("加權分數")
                            .font(AppDesignSystem.captionFont)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.1f", weightedScore))
                            .font(AppDesignSystem.captionFont.weight(.semibold))
                            .foregroundColor(Color.appAccent)
                    }
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
}

