import SwiftUI
import Charts

/// 成績統計視圖
@available(iOS 17.0, *)
struct GradeStatisticsView: View {
    let statistics: GradeStatistics
    let organizationName: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appPrimaryBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppDesignSystem.paddingLarge) {
                        // 統計摘要卡片
                        statisticsSummaryCards
                        
                        // 成績分布圖表
                        if !statistics.distribution.isEmpty {
                            distributionChart
                        }
                    }
                    .padding(.horizontal, AppDesignSystem.paddingMedium)
                    .padding(.vertical, AppDesignSystem.paddingLarge)
                }
            }
            .navigationTitle("成績統計")
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
    
    private var statisticsSummaryCards: some View {
        VStack(spacing: AppDesignSystem.paddingMedium) {
            HStack(spacing: AppDesignSystem.paddingMedium) {
                StatCard(
                    title: "總學生數",
                    value: "\(statistics.totalStudents)",
                    icon: "person.3.fill",
                    color: .blue
                )
                
                StatCard(
                    title: "已評分數",
                    value: "\(statistics.gradedCount)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
            }
            
            if let averageScore = statistics.averageScore {
                HStack(spacing: AppDesignSystem.paddingMedium) {
                    StatCard(
                        title: "平均分",
                        value: String(format: "%.1f", averageScore),
                        icon: "chart.bar.fill",
                        color: .orange
                    )
                    
                    if let medianScore = statistics.medianScore {
                        StatCard(
                            title: "中位數",
                            value: String(format: "%.1f", medianScore),
                            icon: "chart.line.uptrend.xyaxis",
                            color: .purple
                        )
                    }
                }
            }
            
            if let highestScore = statistics.highestScore,
               let lowestScore = statistics.lowestScore {
                HStack(spacing: AppDesignSystem.paddingMedium) {
                    StatCard(
                        title: "最高分",
                        value: String(format: "%.1f", highestScore),
                        icon: "arrow.up.circle.fill",
                        color: .green
                    )
                    
                    StatCard(
                        title: "最低分",
                        value: String(format: "%.1f", lowestScore),
                        icon: "arrow.down.circle.fill",
                        color: .red
                    )
                }
            }
            
            if let passRate = statistics.passRate {
                StatCard(
                    title: "通過率",
                    value: String(format: "%.1f%%", passRate),
                    icon: "percent",
                    color: .teal
                )
            }
        }
    }
    
    private var distributionChart: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.paddingMedium) {
            Text("成績分布")
                .font(AppDesignSystem.headlineFont)
            
            VStack(alignment: .leading, spacing: AppDesignSystem.paddingSmall) {
                ForEach(statistics.distribution, id: \.grade) { dist in
                    DistributionRow(distribution: dist)
                }
            }
        }
        .standardCard()
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: AppDesignSystem.paddingSmall) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
            
            Text(title)
                .font(AppDesignSystem.captionFont)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(AppDesignSystem.paddingMedium)
        .background(Color.appSecondaryBackground)
        .cornerRadius(AppDesignSystem.cornerRadiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: AppDesignSystem.cornerRadiusMedium)
                .stroke(Color.appCardBorder, lineWidth: 0.5)
        )
    }
}

struct DistributionRow: View {
    let distribution: GradeStatistics.GradeDistribution
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(distribution.grade.rawValue)
                    .font(AppDesignSystem.bodyFont.weight(.medium))
                    .frame(width: 40, alignment: .leading)
                
                Text("\(distribution.count) 人")
                    .font(AppDesignSystem.bodyFont)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(String(format: "%.1f%%", distribution.percentage))
                    .font(AppDesignSystem.bodyFont.weight(.medium))
                    .foregroundColor(Color.appAccent)
            }
            
            // 進度條
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.appPrimaryBackground)
                        .frame(height: 8)
                    
                    Rectangle()
                        .fill(Color.appAccent)
                        .frame(width: geometry.size.width * CGFloat(distribution.percentage / 100), height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(AppDesignSystem.paddingMedium)
        .background(Color.appPrimaryBackground)
        .cornerRadius(AppDesignSystem.cornerRadiusSmall)
    }
}

